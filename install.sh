#!/usr/bin/env bash
# install.sh - set up Windows KakaoTalk (32-bit) on ARM64EC Wine + FEX for Omarchy on Asahi Linux (aarch64).
# Automates README.md "설치 순서" 1-7. Every step checks its end state first, so the script can be re-run.
#
#   ./install.sh            run every step whose check fails, in order; finished steps are skipped
#   ./install.sh --check    only inspect: one line per step, "[ok] <step>" or "[todo] <step>: <what is missing>";
#                           exit 0 if every step is ok, 1 otherwise ("[info]" lines are not failures)
#   ./install.sh --step N   run step N (1-7) even if its check passes (e.g. --step 2 updates ~/.local/bin)
#
# Never uses sudo: missing tools are listed and the script exits 1. Never starts KakaoTalk.
# ~/.config files are backed up as <file>.bak.<epoch> before editing, and each config block is appended at most once.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
EC=$HOME/.local/share/kakaotalk-ec
ROOT=$EC/root
PREFIX=$EC/prefix
PYDIR=$EC/py
BIN=$HOME/.local/bin
KT_DIR="$PREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk"
RICHED=$ROOT/usr/lib64/wine/i386-windows/riched20.dll
HYPR=$HOME/.config/hypr
XIM=$HOME/.config/fcitx5/conf/xim.conf
SHELL_JSON=$HOME/.config/omarchy/shell.json
ICON=$HOME/.local/share/icons/kakaotalk.png
DESKTOP=$HOME/.local/share/applications/kakaotalk.desktop
NOTO=/usr/share/fonts/noto-cjk

TOOLS=(curl bsdtar python3 magick wl-copy wl-paste jq patch make gcc bison flex inotifywait)
COPR=https://download.copr.fedorainfracloud.org/results/lacamar/wine-arm64ec/fedora-43-aarch64
RPMS=(
  11027010-wine/wine-core-11.18-ec3.fc43.aarch64.rpm
  11027010-wine/wine-common-11.18-ec3.fc43.noarch.rpm
  11027010-wine/wine-filesystem-11.18-ec3.fc43.noarch.rpm
  11027010-wine/wine-pulseaudio-11.18-ec3.fc43.aarch64.rpm
  11027010-wine/wine-{tahoma,system,marlett,symbol,wingdings,small,courier,ms-sans-serif,arial}-winefonts-11.18-ec3.fc43.noarch.rpm
  11019142-fex-emu-wine/fex-emu-wine-2609-4.fc43.aarch64.rpm
)
PY_URL=https://www.python.org/ftp/python/3.13.15/python-3.13.15-embed-arm64.zip
KT_URL=https://app-pc.kakaocdn.net/talk/win32/KakaoTalk_Setup.exe
NAMES=("" "1 Wine + FEX" "2 bin scripts" "3 Wine prefix" "4 KakaoTalk" "5 helper Python" "6 desktop integration" "7 riched20 patch")

