# AI-SETUP.md — AI 에이전트용 설치 안내

이 문서는 사용자를 대신해 이 저장소의 설정을 설치하는 **AI 코딩 에이전트**(Claude Code, Codex, OmO 등)를 위한 안내다.
사람이 읽을 설명은 [README.md](README.md)와 `docs/`에 있다. 여기서는 순서, 확인 조건, 하지 말아야 할 일을 정한다.

에이전트는 이 문서를 처음부터 끝까지 읽은 뒤 시작하고, 각 단계의 **확인** 조건이 통과해야 다음 단계로 넘어간다.
확인이 실패하면 그 자리에서 멈추고 사용자에게 출력과 함께 알린다. 추측으로 다음 단계를 진행하지 않는다.

---

## 0. 안전 규칙 (항상 지킬 것)

1. **root 권한을 쓰지 않는다.** `sudo`, `pacman -S` 같은 시스템 설치가 필요하면 멈추고 사용자에게 설치를 요청한다. 이 저장소의 모든 단계는 사용자 홈 안에서 끝난다.
2. **실제 대화방에 아무것도 보내지 않는다.** 카톡 창에 키 입력, 붙여넣기, 파일 드롭을 하지 않는다. 동작 확인이 꼭 필요하면 사용자에게 **나와의 채팅**을 열어 달라고 하고, 열었다고 확인받은 뒤에만 시험한다. Wine의 "앞 창"이 실제 단체방일 수 있다.
3. **카톡을 종료하기 전에 알린다.** `kakaotalk kill`은 열린 채팅 창을 모두 닫고 Windows 클립보드를 비운다.
4. **대화 내용을 기록하지 않는다.** `WINEDEBUG=+font`, `+richedit` 같은 추적은 화면의 글자를 그대로 남긴다. 이런 추적을 켰다면 디스크에 남기지 말고, 끝나면 `WINEDEBUG=-all`로 되돌린다. `+loaddll`, `+clipboard`는 괜찮다.
5. **큰 이미지를 Wayland 클립보드에 `image/bmp`로 올리지 않는다.** Hyprland의 XWayland 창 관리자가 망가져 재로그인해야 한다.
6. **`pkill -f` 패턴이 자기 셸에 걸리지 않게 한다.** `pkill -f '[k]akaotalk-clipbridge'`처럼 쓴다.
7. **사용자 설정 파일을 고치기 전에 백업한다.** `~/.config/hypr/hyprland.lua`, `autostart.lua`, `~/.config/omarchy/shell.json`은 `cp file file.bak.$(date +%s)`로 먼저 복사한다.
8. **카톡 로그인은 사용자가 한다.** 설치가 끝나면 사용자에게 로그인을 넘기고 기다린다. 계정 정보를 묻지 않는다.

---

## 1. 대상 환경 확인

아래가 모두 맞아야 한다. 하나라도 다르면 멈추고 사용자에게 알린다(다른 환경에서는 검증되지 않았다).

| 확인 | 명령 | 기대값 |
|---|---|---|
| CPU | `uname -m` | `aarch64` |
| 페이지 크기 | `getconf PAGESIZE` | `16384` (Asahi) |
| 데스크톱 | `hyprctl version \| head -1` | Hyprland 0.56 이상 |
| Lua 설정 | `ls ~/.config/hypr/hyprland.lua ~/.config/hypr/autostart.lua` | 둘 다 있음 |
| Omarchy | `command -v omarchy` | 경로가 나옴 |
| 입력기 | `pgrep -x fcitx5` | PID가 나옴 |
| 도구 | `./install.sh --check`의 첫 줄 (또는 `for b in curl bsdtar python3 magick wl-copy wl-paste jq patch make gcc bison flex inotifywait; do command -v $b >/dev/null \|\| echo "missing $b"; done`) | `[ok] tools` (또는 출력 없음) |
| 트레이용 | `python3 -c 'import gi; gi.require_version("Gio","2.0")'` | 오류 없음 |

없는 도구가 있으면 사용자에게 설치를 요청한다(규칙 1).

---

## 2. 설치 단계

저장소를 받은 폴더에서 실행한다. 경로는 모두 `$HOME` 기준이다.

### 2-0. 기본 경로: `install.sh`

`install.sh`가 README "설치 순서" 1-7을 자동으로 한다. 에이전트는 이 경로를 먼저 쓴다.

```bash
./install.sh --check   # 읽기만 한다. 단계마다 "[ok] <단계>" 또는 "[todo] <단계>: <빠진 것>"
./install.sh           # [todo]인 단계만 순서대로 실행하고, 끝난 단계는 건너뛴다
./install.sh --step N  # N단계(1-7)만 다시 실행한다
```

