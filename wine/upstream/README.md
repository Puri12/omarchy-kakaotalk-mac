# riched20 upstream 제출 안내

`0001-riched20-Rewrap-marked-paragraphs-before-computing-caret-coordinates.patch`는 `wine/riched20-cursor-coords-rewrap.patch`의 수정을 Wine upstream에 보낼 수 있게 `git format-patch` 형식으로 정리한 것이다.

## 내용

- `dlls/riched20/caret.c`: `cursor_coords()`에서 `assert(~para->nFlags & MEPF_REWRAP)`를 지우고, 문단에 재배치 표시가 남아 있으면 `wrap_marked_paras_dc()`로 먼저 재배치한다. 재배치 뒤에는 `cursor->run`을 다시 읽는다.
- `dlls/riched20/tests/richole.c`: `test_Select_after_SetText()`를 추가한다. 포커스를 받은 RichEdit 창에서 `ITextRange::SetText`, `Collapse(tomEnd)`, `Select`를 차례로 호출하고, 선택 위치가 3-3인지 확인한다. 수정 전 Wine에서는 이 테스트가 assertion으로 중단될 것이다.

원인은 `ITextRange::SetText`(`dlls/riched20/richole.c`)가 텍스트를 넣은 뒤 문단을 재배치하지 않는 데 있다. 그 직후 `Select`, `EM_SETSEL`, `WM_SETFOCUS`가 캐럿 좌표를 계산하면 assertion에 걸려 프로세스가 죽는다. 같은 증상이 WineHQ 버그 40690과 39342에 보고되어 있다.

## 검증 상태

- wine-11.18 태그의 `caret.c`와 `tests/richole.c`에 `git apply --check`와 `git am`을 돌려 두 파일 모두 깔끔하게 적용되는 것을 확인했다.
- `caret.c` 수정은 `tools/riched20-repro.py`로 확인했다. 수정 전 Wine 11.18은 assertion으로 종료 코드 3을 내고, 수정 후에는 통과한다.
- 추가한 conformance test는 여기서 컴파일하거나 실행하지 않았다. 제출 전에 아래 절차로 직접 빌드하고 돌려야 한다.

## 채워야 할 자리

패치 머리의 다음 값은 임시 값이다. Wine은 실명 저자만 받는다.

- `From: Your Name <you@example.com>`: 실제 이름과 이메일로 바꾼다.
- `Date:`: `git am`을 거쳐 커밋하면 다시 만들어지므로 그대로 두어도 된다.

가장 쉬운 방법은 `git am`으로 적용한 뒤 `git commit --amend --reset-author`로 저자를 자신으로 바꾸는 것이다.

## 제출 절차

1. gitlab.winehq.org에 가입하고 `wine/wine` 저장소를 fork한다.
2. fork를 받아 최신 master에서 브랜치를 만든다.

   ```sh
   git clone https://gitlab.winehq.org/<계정>/wine.git
   cd wine
   git remote add upstream https://gitlab.winehq.org/wine/wine.git
   git fetch upstream
   git switch -c riched20-cursor-coords upstream/master
   git am ~/path/to/0001-riched20-Rewrap-marked-paragraphs-before-computing-caret-coordinates.patch
   git commit --amend --reset-author --no-edit
   ```

   master가 11.18보다 앞서 있어 충돌이 나면 `git am --3way`로 다시 시도한다.

3. 빌드하고 테스트를 돌린다.

   ```sh
   ./configure --enable-win64   # 32비트 테스트도 보려면 --enable-archs=i386,x86_64
   make -j"$(nproc)"
   make dlls/riched20/tests/test
   ```

   `richole.c` 결과에 실패가 없어야 한다. 수정 전 커밋에서 같은 테스트가 중단되는지도 한 번 보면 좋다. 패치를 되돌리지 않고 caret.c만 확인하려면 `git stash`나 `git checkout HEAD~ -- dlls/riched20/caret.c`를 쓴다.

4. fork에 브랜치를 push하고 `wine/wine`의 master를 대상으로 Merge Request를 연다. 제목은 커밋 제목을 그대로 쓰고, 설명에는 버그 40690과 39342 링크를 적는다.
5. Wine CI(testbot) 결과와 리뷰 의견을 보고, 수정이 필요하면 커밋을 고친 뒤 force push한다.
