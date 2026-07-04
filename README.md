# Card Draft

`Card Draft`는 5칸 필드 전투를 사용하는 싱글플레이 로그라이크 덱빌딩 RPG 프로토타입이다.

## 현재 빌드

- 메인 흐름: `새 런 시작 -> 맵 -> 전투 -> 카드 보상 -> 이벤트/상점/휴식 -> 보스 -> 다음 Act`
- Act 1개: 국경지대
- 기본 런 길이: 8개 노드
  - `battle -> event/shop -> battle -> battle/shop -> shop -> elite/event -> rest -> boss`
- 스타터 4종 + 런 카드 풀 30장
- 유물 15개, 이벤트 5개
- 전투 규칙: 영웅 체력 0 승패, 마나 1부터 시작, 턴마다 +1, 필드 5칸
- 빌드 태그: 화염, 드로우, 사망, 버프, 저체력, 소환
- 초보자 유도 UI
  - 화면 상단의 `다음 행동` 배너로 지금 해야 할 일을 표시
  - 주요 버튼은 `▶`와 강조 테두리로 우선순위 표시
  - 전투 중 사용 가능한 카드/공격 가능한 유닛/공격 대상만 밝게 표시
- 런 저장: `user://run_state.json`
- 메타/설정용 로컬 프로필: `user://meta_profile.json`
- 이어하기 복원 범위
  - 전투 중 손패/필드/턴/로그/타이머 복원
  - 카드 제거/카드 강화 같은 서브 화면도 런 상태 기준으로 복원

## 실행

Godot 4.6 이상에서 이 폴더를 열고 실행한다.

시작 씬:

```text
res://src/core/Main.tscn
```

## 조작

- 메인 메뉴에서 `새 런 시작` 또는 `이어하기`
- 맵에서 밝게 표시된 현재 노드 `진입`
- 전투에서는 `다음 행동` 안내를 보고, 밝게 표시된 카드나 유닛부터 선택
- 전투 승리 후 카드 3장 중 1장 선택
- 보상 카드 중 1장은 현재 최고 빌드 태그에 맞춰 우선 제시
- 상점에서 카드/유물 구매 또는 카드 제거
- 휴식에서 회복 또는 카드 강화
- 런 종료 후 결과 화면에서 메인 메뉴 복귀

## 주요 파일

- 메인 허브: `res://scripts/core/main.gd`
- 런 흐름 코디네이터: `res://scripts/core/run_flow_coordinator.gd`
- 전투 화면: `res://scripts/ui/screens/battle_screen.gd`
- 런 저장/진행 상태: `res://scripts/services/run_state.gd`
- 카드 데이터: `res://data/cards.json`
- 유물 데이터: `res://data/relics.json`
- 이벤트 데이터: `res://data/events.json`
- 적 데이터: `res://data/enemies.json`
- Act 데이터: `res://data/acts.json`

## 테스트

최소 로직 회귀 테스트를 headless Godot script로 실행할 수 있다.

```bash
godot4 --headless -s res://tests/godot/run_tests.gd
```

현재 포함:
- `RunState` 저장/진행 회귀
- `CardDatabase`의 `*_plus` 카드 복원 회귀
- `EventRunService` 이벤트 해결 로직 회귀
- `ShopRunService` 상점 구매/회복/제거 로직 회귀

## 문서

- 현재 코드 기준 게임 기획서: `res://docs/game-design.md`
- 개발 메모: `res://docs/knowledge.md`
- 카드 제작 가이드: `res://docs/card-authoring.md`
- UI/반응형 가이드: `res://docs/ui-responsive.md`
