# 새 메시지 알림

카카오톡에 새 메시지가 오면 데스크톱 알림을 띄우는 설정이다. 알림을 누르면 카카오톡 창이 나온다.

관련 파일:

- `bin/kakaotalk-notify` → `~/.local/bin/`
- `config/hypr/autostart-kakaotalk.lua`의 `kakaotalk-notify` 줄

## 카톡 알림 창을 쓰지 않는 이유

Windows 카카오톡은 새 메시지가 오면 화면 구석에 작은 알림 창을 띄운다. 그런데 이 환경(32비트 카카오톡, ARM64EC Wine)에서는 메시지가 와도 **알림 창을 전혀 만들지 않는다.** 창 목록을 지켜보며 확인했다. 창이 없으니 Hyprland 규칙으로 옮기거나 가로챌 방법도 없다.

## 동작 방식

카톡은 메시지를 받으면 방마다 있는 채팅 기록 DB의 WAL 파일에 쓴다.

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
install -m755 bin/kakaotalk-notify ~/.local/bin/
# config/hypr/autostart-kakaotalk.lua의 kakaotalk-notify 줄을 Hyprland 자동 실행 설정에 추가한 뒤
hyprctl reload && hyprctl configerrors
```

`hyprctl reload`로는 `launch_on_start`가 다시 실행되지 않는다. 바로 쓰려면 `setsid -f ~/.local/bin/kakaotalk-notify`로 한 번 띄운다.

## 확인

- 다른 창에 포커스를 두고, 다른 기기나 다른 사람이 메시지를 보내게 한다. 알림이 한 번 뜨면 된다.
- 카톡 창에 포커스를 둔 채 메시지를 받으면 알림이 뜨지 않는다.
- 가짜 폴더로 시험할 수 있다.

```bash
mkdir -p /tmp/kn/users/a/chat_data
KAKAO_CHAT_DATA_GLOB='/tmp/kn/users/*/chat_data' NOTIFY_CMD='echo NOTIFY' ACTIVE_CLASS_CMD='echo ghostty' kakaotalk-notify &
echo x >> /tmp/kn/users/a/chat_data/chatLogs_123.edb-wal   # NOTIFY 카카오톡 새 메시지
```

## 처음 측정한 값

실제 `chat_data` 폴더를 60초 동안 읽기 전용으로 지켜본 결과는 다음과 같다(이벤트 수만 셌다).

| 파일 | 이벤트 |
|---|---|
| `chatLogs_<방>.edb-wal` (한 방) | `MODIFY` 8번, 모두 같은 1초 안 |
| `chatListInfo.edb-wal` | `MODIFY` 15번 |
| `talkmedia.edb-wal` | `MODIFY` 26번 |

`close_write`는 한 번도 나오지 않았다. 카톡은 WAL 파일을 열어 둔 채로 쓴다. 한 번의 쓰기 묶음이 1초 안에 끝나므로 5초 간격이면 메시지 하나에 알림이 한 번 뜬다.

## 한계

- 보낸 사람과 방 이름은 알 수 없다. DB가 암호화돼 있어서 "새 메시지"라고만 나온다.
- **내가 다른 기기(휴대폰 등)에서 보낸 메시지도** 이 PC의 DB에 기록되므로 알림이 뜬다. 이 PC의 카톡에서 보낸 메시지는 카톡 창에 포커스가 있을 때라 보통 뜨지 않는다.
- 카톡이 읽음 처리나 동기화로 WAL을 다시 쓰면 메시지가 없어도 알림이 뜰 수 있다.
- 한 방에 메시지가 5초 안에 연달아 오면 알림은 한 번만 뜬다.
- 카톡에서 알림을 끈 방은 구분하지 못한다(설정이 암호화돼 있음). 대신 알림의 "이 방 알림 끄기" 버튼으로 끈다(아래).
- 스크립트가 시작된 뒤에 새로 생긴 계정 폴더는 스크립트를 다시 시작해야 지켜본다.

## 방별 알림 끄기

카톡에서 음소거한 방도 알림이 온다. 카톡은 방별 알림 설정을 암호화된 DB(`chatListInfo.edb`)에 저장해서 읽을 수 없기 때문이다. 그래서 이 알림은 따로 끈다.

- 알림의 **"이 방 알림 끄기"** 버튼을 누르면 그 방의 ID가 `~/.config/kakaotalk-notify/muted`에 추가되고, 그 방은 더 이상 알림이 오지 않는다. 알림 자체를 누르면 카톡이 열린다.
- 다시 켜려면 그 파일에서 해당 줄을 지운다. 파일은 바로 다시 읽으므로 재시작할 필요가 없다.
- 방 이름은 알 수 없어서 파일에는 방 ID(`chatLogs_<ID>`의 숫자)와 끈 시각만 남는다.
- 카톡에서 이미 음소거한 방은, 처음 알림이 올 때 한 번씩 이 버튼으로 끄면 된다.
