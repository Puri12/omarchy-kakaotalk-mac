"""Reproduce Wine riched20 'MEPF_REWRAP' assertion (runs inside Wine, 32-bit x86 Python).

ITextRange::SetText inserts text without rewrapping; a following ITextRange::Select
(set_selection -> update_caret -> cursor_coords) asserts while the control has focus.
Usage: python repro.py <out.txt>
"""
import ctypes
import sys
from ctypes import wintypes

out = open(sys.argv[1], "w", encoding="utf-8", buffering=1)
u32 = ctypes.WinDLL("user32")
k32 = ctypes.WinDLL("kernel32")
ole32 = ctypes.WinDLL("ole32")
oleaut = ctypes.WinDLL("oleaut32")

u32.CreateWindowExW.restype = wintypes.HWND
u32.CreateWindowExW.argtypes = [wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
                                ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, wintypes.LPVOID]
u32.SendMessageW.restype = ctypes.c_ssize_t
u32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
oleaut.SysAllocString.restype = ctypes.c_void_p
oleaut.SysAllocString.argtypes = [wintypes.LPCWSTR]
k32.GetModuleFileNameW.argtypes = [wintypes.HMODULE, wintypes.LPWSTR, wintypes.DWORD]

WS_OVERLAPPEDWINDOW, WS_VISIBLE, ES_MULTILINE = 0x00CF0000, 0x10000000, 0x0004
WM_SETFOCUS, WM_USER = 0x0007, 0x0400
EM_GETOLEINTERFACE = WM_USER + 60


class GUID(ctypes.Structure):
    _fields_ = [("d1", wintypes.DWORD), ("d2", wintypes.WORD), ("d3", wintypes.WORD), ("d4", ctypes.c_ubyte * 8)]


def ref(obj):
    return ctypes.c_void_p(ctypes.addressof(obj))


def guid(s):
    g = GUID()
    ole32.CLSIDFromString(s, ctypes.byref(g))
    return g


def call(obj, index, restype, *args):
    vtbl = ctypes.cast(ctypes.cast(obj, ctypes.POINTER(ctypes.c_void_p))[0], ctypes.POINTER(ctypes.c_void_p))
    argtypes = [ctypes.c_void_p] + [type(a) for a in args]
    fn = ctypes.WINFUNCTYPE(restype, *argtypes)(vtbl[index])
    return fn(obj, *args)


ole32.OleInitialize(None)
mod = k32.LoadLibraryW("msftedit.dll")
path = ctypes.create_unicode_buffer(260)
k32.GetModuleFileNameW(mod, path, 260)
out.write(f"msftedit loaded from {path.value}\n")

hwnd = u32.CreateWindowExW(0, "RichEdit50W", "", WS_OVERLAPPEDWINDOW | WS_VISIBLE | ES_MULTILINE,
                           100, 100, 300, 200, None, None, None, None)
out.write(f"hwnd {hwnd}\n")
u32.SendMessageW(hwnd, WM_SETFOCUS, 0, 0)

reole = ctypes.c_void_p()
u32.SendMessageW(hwnd, EM_GETOLEINTERFACE, 0, ctypes.addressof(reole))
doc = ctypes.c_void_p()
iid_doc = guid("{8CC497C0-A1DF-11CE-8098-00AA0047BE5D}")
hr = call(reole, 0, ctypes.c_long, ref(iid_doc), ref(doc))
out.write(f"QI ITextDocument hr={hr:#x}\n")
rng = ctypes.c_void_p()
hr = call(doc, 24, ctypes.c_long, ctypes.c_long(0), ctypes.c_long(0), ref(rng))
out.write(f"Range hr={hr:#x}\n")
hr = call(rng, 8, ctypes.c_long, ctypes.c_void_p(oleaut.SysAllocString("안녕하세요 재현 테스트")))
out.write(f"SetText hr={hr:#x}\n")
hr = call(rng, 24, ctypes.c_long, ctypes.c_long(0))
out.write(f"Collapse hr={hr:#x}\n")
out.write("calling Select (builtin Wine asserts here)\n")
hr = call(rng, 32, ctypes.c_long)
out.write(f"Select hr={hr:#x}\nSURVIVED\n")
