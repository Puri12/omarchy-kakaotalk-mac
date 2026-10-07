"""Shared by kakaotalk-clipbridge and kakaotalk-paste: hand a PNG to KakaoTalk (Wine) and take it back.

set_windows_clipboard() converts the PNG to BMP and puts it on the Windows clipboard as CF_DIB from
inside the Wine prefix (setclip.py). Wine then mirrors it onto the X clipboard as image/bmp, which
must not stay there: a Wayland app pulling megabytes through XWayland breaks Hyprland's XWM. So the
PNG and the CF_DIB size are remembered in CLIP_DIR, and take_back() puts the PNG back once focus
leaves KakaoTalk. If the Windows clipboard holds another bitmap by then (an image copied inside
KakaoTalk), that one is read out inside Wine and published as PNG instead, so Wayland apps can
paste it and it never crosses XWayland either.
"""
import os
import re
import subprocess

KAKAOTALK = os.path.expanduser("~/.local/bin/kakaotalk")
PY_DIR = os.path.expanduser("~/.local/share/kakaotalk-ec/py")
CLIP_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "kakaotalk-clip")
SAVED_PNG = os.path.join(CLIP_DIR, "saved.png")
SAVED_SIZE = os.path.join(CLIP_DIR, "saved.size")
TEXT_TYPES = ("text/plain", "UTF8_STRING", "STRING", "TEXT")
# Longest edge of the bitmap handed to Wine. A full-screen HiDPI screenshot is ~23 MB as BMP. 0 = no limit.
MAX_EDGE = 2560
ERRORS = (subprocess.CalledProcessError, subprocess.TimeoutExpired)


def _setclip(*args):
    """Run setclip.py inside Wine; returns the CF_DIB size in bytes it reports."""
    cmd = [KAKAOTALK, "wine", f"Z:{PY_DIR}/python.exe", f"Z:{PY_DIR}/setclip.py", *args]
    out = subprocess.run(cmd, check=True, timeout=60, capture_output=True, text=True).stdout
    match = re.search(r"(\d+) bytes", out)
    if not match:
        raise subprocess.CalledProcessError(0, cmd, out)
    return int(match.group(1))


def set_windows_clipboard(png):
    """Put the PNG on the Windows clipboard and remember it for take_back(). Returns the CF_DIB size."""
    os.makedirs(CLIP_DIR, exist_ok=True)
    bmp = os.path.join(CLIP_DIR, f"clip-{os.getpid()}.bmp")
    shrink = ["-resize", f"{MAX_EDGE}x{MAX_EDGE}>"] if MAX_EDGE else []
    try:
        subprocess.run(["magick", "png:-", *shrink, "-background", "white", "-alpha", "remove", "-alpha", "off",
                        f"bmp3:{bmp}"], input=png, check=True, timeout=30, capture_output=True)
        size = _setclip(f"Z:{bmp}")
    finally:
        if os.path.exists(bmp):
            os.unlink(bmp)
    with open(SAVED_PNG, "wb") as f:
        f.write(png)
    with open(SAVED_SIZE, "w") as f:
        f.write(str(size))
    return size


def _pop_handed_over():
    """The remembered (png, CF_DIB size), forgotten from now on; None if nothing was handed over."""
    try:
        with open(SAVED_PNG, "rb") as f:
            png = f.read()
        with open(SAVED_SIZE) as f:
            return png, int(f.read())
    except (FileNotFoundError, ValueError):
        return None
    finally:
        for path in (SAVED_PNG, SAVED_SIZE):
            if os.path.exists(path):
                os.unlink(path)


def _copied_in_kakaotalk():
    """The bitmap on the Windows clipboard as PNG, read inside Wine. Returns (png, CF_DIB size)."""
    bmp = os.path.join(CLIP_DIR, f"copied-{os.getpid()}.bmp")
    os.makedirs(CLIP_DIR, exist_ok=True)
    try:
        size = _setclip("--dump", f"Z:{bmp}")
        # Windows apps leave the alpha byte of 32-bit DIBs at 0: it is not transparency.
        png = subprocess.run(["magick", f"bmp:{bmp}", "-alpha", "off", "png:-"],
                             check=True, timeout=30, capture_output=True).stdout
    finally:
        if os.path.exists(bmp):
            os.unlink(bmp)
    return png, size


def take_back(types):
    """After focus left KakaoTalk: replace Wine's bitmap on the Wayland clipboard (current types given) by a PNG.

    Returns what happened, or None if there was nothing to do.
    """
    handed_over = _pop_handed_over()
    # Wine offers its bitmap as image/bmp without image/png. A clipboard that already has a PNG
    # (a Wayland app offering both) needs nothing, and reading it via Wine would cross XWayland.
    if "image/bmp" not in types or "image/png" in types or any(t in types for t in TEXT_TYPES):
        return "the bitmap is not on the Wayland clipboard, nothing to restore" if handed_over else None
    png = None
    if handed_over:
        try:
            current = _setclip("--check")
        except ERRORS:
            current = handed_over[1]  # cannot tell: do not leave the large bitmap on the X clipboard
        if current == handed_over[1]:
            png, what = handed_over[0], "PNG restored"
    if png is None:
        png, size = _copied_in_kakaotalk()
        what = f"image copied in KakaoTalk ({size} bytes DIB) published as PNG ({len(png)} bytes)"
    subprocess.run(["wl-copy", "--type", "image/png"], input=png, check=True, timeout=10,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return what
