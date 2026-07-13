# Card Draft

`Card Draft`는 5칸 필드 전투를 사용하는 싱글플레이 로그라이크 덱빌딩 RPG 프로토타입이다.

## 현재 빌드

- 메인 흐름: `새 런 시작 -> 맵 -> 전투 -> 카드 보상 -> 이벤트/상점/휴식 -> 보스 -> 결과`
- Act 1개: 국경지대
- 기본 런 길이: 5개 노드
  - `battle -> event/shop -> battle -> rest/shop -> boss`
- 스타터 4종 + 런 카드 풀 34장
- 유물 15개, 이벤트 5개
- 전투 규칙: 영웅 체력 0 승패, 마나 1부터 시작, 턴마다 +1, 필드 5칸
- 빌드 태그: 화염, 드로우, 사망, 버프, 저체력, 소환
- 빌드 체감
  - 전투 중 같은 활성 빌드 태그 카드를 이어 쓰면 연계 카운터가 표시되고 추가 효과가 발동
  - 보상 화면은 `바로 활성`, `연계 카드 확보`, `활성까지 N`, `활성 후 효과`를 표시
  - 주요 유물은 빌드 앵커 역할을 하며 전투 중 발동 텍스트와 플로팅 피드백을 제공
- 보스 패턴
  - 국경 수호자: 매 적 턴 선봉 공격 +1
  - 언데드 왕: 3턴마다 해골 지원
  - 강령술사 군주: 매 적 턴 저주 +1
- 초보자 유도 UI
  - 화면 상단의 `다음 행동` 배너로 지금 해야 할 일을 표시
  - 플레이어 턴에는 추천 카드/추천 공격을 짧은 문장으로 표시
  - 적 턴에는 다음 적 행동을 `유닛 공격`, `영웅 공격 위험`, `소환 준비`처럼 표시
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
- 보상 카드 중 1장은 현재 최고 빌드 태그에 맞춰 우선 제시되며, 선택 시 빌드 완성도가 어떻게 변하는지 함께 표시
- 상점에서 카드/유물 구매 또는 카드 제거
- 휴식에서 회복 또는 카드 강화
- 런 종료 후 결과 화면에서 메인 메뉴 복귀

## 주요 파일

- 메인 허브: `res://src/core/main.gd`
- 런 흐름 코디네이터: `res://src/core/run_flow_coordinator.gd`
- 전투 화면: `res://src/ui/screens/battle_screen.gd`
- 런 저장/진행 상태: `res://src/services/run_state.gd`
- 카드 데이터: `res://data/cards.json`
- 유물 데이터: `res://data/relics.json`
- 이벤트 데이터: `res://data/events.json`
- 적 데이터: `res://data/enemies.json`
- Act 데이터: `res://data/acts.json`

## 테스트

기본 개발 루프는 headless 회귀 테스트 하나만 실행한다.

```bash
godot4 --headless -s res://tests/godot/run_tests.gd
```

현재 포함:
- `RunState` 저장/진행 회귀
- `CardDatabase`의 `*_plus` 카드 복원 회귀
- `EventRunService` 이벤트 해결 로직 회귀
- `ShopRunService` 상점 구매/회복/제거 로직 회귀
- 카드 효과, 런 페이싱, 메인 플로우 smoke 테스트

UI를 바꾼 경우에만 반응형 캡처를 따로 확인한다.

```bash
godot4 --path . -s res://tests/godot/capture_ui_responsive.gd
godot4 --path . -s res://tests/godot/validate_ui_captures.gd
```

전투 재미/런 흐름을 확인할 때만 플레이스루 프로브를 실행한다.

```bash
godot4 --path . -s res://tests/godot/playthrough_probe.gd
```

## 문서

- 현재 코드 기준 게임 기획서: `res://docs/game-design.md`
- 개발 메모: `res://docs/knowledge.md`
- 카드 제작 가이드: `res://docs/card-authoring.md`
- UI/반응형 가이드: `res://docs/ui-responsive.md`
