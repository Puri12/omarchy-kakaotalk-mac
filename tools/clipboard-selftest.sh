#!/usr/bin/env bash
# Checks kakaotalk-clipbridge end to end with a SMALL image (safe for XWayland):
# copy a PNG, focus KakaoTalk, confirm CF_DIB landed in Wine, return focus, confirm the PNG came back.
# Requires a running KakaoTalk window and the bridge. Your current clipboard is replaced by the test image.
set -u
if [ ! -S "$XDG_RUNTIME_DIR/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-none}/.socket.sock" ]; then
  export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr/" | head -1)
fi
PY="Z:$HOME/.local/share/kakaotalk-ec/py/python.exe"
SC="Z:$HOME/.local/share/kakaotalk-ec/py/setclip.py"
tmp=$(mktemp --suffix=.png)
trap 'rm -f "$tmp"' EXIT
types() { wl-paste --list-types 2>/dev/null | tr '\n' ' '; }

pgrep -f '^python3 .*/kakaotalk-clipbridge$' > /dev/null || { echo "kakaotalk-clipbridge is not running" >&2; exit 1; }
kakao=$(hyprctl clients -j | python3 -c "
import json, sys
for x in json.load(sys.stdin):
    if x['class'] == 'kakaotalk.exe' and x['title']:
        print(x['address']); break")
[ -n "$kakao" ] || { echo "no KakaoTalk window" >&2; exit 1; }
prev=$(hyprctl activewindow -j | python3 -c "import json, sys; print(json.load(sys.stdin).get('address', ''))")

magick -size 200x150 gradient:orange-purple "png:$tmp"
wl-copy --type image/png < "$tmp" > /dev/null 2>&1
sleep 1
echo "1 copied: wl=[$(types)]"
hyprctl dispatch "hl.dsp.focus({ window = \"address:$kakao\" })" > /dev/null
start=$(date +%s.%N); dib=0
while :; do
  dib=$(kakaotalk wine "$PY" "$SC" --check 2>/dev/null | grep -oE '[0-9]+ bytes' | grep -oE '[0-9]+')
  elapsed=$(awk -v s="$start" -v e="$(date +%s.%N)" 'BEGIN { printf "%.1f", e - s }')
  [ "${dib:-0}" -gt 0 ] && break
  awk -v t="$elapsed" 'BEGIN { exit !(t > 10) }' && break
  sleep 0.5
done
echo "2 kakao focused: wl=[$(types)] CF_DIB=${dib:-0} bytes after ${elapsed}s"
if [ "${dib:-0}" -eq 0 ]; then
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$prev\" })" > /dev/null
  echo "   image never reached the Windows clipboard" >&2
  exit 1
fi
hyprctl dispatch "hl.dsp.focus({ window = \"address:$prev\" })" > /dev/null
sleep 2
echo "3 focus back: wl=[$(types)]"
if wl-paste --type image/png 2>/dev/null | cmp -s - "$tmp"; then
  echo "   PNG restored intact"
else
  echo "   PNG NOT restored" >&2
  exit 1
fi
