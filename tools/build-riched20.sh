#!/usr/bin/env bash
# Build Wine's 32-bit riched20.dll with wine/riched20-cursor-coords-rewrap.patch and install it into
# the unpacked ARM64EC Wine, so KakaoTalk no longer aborts with
# "Assertion failed: ~para->nFlags & MEPF_REWRAP, file dlls/riched20/caret.c". See docs/riched20-crash.md.
#   tools/build-riched20.sh             build + install (the original is kept for --restore)
#   tools/build-riched20.sh --restore   put the original riched20.dll back
# After install, writes riched20-fix/riched20.dll.patched.wine-version (`wine64 --version`)
# so `kakaotalk check` can reinstall this DLL only for the same Wine build.
# No root needed: the i386 PE cross compiler comes from an llvm-mingw release tarball.
# Downloads ~110 MB and uses ~1.2 GB under ~/.cache while building; removed afterwards
# (set KEEP_BUILD=1 to keep it). Restart KakaoTalk afterwards (kakaotalk kill; kakaotalk).
set -euo pipefail

WINE_VERSION="${WINE_VERSION:-11.18}"
LLVM_MINGW="${LLVM_MINGW:-20260922}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
root="$HOME/.local/share/kakaotalk-ec/root"
target="$root/usr/lib64/wine/i386-windows/riched20.dll"
keep="$HOME/.local/share/kakaotalk-ec/riched20-fix"
work="${XDG_CACHE_HOME:-$HOME/.cache}/kakao-setup/riched20-build"

install_dll() {  # atomic replace: a running KakaoTalk keeps its mapped copy
  install -m755 "$1" "$target.new"
  mv -f "$target.new" "$target"
}

[[ -f "$target" ]] || { echo "not found: $target (install the ARM64EC Wine first)" >&2; exit 1; }
mkdir -p "$keep"

if [[ "${1:-}" == "--restore" ]]; then
  [[ -f "$keep/riched20.dll.orig" ]] || { echo "no backup in $keep" >&2; exit 1; }
  install_dll "$keep/riched20.dll.orig"
  echo "restored the original riched20.dll; restart KakaoTalk"
  exit 0
fi

installed="$("$root/usr/bin/wine64" --version 2>/dev/null || true)"
if [[ "$installed" != "wine-$WINE_VERSION"* ]]; then
  echo "installed Wine is '$installed', building riched20 from wine-$WINE_VERSION;" >&2
  echo "set WINE_VERSION to match (e.g. WINE_VERSION=${installed#wine-}) and rerun" >&2
  exit 1
fi

case "$(uname -m)" in
  aarch64) host=aarch64 ;;
  x86_64) host=x86_64 ;;
  *) echo "unsupported host $(uname -m)" >&2; exit 1 ;;
esac

rm -rf "$work"
mkdir -p "$work"
cd "$work"
echo "downloading llvm-mingw $LLVM_MINGW and wine-$WINE_VERSION source"
curl -fsSL "https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_MINGW/llvm-mingw-$LLVM_MINGW-ucrt-ubuntu-22.04-$host.tar.xz" | bsdtar -xf -
curl -fsSL "https://dl.winehq.org/wine/source/${WINE_VERSION%%.*}.x/wine-$WINE_VERSION.tar.xz" | bsdtar -xf -
export PATH="$work/llvm-mingw-$LLVM_MINGW-ucrt-ubuntu-22.04-$host/bin:$PATH"

patch -d "wine-$WINE_VERSION" -p1 < "$repo/wine/riched20-cursor-coords-rewrap.patch"

mkdir build
cd build
echo "configuring (build log: $work/build/build.log)"
"../wine-$WINE_VERSION/configure" --enable-archs="$host,i386" --disable-tests \
  --without-x --without-freetype --without-fontconfig --without-gstreamer --without-pulse \
  --without-alsa --without-oss --without-cups --without-dbus --without-sane --without-krb5 \
  --without-gnutls --without-vulkan --without-wayland --without-opencl --without-pcap \
  --without-usb --without-v4l2 --without-gphoto --without-netapi --without-sdl --without-capi \
  --without-udev --without-unwind --without-xinput > build.log 2>&1
echo "building dlls/riched20/i386-windows/riched20.dll"
make -j"$(nproc)" dlls/riched20/i386-windows/riched20.dll >> build.log 2>&1
built="$work/build/dlls/riched20/i386-windows/riched20.dll"

if [[ ! -f "$keep/riched20.dll.orig" ]]; then
  # Only a stock build still carries the assertion text; never back up an already patched DLL.
  if grep -aq 'MEPF_REWRAP' "$target"; then
    cp -p "$target" "$keep/riched20.dll.orig"
  else
    echo "warning: installed riched20.dll is already patched; no original backed up" >&2
  fi
fi
cp "$built" "$keep/riched20.dll.patched"
install_dll "$built"
# Stamp the Wine build this DLL was compiled against. The launcher reinstalls it only
# when `wine64 --version` still prints this string.
printf '%s\n' "$installed" > "$keep/riched20.dll.patched.wine-version"
echo "installed patched riched20.dll (original: $keep/riched20.dll.orig)"

cd /
[[ "${KEEP_BUILD:-0}" == 1 ]] || rm -rf "$work"
echo "done; verify with tools/riched20-selftest.sh, then restart KakaoTalk"
