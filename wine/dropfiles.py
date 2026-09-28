"""Drop files onto the focused KakaoTalk chat window, as if dragged from Explorer (runs inside Wine).

  python dropfiles.py <unix path>...

KakaoTalk's Ctrl+V never looks for files on the clipboard (only bitmap, text and its own
formats), but its chat windows accept WM_DROPFILES. The DROPFILES block is written into
KakaoTalk's own address space so the HDROP it receives is valid there.
Exit status: 0 dropped, 3 the foreground window takes no file drops.
"""
import ctypes
import struct
import sys
from ctypes import wintypes

WM_DROPFILES = 0x0233
WS_EX_ACCEPTFILES = 0x10
GWL_EXSTYLE = -20
GA_ROOT = 2
PROCESS_VM_OPERATION = 0x0008
PROCESS_VM_WRITE = 0x0020
MEM_COMMIT_RESERVE = 0x3000
PAGE_READWRITE = 0x04

u32 = ctypes.WinDLL("user32", use_last_error=True)
k32 = ctypes.WinDLL("kernel32", use_last_error=True)
u32.GetForegroundWindow.restype = wintypes.HWND
u32.GetAncestor.argtypes = [wintypes.HWND, wintypes.UINT]
u32.GetAncestor.restype = wintypes.HWND
u32.GetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int]
u32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
u32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
k32.OpenProcess.restype = wintypes.HANDLE
k32.VirtualAllocEx.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_size_t, wintypes.DWORD, wintypes.DWORD]
k32.VirtualAllocEx.restype = ctypes.c_void_p
k32.WriteProcessMemory.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                   ctypes.POINTER(ctypes.c_size_t)]
k32.CloseHandle.argtypes = [wintypes.HANDLE]


def fail(msg):
    raise SystemExit(f"{msg}: error {ctypes.get_last_error()}")


def main(unix_paths):
    hwnd = u32.GetAncestor(u32.GetForegroundWindow(), GA_ROOT)
    if not hwnd or not u32.GetWindowLongW(hwnd, GWL_EXSTYLE) & WS_EX_ACCEPTFILES:
        sys.exit(3)
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
            fail("WriteProcessMemory")
    finally:
        k32.CloseHandle(proc)
    if not u32.PostMessageW(hwnd, WM_DROPFILES, remote, 0):
        fail("PostMessage")


if __name__ == "__main__":
    main(sys.argv[1:])
