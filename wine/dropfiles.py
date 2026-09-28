"""Drop files onto one KakaoTalk chat window, as if dragged from Explorer (runs inside Wine).

  python dropfiles.py --target <title> <x> <y> <w> <h> <unix path>...
  python dropfiles.py --probe <outfile> <title> <x> <y> <w> <h>

The target is the window Hyprland has focused (hyprctl activewindow: title, at, size), not
GetForegroundWindow, which can name a different chat window. It must be exactly one visible
top-level window that accepts file drops (WS_EX_ACCEPTFILES), with that title and a window rect
within 2 px of x, y, x+w, y+h on each edge. Zero or several matches drop nothing.

KakaoTalk's Ctrl+V never looks for files on the clipboard (only bitmap, text and its own
formats), but its chat windows accept WM_DROPFILES. The DROPFILES block is written into
KakaoTalk's own address space so the HDROP it receives is valid there. The message is sent with
SendMessageTimeout; once KakaoTalk has handled it, the block is freed. On timeout it is left in
place, since KakaoTalk may still read it.

--probe only looks: it writes "MATCH 0x<hwnd>" or "NO_MATCH" to <outfile> (a Windows path such as
Z:/tmp/probe.txt, because Wine's stdout is not captured reliably) and sends nothing.
Exit status: 0 dropped (or matched), 3 no single matching window, 4 KakaoTalk did not handle the
drop within 5 s.
"""
import ctypes
import struct
import sys
from ctypes import wintypes

WM_DROPFILES = 0x0233
WS_EX_ACCEPTFILES = 0x10
GWL_EXSTYLE = -20
PROCESS_VM_OPERATION = 0x0008
PROCESS_VM_WRITE = 0x0020
MEM_COMMIT_RESERVE = 0x3000
MEM_RELEASE = 0x8000
PAGE_READWRITE = 0x04
SMTO_ABORTIFHUNG = 0x0002
SEND_TIMEOUT_MS = 5000
TOLERANCE_PX = 2

u32 = ctypes.WinDLL("user32", use_last_error=True)
k32 = ctypes.WinDLL("kernel32", use_last_error=True)
WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
u32.EnumWindows.argtypes = [WNDENUMPROC, wintypes.LPARAM]
u32.IsWindowVisible.argtypes = [wintypes.HWND]
u32.GetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int]
u32.GetWindowTextLengthW.argtypes = [wintypes.HWND]
u32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
u32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
u32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
u32.SendMessageTimeoutW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM,
                                    wintypes.UINT, wintypes.UINT, ctypes.POINTER(ctypes.c_size_t)]
u32.SendMessageTimeoutW.restype = ctypes.c_ssize_t
k32.OpenProcess.restype = wintypes.HANDLE
k32.VirtualAllocEx.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_size_t, wintypes.DWORD, wintypes.DWORD]
k32.VirtualAllocEx.restype = ctypes.c_void_p
k32.VirtualFreeEx.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_size_t, wintypes.DWORD]
k32.WriteProcessMemory.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                   ctypes.POINTER(ctypes.c_size_t)]
k32.CloseHandle.argtypes = [wintypes.HANDLE]


def fail(msg):
    raise SystemExit(f"{msg}: error {ctypes.get_last_error()}")


def find_windows(title, x, y, w, h):
    """Visible top-level drop targets with this title and rect (x, y, x+w, y+h) within tolerance."""
    want = (x, y, x + w, y + h)
    found = []

    def check(hwnd, _):
        if not u32.IsWindowVisible(hwnd) or not u32.GetWindowLongW(hwnd, GWL_EXSTYLE) & WS_EX_ACCEPTFILES:
            return True
        buf = ctypes.create_unicode_buffer(u32.GetWindowTextLengthW(hwnd) + 1)
        u32.GetWindowTextW(hwnd, buf, len(buf))
        rect = wintypes.RECT()
        if buf.value == title and u32.GetWindowRect(hwnd, ctypes.byref(rect)):
            have = (rect.left, rect.top, rect.right, rect.bottom)
            if all(abs(a - b) <= TOLERANCE_PX for a, b in zip(have, want)):
                found.append(hwnd)
        return True

    u32.EnumWindows(WNDENUMPROC(check), 0)
    return found


def drop(hwnd, unix_paths):
    # Z: is mapped to / in this prefix.
    dos_paths = ["Z:" + p.replace("/", "\\") for p in unix_paths]
    # DROPFILES {pFiles, pt.x, pt.y, fNC, fWide} + double-NUL-terminated UTF-16 list.
    data = struct.pack("<IiiII", 20, 0, 0, 0, 1) + "".join(p + "\0" for p in dos_paths).encode("utf-16-le") + b"\0\0"
    pid = wintypes.DWORD()
    u32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    proc = k32.OpenProcess(PROCESS_VM_OPERATION | PROCESS_VM_WRITE, False, pid.value)
    if not proc:
        fail("OpenProcess")
    try:
        remote = k32.VirtualAllocEx(proc, None, len(data), MEM_COMMIT_RESERVE, PAGE_READWRITE)
        if not remote:
            fail("VirtualAllocEx")
        buf = ctypes.create_string_buffer(data, len(data))
        if not k32.WriteProcessMemory(proc, remote, buf, len(data), None):
            k32.VirtualFreeEx(proc, remote, 0, MEM_RELEASE)
            fail("WriteProcessMemory")
        result = ctypes.c_size_t()
        if not u32.SendMessageTimeoutW(hwnd, WM_DROPFILES, remote, 0, SMTO_ABORTIFHUNG, SEND_TIMEOUT_MS,
                                       ctypes.byref(result)):
            # KakaoTalk may still read the block later, so it is left allocated.
            print(f"WM_DROPFILES not handled within {SEND_TIMEOUT_MS} ms: error {ctypes.get_last_error()}",
                  file=sys.stderr)
            sys.exit(4)
        if not k32.VirtualFreeEx(proc, remote, 0, MEM_RELEASE):
            print(f"VirtualFreeEx: error {ctypes.get_last_error()}", file=sys.stderr)
    finally:
        k32.CloseHandle(proc)


def usage():
    raise SystemExit(__doc__)


def main(args):
    if len(args) >= 7 and args[0] == "--probe":
        outfile, title, geometry = args[1], args[2], args[3:7]
        if len(args) != 7:
            usage()
    elif len(args) >= 7 and args[0] == "--target":
        outfile, title, geometry, paths = None, args[1], args[2:6], args[6:]
    else:
        usage()
    try:
        x, y, w, h = (int(v) for v in geometry)
    except ValueError:
        usage()
    matches = find_windows(title, x, y, w, h)
    hwnd = matches[0] if len(matches) == 1 else None
    if outfile is not None:
        with open(outfile, "w", encoding="utf-8") as f:
            f.write(f"MATCH {hwnd:#x}" if hwnd else "NO_MATCH")
        sys.exit(0 if hwnd else 3)
    if not hwnd:
        sys.exit(3)
    drop(hwnd, paths)


if __name__ == "__main__":
    main(sys.argv[1:])