usage() { sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }
die() { echo "install.sh: $*" >&2; exit 1; }
tilde() { printf '%s' "${1/#"$HOME"/\~}"; }
winpath() { local p=${1//\//\\}; printf 'Z:%s' "$p"; }
K() { "$REPO/bin/kakaotalk" wine "$@"; }

MISSING=()
miss() { MISSING+=("$*"); }
reasons() { local IFS=';'; printf '%s' "${MISSING[*]}" | sed 's/;/; /g'; }

missing_tools() {
  local b out=()
  for b in "${TOOLS[@]}"; do command -v "$b" >/dev/null || out+=("$b"); done
  printf '%s' "${out[*]}"
}

check1() {
  MISSING=()
  local v; v=$("$ROOT/usr/bin/wine64" --version 2>/dev/null || true)
  [[ $v == wine-* ]] || miss "$(tilde "$ROOT")/usr/bin/wine64 --version does not print wine-*"
  [[ -e $ROOT/usr/bin/wine && -e $ROOT/usr/bin/wineserver ]] || miss "wine/wineserver links missing"
  [[ -e $ROOT/usr/lib64/wine/aarch64-windows/libwow64fex.dll ]] || miss "FEX libwow64fex.dll missing"
  ((${#MISSING[@]} == 0))
}

check2() {
  MISSING=()
  local f
  for f in "$REPO"/bin/kakaotalk*; do
    [[ -x $BIN/${f##*/} ]] || miss "$(tilde "$BIN")/${f##*/} not installed"
  done
  ((${#MISSING[@]} == 0))
}

check3() {
  MISSING=()
  local n
  n=$(ls -A "$PREFIX/drive_c/windows/syswow64" 2>/dev/null | wc -l || true)
  ((n >= 800)) || miss "syswow64 has $n files (need 800+)"
  grep -qF '"InstallLanguage"="0412"' "$PREFIX/system.reg" 2>/dev/null || miss "korean.reg not imported"
  grep -qF '"winebth.sys"=""' "$PREFIX/user.reg" 2>/dev/null || miss "winebth.sys override missing"
  awk '/Services\\\\winebth\]/{f=1} f&&/"Start"=/{print; exit}' "$PREFIX/system.reg" 2>/dev/null \
    | grep -qF 'dword:00000004' || miss "winebth Start=4 missing"
  grep -qF '"LogPixels"=dword:000000c0' "$PREFIX/user.reg" 2>/dev/null || miss "LogPixels 192 missing"
  [[ -f $PREFIX/drive_c/windows/Fonts/NotoSansCJK-Regular.ttc ]] || miss "Noto CJK fonts not copied"
  grep -qF 'FontLink\\SystemLink]' "$PREFIX/system.reg" 2>/dev/null || miss "fontlink.reg not imported"
  ((${#MISSING[@]} == 0))
}

check4() {
  MISSING=()
  [[ -f $KT_DIR/KakaoTalk.exe ]] || miss "$(tilde "$KT_DIR")/KakaoTalk.exe missing"
  ((${#MISSING[@]} == 0))
}

check5() {
  MISSING=()
  local f
  for f in python.exe setclip.py dropfiles.py; do
    [[ -f $PYDIR/$f ]] || miss "$(tilde "$PYDIR")/$f missing"
  done
  ((${#MISSING[@]} == 0))
}

# shell.json: "check" exits 0 when an omarchy.tray entry pins kakaotalk; "apply" pins it (keeping other pins).
tray_json() {
  python3 - "$1" "$SHELL_JSON" "$REPO/config/omarchy/shell-tray-entry.json" <<'PY'
import json, os, sys
mode, path, entry_path = sys.argv[1:4]
entry = json.load(open(entry_path, encoding="utf-8"))
data = json.load(open(path, encoding="utf-8"))
trays = []
def walk(node):
    if isinstance(node, dict):
        if node.get("id") == entry["id"]:
            trays.append(node)
        for v in node.values():
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)
walk(data)
if mode == "check":
    sys.exit(0 if any("kakaotalk" in t.get("pinned", []) for t in trays) else 1)
if trays:
    for t in trays:
        pinned = t.setdefault("pinned", [])
        for p in entry["pinned"]:
            if p not in pinned:
                pinned.append(p)
else:
    right = data.get("bar", {}).get("layout", {}).get("right")
    if not isinstance(right, list):
        sys.exit("shell.json has no omarchy.tray entry and no bar.layout.right list; add the tray entry by hand")
    right.append(entry)
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
PY
}

# Paragraph of config/hypr/autostart-kakaotalk.lua that starts kakaotalk-notify (empty if the block has none).
notify_paragraph() { awk -v RS= -v ORS='\n\n' '/kakaotalk-notify/' "$REPO/config/hypr/autostart-kakaotalk.lua"; }

check6() {
  MISSING=()
  [[ -f $ICON ]] || miss "$(tilde "$ICON") missing"
  [[ -f $DESKTOP ]] || miss "$(tilde "$DESKTOP") missing"
  cmp -s "$REPO/config/fcitx5/xim.conf" "$XIM" || miss "$(tilde "$XIM") differs from repo"
  if [[ -f $HYPR/hyprland.lua ]]; then
    grep -q kakao_paste_update "$HYPR/hyprland.lua" || miss "hyprland.lua lacks the KakaoTalk block"
  else
    miss "$(tilde "$HYPR")/hyprland.lua not found"
  fi
  if [[ -f $HYPR/autostart.lua ]]; then
    grep -q kakaotalk-clipbridge "$HYPR/autostart.lua" || miss "autostart.lua lacks the KakaoTalk block"
    if [[ -n $(notify_paragraph) ]] && ! grep -q kakaotalk-notify "$HYPR/autostart.lua"; then
      miss "autostart.lua does not start kakaotalk-notify"
    fi
  else
    miss "$(tilde "$HYPR")/autostart.lua not found"
  fi
  if [[ -f $SHELL_JSON ]]; then
    tray_json check 2>/dev/null || miss "shell.json omarchy.tray does not pin kakaotalk"
  else
    miss "$(tilde "$SHELL_JSON") not found"
  fi
  ((${#MISSING[@]} == 0))
}

check7() {
  MISSING=()
  if [[ ! -f $RICHED ]]; then
    miss "$(tilde "$RICHED") missing"
  elif grep -aq MEPF_REWRAP "$RICHED"; then
    miss "installed riched20.dll is the stock one (contains MEPF_REWRAP)"
  fi
  ((${#MISSING[@]} == 0))
}

BACKED_UP=()
backup() {
  local f=$1 b
  [[ -e $f ]] || return 0
  for b in "${BACKED_UP[@]}"; do [[ $b == "$f" ]] && return 0; done
  b="$f.bak.$(date +%s)"
  cp -p -- "$f" "$b"
  BACKED_UP+=("$f")
  echo "  backup: $(tilde "$b")"
}

run1() {
  local cache=${XDG_CACHE_HOME:-$HOME/.cache}/kakao-setup/ec p f d t
  mkdir -p "$ROOT" "$cache"
  for p in "${RPMS[@]}"; do
    f=$cache/${p##*/}
    if [[ ! -f $f ]]; then
      echo "  downloading ${p##*/}"
      curl -fsSL -o "$f.part" "$COPR/$p"
      mv "$f.part" "$f"
    fi
    bsdtar -xf "$f" -C "$ROOT"
  done
  # Links Fedora's alternatives scripts would create; without them: "could not exec wineserver", "d3d11.dll not found".
  ln -sf wine64 "$ROOT/usr/bin/wine"
  ln -sf wineserver64 "$ROOT/usr/bin/wineserver"
  for d in aarch64-windows i386-windows; do
    for f in "$ROOT/usr/lib64/wine/$d"/wine-*.dll; do
      t=${f##*/}; t=${t#wine-}
      [[ -e $ROOT/usr/lib64/wine/$d/$t ]] || ln -s "${f##*/}" "$ROOT/usr/lib64/wine/$d/$t"
    done
  done
}

run2() {
  install -Dm755 -t "$BIN" "$REPO"/bin/kakaotalk*
}

run3() {
  [[ -f $NOTO/NotoSansCJK-Regular.ttc && -f $NOTO/NotoSansCJK-Bold.ttc ]] \
    || die "$NOTO/NotoSansCJK-{Regular,Bold}.ttc not found; install the Noto CJK fonts (noto-fonts-cjk) and rerun"
  local tmp
  K wineboot -i
  K reg import "$(winpath "$REPO/wine/korean.reg")"   # Korean UI (0412); must be in place before KakaoTalk is installed
  K winecfg /v win10
  K reg add 'HKLM\System\CurrentControlSet\Services\winebth' /v Start /t REG_DWORD /d 4 /f
  K reg add 'HKCU\Software\Wine\DllOverrides' /v winebth.sys /t REG_SZ /d '' /f
  K reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 192 /f   # display scale 2.0
  K reg add 'HKCU\Software\Wine\Fonts' /v LogPixels /t REG_DWORD /d 192 /f
  install -m644 "$NOTO"/NotoSansCJK-{Regular,Bold}.ttc "$PREFIX/drive_c/windows/Fonts/"
  tmp=$(mktemp --suffix=.reg)
  python3 "$REPO/wine/fontlink.py" "$tmp"
  K reg import "$(winpath "$tmp")"
  rm -f "$tmp"
}

run4() {
  local tmp; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/KakaoTalk_Setup.exe" "$KT_URL"   # 32-bit client; the 64-bit one does not work here
  K "$tmp/KakaoTalk_Setup.exe" /S
  rm -rf "$tmp"
}

run5() {
  mkdir -p "$PYDIR"
  if [[ ! -f $PYDIR/python.exe ]]; then
    local tmp; tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/py.zip" "$PY_URL"
    bsdtar -xf "$tmp/py.zip" -C "$PYDIR"
    rm -rf "$tmp"
  fi
  install -m644 "$REPO/wine/setclip.py" "$REPO/wine/dropfiles.py" "$PYDIR/"
}

run6() {
  local hypr_changed=0 para
  [[ -f $KT_DIR/KakaoTalk.exe ]] || die "KakaoTalk is not installed yet (step 4)"
  [[ -f $HYPR/hyprland.lua && -f $HYPR/autostart.lua ]] \
    || die "$(tilde "$HYPR")/hyprland.lua and autostart.lua are required (Hyprland Lua config)"

  install -Dm644 "$KT_DIR/skin/default/image/2.0/x2.0/setting_img_talkappicon.png" "$ICON"
  install -Dm644 "$REPO/config/applications/kakaotalk.desktop" "$DESKTOP"

  if ! cmp -s "$REPO/config/fcitx5/xim.conf" "$XIM"; then
    backup "$XIM"
    install -Dm644 "$REPO/config/fcitx5/xim.conf" "$XIM"
    systemctl --user restart omarchy-fcitx5.service \
      || echo "  warning: could not restart omarchy-fcitx5.service; restart fcitx5 or log in again" >&2
  fi

  if ! grep -q kakao_paste_update "$HYPR/hyprland.lua"; then
    backup "$HYPR/hyprland.lua"
    { echo; cat "$REPO/config/hypr/hyprland-kakaotalk.lua"; } >> "$HYPR/hyprland.lua"
    echo "  appended config/hypr/hyprland-kakaotalk.lua to $(tilde "$HYPR")/hyprland.lua"
    hypr_changed=1
  fi
  if ! grep -q kakaotalk-clipbridge "$HYPR/autostart.lua"; then
    backup "$HYPR/autostart.lua"
    { echo; cat "$REPO/config/hypr/autostart-kakaotalk.lua"; } >> "$HYPR/autostart.lua"
    echo "  appended config/hypr/autostart-kakaotalk.lua to $(tilde "$HYPR")/autostart.lua"
    hypr_changed=1
  else
    # Older installs have the block without kakaotalk-notify: add only that part.
    para=$(notify_paragraph)
    if [[ -n $para ]] && ! grep -q kakaotalk-notify "$HYPR/autostart.lua"; then
      backup "$HYPR/autostart.lua"
      printf '\n%s\n' "$para" >> "$HYPR/autostart.lua"
      echo "  appended the kakaotalk-notify autostart to $(tilde "$HYPR")/autostart.lua"
      hypr_changed=1
    fi
  fi
  if ((hypr_changed)) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload >/dev/null
    hyprctl configerrors
  fi

  if [[ ! -f $SHELL_JSON ]]; then
    echo "  warning: $(tilde "$SHELL_JSON") not found; pin kakaotalk in omarchy.tray by hand" >&2
  elif ! tray_json check; then
    backup "$SHELL_JSON"
    tray_json apply
    python3 -m json.tool "$SHELL_JSON" >/dev/null
    echo "  pinned kakaotalk in omarchy.tray ($(tilde "$SHELL_JSON"))"
    if command -v omarchy >/dev/null; then omarchy restart shell || true; fi
  fi
}

run7() {
  "$REPO/tools/build-riched20.sh"
  "$REPO/tools/riched20-selftest.sh"
}

info_diffs() {
  local f
  for f in "$REPO"/bin/kakaotalk*; do
    if [[ -f $BIN/${f##*/} ]] && ! cmp -s "$f" "$BIN/${f##*/}"; then
      echo "[info] $(tilde "$BIN")/${f##*/} differs from the repo (./install.sh --step 2 updates it)"
    fi
  done
  for f in setclip.py dropfiles.py; do
    if [[ -f $PYDIR/$f ]] && ! cmp -s "$REPO/wine/$f" "$PYDIR/$f"; then
      echo "[info] $(tilde "$PYDIR")/$f differs from the repo (./install.sh --step 5 updates it)"
    fi
  done
}

# After a step ran, its end state may lag (wineserver writes the registry lazily, the installer may detach).
verify_after() {
  local n=$1 i tries=1
  [[ $n == 3 || $n == 4 ]] && tries=90
  for ((i = 0; i < tries; i++)); do
    "check$n" && return 0
    ((tries > 1)) && sleep 1
  done
  echo "[fail] ${NAMES[n]}: $(reasons)" >&2
  exit 1
}

do_check() {
  local n fail=0 miss_t
  miss_t=$(missing_tools)
  if [[ -n $miss_t ]]; then echo "[todo] tools: missing $miss_t"; fail=1; else echo "[ok] tools"; fi
  for n in 1 2 3 4 5 6 7; do
    if "check$n"; then echo "[ok] ${NAMES[n]}"; else echo "[todo] ${NAMES[n]}: $(reasons)"; fail=1; fi
  done
  info_diffs
  exit "$fail"
}

next_steps() {
  cat <<EOF

Done. Next steps (manual):
  1. Start the helpers: log out and back in once, or run
       setsid -f ~/.local/bin/kakaotalk-clipbridge; setsid -f ~/.local/bin/kakaotalk-tray; setsid -f ~/.local/bin/kakaotalk-notify
  2. Launch KakaoTalk from the app menu or with: kakaotalk   (each launch runs 'kakaotalk check')
  3. Log in to KakaoTalk yourself.
  4. Test file paste in "나와의 채팅" only. Check the setup any time with: ./install.sh --check
EOF
}

mode=all step=
case "${1:-}" in
  "") ;;
  --check) mode=check ;;
  --step) mode=step; step=${2:-}; [[ $step =~ ^[1-7]$ ]] || usage 2 ;;
  -h|--help) usage 0 ;;
  *) usage 2 ;;
esac

[[ $mode == check ]] && do_check
((EUID != 0)) || die "run as your user, not root"
[[ $(uname -m) == aarch64 ]] || echo "warning: this setup is only tested on aarch64 (Asahi Linux)" >&2
miss_t=$(missing_tools)
[[ -z $miss_t ]] || die "missing tools: $miss_t (install them with your package manager and rerun; this script never uses sudo)"

if [[ $mode == step ]]; then
  echo "[run] ${NAMES[step]}"
  "run$step"
  verify_after "$step"
  echo "[ok] ${NAMES[step]}"
else
  for n in 1 2 3 4 5 6 7; do
    if "check$n"; then echo "[ok] ${NAMES[n]} (already done)"; continue; fi
    echo "[run] ${NAMES[n]}: $(reasons)"
    "run$n"
    verify_after "$n"
    echo "[ok] ${NAMES[n]}"
  done
fi
next_steps
