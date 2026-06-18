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
- `res://scripts/ui/ui_factory.gd`
  - 공통 화면 패널, 버튼 스타일, 안내 배너
- `res://docs/ui-card-draft-guide.md`
  - 8개 핵심 화면의 역할, 정보 우선순위, 플레이어 유도 기준

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
- `build_tags`는 카드/유물 데이터에 저장한다. 유효 태그는 `fire`, `draw`, `death`, `buff`, `low_hp`, `summon`이다.
- 빌드 점수 5 이상이면 해당 빌드가 활성화되고, 전투 효과가 실제로 적용된다.
- 카드 보상은 완전 랜덤 3장이 아니라, 현재 최고 빌드 태그와 맞는 카드 1장을 우선 섞는다.
- 전투 승리 조건은 `적 영웅 체력 0` 하나로 고정한다. 저주/의식 스택은 당장 카드 효과 상태값으로만 남긴다.
- UI는 초보자 유도를 우선한다.
  - `다음 행동` 배너로 현재 해야 할 일을 표시한다.
  - 주요 버튼은 `style_primary_button()`으로 강조한다.
  - 전투에서는 사용 가능한 카드, 공격 가능한 유닛, 선택된 유닛, 공격 대상을 서로 다르게 표시한다.
  - 불가능한 손패/노드/버튼은 어둡게 표시한다.
- 유물은 전투 훅 기반으로 적용한다.
- 보스/엘리트는 카드 보상 외에 유물 보상이 붙을 수 있다.
- 상점은 런 내 카드/유물/제거/회복 전용이다.
- 메타 진행은 현재 `영혼석`, `시작 체력`, `시작 골드`, `두 번째 기회`까지만 로컬로 반영한다.
- 서버/API/랭크/카드팩 구매 흐름은 제거했고, 런 코어는 로컬 Godot 기준으로 동작한다.

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

## 2026-06-12 작업 기록

- 빌드 중심 v2 반영
  - 카드/유물 데이터에 `build_tags` 추가
  - 화염/드로우/사망/버프/저체력/소환 활성 효과를 전투에 연결
  - 카드 보상이 현재 최고 빌드 태그를 1장 우선 제시하도록 변경
  - 저주/의식 특수 승리 조건 제거, 승리 조건을 `적 영웅 체력 0`으로 고정
- 초보자 유도 UI 추가
  - `ui_factory.gd`에 `make_guidance_banner()`, `style_primary_button()` 추가
  - 메인 메뉴에서 새 런/이어하기 버튼을 주요 행동으로 강조
  - 맵 화면에서 현재 진입 가능한 노드만 크게 밝게 표시
  - 보상 화면에서 현재 빌드 추천 카드와 선택 버튼 강조
  - 전투 화면에서 현재 행동 안내, 사용 가능 카드, 공격 가능 유닛, 공격 대상, 영웅 공격 버튼 강조

## 현재 시스템 한계 및 개선 과제 (TODO)

- **덱 순환 구조 부재 (Deck/Discard)**
  - `battle_screen.gd`의 덱 소진 시 리셔플 로직 없음 (바로 피로 피해 직행)
  - 버리는 패(Discard Pile) 데이터 자체가 없어 사용한 카드가 완전히 소멸됨
  - 핸드 수 제한 및 턴 종료 시 남은 패 버리기 로직 누락
- **단일 선형 맵 라우팅**
  - `run_state.gd`의 `advance_after_node()`가 단순 배열 인덱스 증가(`current_node_index += 1`)로 구현됨
  - 트리 형태의 분기 노드 데이터 구조 및 화면 상 분기 선택 UI 개발 필요
- **미구현 더미 로직**
  - `battle_card_effects.gd` 내 `bone_soldier`(해골 병사) 사망 시 부가 효과 처리 등이 `pass`로 남아있어 보완 필요