1. 먼저 `./install.sh --check`를 실행하고 출력 전체를 사용자에게 보여 준다. 종료 코드 0이면 설치는 끝난 상태다. 2-8로 간다.
2. `[todo] tools: missing ...`이 있으면 멈추고 사용자에게 그 도구의 설치를 요청한다(규칙 1). 스크립트도 `sudo`를 쓰지 않고 종료 코드 1로 멈춘다.
3. `./install.sh`를 실행하기 전에 사용자에게 알린다. Wine과 카톡 설치 파일 다운로드(수백 MB), riched20 빌드(약 110MB 다운로드, `~/.cache`에 약 1.2GB), `~/.config/hypr/hyprland.lua`, `autostart.lua`, `~/.config/omarchy/shell.json`, `~/.config/fcitx5/conf/xim.conf` 수정이 포함된다. 설정 파일은 스크립트가 `<파일>.bak.<시각>`으로 백업하고 블록을 한 번만 추가한다(규칙 7). 백업 경로는 출력의 `backup:` 줄에 나온다.
4. 스크립트는 단계마다 끝 상태를 다시 확인하고, 통과하지 못하면 `[fail] <단계>: <이유>`를 출력하고 멈춘다. 그때는 추측으로 다음 단계를 진행하지 말고, 출력과 함께 사용자에게 알린다. 원인이 분명하면 아래 2-1~2-7의 해당 단계를 손으로 실행해도 된다.
5. 끝나면 `./install.sh --check`를 다시 실행해 모든 단계가 `[ok]`이고 종료 코드가 0인지 확인한다. `[info] ... differs from the repo` 줄은 실패가 아니다. 저장소 쪽이 새 버전이면 사용자에게 알린 뒤 `--step 2`(bin 스크립트)나 `--step 5`(도우미 Python 파일)로 갱신한다.
6. 스크립트는 카톡을 실행하지 않는다. 이어서 2-6의 `hyprctl configerrors` 확인과 2-7의 `tools/riched20-selftest.sh`, 2-8을 한다.

아래 2-1~2-7은 스크립트가 하는 일을 단계별로 적은 것이다. 스크립트를 쓸 수 없거나 한 단계가 실패했을 때의 수동 경로이고, 각 **확인** 조건은 두 경로 모두에 적용된다.

### 2-1. ARM64EC Wine과 FEX 풀기

README의 "1. ARM64EC Wine과 FEX DLL 받기" 두 코드 블록을 그대로 실행한다.

**확인:** `~/.local/share/kakaotalk-ec/root/usr/bin/wine64 --version`이 `wine-11.18`로 시작한다.

다른 버전이 받아졌다면 이후 riched20 빌드에 `WINE_VERSION=<버전>`을 넘겨야 한다. 사용자에게 알리고 계속한다.

### 2-2. 실행 스크립트

```bash
install -m755 bin/kakaotalk bin/kakaotalk-clipbridge bin/kakaotalk-tray bin/kakaotalk-paste bin/kakaotalk-notify ~/.local/bin/
```

**확인:** `~/.local/bin/kakaotalk wine --version`이 2-1과 같은 버전을 출력한다.

### 2-3. prefix 만들기 (카톡 설치 전)

README "3. prefix 생성과 설정"을 실행한다. `Z:\path\to\wine\korean.reg`는 이 저장소의 실제 경로로 바꾼다(`Z:` = `/`).

**확인:**
- `ls ~/.local/share/kakaotalk-ec/prefix/drive_c/windows/syswow64 | wc -l`이 800 이상
- `~/.local/bin/kakaotalk wine reg query 'HKCU\Software\Wine\DllOverrides' /v winebth.sys`가 값 없이(빈 문자열) 나온다

### 2-4. 카카오톡 설치 (32비트)

README "4. 카카오톡 설치"를 실행한다. 64비트 설치 파일은 쓰지 않는다.

**확인:** `ls "$HOME/.local/share/kakaotalk-ec/prefix/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe"`

### 2-5. 도우미용 Python

README "5. 클립보드 도우미용 Python"을 실행한다(`setclip.py`, `dropfiles.py` 복사 포함).

**확인:** `ls ~/.local/share/kakaotalk-ec/py/{python.exe,setclip.py,dropfiles.py}`

### 2-6. 데스크톱 연동

규칙 7에 따라 백업한 뒤 README "6. 데스크톱 연동"을 실행한다.

- `cat ... >> hyprland.lua`는 **한 번만** 실행한다. 이미 들어 있는지 먼저 본다: `grep -c kakao_paste_update ~/.config/hypr/hyprland.lua`가 0일 때만 추가한다. `autostart.lua`도 `grep -c kakaotalk-clipbridge`로 같은 방식으로 확인한다.
- `shell.json`의 `omarchy.tray` 항목은 JSON으로 읽어 바꾼다(문자열 치환 금지). 바꾼 뒤 `python3 -m json.tool` 으로 검사한다.

