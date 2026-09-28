# 파일·동영상 붙여넣기 (파일 관리자에서 복사 → 카카오톡 Ctrl+V)

파일 관리자(Nautilus 등)에서 복사한 파일이나 동영상을 카카오톡 채팅창에서 **Ctrl+V로 첨부**하기 위한 설정이다.

관련 파일:

- `bin/kakaotalk-paste` → `~/.local/bin/`
- `wine/dropfiles.py` → `~/.local/share/kakaotalk-ec/py/`
- `config/hypr/hyprland-kakaotalk.lua`의 Ctrl+V 바인딩 부분

## 증상

- 파일 선택 버튼으로는 파일과 동영상이 잘 올라간다. 업로드 자체는 문제가 없다.
- 파일 관리자에서 복사한 파일을 Ctrl+V 하면 첨부되지 않고 **파일 경로가 글자로** 입력창에 들어간다.
- 스크린샷 붙여넣기가 되는 건 [clipboard-paste.md](clipboard-paste.md)의 브리지가 이미지를 넣어 주기 때문이다.

## 원인: 카톡의 Ctrl+V는 파일 형식을 찾지 않는다

`KAKAO_WINEDEBUG='-all,trace+clipboard' kakaotalk`로 실행하고 채팅방에서 Ctrl+V를 눌러 확인했다. 카톡이 조회하는 형식은 다음 네 가지뿐이다.

```
NtUserIsClipboardFormatAvailable 0002 L"#2"                                -> CF_BITMAP
NtUserIsClipboardFormatAvailable c08d L"KAKAOTALK_CLIPBOARD_FORMAT_IMAGE"
NtUserIsClipboardFormatAvailable 000d L"#13"                               -> CF_UNICODETEXT
NtUserIsClipboardFormatAvailable c08e L"KAKAOTALK_CLIPBOARD_FORMAT_EMOJI"
```

Windows 클립보드에 탐색기와 같은 형식(`CF_HDROP`, `Shell IDList Array`, `FileNameW`, `Preferred DropEffect`)을 넣어 두어도, 카톡은 `CF_HDROP`(#15)을 한 번도 조회하지 않았고 클립보드를 열지도 않았다. 그래서 클립보드를 어떻게 바꿔도 Ctrl+V로는 파일이 첨부되지 않는다.

대신 채팅방 창(`EVA_Window_Dblclk`)에는 `WS_EX_ACCEPTFILES`가 켜져 있어 **파일 끌어다 놓기(`WM_DROPFILES`)는 받는다.** OLE 드롭 대상은 등록돼 있지 않다.

## 해결 방식

Ctrl+V를 끌어다 놓기로 바꿔 넘긴다.

1. Hyprland가 **카카오톡 창에 포커스가 있을 때만** Ctrl+V를 `kakaotalk-paste`에 바인딩한다(`window.active` 이벤트에서 바인딩을 걸고 푼다). 다른 앱의 Ctrl+V는 건드리지 않는다.
2. `kakaotalk-paste`는 Wayland 클립보드에 `text/uri-list`가 있고 모두 존재하는 로컬 파일이면, Wine 안에서 `dropfiles.py`를 실행한다.
3. `dropfiles.py`는 Wine의 전면 창(최상위 창)이 `WS_EX_ACCEPTFILES`인지 확인한다. 맞으면 `DROPFILES` 블록을 **카톡 프로세스 메모리에 직접 써 넣고**(`VirtualAllocEx` + `WriteProcessMemory`) 그 주소를 `WM_DROPFILES`로 보낸다. 다른 프로세스에서 만든 메모리 핸들은 카톡에서 쓸 수 없기 때문이다. 경로는 `Z:` 드라이브(`/`에 연결됨) 기준으로 바꾼다.
4. 카톡에 **"파일 전송" 확인 창**이 뜨고, "N개 전송"을 눌러야 실제로 보내진다.
5. 클립보드에 파일이 없거나(텍스트, 스크린샷 등) 전면 창이 드롭을 받지 않으면, `hl.dsp.send_key_state`로 원래 Ctrl+V를 전달한다. 합성 키는 바인딩을 다시 거치지 않는다.

## 설치

```bash
install -m755 bin/kakaotalk-paste ~/.local/bin/
cp wine/dropfiles.py ~/.local/share/kakaotalk-ec/py/
# config/hypr/hyprland-kakaotalk.lua의 Ctrl+V 부분을 ~/.config/hypr/hyprland.lua에 추가한 뒤
hyprctl reload && hyprctl configerrors
```

## 확인

- 카톡 창에 포커스를 두고 `hyprctl binds -j | jq '.[]|select(.key=="V" and .modmask==4)'`를 실행하면 `KakaoTalk: paste copied files as attachments`가 보인다. 다른 창으로 옮기면 사라진다.
- 파일 관리자에서 파일을 복사하고, 나와의 채팅방 입력창에서 Ctrl+V를 누른다. "파일 전송" 확인 창에 파일 이름과 크기가 나오면 된다.

## 실패한 방식 (다시 시도하지 말 것)

| 시도 | 결과 |
|---|---|
| 카톡 포커스 시 Windows 클립보드를 `CF_HDROP`만으로 교체 (텍스트 형식 없이) | 경로 글자는 안 붙지만 **아무 반응도 없음.** 카톡이 `CF_HDROP`을 조회하지 않음 |
| 위에 `Shell IDList Array`, `FileNameW`, `Preferred DropEffect`까지 추가 | 같음. 트레이스로 조회하지 않는 것을 확인 |
| 로컬 `GlobalAlloc` 핸들로 `WM_DROPFILES` 보내기 | 다른 프로세스의 핸들이라 카톡에서 무효. 카톡 메모리에 직접 써야 함 |

## 주의와 한계

- 붙여넣을 때마다 Wine 프로세스를 하나 띄워서 확인 창까지 1~2초쯤 걸린다.
- 드롭마다 카톡 메모리에 작은 블록(한 페이지)이 하나 남는다. 카톡을 재시작하면 사라진다.
- 진단용으로 `kakaotalk kill`로 카톡을 재시작하면 열려 있던 채팅방 창이 닫히고 Windows 클립보드가 비워진다.
- `trace+clipboard`를 켠 채로 두지 말 것. 로그가 계속 쌓인다.
- 폴더는 첨부하지 않는다(모두 일반 파일일 때만 드롭한다).
