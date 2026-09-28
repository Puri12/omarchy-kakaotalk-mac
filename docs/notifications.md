# 새 메시지 알림

카카오톡에 새 메시지가 오면 데스크톱 알림을 띄우는 설정이다. 알림을 누르면 카카오톡 창이 나온다.

관련 파일:

- `bin/kakaotalk-notify` → `~/.local/bin/`
- `bin/kakaotalk` (카톡 실행기; 알림에 쓸 방 이름을 넘겨준다) → `~/.local/bin/`
- `config/hypr/autostart-kakaotalk.lua`의 `kakaotalk-notify` 줄

## 동작 방식

카톡은 새 메시지가 오면 화면 오른쪽 아래에 알림 창을 띄운다. 이 창은 Wine 창이라 Omarchy 알림과 따로 놀고, 모든 워크스페이스 위에 고정돼 뜬다. 그래서 창은 숨기고 같은 알림을 Omarchy 알림으로 보낸다.

1. 알림 창은 제목 없는 `kakaotalk.exe` 창으로, 화면 아래 끝에서 열린 뒤 위로 올라온다. `kakaotalk-notify`는 Hyprland 이벤트 소켓에서 이런 창이 열리는 것을 보고, 고정을 풀어 숨김 워크스페이스(`special:katokpopup`)로 옮긴다. 메뉴·툴팁도 제목이 없어서, 화면 아래 끝에서 열리는 창만 알림 창으로 본다. 그림자 창(`KakaoTalkShadowWnd`)도 같이 옮긴다.
2. 알림 제목은 **방 이름**, 내용은 "새 메시지", 아이콘은 카카오톡이다. 메시지 내용과 보낸 사람은 넣지 않는다. 누르면 카톡이 열린다.
3. 카톡은 알림을 끈 방에는 알림 창을 띄우지 않으므로, 카톡의 방별 알림 설정이 그대로 적용된다.

### 방 이름을 얻는 방법

카톡은 알림 창의 글자를 Wine의 `DrawTextExW`로 그린다. 실행기 `kakaotalk`는 카톡을 Wine 글자 추적(`WINEDEBUG=-all,+text`)으로 띄우고, stderr를 `kakaotalk-notify relay <로그>`로 넘긴다.

- relay는 추적 줄에서 알림 창의 모양(왼쪽 위 모서리의 방 이름 → 한 열의 보낸 사람·내용 → "전송" 버튼)을 찾아 **방 이름만** `$XDG_RUNTIME_DIR/kakaotalk-notify/room.sock`으로 보낸다.
- 추적에는 카톡이 화면에 그리는 모든 글자(대화 내용 포함)가 들어 있으므로, relay는 추적 줄을 어디에도 쓰지 않고 버린다. 추적이 아닌 줄(Wine 오류, 충돌 기록)만 `~/.local/state/kakaotalk.log`에 남긴다.
- 알림 창이 열린 뒤 3초 안에 방 이름이 오지 않으면(예: 실행기를 거치지 않고 카톡을 띄웠을 때) 제목을 "카카오톡"으로 보낸다.
- `KAKAO_WINEDEBUG`를 직접 지정하면 relay를 쓰지 않고 예전처럼 stderr를 로그 파일에 바로 쓴다.

처음에는 알림 창을 캡처해 OCR로 읽었는데, 한글과 영문이 섞인 방 이름을 자주 틀리게 읽어서 이 방식으로 바꿨다.

## 설치

```bash
install -m755 bin/kakaotalk bin/kakaotalk-notify ~/.local/bin/
# config/hypr/autostart-kakaotalk.lua의 kakaotalk-notify 줄을 Hyprland 자동 실행 설정에 추가한 뒤
hyprctl reload && hyprctl configerrors
```

`hyprctl reload`로는 `launch_on_start`가 다시 실행되지 않는다. 바로 쓰려면 `setsid -f ~/.local/bin/kakaotalk-notify`로 한 번 띄운다.

## 확인

- 다른 사람이 메시지를 보내면 오른쪽 아래 카톡 창 대신 방 이름이 제목인 알림이 뜬다. `~/.local/state/kakaotalk-notify.log`에 `popup: notified (room)`이 남는다.
- `(no room name)`이면 카톡이 `kakaotalk` 실행기로 뜨지 않은 것이다(`pgrep -af '[k]akaotalk-notify relay'`에 아무것도 안 나옴). 카톡을 종료하고 `kakaotalk`로 다시 띄운다.

## 한계

- 알림 창을 찾을 때 창 위치(화면 아래 끝)와 글자 배치에 기대므로, 카톡 업데이트로 알림 창 모양이 바뀌면 방 이름이 빠지거나 알림이 안 올 수 있다.
- 보낸 사람과 내용은 넣지 않는다. Omarchy 알림 기록에는 방 이름이 남는다.
- 카톡이 알림 창을 띄우지 않으면(카톡 설정에서 알림을 껐거나, 카톡 창을 보고 있을 때) 알림도 없다.
