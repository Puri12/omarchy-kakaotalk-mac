# 새 메시지 알림

카카오톡에 새 메시지가 오면 데스크톱 알림을 띄우는 설정이다. 알림을 누르면 카카오톡 창이 나온다.

관련 파일:

- `bin/kakaotalk-notify` → `~/.local/bin/`
- `bin/kakaotalk` (카톡 실행기; 알림에 쓸 방 이름을 넘겨준다) → `~/.local/bin/`
- `config/hypr/autostart-kakaotalk.lua`의 `kakaotalk-notify` 줄

방식은 두 가지다. 기본은 카톡 알림 창을 숨기고 시스템 알림으로 바꾸는 **popup 모드**이고, 카톡이 알림 창을 띄우지 않는 환경을 위해 채팅 DB 파일 변화를 보는 **wal 모드**(`KAKAO_NOTIFY_MODE=wal`)가 있다.

## popup 모드 (기본)

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

## wal 모드



카톡이 알림 창을 띄우지 않는 환경용이다(이 저장소를 처음 만들 때 이 컴퓨터가 그랬다). `KAKAO_NOTIFY_MODE=wal`로 켠다. 카톡은 메시지를 받으면 방마다 있는 채팅 기록 DB의 WAL 파일에 쓴다.

```
~/.local/share/kakaotalk-ec/prefix/drive_c/users/$USER/AppData/Local/Kakao/KakaoTalk/users/<계정>/chat_data/chatLogs_<방 번호>.edb-wal
```

1. `kakaotalk-notify`는 `inotifywait`로 모든 계정의 `chat_data` 폴더를 지켜보고, `chatLogs_<숫자>.edb-wal` 파일의 `modify`, `close_write` 이벤트만 본다. `chatListInfo.edb-wal`, `talkmedia.edb-wal` 같은 다른 파일은 무시한다.
2. 메시지 하나에 쓰기가 여러 번 일어나므로, 방마다 알림을 보낸 뒤 **5초 동안** 같은 방의 이벤트를 무시한다.
3. 카카오톡 창(`kakaotalk.exe`)에 포커스가 있으면 알림을 보내지 않는다(`hyprctl activewindow -j`로 확인).
4. 알림은 `omarchy notification send`로 보낸다. 제목은 "카카오톡", 내용은 "새 메시지"이고, 누르면 `kakaotalk`를 실행해 숨어 있던 창을 다시 띄운다.
5. 계정 폴더가 아직 없으면(첫 로그인 전) 30초마다 다시 찾는다.

DB는 암호화돼 있고, 이 스크립트는 파일 이름과 이벤트만 본다. 내용은 읽지도 저장하지도 않는다.

## 설치

```bash
install -m755 bin/kakaotalk bin/kakaotalk-notify ~/.local/bin/
# config/hypr/autostart-kakaotalk.lua의 kakaotalk-notify 줄을 Hyprland 자동 실행 설정에 추가한 뒤
hyprctl reload && hyprctl configerrors
```

`hyprctl reload`로는 `launch_on_start`가 다시 실행되지 않는다. 바로 쓰려면 `setsid -f ~/.local/bin/kakaotalk-notify`로 한 번 띄운다.

## 확인

- popup 모드: 다른 사람이 메시지를 보내면 오른쪽 아래 카톡 창 대신 방 이름이 제목인 알림이 뜬다. `~/.local/state/kakaotalk-notify.log`에 `popup: notified (room)`이 남는다. `(no room name)`이면 카톡을 `kakaotalk` 실행기로 다시 띄운다.
- wal 모드: 다른 창에 포커스를 두고, 다른 기기나 다른 사람이 메시지를 보내게 한다. 알림이 한 번 뜨면 된다.
- 카톡 창에 포커스를 둔 채 메시지를 받으면 알림이 뜨지 않는다.
- 가짜 폴더로 시험할 수 있다.

```bash
mkdir -p /tmp/kn/users/a/chat_data
KAKAO_CHAT_DATA_GLOB='/tmp/kn/users/*/chat_data' NOTIFY_CMD='echo NOTIFY' ACTIVE_CLASS_CMD='echo ghostty' kakaotalk-notify &
echo x >> /tmp/kn/users/a/chat_data/chatLogs_123.edb-wal   # NOTIFY 카카오톡 새 메시지
```

## 처음 측정한 값 (wal 모드)

실제 `chat_data` 폴더를 60초 동안 읽기 전용으로 지켜본 결과는 다음과 같다(이벤트 수만 셌다).

| 파일 | 이벤트 |
|---|---|
| `chatLogs_<방>.edb-wal` (한 방) | `MODIFY` 8번, 모두 같은 1초 안 |
| `chatListInfo.edb-wal` | `MODIFY` 15번 |
| `talkmedia.edb-wal` | `MODIFY` 26번 |

`close_write`는 한 번도 나오지 않았다. 카톡은 WAL 파일을 열어 둔 채로 쓴다. 한 번의 쓰기 묶음이 1초 안에 끝나므로 5초 간격이면 메시지 하나에 알림이 한 번 뜬다.

## 한계

- popup 모드: 알림 창을 찾을 때 창 위치(화면 아래 끝)와 글자 배치에 기대므로, 카톡 업데이트로 알림 창 모양이 바뀌면 방 이름이 빠지거나 알림이 안 올 수 있다.
- popup 모드: Omarchy 알림 기록에 방 이름이 남는다.

wal 모드:

- 보낸 사람과 방 이름은 알 수 없다. DB가 암호화돼 있어서 "새 메시지"라고만 나온다.
- **내가 다른 기기(휴대폰 등)에서 보낸 메시지도** 이 PC의 DB에 기록되므로 알림이 뜬다. 이 PC의 카톡에서 보낸 메시지는 카톡 창에 포커스가 있을 때라 보통 뜨지 않는다.
- 카톡이 읽음 처리나 동기화로 WAL을 다시 쓰면 메시지가 없어도 알림이 뜰 수 있다.
- 한 방에 메시지가 5초 안에 연달아 오면 알림은 한 번만 뜬다.
- 카톡에서 알림을 끈 방은 구분하지 못한다(설정이 암호화돼 있음). 대신 알림의 "이 방 알림 끄기" 버튼으로 끈다(아래).
- 스크립트가 시작된 뒤에 새로 생긴 계정 폴더는 스크립트를 다시 시작해야 지켜본다.

## 방별 알림 끄기 (wal 모드)

카톡에서 음소거한 방도 알림이 온다. 카톡은 방별 알림 설정을 암호화된 DB(`chatListInfo.edb`)에 저장해서 읽을 수 없기 때문이다. 그래서 이 알림은 따로 끈다.

- 알림의 **"이 방 알림 끄기"** 버튼을 누르면 그 방의 ID가 `~/.config/kakaotalk-notify/muted`에 추가되고, 그 방은 더 이상 알림이 오지 않는다. 알림 자체를 누르면 카톡이 열린다.
- 다시 켜려면 그 파일에서 해당 줄을 지운다. 파일은 바로 다시 읽으므로 재시작할 필요가 없다.
- 방 이름은 알 수 없어서 파일에는 방 ID(`chatLogs_<ID>`의 숫자)와 끈 시각만 남는다.
- 카톡에서 이미 음소거한 방은, 처음 알림이 올 때 한 번씩 이 버튼으로 끄면 된다.
