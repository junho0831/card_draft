# Card Draft 개발 메모

## 현재 방향

이 프로젝트는 `AI 매칭형 TCG MVP`에서 `싱글플레이 로그라이크 덱빌딩 RPG`로 방향을 바꿨다.

현재 메인 흐름은 다음과 같다.

1. 런 시작
2. Act 맵 진행
3. 전투
4. 카드 보상
5. 이벤트 / 상점 / 휴식
6. 보스
7. 다음 Act 또는 런 종료

## 핵심 파일

- `res://scripts/core/main.gd`
  - 앱 허브, 서비스 조립, 공용 UI 진입점
- `res://scripts/core/run_flow_coordinator.gd`
  - 런 흐름, 화면 전환, 이어하기 라우팅
- `res://scripts/services/run_state.gd`
  - 로컬 런 저장/로드, 노드 진행 상태
- `res://scripts/services/run_generator.gd`
  - Act 로드와 시작 덱 생성
- `res://scripts/battle/battle_card_effects.gd`
  - 카드별 전투 효과 처리
- `res://scripts/services/relic_service.gd`
  - 유물 로드와 전투 훅 처리
- `res://scripts/services/event_service.gd`
  - 이벤트 로드와 랜덤 선택
- `res://scripts/services/enemy_service.gd`
  - 일반 적/엘리트/보스 데이터 로드
- `res://scripts/ui/screens/battle_screen.gd`
  - 전투 UI, 전투 상태, 전투 스냅샷 복원

## 데이터 파일

- `res://data/cards.json`
- `res://data/relics.json`
- `res://data/events.json`
- `res://data/enemies.json`
- `res://data/acts.json`

## 저장 파일

- `user://meta_profile.json`
  - 메타 강화, 설정, 카드 보관함용 로컬 프로필
- `user://run_state.json`
  - 진행 중 런 상태

## 구현 메모

- 전투 UI는 `battle_screen.gd`로 분리되어 있고 `main.gd`는 직접 전투 로직을 들고 있지 않는다.
- 런 흐름은 `run_flow_coordinator.gd`가 담당한다.
- 이어하기는 단순 `active_enemy` 재진입이 아니라 `battle_snapshot` 기준으로 전투 상태를 복원한다.
- 카드 제거/카드 강화 같은 서브플로우도 `pending_subscreen`을 런 상태에 저장해 재시작 후 복원한다.
- 스타터 덱은 `민병대 x3 / 초보 검병 x3 / 작은 불꽃 x2 / 응급 치료 x2`다.
- 스타터 카드는 보상/상점 풀에서 제외한다.
- 유물은 전투 훅 기반으로 적용한다.
- 보스/엘리트는 카드 보상 외에 유물 보상이 붙을 수 있다.
- 상점은 런 내 카드/유물/제거/회복 전용이다.
- 메타 진행은 현재 `영혼석`, `시작 체력`, `시작 골드`, `두 번째 기회`까지만 로컬로 반영한다.
- 현재 서버 관련 코드와 `/server` 모듈은 남겨두되, 런 코어는 로컬 기준으로 동작한다.

## 2026-06-10 작업 기록

- `battle_screen.gd`
  - `main.gd` 참조 불일치 수정
  - 컷신/리릭 컨텍스트 키 정리
  - `_refresh_ui()` 및 턴 타이머 생성 보강
  - 전투 중 카드 사용/AI 턴/피로 피해 경계 버그 수정
  - `battle_snapshot` 저장/복원 추가
- `run_flow_coordinator.gd` 추가
  - 새 런 시작, 이어하기, 맵/이벤트/상점/휴식/전투 라우팅 분리
- `main.gd`
  - 화면 전환 일부를 coordinator로 위임
  - 서브 화면 콜백 target 지정 가능하도록 `_add_menu_button`, `_show_message` 확장
- `run_state.gd`
  - `battle_snapshot`, `pending_subscreen`, `pending_message` 저장 필드 추가
- 이어하기 개선
  - 전투 중 손패/필드/턴/로그/타이머 복원
  - 카드 제거/강화 서브화면 복원
  - 이벤트 결과 확인 모달 복원
- `card_database.gd`
  - 저장된 `*_plus` 카드 ID를 재시작 후 다시 합성해 덱 복원 가능하게 수정
- 테스트 추가
  - `tests/godot/run_tests.gd` headless 테스트 러너 추가
  - `tests/godot/run_state_test.gd` 추가
  - `tests/godot/card_database_test.gd` 추가
  - `tests/godot/event_run_service_test.gd` 추가
  - `tests/godot/shop_run_service_test.gd` 추가
- 서비스 분리
  - `scripts/services/event_run_service.gd` 추가
  - `scripts/services/shop_run_service.gd` 추가
  - `event_screen.gd`, `shop_screen.gd`는 UI + 결과 라우팅 중심으로 단순화
