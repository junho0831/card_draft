# 게임 실행과 테스트

이 문서는 Linux 터미널 기준이다. 프로젝트는 Godot 4.6을 대상으로 하며, 최근 검증 버전은 4.6.3이다.

## 준비

프로젝트 폴더로 이동하고 Godot 버전을 확인한다.

```bash
cd /home/junho/RiderProjects/card_draft
godot --version
```

다른 위치에 내려받았다면 `cd` 경로를 바꾼다. 현재 개발 PC의 Godot 실행 파일은 `/home/junho/.local/bin/godot`이다. `godot` 명령을 찾지 못하면 명령어의 `godot` 부분을 설치한 실행 파일의 전체 경로로 바꾼다. 이 PC의 `godot4`는 별도의 Snap 설치이므로 버전을 확인하고 사용한다.

## 게임 실행

### 터미널에서 바로 플레이

```bash
godot --path .
```

기본 시작 씬인 `src/core/Main.tscn`이 실행된다. 메인 메뉴에서 `새 런 시작` 또는 `이어하기`를 선택한다. 처음 시작하면 단계별 학습이 기본이며, 세력 선택 화면의 `바로 시작`으로 일반 런을 시작할 수 있다.

### Godot 에디터에서 실행

```bash
godot --editor --path .
```

에디터가 열리면 **F5**를 눌러 프로젝트를 실행하고 **F8**로 실행을 중지한다. Godot 프로젝트 관리자에서 `project.godot`을 가져온 뒤 열어도 된다.

### 개인 저장과 분리해서 직접 플레이

새 사용자 학습을 확인하거나 시험 삼아 플레이할 때 사용한다.

```bash
mkdir -p /tmp/card-draft-manual
godot --path . -- --test-data-dir=/tmp/card-draft-manual
```

이 실행의 런과 프로필은 지정한 폴더에 저장된다. 같은 폴더를 다시 사용하면 그곳의 진행 상태를 이어받는다. 처음부터 확인하려면 새로운 폴더 이름을 사용한다.

## 기본 회귀 테스트

코드를 수정한 뒤에는 우선 아래 테스트를 실행한다. 게임 창 없이 진행된다.

```bash
godot --headless --path . -s res://tests/godot/run_tests.gd -- --test-data-dir=/tmp/card-draft-tests
```

시작 시 출력되는 경로를 확인한다.

```text
TEST STORAGE: /tmp/card-draft-tests/run_state.json | /tmp/card-draft-tests/meta_profile.json
```

정상적으로 끝나면 다음과 같은 결과가 나온다.

```text
PASS 1199 assertions
```

숫자는 테스트 파일 수가 아니라 **검증 항목의 합계**이며 테스트 추가에 따라 달라진다. `FAIL`, `SCRIPT ERROR`, `Parse Error`가 나오면 해당 로그를 확인한다. 성공 시 종료 코드는 `0`이며, 명령 직후 `echo $?`로 확인할 수 있다. 실행 중 한동안 출력이 없을 수 있으므로 최종 결과가 나올 때까지 기다린다.

검증 범위는 카드 효과·강화, 대상 선택과 취소, 전투 및 보상 저장 복원, 정산 중복 방지, 단계별 학습 진행 등이다. 재미나 초보자의 이해도를 자동으로 판정하는 테스트는 아니다.

로그를 파일에 남기려면 다음처럼 실행한다.

```bash
godot --headless --path . -s res://tests/godot/run_tests.gd -- --test-data-dir=/tmp/card-draft-tests > /tmp/card-draft-tests.log 2>&1
```

다른 터미널에서 진행 로그를 볼 수 있다. 로그 보기의 `Ctrl+C`는 테스트 자체를 중지하지 않는다.

```bash
tail -f /tmp/card-draft-tests.log
```

## 자동 플레이 검사

전투나 런 진행을 변경했을 때 추가로 실행한다.

### 일반 런: 세 세력 × 일반·엘리트 경로

```bash
godot --headless --path . -s res://tests/godot/playthrough_probe.gd -- --test-data-dir=/tmp/card-draft-playthrough
```

### 학습 런: 세 세력

```bash
godot --headless --path . -s res://tests/godot/playthrough_probe.gd -- --test-data-dir=/tmp/card-draft-learning --guided
```

결과는 각 테스트 폴더의 `playthrough_metrics.json`에 기록된다. `cases`에서 세력별 `result`와 완료 지점 수를, `battles`에서 전투 턴 수와 피니시 발생 등을 확인한다. `hp_lost_net`은 회복을 포함한 전투 전후 체력 차이다.

자동 플레이에서 패배도 정상 종료로 처리하므로 종료 코드만 보지 말고 `PLAYTHROUGH CASES`의 승패도 확인한다.

## 화면 검사

화면을 변경했을 때 실행한다. 아래 캡처 명령에는 그래픽 화면이 필요하므로 `--headless`를 붙이지 않는다.

### 전체 반응형 화면

```bash
godot --path . -s res://tests/godot/capture_ui_responsive.gd -- --test-data-dir=/tmp/card-draft-ui
```

