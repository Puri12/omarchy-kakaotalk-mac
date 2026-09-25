"""Put a BMP file on the Windows clipboard as CF_DIB (runs inside Wine).

  python setclip.py <file.bmp>   set the clipboard
  python setclip.py --check      print the CF_DIB size currently on the clipboard

Setting the image inside Wine means KakaoTalk reads it from wineserver directly instead
of pulling megabytes through Hyprland's XWayland clipboard bridge, which hangs.
"""
import ctypes
import sys
import time
from ctypes import wintypes

CF_DIB = 8
GMEM_MOVEABLE = 0x0002

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
u32 = ctypes.WinDLL("user32", use_last_error=True)
k32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
k32.GlobalAlloc.restype = wintypes.HGLOBAL
k32.GlobalLock.argtypes = [wintypes.HGLOBAL]
k32.GlobalLock.restype = ctypes.c_void_p
k32.GlobalUnlock.argtypes = [wintypes.HGLOBAL]
k32.GlobalSize.argtypes = [wintypes.HGLOBAL]
k32.GlobalSize.restype = ctypes.c_size_t
u32.OpenClipboard.argtypes = [wintypes.HWND]
u32.SetClipboardData.argtypes = [wintypes.UINT, wintypes.HANDLE]
u32.SetClipboardData.restype = wintypes.HANDLE
u32.GetClipboardData.argtypes = [wintypes.UINT]
u32.GetClipboardData.restype = wintypes.HANDLE


def open_clipboard():
    for _ in range(50):
        if u32.OpenClipboard(None):
            return
        time.sleep(0.02)
    raise SystemExit(f"OpenClipboard failed: {ctypes.get_last_error()}")


def set_dib(path):
    data = open(path, "rb").read()
    if data[:2] != b"BM":
        raise SystemExit("not a BMP file")
    dib = data[14:]  # CF_DIB is the BMP without its BITMAPFILEHEADER
    handle = k32.GlobalAlloc(GMEM_MOVEABLE, len(dib))
    ptr = k32.GlobalLock(handle)
    ctypes.memmove(ptr, dib, len(dib))
    k32.GlobalUnlock(handle)
    open_clipboard()
    try:
        u32.EmptyClipboard()
        if not u32.SetClipboardData(CF_DIB, handle):
            raise SystemExit(f"SetClipboardData failed: {ctypes.get_last_error()}")
    finally:
        u32.CloseClipboard()
    print(f"CF_DIB set: {len(dib)} bytes")


def check():
    open_clipboard()
    try:
        handle = u32.GetClipboardData(CF_DIB)
        print(f"CF_DIB on clipboard: {k32.GlobalSize(handle) if handle else 0} bytes")
    finally:
        u32.CloseClipboard()


if __name__ == "__main__":
    check() if sys.argv[1:] == ["--check"] else set_dib(sys.argv[1])
