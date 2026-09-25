# 스크린샷 붙여넣기 (클립보드 이미지 → 카카오톡)

Omarchy에서 찍은 스크린샷을 카카오톡 채팅창에 **Ctrl+V로 이미지 첨부**하기 위한 설정이다.

관련 파일:

- `bin/kakaotalk-clipbridge` → `~/.local/bin/` (로그인 시 자동 시작)
- `wine/setclip.py` → `~/.local/share/kakaotalk-ec/py/`
- Windows ARM64 embeddable Python → `~/.local/share/kakaotalk-ec/py/`
- `tools/clipboard-selftest.sh`: 동작 확인용

## 왜 그냥은 안 되나

1. Omarchy 스크린샷(`omarchy-capture-screenshot`)은 클립보드에 `wl-copy --type image/png` **하나만** 올린다.
2. 카카오톡은 XWayland 위의 Wine X11 드라이버로 돈다. Wine은 X11 클립보드의 `image/bmp`는 Windows 이미지 형식 `CF_DIB`로 바꾸지만, **`image/png`는 "PNG"라는 이름의 등록 형식**으로만 넘긴다. Windows 앱은 이 형식을 찾지 않는다. 그래서 카카오톡은 붙여넣을 이미지가 없다고 판단한다.

## 해결 방식

카카오톡 창에 포커스가 있을 때 클립보드가 `image/png`만 가지고 있으면, 브리지가 다음을 한다.

1. PNG를 BMP로 변환한다 (ImageMagick, 알파는 흰 배경에 합성).
2. **Wine prefix 안에서** Windows ARM64 Python으로 `setclip.py`를 실행해 Windows 클립보드에 `CF_DIB`를 직접 넣는다.
3. 카카오톡은 Ctrl+V를 누를 때 같은 Wine 안(wineserver)에서 이미지를 읽는다. **큰 데이터가 XWayland를 지나가지 않는다.**
4. Hyprland는 Wine 클립보드를 Wayland 쪽에 `image/bmp` 등으로 복사해 온다. 그래서 **카카오톡에서 포커스가 빠지면 원래 PNG를 다시 올린다.** 다른 Wayland 앱이 큰 BMP를 XWayland를 통해 끌어가지 않게 하기 위해서다. 카톡 안에서 새로 텍스트를 복사했다면 되돌리지 않는다.

이벤트는 두 곳에서 받는다.

- **Hyprland 이벤트 소켓(`activewindow`):** 다른 창에서 카톡으로 포커스가 옮겨올 때
- **`wl-paste --watch`:** 카톡을 보던 중에 스크린샷을 찍을 때. 영역 선택 화면은 레이어 오버레이라서 포커스 이벤트가 생기지 않는다.

3450×2224 스크린샷(BMP 약 23MB)을 기준으로 변환과 설정에 약 0.3초가 걸린다.

## 실패한 방식 (다시 시도하지 말 것)

| 시도 | 결과 |
|---|---|
| X11 CLIPBOARD를 직접 소유하고 `image/png` + `image/bmp` 제공 (python-xlib) | 카톡에 포커스가 가면 Hyprland xwm이 소유권을 되가져감. 되찾게 하자 핑퐁이 생겼고, **xwm이 고장나 모든 X11 창이 사라짐** (재로그인 필요) |
| 카톡 포커스 동안 Wayland 클립보드를 `image/bmp`로 교체 | 작은 이미지는 되지만, 실제 스크린샷(23MB)을 붙여넣자 **카톡이 멈추고 xwm이 다시 고장** (재로그인 필요) |
| 파일 경로를 `text/uri-list`로 제공 (Wine → CF_HDROP) | `wl-copy`가 `text/plain` 별칭을 자동으로 같이 올림. 카톡이 텍스트를 우선해서 **`file:///...` 경로 문자열이 붙여넣어짐** |

교훈: **수 MB 이상의 데이터를 Hyprland의 XWayland 클립보드 브리지로 넘기지 말 것.** 창 관리자가 망가지면 X11 창이 하나도 뜨지 않는다. `hyprctl eval`로 XWayland를 껐다 켜도, SIGTERM을 보내도 복구되지 않는다. 로그아웃해야 한다.

## 확인 방법

```bash
# 브리지가 떠 있는지
pgrep -af '[k]akaotalk-clipbridge'

# Wine 클립보드에 지금 들어 있는 이미지 크기
kakaotalk wine "Z:$HOME/.local/share/kakaotalk-ec/py/python.exe" \
  "Z:$HOME/.local/share/kakaotalk-ec/py/setclip.py" --check

# 작은 이미지로 전체 흐름 자동 점검 (카톡이 떠 있어야 함)
tools/clipboard-selftest.sh
```

`clipboard-selftest.sh` 결과가 이렇게 나오면 정상이다.

```
1 copied: wl=[image/png ]
2 kakao focused: wl=[PIXMAP image/bmp MULTIPLE #2 #17 ] CF_DIB=90040 bytes after 1.0s
3 focus back: wl=[image/png ]
   PNG restored intact
```

10초 안에 `CF_DIB`가 들어오지 않으면 실패로 끝난다. 브리지 로그를 보려면 브리지를 이렇게 띄운다.

```bash
setsid -f sh -c "exec $HOME/.local/bin/kakaotalk-clipbridge 2>>$XDG_RUNTIME_DIR/kakaotalk-clipbridge.log"
```

## 문제가 생겼을 때

| 증상 | 조치 |
|---|---|
| 붙여넣어도 아무것도 안 됨 | 브리지가 떠 있는지 확인한다. 없으면 `setsid -f uwsm-app -- ~/.local/bin/kakaotalk-clipbridge` |
| X11 창(카톡 등)이 전부 사라짐 | xwm 고장. `omarchy system logout` 후 다시 로그인한다 |
| 다른 앱에 붙여넣은 이미지가 BMP로 들어감 | 카톡에서 포커스를 옮기면 PNG로 되돌아간다. 카톡이 포커스된 상태에서 다른 앱에 붙여넣으면 안 된다 |
