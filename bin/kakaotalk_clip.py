"""Shared by kakaotalk-clipbridge and kakaotalk-paste: hand a PNG to KakaoTalk (Wine) and take it back.

set_windows_clipboard() converts the PNG to BMP and puts it on the Windows clipboard as CF_DIB from
inside the Wine prefix (setclip.py). Wine then mirrors it onto the X clipboard as image/bmp, which
must not stay there: a Wayland app pulling megabytes through XWayland breaks Hyprland's XWM. So the
PNG and the CF_DIB size are remembered in CLIP_DIR, and restore_png() puts the PNG back once focus
leaves KakaoTalk - unless the Windows clipboard no longer holds that bitmap, i.e. something else
was copied inside KakaoTalk since.
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


def _setclip(arg):
    """Run setclip.py inside Wine; returns the CF_DIB size in bytes it reports."""
    cmd = [KAKAOTALK, "wine", f"Z:{PY_DIR}/python.exe", f"Z:{PY_DIR}/setclip.py", arg]
    out = subprocess.run(cmd, check=True, timeout=60, capture_output=True, text=True).stdout
    match = re.search(r"(\d+) bytes", out)
    if not match:
        raise subprocess.CalledProcessError(0, cmd, out)
    return int(match.group(1))


def set_windows_clipboard(png):
    """Put the PNG on the Windows clipboard and remember it for restore_png(). Returns the CF_DIB size."""
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


def handed_over():
    return os.path.exists(SAVED_SIZE)


def restore_png(types):
    """Put the remembered PNG back on the Wayland clipboard, whose current types are given.

    Returns what happened, or None if nothing had been handed over.
    """
    try:
        with open(SAVED_PNG, "rb") as f:
            png = f.read()
        with open(SAVED_SIZE) as f:
            size = int(f.read())
    except (FileNotFoundError, ValueError):
        return None
    finally:
        for path in (SAVED_PNG, SAVED_SIZE):
            if os.path.exists(path):
                os.unlink(path)
    if "image/bmp" not in types or any(t in types for t in TEXT_TYPES):
        return "the bitmap is not on the Wayland clipboard, nothing to restore"
    try:
        current = _setclip("--check")
    except ERRORS:
        current = size  # cannot tell: do not leave the large bitmap on the X clipboard
    if current != size:
        return f"another image was copied in KakaoTalk ({current} bytes, handed over {size}), PNG not restored"
    subprocess.run(["wl-copy", "--type", "image/png"], input=png, check=True, timeout=10,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return "PNG restored"