1920×1080, 1280×720, 1024×768, 800×1280, 390×844 화면을 `/tmp/card-draft-ui/ui_captures_responsive/`에 저장한다. 캡처 완료 후 파일 검사를 실행한다.

```bash
godot --headless --path . -s res://tests/godot/validate_ui_captures.gd -- --test-data-dir=/tmp/card-draft-ui
```

정상 결과는 `PASS responsive UI captures validated`다. 파일 검사는 이미지 존재와 기본 내용만 확인하므로 실제 글자 잘림, 버튼 위치, 안내 문구는 PNG를 열어 확인한다.

모바일 화면만 확인하려면 다음 명령을 사용한다. 이 명령만 실행한 폴더에서는 전체 해상도를 요구하는 파일 검사가 통과하지 않는다.

```bash
godot --path . -s res://tests/godot/capture_ui_responsive.gd -- --test-data-dir=/tmp/card-draft-ui-mobile --single-viewport mobile_390x844 390 844
```

### 단계별 학습 화면

```bash
godot --resolution 390x844 --path . -s res://tests/godot/capture_onboarding.gd -- --test-data-dir=/tmp/card-draft-onboarding-ui
```

지정한 폴더에 학습 선택, 지도, 첫 전투, 장비 보상, 두 번째 전투 PNG가 저장된다. 정상 결과는 `PASS onboarding captures`다. 첫 턴 마나 표시도 검사한다.

화면이 없는 Linux 환경에서는 Xvfb가 설치되어 있다면 캡처 명령 앞에 `xvfb-run -a`를 붙인다.

```bash
xvfb-run -a godot --resolution 390x844 --path . -s res://tests/godot/capture_onboarding.gd -- --test-data-dir=/tmp/card-draft-onboarding-ui
```

현재 캡처 종료 시 그래픽 리소스 해제 경고가 남는 경우가 있다. 관련 검증 기록은 [전략 업데이트 검증 기록](strategy-verification.md)을 참고한다.

## 저장 경로와 실행 시 주의점

- 일반 게임 저장은 Godot의 `user://run_state.json`, `user://meta_profile.json`을 사용한다. 실제 폴더는 운영체제와 설치 방식에 따라 달라진다.
- 테스트에는 반드시 `-- --test-data-dir=/절대/경로`를 넣는다. 앞의 단독 `--`는 뒤의 옵션을 게임 스크립트에 전달하기 위한 구분자다.
- 테스트 진입점은 분리된 저장 경로가 없으면 실행을 거부한다. 테스트 폴더에는 시험용 런·프로필이 기록되므로 개인 저장 폴더를 지정하지 않는다.
- Snap 실행에서는 `XDG_DATA_HOME`만 변경하는 방법으로 저장 격리를 보장할 수 없다. 위의 명시적 옵션을 사용한다.
- 여러 테스트를 동시에 실행한다면 서로 다른 폴더를 지정한다. `/tmp` 아래의 결과는 재부팅이나 시스템 정리로 삭제될 수 있다.


## 시작 전략 120회 비교

여섯 전략마다 같은 시드 20260909~20260918을 일반·엘리트 경로에 각각 적용한다. 아래 명령은 순차 실행하며 개인 저장과 분리된다.

```bash
for strategy in human_legion human_elite elf_cycle elf_ambush undead_sacrifice undead_blood; do
  godot --headless --path . -s res://tests/godot/playthrough_probe.gd -- --test-data-dir=/tmp/card-draft-matrix-$strategy --strategy=$strategy
done
```

각 폴더의 `progress.json`은 완료한 경우를 저장한다. 같은 명령을 다시 실행하면 완료 시드·경로를 건너뛰고 이어서 검사한다. 코드를 바꿔 새로 비교할 때는 새 폴더를 사용한다. 전략별로 폴더를 공유하지 않는다. 완료 결과는 `playthrough_metrics.json`이며 `STRATEGY RESULT`에 승수와 진행 정지가 표시된다. 진행 정지 또는 해당 전략의 20회 전패는 종료 코드 1이다.

`battles`의 `turns`, `first_turn_win`, `finisher`와 `metrics.equipment`, `metrics.sacrifices`, `metrics.draws`를 비교한다. 드로우는 시작 손패를 포함한 실제 손패 추가 수이며, 손패 초과로 버려진 카드는 제외한다. 자동 승률은 재미나 신규 사용자의 10~15분 플레이 시간을 보장하지 않는다.

### 전략 화면과 카드 입력 시나리오

```bash
godot --resolution 1280x720 --path . -s res://tests/godot/capture_strategies.gd -- --test-data-dir=/tmp/card-draft-strategy-desktop --desktop
godot --resolution 390x844 --path . -s res://tests/godot/capture_strategies.gd -- --test-data-dir=/tmp/card-draft-strategy-mobile
```

전략 선택·덱 펼쳐보기·시작 버튼 PNG와 인간·엘프 네 전략의 `input_scenarios.json`을 저장한다. 입력 시나리오는 실제 카드 선택 및 아군 대상 확정 핸들러를 호출하는 자동 검사이며 신규 사용자 직접 플레이 검증과는 구분한다.
