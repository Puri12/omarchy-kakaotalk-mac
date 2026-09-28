#!/usr/bin/env bash
# Run tools/riched20-repro.py with 32-bit (x86) Windows Python in the KakaoTalk prefix.
# PASS: riched20 survives ITextRange SetText -> Collapse -> Select (patched build installed).
# FAIL: the process aborts with the MEPF_REWRAP assertion (stock Wine riched20).
# Uses a temporary x86 embeddable Python (~11 MB) that is removed afterwards.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
kakaotalk="$HOME/.local/bin/kakaotalk"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/py.zip" https://www.python.org/ftp/python/3.13.15/python-3.13.15-embed-win32.zip
mkdir "$tmp/py32"
bsdtar -xf "$tmp/py.zip" -C "$tmp/py32"
cp "$repo/tools/riched20-repro.py" "$tmp/repro.py"

status=0
"$kakaotalk" wine "Z:$tmp/py32/python.exe" -X utf8 "Z:$tmp/repro.py" "Z:$tmp/out.txt" \
  </dev/null >"$tmp/err.txt" 2>&1 || status=$?
cat "$tmp/out.txt" 2>/dev/null || true
grep -a 'Assertion failed' "$tmp/err.txt" || true

if [[ $status -eq 0 ]] && grep -q '^SURVIVED' "$tmp/out.txt"; then
  echo "PASS: riched20 handled SetText + Select without aborting"
else
  echo "FAIL: exit status $status (stock riched20 aborts here; run tools/build-riched20.sh)"
  exit 1
fi
