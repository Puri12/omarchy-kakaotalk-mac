# 카톡에서 타이핑 중 트랙패드 탭 막기

카카오톡에서 채팅을 치는 동안 손바닥이 트랙패드에 닿아 탭(가볍게 톡 치는 클릭)이 들어가는 문제를 막는 설정이다.

관련 파일: `config/hypr/hyprland-kakaotalk.lua`의 `input.keyboard.key` 부분

## 증상

- 카톡 입력창에서 한글을 치는 중에 커서가 엉뚱한 곳으로 옮겨지거나, 다른 채팅방 창이 클릭된다.
- 다른 앱에서는 거의 문제가 없는데 카톡에서 두드러진다.

## 원인

- Asahi(Apple Silicon) 트랙패드는 libinput의 "타이핑 중 비활성화(disable-while-typing)"만으로는 탭이 막히지 않는다. Omarchy 기본 설정(`default/hypr/input.lua`)도 같은 이유로 `tap_to_click = false`를 쓴다.
- 탭 클릭을 켜 둔 경우(`~/.config/hypr/input.lua`의 `tap_to_click = true`) 손바닥 탭이 들어온다.
- 카톡에서만 두드러지는 이유는 확인하지 못했다.

## 해결

카톡 창에 포커스가 있을 때 키가 눌리면 탭 클릭을 끄고, 마지막 키 입력 0.7초 뒤에 다시 켠다.

- Hyprland Lua의 `input.keyboard.key` 이벤트에서 `hl.config({ input = { touchpad = { tap_to_click = ... } } })`로 바꾼다.
- 꾹 누르는 물리 클릭은 계속 된다.
- 다른 앱에서는 탭 클릭 설정을 바꾸지 않는다.
- 탭 클릭을 원래 꺼 둔 경우(Omarchy 기본값)에는 필요 없다. 이 부분을 빼거나 그대로 둬도 된다. 다만 0.7초 뒤에 `tap_to_click = true`로 되돌리므로, 탭을 끈 채 쓰려면 이 부분을 **빼야** 한다.

## 확인

```bash
hyprctl reload && hyprctl configerrors                   # 오류 없음
hyprctl getoption input:touchpad:tap-to-click            # 카톡에서 입력하는 동안 false, 멈추면 true
```