**확인:**
- `hyprctl reload && hyprctl configerrors`의 출력이 비어 있다
- 사용자에게 알린 뒤 다시 로그인했거나, 다음을 수동으로 띄웠다: `setsid -f ~/.local/bin/kakaotalk-clipbridge`, `setsid -f ~/.local/bin/kakaotalk-tray`, `setsid -f ~/.local/bin/kakaotalk-notify`

### 2-7. 입력창 크래시 패치 (riched20)

```bash
tools/build-riched20.sh        # 필요하면 WINE_VERSION=<2-1의 버전>
tools/riched20-selftest.sh
```

- 빌드는 root 없이 llvm-mingw를 받아 쓴다. 약 110MB를 받고 빌드 중 `~/.cache`에 약 1.2GB를 쓴 뒤 지운다. 시작 전에 사용자에게 알린다.

**확인:** `riched20-selftest.sh`의 마지막 줄이 `PASS`다.

`FAIL`이면 `--restore`로 되돌리지 말고 출력과 함께 멈춘다.

### 2-8. 첫 실행과 로그인

```bash
setsid -f ~/.local/bin/kakaotalk
```

**확인:** 30초 안에 `hyprctl clients -j | jq -r '.[]|select(.class=="kakaotalk.exe")|.title'`에 `카카오톡`이 나온다.

그다음 **사용자에게 로그인을 넘기고 기다린다**(규칙 8).

---

## 3. 설치 후 점검

로그인이 끝났다고 사용자가 알려 준 뒤에 한다.

| 기능 | 확인 방법 | 기대값 |
|---|---|---|
| 스크린샷 붙여넣기 | `tools/clipboard-selftest.sh` (카톡 창으로 포커스를 잠깐 옮기고 클립보드를 작은 테스트 이미지로 바꾼다. 먼저 사용자에게 알린다) | 종료 코드 0, `PNG restored intact` |
| 파일 붙여넣기 바인딩 | 사용자가 카톡 창을 클릭한 상태에서 `hyprctl binds -j \| jq -r '.[]\|select(.key=="V" and .modmask==4)\|.description'` | `KakaoTalk: paste copied files as attachments` |
| 타이핑 중 탭 막기 | 사용자가 카톡에서 입력하는 동안 `hyprctl getoption input:touchpad:tap-to-click` | 입력 중 `false`, 멈추면 `true` |
| 크래시 패치 | `tools/riched20-selftest.sh` | `PASS` |
| 설치 전체 | `./install.sh --check` | 모든 단계 `[ok]`, 종료 코드 0 |
| 상태 점검 | `~/.local/bin/kakaotalk check` (카톡 실행 때마다 자동. 로그를 1MiB 넘으면 마지막 2000줄로 줄이고, 기본 riched20이 돌아왔으면 같은 Wine 버전일 때만 패치본을 다시 넣는다) | 오류 없이 끝남. 로그에 Wine 버전 경고가 있으면 2-7을 다시 한다 |
| 새 메시지 알림 | `pgrep -f '[k]akaotalk-notify'` | PID가 나옴. 실제 알림은 사용자가 다른 기기에서 **나와의 채팅**에 보내 보게 한다. 제목이 방 이름이고 `~/.local/state/kakaotalk-notify.log`에 `popup: notified (room)`이 남으면 된다 |
| 로그 | `tail ~/.local/state/kakaotalk.log` | `Assertion failed` 없음 |

실제 파일 첨부는 사용자가 **나와의 채팅**에서 직접 해 보게 한다(규칙 2). "파일 전송" 확인 창이 뜨면 성공이다.

---

## 4. 되돌리기

| 대상 | 방법 |
|---|---|
| riched20 패치 | `tools/build-riched20.sh --restore` 후 카톡 재시작 |
| Hyprland 설정 | 2-6에서 만든 `.bak` 파일로 복원 후 `hyprctl reload` |
| 전체 | `~/.local/bin/kakaotalk kill` 후 `~/.local/share/kakaotalk-ec`와 `~/.local/bin/kakaotalk*`를 지운다 (사용자 확인 후) |

---

## 5. 사용자에게 보고할 내용

끝나면 다음을 짧게 알린다.

- 통과한 확인 조건과, 통과하지 못했거나 건너뛴 조건(이유 포함)
- 바꾼 사용자 파일과 백업 위치
- 사용자가 직접 해야 할 일(로그인, 나와의 채팅에서 파일 첨부 시험)
- 마지막 `./install.sh --check` 출력과 종료 코드
- 알려진 한계: 64비트 클라이언트 불가, 알림은 방 이름과 `새 메시지`뿐(보낸 사람·내용 없음), 바 아이콘에 안 읽음 표시 없음
