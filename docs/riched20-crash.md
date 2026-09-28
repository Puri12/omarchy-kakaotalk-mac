# 카카오톡이 스스로 종료되는 문제 (riched20 `MEPF_REWRAP` 단정문)

채팅 중 카카오톡이 예고 없이 사라지는 문제와, Wine의 riched20을 고쳐 다시 빌드하는 해결 방법이다.

관련 파일:

- `wine/riched20-cursor-coords-rewrap.patch`: Wine 11.18 `dlls/riched20/caret.c` 한 곳을 고치는 패치
- `tools/build-riched20.sh`: 패치한 32비트 `riched20.dll`을 빌드해 설치 (`--restore`로 원래대로)
- `tools/riched20-repro.py`, `tools/riched20-selftest.sh`: 재현 테스트

## 증상

- 카카오톡 창이 갑자기 사라진다. 트레이 아이콘도 함께 사라진다.
- `~/.local/state/kakaotalk.log`에 다음 줄이 남고 종료 코드는 3이다.

```
Assertion failed: ~para->nFlags & MEPF_REWRAP, file dlls/riched20/caret.c, line 232
=== ... exit 3 (pid ...)
```

확인한 환경에서는 사흘 동안 세 번 일어났다.

## 원인

카톡 채팅 입력창은 `RichEdit50W`(msftedit)이고, Wine에서는 Wine의 riched20이 처리한다.

- `cursor_coords()`(커서 화면 위치 계산)는 문단의 줄바꿈이 끝났다고 가정하고 `assert`로 확인한다.
- 그런데 `ITextRange::SetText`(richole.c)는 글자를 넣은 뒤 줄바꿈을 다시 하지 않는다.
- 그 직후 커서를 옮기거나(`ITextRange::Select`, `EM_SETSEL`) 포커스를 받으면(`WM_SETFOCUS`) 줄바꿈이 밀린 문단으로 커서 위치를 계산하게 되고, `assert`가 실패해 프로세스가 통째로 종료된다.

같은 단정문 오류가 WineHQ에 오래전부터 올라와 있다([Bug 40690](https://bugs.winehq.org/show_bug.cgi?id=40690), [Bug 39342](https://bugs.winehq.org/show_bug.cgi?id=39342)).

## 재현

32비트(x86) Windows Python으로 `RichEdit50W` 창을 만들고, 포커스를 준 뒤 TOM으로 `SetText` → `Collapse` → `Select`를 호출한다.

```bash
tools/riched20-selftest.sh
```

- 고치기 전(기본 Wine): 종료 코드 3과 위의 `Assertion failed` 줄 → `FAIL`
- 고친 뒤: `SURVIVED` → `PASS`

카톡 안에서 실제로 이 순서가 언제 일어나는지는 확인하지 못했다. 다만 같은 단정문을 원할 때 만들 수 있어서, 수정이 되었는지 판정하는 데 쓴다.

## 해결: 패치한 riched20 빌드

패치는 단정문 대신, 줄바꿈이 밀린 문단이면 먼저 줄바꿈을 하고 커서 위치를 계산한다.

```diff
-  assert(~para->nFlags & MEPF_REWRAP);
+  if (para->nFlags & MEPF_REWRAP)
+    wrap_marked_paras_dc( editor, hdc, FALSE );
+  run = cursor->run;
+  size_run = run;
```

줄바꿈 중에 run이 나뉠 수 있어서, run은 줄바꿈 뒤에 다시 읽는다.

```bash
tools/build-riched20.sh      # 빌드 후 ~/.local/share/kakaotalk-ec/root/usr/lib64/wine/i386-windows/riched20.dll 교체
tools/riched20-selftest.sh   # PASS 확인
~/.local/bin/kakaotalk kill && kakaotalk   # 카톡 재시작
```

- root 권한은 필요 없다. i386 PE 교차 컴파일러는 [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) 배포 파일을 받아 쓴다.
- 약 110MB를 받고, 빌드 중에 `~/.cache`를 약 1.2GB 쓴다. 끝나면 지운다(`KEEP_BUILD=1`이면 남긴다).
- 원본은 `~/.local/share/kakaotalk-ec/riched20-fix/riched20.dll.orig`에 보관한다. `tools/build-riched20.sh --restore`로 되돌린다.
- 파일은 새 파일로 바꿔치기(rename)하므로 실행 중인 카톡에는 영향이 없다. 재시작해야 적용된다.
- 설치된 Wine 버전과 빌드할 소스 버전이 다르면 스크립트가 멈춘다. `WINE_VERSION=...`으로 맞춘다.
- Wine RPM을 새로 풀면 원본으로 돌아가므로 스크립트를 다시 실행한다.

## 실패한 방식 (다시 시도하지 말 것)

| 시도 | 결과 |
|---|---|
| winetricks `msftedit`(Windows 7 SP1 x86의 원본 `msftedit.dll`) + `KakaoTalk.exe` 전용 `msftedit=native,builtin` | 재현 테스트는 통과. 하지만 **카톡이 이 DLL을 불러온 직후 스스로 종료**(종료 코드 0, 창이 뜨기 전) |
| 원본 `msftedit.dll`을 카톡 설치 폴더에만 두기 | 카톡이 `C:\windows\system32\MSFTEDIT.DLL` 전체 경로로 불러와서 무시됨 |
| `WINEDLLPATH`로 패치한 DLL을 먼저 찾게 하기 | 기본 Wine DLL 폴더가 우선이라 적용되지 않음 |
