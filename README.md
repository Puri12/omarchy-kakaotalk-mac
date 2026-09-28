# omarchy-kakaotalk-mac

Apple Silicon 맥(Asahi Linux)에서 돌아가는 Omarchy에서 **Windows용 카카오톡**을 쓰기 위한 설정 기록.

- 검증 환경: MacBook Pro 16" M1 Max, Omarchy 4.0.3 (Arch Linux ARM / Asahi Alarm), aarch64, **16K 페이지**, 화면 배율 2.0, Hyprland 0.56 (Lua 설정), fcitx5 + hangul
- 확인일: 2026-09-25
- 참고: x86_64 Omarchy용 가이드인 [minpeter/omarchy-kakaotalk](https://github.com/minpeter/omarchy-kakaotalk)는 이 맥에 그대로 쓸 수 없다. Bottles와 Soda가 x86 전용이기 때문이다. 이 저장소는 그 가이드의 최적화 항목을 ARM 환경으로 옮긴 것이다.

카카오톡 바이너리와 계정 정보는 들어 있지 않다. 설치 파일은 카카오 CDN에서 받는다.

웹 가이드: https://puri12.github.io/omarchy-kakaotalk-mac/ (`site/`, GitHub Actions로 배포)

AI 코딩 에이전트(Claude Code, Codex 등)에게 설치를 맡길 때는 [AI-SETUP.md](AI-SETUP.md)를 읽게 한다.

---

## 결론 요약

| 방식 | 결과 |
|---|---|
| Bottles + Soda (minpeter 가이드) | ❌ 모두 x86 전용 |
| muvm + FEX + x86 Wine (Kron4ek) | ❌ 32비트 클라이언트는 로그인 후 흰 창만 뜬다. 64비트 클라이언트는 Themida로 보호된 `Vox3.dll`에서 크래시 (FEX 위에서는 `syscall user dispatch`를 켤 수 없음) |
| **ARM64EC Wine 11.18 + FEX wow64 DLL, 32비트 클라이언트** | ✅ **동작함.** muvm 없이 16K 호스트에서 네이티브로 실행 |
| 같은 방식 + 64비트 클라이언트 | ❌ Themida로 보호된 `Vox.dll`이 풀린 코드로 넘어가는 순간 실행 위반 |

Wine은 [lacamar/wine-arm64ec](https://copr.fedorainfracloud.org/coprs/lacamar/wine-arm64ec/) COPR에 올라온 Fedora aarch64 RPM을 **풀어서** 쓴다. 시스템에는 설치하지 않는다.

---

## 파일 구성

```
install.sh                  설치 순서 1-7 자동 실행 (--check로 점검만, --step N으로 한 단계만)
bin/kakaotalk               실행 스크립트 → ~/.local/bin/  (kakaotalk check: 로그 정리, riched20 패치 재적용)
bin/kakaotalk-clipbridge    스크린샷 붙여넣기 브리지 → ~/.local/bin/  (로그인 시 자동 시작)
bin/kakaotalk-tray          바의 카톡 아이콘 (StatusNotifierItem) → ~/.local/bin/  (로그인 시 자동 시작)
bin/kakaotalk-paste         카톡 창의 Ctrl+V: 복사한 파일을 첨부로 넘김 → ~/.local/bin/
bin/kakaotalk-notify        새 메시지 데스크톱 알림 → ~/.local/bin/  (로그인 시 자동 시작)
wine/setclip.py             Wine 안에서 BMP를 Windows 클립보드(CF_DIB)에 넣는 도우미 → ~/.local/share/kakaotalk-ec/py/
wine/dropfiles.py           Wine 안에서 채팅방 창에 파일을 끌어다 놓기(WM_DROPFILES)로 넘기는 도우미 → ~/.local/share/kakaotalk-ec/py/
wine/korean.reg             한국어 UI(0412)와 한글 글꼴 치환 (설치 전에 넣어야 함)
wine/fontlink.py            한글 폰트 링크 .reg 생성기 (입력창 한글 네모 방지)
wine/riched20-cursor-coords-rewrap.patch  카톡이 스스로 종료되는 riched20 단정문 수정 (Wine 11.18)
wine/upstream/              Wine upstream에 보낼 riched20 패치 (conformance 테스트 포함)와 제출 안내
config/hypr/hyprland-kakaotalk.lua   창 규칙 → ~/.config/hypr/hyprland.lua 끝에 추가
config/hypr/autostart-kakaotalk.lua  자동 시작 → ~/.config/hypr/autostart.lua에 추가
config/fcitx5/xim.conf               On-The-Spot 한글 조합 → ~/.config/fcitx5/conf/
config/omarchy/shell-tray-entry.json 바 트레이에 아이콘 고정 → ~/.config/omarchy/shell.json의 omarchy.tray 항목
config/applications/kakaotalk.desktop 앱 메뉴 항목 → ~/.local/share/applications/
docs/clipboard-paste.md     스크린샷 붙여넣기 원리, 실패한 방식, 확인과 복구 방법
docs/file-paste.md          파일·동영상 붙여넣기 원리 (카톡 Ctrl+V가 파일을 안 찾는 이유), 실패한 방식
tools/clipboard-selftest.sh 붙여넣기 브리지 자동 점검 (작은 이미지로 안전하게)
tools/build-riched20.sh     패치한 32비트 riched20.dll 빌드·설치 (root 불필요, --restore로 원복)
tools/riched20-selftest.sh  riched20 단정문 재현 테스트 (PASS/FAIL)
tools/riched20-repro.py     재현 테스트 본체 (32비트 Windows Python에서 실행)
docs/riched20-crash.md      카톡이 스스로 종료되는 원인, 재현, 패치, 실패한 방식
docs/trackpad-typing.md     카톡에서 타이핑 중 트랙패드 탭 막기
docs/emoji.md               이모지·기호가 네모(☒)로 보이는 문제, 고친 범위와 남은 한계
docs/notifications.md       새 메시지 알림 원리와 한계
tools/check-site-links.py   웹 가이드(site/)의 저장소 링크 검사
.github/workflows/check.yml CI: bash -n, shellcheck, py_compile, luac -p, 링크 검사
AI-SETUP.md                 AI 에이전트용 설치 안내 (확인 조건과 안전 규칙 포함)
```

실행에 필요한 경로:

```
~/.local/share/kakaotalk-ec/root     RPM을 푼 ARM64EC Wine (약 2.3GB)
~/.local/share/kakaotalk-ec/prefix   Wine prefix
~/.local/share/kakaotalk-ec/py       Windows ARM64 embeddable Python + setclip.py + dropfiles.py
~/.local/share/icons/kakaotalk.png   바와 메뉴 아이콘 (카톡 설치 폴더에서 복사)
```

---

## 빠른 설치

저장소를 받은 폴더에서 실행한다. 아래 "설치 순서" 1-7을 차례로 실행하고, 이미 끝난 단계는 건너뛴다.

```bash
./install.sh --check   # 점검만 한다. 단계마다 [ok] 또는 [todo]를 출력하고, 모두 ok면 종료 코드 0
./install.sh           # [todo]인 단계만 순서대로 실행한다. 다시 실행해도 된다
./install.sh --step 2  # 한 단계만 다시 실행한다 (예: 저장소의 bin 스크립트로 갱신)
```

- `sudo`를 쓰지 않는다. 필요한 도구(`curl bsdtar python3 magick wl-copy wl-paste jq patch make gcc bison flex inotifywait`)가 없으면 목록을 출력하고 멈춘다. 직접 설치한 뒤 다시 실행한다.
- `~/.config`의 파일은 고치기 전에 `<파일>.bak.<시각>`으로 백업한다. Hyprland 설정 블록은 한 번만 추가하고, `shell.json`은 JSON으로 읽어 고친다.
- `--check`는 설치된 `~/.local/bin` 스크립트가 저장소와 다르면 `[info]` 줄로 알려 준다. 실패로 치지 않는다.
- 카톡을 실행하지 않는다. 끝나면 다시 로그인(또는 도우미 수동 실행), 카톡 실행, 로그인 순서를 안내한다.

각 단계가 하는 일은 아래 설치 순서와 같다. 스크립트가 멈추면 그 단계를 손으로 실행한다.

---

## 설치 순서

### 1. ARM64EC Wine과 FEX DLL 받기 (시스템 설치 없음)

COPR 저장소 메타데이터(`repodata/primary.xml`)에서 최신 빌드의 경로를 찾는다. 확인 당시 빌드는 `11027010-wine`(Wine 11.18-ec3)과 `11019142-fex-emu-wine`(2609-4)이었다.

```bash
B=https://download.copr.fedorainfracloud.org/results/lacamar/wine-arm64ec/fedora-43-aarch64
R=~/.local/share/kakaotalk-ec/root; mkdir -p $R ~/.cache/kakao-setup/ec && cd ~/.cache/kakao-setup/ec
for p in \
  11027010-wine/wine-core-11.18-ec3.fc43.aarch64.rpm \
  11027010-wine/wine-common-11.18-ec3.fc43.noarch.rpm \
  11027010-wine/wine-filesystem-11.18-ec3.fc43.noarch.rpm \
  11027010-wine/wine-pulseaudio-11.18-ec3.fc43.aarch64.rpm \
  11027010-wine/wine-{tahoma,system,marlett,symbol,wingdings,small,courier,ms-sans-serif,arial}-winefonts-11.18-ec3.fc43.noarch.rpm \
  11019142-fex-emu-wine/fex-emu-wine-2609-4.fc43.aarch64.rpm; do
  curl -fsSLO $B/$p && bsdtar -xf $(basename $p) -C $R
done
```

Fedora의 alternatives 스크립트가 해 주던 링크를 직접 건다. 이걸 빠뜨리면 `could not exec wineserver`나 `d3d11.dll not found`가 난다.

```bash
cd $R/usr/bin && ln -sf wine64 wine && ln -sf wineserver64 wineserver
for d in aarch64-windows i386-windows; do
  cd $R/usr/lib64/wine/$d
  for f in wine-*.dll; do t=${f#wine-}; [ -e "$t" ] || ln -s "$f" "$t"; done
done
```

`$R/usr/bin/wine64 --version`이 `wine-11.18 (Staging)`을 출력하면 된다. 없는 라이브러리는 카메라용 `libgphoto2`뿐이고 무시해도 된다.

### 2. 실행 스크립트 설치

```bash
install -m755 bin/kakaotalk bin/kakaotalk-clipbridge bin/kakaotalk-tray bin/kakaotalk-paste bin/kakaotalk-notify ~/.local/bin/
```

`kakaotalk`은 `HODLL=libwow64fex.dll`(32비트 x86 코드를 FEX로 에뮬레이션)과 `winebth.sys` 차단을 설정한다. `kakaotalk wine <명령>`으로 이 prefix의 Wine을 실행할 수 있다. `kakaotalk check`는 로그 정리와 riched20 패치 재적용을 한다(아래 "상태 점검" 참고).

### 3. prefix 생성과 설정 (카톡 설치 전에)

```bash
K=~/.local/bin/kakaotalk
$K wine wineboot -i
$K wine reg import 'Z:\path\to\wine\korean.reg'          # 한국어 UI (0412). 설치 전에 넣어야 적용됨
$K wine winecfg /v win10
$K wine reg add 'HKLM\System\CurrentControlSet\Services\winebth' /v Start /t REG_DWORD /d 4 /f
$K wine reg add 'HKCU\Software\Wine\DllOverrides' /v winebth.sys /t REG_SZ /d '' /f
$K wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 192 /f   # 배율 2.0 기준
$K wine reg add 'HKCU\Software\Wine\Fonts' /v LogPixels /t REG_DWORD /d 192 /f
cp /usr/share/fonts/noto-cjk/NotoSansCJK-{Regular,Bold}.ttc ~/.local/share/kakaotalk-ec/prefix/drive_c/windows/Fonts/
cp /usr/share/fonts/noto/NotoSansSymbols{,2}-Regular.ttf ~/.local/share/kakaotalk-ec/prefix/drive_c/windows/Fonts/   # 기호·점자 폴백
curl -fsSL -o ~/.local/share/kakaotalk-ec/prefix/drive_c/windows/Fonts/NotoEmoji-Regular.ttf 'https://github.com/google/fonts/raw/main/ofl/notoemoji/NotoEmoji%5Bwght%5D.ttf'   # 흑백 이모지 폴백
python3 wine/fontlink.py /tmp/fontlink.reg && $K wine reg import 'Z:\tmp\fontlink.reg'
```

`syswow64`가 채워졌는지 확인한다(파일 800개 이상). 비어 있으면 32비트 설치 파일이 `Application could not be started`로 실패한다.

### 4. 카카오톡 설치 (32비트 클라이언트)

```bash
curl -fsSL -o /tmp/KakaoTalk_Setup.exe https://app-pc.kakaocdn.net/talk/win32/KakaoTalk_Setup.exe
$K wine /tmp/KakaoTalk_Setup.exe /S
```

`C:\Program Files (x86)\Kakao\KakaoTalk\KakaoTalk.exe`가 생기면 된다. 64비트판(`lk.kakaocdn.net/talkpc/talk/win32/x64/KakaoTalk_Setup.exe`)은 이 환경에서 동작하지 않는다.

### 5. 클립보드 도우미용 Python

```bash
D=~/.local/share/kakaotalk-ec/py; mkdir -p $D && cd $D
curl -fsSL -o py.zip https://www.python.org/ftp/python/3.13.15/python-3.13.15-embed-arm64.zip && bsdtar -xf py.zip && rm py.zip
cp /path/to/wine/setclip.py /path/to/wine/dropfiles.py $D/
```

ARM64 PE라서 Wine에서 에뮬레이션 없이 네이티브로 실행된다.

### 6. 데스크톱 연동

```bash
cp "$HOME/.local/share/kakaotalk-ec/prefix/drive_c/Program Files (x86)/Kakao/KakaoTalk/skin/default/image/2.0/x2.0/setting_img_talkappicon.png" ~/.local/share/icons/kakaotalk.png
cp config/applications/kakaotalk.desktop ~/.local/share/applications/
install -Dm644 config/fcitx5/xim.conf ~/.config/fcitx5/conf/xim.conf && systemctl --user restart omarchy-fcitx5.service
cat config/hypr/hyprland-kakaotalk.lua >> ~/.config/hypr/hyprland.lua
cat config/hypr/autostart-kakaotalk.lua >> ~/.config/hypr/autostart.lua
hyprctl reload && hyprctl configerrors
```

`~/.config/omarchy/shell.json`의 `{"id": "omarchy.tray"}` 항목을 `config/omarchy/shell-tray-entry.json` 내용으로 바꾼다. 그다음 `omarchy restart shell`을 실행한다.

`.desktop`의 `Exec=kakaotalk`은 `~/.local/bin`이 세션 `PATH`에 있다고 가정한다(Omarchy 기본값). `Icon=kakaotalk`은 `~/.local/share/icons/kakaotalk.png`로 찾아진다.

### 7. 입력창 크래시 패치 (riched20)

기본 Wine의 riched20은 채팅 중 가끔 단정문(`MEPF_REWRAP`)으로 카톡을 통째로 종료한다. 패치한 32비트 `riched20.dll`로 바꾼다.

```bash
tools/build-riched20.sh      # llvm-mingw로 교차 빌드 후 설치 (약 110MB 다운로드, 빌드 후 정리)
tools/riched20-selftest.sh   # PASS면 적용됨
~/.local/bin/kakaotalk kill && kakaotalk
```

Wine RPM을 같은 버전으로 다시 풀었다면 `kakaotalk check`(카톡 실행 때마다 자동)가 보관해 둔 패치본을 다시 넣는다. 버전이 바뀌었다면 이 스크립트를 다시 실행한다. 자세한 내용은 [docs/riched20-crash.md](docs/riched20-crash.md)에 있다.

---

## 구성 요소 설명

### 한글 입력: On-The-Spot (`xim.conf`)

fcitx5의 기본값(`UseOnTheSpot=False`)에서는 X11 앱에서 조합 중인 한글이 **아래쪽 별도 네모**에 보였다가 늦게 입력된다. `UseOnTheSpot=True`로 바꾸면 입력창 안에 바로 표시된다.

### 한글 네모 방지 (`fontlink.py`)

입력창 글꼴(Tahoma, Segoe UI 등)에 한글이 없으면 네모로 보인다. 21개 글꼴에 `Noto Sans CJK KR` SystemLink를 걸어 한글을 대신 그리게 한다.

### 스크린샷 붙여넣기 (`kakaotalk-clipbridge` + `setclip.py`)

- Wine X11 드라이버는 `image/png`를 Windows 앱이 찾지 않는 "PNG"라는 형식으로만 넘긴다. Omarchy 스크린샷은 `image/png`만 올린다.
- 카카오톡 창에 포커스가 있으면(카톡을 보는 중에 찍은 스크린샷 포함), 브리지가 PNG를 BMP로 바꾸고 **Wine 안에서 Windows 클립보드(`CF_DIB`)에 직접 넣는다.** 3450×2224 스크린샷 기준 약 0.3초 걸린다.
- 카톡은 Wine 안에서 바로 읽으므로 큰 데이터가 XWayland를 거치지 않는다.
- Hyprland가 Wine 클립보드를 Wayland 쪽에 `image/bmp`로 복사해 오므로, **카톡에서 벗어나면 원래 PNG로 즉시 되돌린다.**

자세한 내용은 [docs/clipboard-paste.md](docs/clipboard-paste.md)에 있다. 동작 확인은 `tools/clipboard-selftest.sh`로 한다.

⚠️ **하지 말 것**

- 수 MB 이상의 이미지를 Wayland 클립보드(`image/bmp`)로 X11 앱에 넘기면 붙여넣기가 멈추고 **Hyprland의 XWayland 창 관리자가 망가진다.** 모든 X11 창이 사라지고, 로그아웃해야 복구된다.
- X11 CLIPBOARD 소유권을 두고 Hyprland xwm과 경쟁해서도 안 된다. 같은 고장이 난다.
- `text/uri-list` 방식도 안 된다. `wl-copy`가 `text/plain` 별칭을 같이 올려서 카톡이 파일 경로를 글자로 붙여넣는다.

### 파일·동영상 붙여넣기 (`kakaotalk-paste` + `dropfiles.py`)

- 카톡의 Ctrl+V는 클립보드에서 이미지, 텍스트, 카톡 전용 형식만 찾고 **파일(`CF_HDROP`)은 찾지 않는다.** 그래서 복사한 파일은 경로 글자로 붙는다.
- 채팅방 창은 파일 끌어다 놓기(`WM_DROPFILES`)는 받는다. 그래서 카톡 창에 포커스가 있을 때만 Ctrl+V를 `kakaotalk-paste`에 바인딩하고, 클립보드에 로컬 파일이 있으면 채팅방에 드롭으로 넘긴다. 카톡의 "파일 전송" 확인 창이 뜬다.
- 드롭 대상은 Hyprland에서 포커스된 카톡 창 하나다. 창 제목과 위치·크기로 Wine 쪽 창을 찾아 맞춘다. 맞는 창이 없으면 아무것도 드롭하지 않고 원래 Ctrl+V를 전달한다. Wine의 "앞 창"이 다른 대화방이어도 엉뚱한 방으로 가지 않는다.
- 드롭하려고 카톡 프로세스에 쓴 메모리 블록은 드롭이 끝나면 해제한다.
- 파일이 아니면 원래 Ctrl+V를 그대로 전달한다. 텍스트와 스크린샷 붙여넣기는 그대로다.

자세한 내용은 [docs/file-paste.md](docs/file-paste.md)에 있다.

### 타이핑 중 트랙패드 탭 막기 (`hyprland-kakaotalk.lua`)

- Asahi 트랙패드는 "타이핑 중 비활성화"만으로는 탭이 막히지 않는다. Omarchy 기본값은 그래서 탭 클릭을 끈다.
- 탭 클릭을 켜 두었다면, 카톡 창에서 키를 누르는 동안 탭 클릭을 끄고 마지막 입력 0.7초 뒤 다시 켠다. 물리 클릭은 계속 된다.
- 사용자의 `tap_to_click`이 켜져 있을 때만 동작하고, 끝나면 원래 값으로 되돌린다. 탭 클릭을 끈 채 써도 이 부분을 뺄 필요가 없다.

자세한 내용은 [docs/trackpad-typing.md](docs/trackpad-typing.md)에 있다.

### 입력창 크래시 패치 (`riched20-cursor-coords-rewrap.patch`)

- Wine의 `ITextRange::SetText`는 글자를 넣고 줄바꿈을 다시 하지 않는다. 그 직후 커서를 옮기거나 포커스를 받으면 커서 위치 계산의 `assert`가 실패해 카톡이 종료된다(종료 코드 3).
- 패치는 단정문 대신 밀린 줄바꿈을 먼저 한다. 32비트 테스트로 재현했고, 기본 Wine은 FAIL, 패치본은 PASS다.
- Windows 7 원본 `msftedit.dll`로 바꾸는 방법은 카톡이 시작 직후 종료해서 쓸 수 없었다.

자세한 내용은 [docs/riched20-crash.md](docs/riched20-crash.md)에 있다.

### 새 메시지 알림 (`kakaotalk-notify`)

- 이 환경의 32비트 카톡은 새 메시지 알림 창을 만들지 않는다. 대신 메시지가 오면 방마다 있는 채팅 기록 DB 파일(`chatLogs_<방 번호>.edb-wal`)을 고친다.
- `kakaotalk-notify`는 이 파일의 변경을 `inotifywait`로 지켜보고 데스크톱 알림(제목 `카카오톡`, 본문 `새 메시지`)을 띄운다. 알림을 누르면 카톡 창이 나온다.
- 한 방에서 5초 안에 이어진 변경은 알림 하나로 묶는다. 카톡 창에 포커스가 있을 때는 알리지 않는다.
- 보낸 사람과 방 이름은 보여 주지 않는다. 파일 이름만 보고 내용은 읽지 않는다.
- `autostart-kakaotalk.lua`로 로그인 시 자동 시작한다.

자세한 내용은 [docs/notifications.md](docs/notifications.md)에 있다.

### 상태 점검 (`kakaotalk check`)

`kakaotalk check`로 직접 실행할 수 있고, 카톡을 실행할 때마다 자동으로 실행된다.

- `~/.local/state/kakaotalk.log`가 1MiB를 넘으면 마지막 2000줄만 남긴다.
- Wine RPM을 다시 풀어 기본 `riched20.dll`이 돌아왔다면 보관해 둔 패치본(`~/.local/share/kakaotalk-ec/riched20-fix`)을 다시 넣는다. 패치본을 빌드한 Wine 버전과 설치된 버전이 같을 때만 넣고, 다르면 `tools/build-riched20.sh`를 다시 실행하라는 경고를 로그에 남긴다.

설치 전체의 점검은 `./install.sh --check`로 한다.

### 바 아이콘 (`kakaotalk-tray`)

- Wine의 트레이 아이콘은 XEmbed 방식이라 Omarchy 바가 표시하지 못한다.
- `xembedsniproxy`로 변환하면 표시는 되지만, **카톡 채팅창의 키보드 입력을 가로챘다.** 그래서 쓰지 않는다.
- 대신 PyGObject로 StatusNotifierItem을 직접 등록한다. 클릭하면 `kakaotalk`을 실행하고, 이미 떠 있는 카톡이면 숨은 창이 다시 나온다. 안 읽은 메시지 표시는 없다.
- 창을 X로 닫으면 카톡은 트레이로 숨는다. 바 아이콘이나 앱 메뉴로 다시 연다.

### 창 규칙 (`hyprland-kakaotalk.lua`)

- 카톡 창: 불투명(`force_rgbx`, opacity 1)
- Wine의 빈 `explorer.exe` 창: 숨김 (minpeter 가이드에서 가져옴)
- 카톡 창에 포커스가 있을 때만 Ctrl+V → `kakaotalk-paste`
- 카톡 창에서 타이핑하는 동안 트랙패드 탭 클릭 끄기

### minpeter 가이드 항목 대응

| 가이드 항목 | 이 환경 |
|---|---|
| winebth 차단 (레지스트리 907MB 비대화) | ✅ DLL override + `Start=4`. `system.reg`는 약 4MB, WINEBTH 기록 0건 |
| wineserver CPU 100% | ✅ 약 2% |
| ntsync | ✅ `/dev/ntsync`가 커널에 내장돼 있어 자동 사용 |
| DPI | ✅ 192 (배율 2.0) |
| Qt 환경변수 | ➖ 64비트 Qt 클라이언트용이라 해당 없음 |

---

## 문제 해결

| 증상 | 원인과 조치 |
|---|---|
| 카톡 창이 안 뜨고 프로세스만 있음 | XWayland xwm이 고장난 상태. 간단한 X11 창도 안 뜨면 확실하다. `omarchy system logout` 후 다시 로그인한다. Xwayland를 `kill`해도 재시작되지 않는다 |
| 카톡 창이 사라짐 | 트레이로 숨은 것. 바 아이콘을 누르거나 `kakaotalk`을 다시 실행한다 |
| 무엇이 빠졌는지 모름 | `./install.sh --check`로 단계별 `[todo]`를 보고 `./install.sh`로 채운다 |
| 새 메시지 알림이 안 뜸 | `pgrep -f '[k]akaotalk-notify'`로 실행 중인지 본다. 없으면 `setsid -f ~/.local/bin/kakaotalk-notify`. 카톡 창에 포커스가 있을 때는 원래 뜨지 않는다. [docs/notifications.md](docs/notifications.md) 참고 |
| Ctrl+V로 파일이 안 붙고 경로 글자가 붙음 | 포커스된 카톡 창을 Wine 쪽에서 찾지 못해 원래 Ctrl+V를 넘긴 것. 채팅방 창을 한 번 클릭한 뒤 다시 누른다 |
| 카톡이 통째로 종료되고 로그에 `MEPF_REWRAP` | 기본 riched20의 단정문. `kakaotalk check`를 실행하고 로그에 Wine 버전 경고가 있으면 `tools/build-riched20.sh`로 다시 패치한다. `tools/riched20-selftest.sh`로 확인 |
| 채팅 중 커서가 튀거나 다른 창이 클릭됨 | 손바닥 탭. `hyprland-kakaotalk.lua`의 타이핑 중 탭 막기 부분이 들어갔는지 확인 |
| 로그아웃/로그인 뒤 wireplumber CPU 100% | wireplumber 0.5.17의 루프 버그(`wp_proxy_get_bound_id` 이후). `systemctl --user kill --signal=KILL wireplumber && systemctl --user restart wireplumber` |
| 바에 아이콘이 안 보임 | `omarchy restart shell` |
| `pkill -f` 쓸 때 주의 | 패턴이 자기 셸의 명령줄에도 매칭돼 셸 자신이 죽는다. `[k]akaotalk` 형태로 쓴다 |

## 한계

- 64비트 클라이언트(`KakaoTalkUI.exe`)는 사용할 수 없다 (Themida).
- 통화는 충분히 검증하지 않았다.
- 알림은 `새 메시지`라는 기본 알림뿐이다. 이 환경의 32비트 카톡은 알림 창을 만들지 않아서, 보낸 사람, 방 이름, 내용은 보여 줄 수 없다. 다른 기기(휴대폰 등)에서 내가 보낸 메시지나 읽음 처리·동기화로 DB가 바뀌어도 알림이 뜰 수 있다.
- riched20 패치는 Wine 11.18 기준이다. 다른 버전은 `WINE_VERSION`을 맞춰 다시 빌드해야 한다.
- 바 아이콘에는 안 읽은 메시지 표시가 없다.

## 라이선스

이 저장소의 스크립트와 문서는 MIT([LICENSE](LICENSE))로 배포된다. 예외로 `wine/fontlink.py`는 [chaotic-ground/kakaotalk-on-wine](https://github.com/chaotic-ground/kakaotalk-on-wine)의 `link_fallback_fonts`를 고친 것이라 원본을 따라 **GPL-3.0-or-later**다. `wine/korean.reg`의 한국어 UI 레지스트리 값도 같은 저장소의 설명을 참고했다. winebth 차단과 빈 창 숨김 규칙 같은 일부 설정은 [minpeter/omarchy-kakaotalk](https://github.com/minpeter/omarchy-kakaotalk)을 참고했다. `wine/riched20-cursor-coords-rewrap.patch`는 Wine 소스를 고친 것이라 Wine과 같은 **LGPL-2.1-or-later**다. 카카오톡은 Kakao Corp.의 제품이며, 이 저장소에는 카카오 소프트웨어가 포함되어 있지 않다.
