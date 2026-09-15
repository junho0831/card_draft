# 전투 실행과 화면 수명 분리 (2026-09-15)

## 구현 범위

이번 단계는 공격 진입점과 화면 연출의 수명을 분리한다. 피해 계산, 처치 시 반격 생략, 돌파, 장비·사망 효과는 기존 규칙 함수를 유지한다. 전투 엔진 전체의 추출이나 저장 형식 변경은 포함하지 않는다.

- `src/battle/battle_attack_executor.gd`: 플레이어·AI의 유닛/영웅 공격을 세력과 전투 유닛 ID로 받는다. 첫 비동기 대기 전에 턴, 공격권, 대상, 선봉, 진행 중 행동을 검사하고 잠근다. 중복 요청은 거부한다.
- `src/ui/components/battle_presentation_session.gd`: 자동 화면 이동, 공격 접근·반동 Tween과 취소 가능한 대기를 관리한다. 화면을 다시 만들면 이전 세션을 폐기한다. 폐기한 Tween의 `finished` 신호를 무한히 기다리지 않는다.
- `landscape_battle_view.gd`: 레이아웃과 ID에 대응하는 화면 요소 찾기를 담당한다. 자신이 연결된 세션만 정리해 이전 화면의 종료가 새 화면을 취소하지 않게 한다.
- `battle_screen.gd`: 기존 규칙과 화면 연결을 유지한다. 카드, 필살기, 턴 전환의 진행 중 작업을 추적하고 메뉴 이동 전에 완료를 기다린다.

피해와 후속 효과를 적용하는 구간에는 비동기 대기를 넣지 않는다. 공격이 시작할 때의 연출 세션을 고정해 화면 회전 후 새 화면에서 같은 연출을 다시 시작하지 않는다. 기존 효과 렌더링 도우미와 일부 임시 시각 효과는 여전히 BattleScreen에 남아 있다.

## 중단과 저장

| 상황 | 동작 |
|---|---|
| 전장 스크롤 | 자동 화면 이동만 취소, 확정한 공격은 완료 |
| 화면 회전/재구성 | 이전 연출을 취소, 확정한 공격의 피해·공격권은 한 번 적용 |
| 메뉴 이동 | 진행 중 확정 행동을 마친 뒤 저장, 남은 AI 행동은 중단 |
| 이어하기 | 저장한 AI 단계와 유닛 공격권으로 남은 행동부터 진행 |

실행 잠금, Tween, 세션 객체는 저장하지 않는다. 기존 snapshot과 유닛 ID, AI 단계 필드를 사용한다. UI 버튼 이벤트 처리 중 화면을 바꿀 때 루트 패널은 먼저 숨긴 뒤 프레임 종료에 삭제한다.

## 검증 결과

Godot 4.6.3에서 별도 테스트 저장 경로로 실행했다.

- 회귀 검사 **1,393개 통과**. 새 실행기 검사 37개에는 기존 경로와 결과 비교(양 세력, 유닛/영웅, 처치, 장비·사망 효과), 잘못된 ID, 선봉, 중복 공격, 메뉴 저장, 남은 AI 공격 재개가 포함된다.
- 실제 Tween을 사용하는 자동 검사: 공격 도중 화면 재구성/메뉴 이동, 대기 해제, 피해 1회 적용, 저장 후 재개 통과.
- 화면 입력 검사: 844×390, 667×375, 390×844, 1280×720 통과. 자동 포커스, 수동 스크롤 취소, 고정 버튼, 공격 예측·입력을 확인했다.
- Android API 36 에뮬레이터의 QA 전용 APK에서 adb 터치 입력으로 카드 상세 열기/닫기, 공격자 선택, 전장 스크롤, 적 공격, 메뉴와 이어하기, 가로/세로 회전을 확인했다. 테스트 유닛은 적 HP 10→7, 아군 HP 10→8로 변했고, 이어하기와 회전 후에도 소모한 공격권과 체력이 보존됐다.
- 공격 도중 정확한 시점의 중단은 자동 Tween 검사로 검증했다. Android에서 빠르게 연속 입력한 메뉴 탭은 자동 이동 취소로 소비되어, 공격 완료 후 다시 메뉴를 눌렀다. 이 입력을 Android 공격 도중 메뉴 이동 성공으로 간주하지 않는다.

Android 패키지는 `com.card_draft.mobileqa`, 저장 경로는 `/data/user/0/com.card_draft.mobileqa/files/mobile-qa-0914`다. 캡처와 Android 로그는 `build/refactor-2026-09-15/`에 남긴다. 실물 휴대폰 검증은 수행하지 않았다.

기존 테스트 종료의 CanvasItem/ObjectDB 정리 경고가 남는다. Android 로그에서도 `can_process: !is_inside_tree()` 엔진 오류 2건을 관찰했다. 입력·저장 검증은 통과했지만 전체 화면 요소 수명 정리가 끝난 것으로 보지 않는다. 이번 변경으로 스크립트 오류나 공격 진행 정지는 관찰하지 않았다.

## 재실행

```bash
godot --headless --path . -s res://tests/godot/run_tests.gd -- --test-data-dir=/tmp/card-draft-refactor-regression
xvfb-run -a godot --path . -s res://tests/godot/battle_presentation_lifecycle_test.gd -- --test-data-dir=/tmp/card-draft-refactor-lifecycle
xvfb-run -a godot --path . -s res://tests/godot/capture_battle_redesign.gd -- --test-data-dir=/tmp/card-draft-refactor-landscape --landscape
```

다른 화면 크기의 옵션은 `capture_battle_redesign.gd`의 명령행 분기를 기준으로 사용한다. 테스트 저장은 실제 플레이 저장과 반드시 분리한다.
