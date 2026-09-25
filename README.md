# omarchy-kakaotalk-mac

Apple Silicon 맥(Asahi Linux)에서 돌아가는 Omarchy에서 **Windows용 카카오톡**을 쓰기 위한 설정 기록.

- 검증 환경: MacBook Pro 16" M1 Max, Omarchy 4.0.3 (Arch Linux ARM / Asahi Alarm), aarch64, **16K 페이지**, 화면 배율 2.0, Hyprland 0.56 (Lua 설정), fcitx5 + hangul
- 확인일: 2026-09-25
- 참고: x86_64 Omarchy용 가이드인 [minpeter/omarchy-kakaotalk](https://github.com/minpeter/omarchy-kakaotalk)는 이 맥에 그대로 쓸 수 없다. Bottles와 Soda가 x86 전용이기 때문이다. 이 저장소는 그 가이드의 최적화 항목을 ARM 환경으로 옮긴 것이다.

카카오톡 바이너리와 계정 정보는 들어 있지 않다. 설치 파일은 카카오 CDN에서 받는다.

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
bin/kakaotalk               실행 스크립트 → ~/.local/bin/
bin/kakaotalk-clipbridge    스크린샷 붙여넣기 브리지 → ~/.local/bin/  (로그인 시 자동 시작)
bin/kakaotalk-tray          바의 카톡 아이콘 (StatusNotifierItem) → ~/.local/bin/  (로그인 시 자동 시작)
wine/setclip.py             Wine 안에서 BMP를 Windows 클립보드(CF_DIB)에 넣는 도우미 → ~/.local/share/kakaotalk-ec/py/
wine/korean.reg             한국어 UI(0412)와 한글 글꼴 치환 (설치 전에 넣어야 함)
wine/fontlink.py            한글 폰트 링크 .reg 생성기 (입력창 한글 네모 방지)
config/hypr/hyprland-kakaotalk.lua   창 규칙 → ~/.config/hypr/hyprland.lua 끝에 추가
config/hypr/autostart-kakaotalk.lua  자동 시작 → ~/.config/hypr/autostart.lua에 추가
config/fcitx5/xim.conf               On-The-Spot 한글 조합 → ~/.config/fcitx5/conf/
config/omarchy/shell-tray-entry.json 바 트레이에 아이콘 고정 → ~/.config/omarchy/shell.json의 omarchy.tray 항목
config/applications/kakaotalk.desktop 앱 메뉴 항목 → ~/.local/share/applications/
```

실행에 필요한 경로:

```
~/.local/share/kakaotalk-ec/root     RPM을 푼 ARM64EC Wine (약 2.3GB)
~/.local/share/kakaotalk-ec/prefix   Wine prefix
~/.local/share/kakaotalk-ec/py       Windows ARM64 embeddable Python + setclip.py
~/.local/share/icons/kakaotalk.png   바와 메뉴 아이콘 (카톡 설치 폴더에서 복사)
```

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
install -m755 bin/kakaotalk bin/kakaotalk-clipbridge bin/kakaotalk-tray ~/.local/bin/
```

`kakaotalk`은 `HODLL=libwow64fex.dll`(32비트 x86 코드를 FEX로 에뮬레이션)과 `winebth.sys` 차단을 설정한다. `kakaotalk wine <명령>`으로 이 prefix의 Wine을 실행할 수 있다.

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
cp /path/to/wine/setclip.py $D/
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

⚠️ **하지 말 것**

- 수 MB 이상의 이미지를 Wayland 클립보드(`image/bmp`)로 X11 앱에 넘기면 붙여넣기가 멈추고 **Hyprland의 XWayland 창 관리자가 망가진다.** 모든 X11 창이 사라지고, 로그아웃해야 복구된다.
- X11 CLIPBOARD 소유권을 두고 Hyprland xwm과 경쟁해서도 안 된다. 같은 고장이 난다.
- `text/uri-list` 방식도 안 된다. `wl-copy`가 `text/plain` 별칭을 같이 올려서 카톡이 파일 경로를 글자로 붙여넣는다.

### 바 아이콘 (`kakaotalk-tray`)

- Wine의 트레이 아이콘은 XEmbed 방식이라 Omarchy 바가 표시하지 못한다.
- `xembedsniproxy`로 변환하면 표시는 되지만, **카톡 채팅창의 키보드 입력을 가로챘다.** 그래서 쓰지 않는다.
- 대신 PyGObject로 StatusNotifierItem을 직접 등록한다. 클릭하면 `kakaotalk`을 실행하고, 이미 떠 있는 카톡이면 숨은 창이 다시 나온다. 안 읽은 메시지 표시는 없다.
- 창을 X로 닫으면 카톡은 트레이로 숨는다. 바 아이콘이나 앱 메뉴로 다시 연다.

### 창 규칙 (`hyprland-kakaotalk.lua`)

- 카톡 창: 불투명(`force_rgbx`, opacity 1)
- Wine의 빈 `explorer.exe` 창: 숨김 (minpeter 가이드에서 가져옴)

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
| 로그아웃/로그인 뒤 wireplumber CPU 100% | wireplumber 0.5.17의 루프 버그(`wp_proxy_get_bound_id` 이후). `systemctl --user kill --signal=KILL wireplumber && systemctl --user restart wireplumber` |
| 바에 아이콘이 안 보임 | `omarchy restart shell` |
| `pkill -f` 쓸 때 주의 | 패턴이 자기 셸의 명령줄에도 매칭돼 셸 자신이 죽는다. `[k]akaotalk` 형태로 쓴다 |

## 한계

- 64비트 클라이언트(`KakaoTalkUI.exe`)는 사용할 수 없다 (Themida).
- 통화, 파일 전송 전반, 알림은 충분히 검증하지 않았다.
- 바 아이콘에는 안 읽은 메시지 표시가 없다.
