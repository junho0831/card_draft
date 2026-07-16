# Card Draft 개발 메모

## 현재 방향

이 프로젝트는 `AI 매칭형 TCG MVP`에서 `싱글플레이 로그라이크 덱빌딩 RPG`로 방향을 바꿨다.

현재 메인 흐름은 다음과 같다.

1. 런 시작
2. 5노드 Act 맵 진행
3. 전투
4. 카드 보상
5. 이벤트 / 상점 / 휴식
6. 보스
7. 런 종료

## 핵심 파일

- `res://src/core/main.gd`
  - 앱 허브, 서비스 조립, 공용 UI 진입점
- `res://src/core/run_flow_coordinator.gd`
  - 런 흐름, 화면 전환, 이어하기 라우팅
- `res://src/services/run_state.gd`
  - 로컬 런 저장/로드, 노드 진행 상태
- `res://src/services/run_generator.gd`
  - Act 로드와 시작 덱 생성
- `res://src/battle/battle_card_effects.gd`
  - 카드별 전투 효과 처리
- `res://src/services/relic_service.gd`
  - 유물 로드와 전투 훅 처리
- `res://src/services/event_service.gd`
  - 이벤트 로드와 랜덤 선택
- `res://src/services/enemy_service.gd`
  - 일반 적/엘리트/보스 데이터 로드
- `res://src/services/audio_manager.gd`
  - 효과음 재생, 직접 제작 WAV 로드, 코드 생성 fallback 스트림 관리
- `res://src/ui/screens/battle_screen.gd`
  - 전투 UI, 전투 상태, 전투 스냅샷 복원
- `res://src/ui/ui_factory.gd`
  - 공통 화면 패널, 칩, 안내 배너, 카드/유물 표시 helper
- `res://src/ui/styles/ui_styles.gd`
  - 공통 UI 버튼/패널/카드 텍스트 스타일
- `res://src/ui/styles/battle_styles.gd`
  - 전투 화면 전용 카드/필드/버튼 스타일
- `res://assets/ui/main_theme.tres`
  - 코드에서 개별 스타일을 지정하지 않은 컨트롤의 중립적인 기본 테마
- `res://tools/generate_game_sfx.gd`
  - `AudioManager` 합성식을 이용한 효과음 WAV 재생성 스크립트
- `res://docs/ui-card-draft-guide.md`
  - 8개 핵심 화면의 역할, 정보 우선순위, 플레이어 유도 기준
- `res://docs/game-design.md`
  - 현재 코드 기준의 게임 기획 기준 문서

## 데이터 파일

- `res://data/cards.json`
- `res://data/relics.json`
- `res://data/events.json`
- `res://data/enemies.json`
- `res://data/acts.json`
- `res://assets/audio/*.wav`
  - 직접 제작 44.1kHz 16-bit mono 효과음

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
- 전투는 `discard_pile`, 덱 재셔플, 손패 제한 10장, 턴 종료 시 패 버리기까지 포함한다.
- 스타터 덱은 `민병대 x3 / 초보 검병 x3 / 작은 불꽃 x2 / 응급 치료 x2`다.
- 스타터 카드는 보상/상점 풀에서 제외한다.
- `build_tags`는 카드/유물 데이터에 저장한다. 유효 태그는 `fire`, `draw`, `death`, `buff`, `low_hp`, `summon`이다.
- 빌드 점수 5 이상이면 해당 빌드가 활성화되고, 전투 효과가 실제로 적용된다.
- 활성 빌드 태그 카드를 한 턴에 연속으로 사용하면 연계 카운터가 올라가고 태그별 추가 효과가 발동한다.
- 카드 보상은 완전 랜덤 3장이 아니라, 현재 최고 빌드 태그와 맞는 카드 1장을 우선 섞는다.
- 보상 카드는 `바로 활성`, `연계 카드 확보`, `활성까지 N`, `활성 후 효과`처럼 빌드 완성도 기준의 이유를 표시한다.
- 전투 승리 조건은 `적 영웅 체력 0` 하나로 고정한다. 저주/의식 스택은 당장 카드 효과 상태값으로만 남긴다.
- UI는 초보자 유도를 우선한다.
  - `다음 행동` 배너로 현재 해야 할 일을 표시한다.
  - 주요 버튼은 `style_primary_button()`으로 강조한다.
  - 전투에서는 사용 가능한 카드, 공격 가능한 유닛, 선택된 유닛, 공격 대상을 서로 다르게 표시한다.
  - 불가능한 손패/노드/버튼은 어둡게 표시한다.
- 유물은 전투 훅 기반으로 적용한다.
- 대표 유물은 빌드 앵커 역할을 가진다. 예: 불타는 심장은 화염 2번째 주문을 강화하고, 기사단 깃발은 1체력 소환 유닛을 +1/+1로 키운다.
- 보스는 전투 상단에 한 줄 패턴을 예고하고 턴 시작 훅에서 작은 기믹을 발동한다.
  - 국경 수호자: 선봉 공격 +1
  - 언데드 왕: 3턴마다 해골 지원
  - 강령술사 군주: 저주 +1
- 보스/엘리트는 카드 보상 외에 유물 보상이 붙을 수 있다.
- 상점은 런 내 카드/유물/제거/회복 전용이다.
- 메타 진행은 현재 `영혼석`, `시작 체력`, `시작 골드`, `두 번째 기회`까지만 로컬로 반영한다.
- 서버/API/랭크/카드팩 구매 흐름은 제거했고, 런 코어는 로컬 Godot 기준으로 동작한다.
- 현재 기본 Act는 `battle -> event/shop -> battle -> rest/shop -> boss` 5노드 구조다.
- 엘리트는 기본 런에서 제외하고, 후속 도전 모드 후보로 둔다.
- 전투 안내는 플레이어 추천 행동과 다음 적 행동을 짧은 문장으로 보여준다.
- 화면 셸은 석재/양피지/룬 프레임을 사용하지 않는 흑연색 그라데이션을 공통 배경으로 사용한다. 카드 아트가 판타지 정체성을 담당하고, 조작 UI는 대칭 8px 이하 모서리, 얇은 중립 테두리, 파란 주요 행동색으로 정리한다.
- 카드 UI는 이름, 비용, 종족/속성, 핵심 효과, 보조 설명, 상태 바를 카드 안에서 분리하고 종족별 색은 테두리 우선순위로 유지한다.
- 손패는 현재 `Control` 기반 수동 배치다. 카드마다 `_hand_slot` 런타임 값을 부여해 카드를 사용해도 남은 카드가 매번 재정렬되지 않게 하고, 첫 5장은 교차 슬롯에 넓게 배치한다. 위치/회전/scale/`z_index`는 슬롯 기준으로 계산한다.
- 카드 hover 시 확대, 회전 복원, 보드 프리뷰, 간단 툴팁을 함께 보여준다.
- 효과음은 `assets/audio/*.wav`를 우선 사용한다. `tools/generate_game_sfx.gd`가 `AudioManager`와 같은 합성식으로 파일을 만들며, 파일이 없을 때도 같은 런타임 생성 스트림을 사용한다.
- 효과음 재질 기준은 `draw=카드 마찰`, `play=가죽 슬랩+테이블`, `summon=포털+착지`, `hit/counter=무기/방패 금속`, `finisher=다중 저역 충격`이다.
- 전투 도파민 포인트는 `연계`, `처치`, `강타`, `승리 + 골드` 순간에 집중한다.
- Godot CLI가 셸 PATH에 없으면 현재 개발 머신에서는 `/opt/homebrew/bin/godot` 경로를 사용했다.

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
  - `src/services/event_run_service.gd` 추가
  - `src/services/shop_run_service.gd` 추가
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

## 2026-07-13 작업 기록

- 짧은 런과 빌드 체감 강화
  - 기본 Act 흐름을 5노드 짧은 런으로 유지하고, 보스/방어형 적 전투가 과도하게 늘어지지 않도록 적 HP와 덱 구성을 조정
  - 시작 유물이 항상 부여되도록 기본 시작 유물을 `knight_banner`로 설정
  - 유물 발동 콜백을 전투 화면에 연결해 로그, 플로팅 텍스트, 빌드 트리거 수치로 확인 가능하게 변경
- 빌드별 콤보 카운터와 보상 이유 강화
  - 전투 중 빌드 칩에 현재 연계 태그와 연계 수를 표시
  - 추천 카드 선택 로직이 빌드 활성 직전 카드와 현재 연계 태그 카드를 더 우선하도록 조정
  - 보상 화면에 `바로 활성`, `연계 카드 확보`, `활성까지 N`, `활성 후 효과`를 추가
- 대표 유물 앵커 효과 강화
  - `burning_heart`, `world_tree_leaf`, `knight_banner`, `necromancer_ring`, `blood_chalice`, `war_drum`의 체감 효과와 설명을 강화
- 보스 한 줄 기믹 추가
  - 국경 수호자, 언데드 왕, 강령술사 군주가 각각 짧은 패턴을 가지고 전투 상단/로그/피드백에 표시됨
- 검증 상태
  - `run_tests.gd`: `PASS 273 assertions`
  - `playthrough_probe.gd`: 승리, `boss_steps=45`, `max_battle_steps=45`
  - `capture_ui_responsive.gd` + `validate_ui_captures.gd`: 반응형 캡처 검증 통과

## 2026-07-13 추가 작업 기록

- UI 스타일 모듈화
	- 공통 스타일은 `src/ui/styles/ui_styles.gd`, 전투 스타일은 `src/ui/styles/battle_styles.gd`로 분리
	- 기존 fantasy texture 중심 버튼/패널 의존을 줄이고 스타일 코드를 공통/전투 모듈로 분리
- 손패 안정화
  - 손패 카드에 `_hand_slot`을 부여해 카드 사용 후 남은 카드 위치가 한쪽으로 밀리지 않도록 변경
  - 새로 뽑은 카드는 중앙 우선 슬롯 순서로 빈자리에 들어가며, 기존 카드는 슬롯을 유지
- 효과음 직접 제작
	- 현재는 `tools/generate_game_sfx.gd`로 `click`, `hover`, `draw`, `play`, `summon`, `spell`, `hit`, `counter`, `finisher`, `combo`, `heal`, `reward`, `victory`, `defeat` WAV 생성
  - `AudioManager`에 커스텀 사운드 캐시와 WAV 직접 로더 추가
- 검증 상태
  - `run_tests.gd`: `PASS 273 assertions`
  - `capture_ui_responsive.gd` + `validate_ui_captures.gd`: 반응형 캡처 검증 통과

## 2026-07-16 추가 작업 기록

- 전체 화면 현대화
  - 석재 전장 배경과 룬 버튼 장식을 실제 렌더 경로에서 제거
  - 공통 패널과 버튼을 흑연색 표면, 얇은 테두리, 대칭 모서리로 통일
  - 1280x720 메인 메뉴를 2열 구조로 바꾸고 실제 카드 아트를 첫 화면에 확대 표시
  - 맵은 가로 화면에서 경로 보드를 첫 화면에 유지하고, 전투는 중복 영웅/전장 헤더를 압축해 손패와 턴 조작을 함께 표시
- 시각 원칙
  - 판타지 감성은 카드 일러스트, 종족색, 전투 효과에 집중
  - 메뉴와 조작 UI에는 고전 MMORPG식 석재, 금장, 룬 프레임을 사용하지 않음
- 모바일 웹 레이아웃
  - 기본 창 크기를 1280x720으로 조정하고 390x844 모바일 캡처를 정식 검증 대상에 추가
  - 모바일 런 요약과 메뉴를 압축해 맵과 보상 콘텐츠가 첫 화면 가까이 보이도록 변경
  - 전투 필드는 기본 3칸을 크게 노출하고 4칸 이상은 가로 스와이프, 손패는 큰 카드 가로 스와이프 레일로 구성
  - 모바일 주요 행동 버튼은 최소 48px 높이를 유지
  - 실행 중 창 크기나 화면 방향이 바뀌면 0.2초 디바운스 후 현재 화면을 새 반응형 구간으로 자동 재배치
  - 전투 재배치 시 손패/필드/선택/타이머/로그 등 플레이 상태는 유지하고 화면 노드만 다시 생성

## 현재 시스템 한계 및 개선 과제 (TODO)

- **맵 구조 확장**
  - 현재는 레이어별 선택지를 고른 뒤 다음 인덱스로 진행한다.
  - 장기적으로는 여러 갈래 경로가 이어지는 트리형 맵 데이터와 경로 선택 UI가 필요하다.
- **상태 효과 확장**
  - 저주/의식 스택은 카드 효과 상태값으로 존재하지만, 아직 승리 조건이나 큰 전략 축으로 쓰이지 않는다.
  - 별도 상태 효과 규칙과 UI 설명을 정리할 필요가 있다.
- **밸런스와 폴리싱**
  - 카드/유물/이벤트 보상 수치, 적 덱 난이도, 골드 경제를 조정해야 한다.
  - 사운드, 파티클, 전투 애니메이션, 카드 연출은 이전보다 강화됐지만 아직 드래그 연출과 카드 사용 타깃팅 감각이 부족하다.
- **손패 레이아웃 고도화**
  - 현재는 데스크톱 고정 슬롯 손패, hover 확대, 모바일 가로 스와이프 손패가 적용되어 있다.
  - 다음 단계는 드래그 재배치, 타깃 프리뷰, 모바일 중앙 스냅과 탭 상세 보기다.
- **테스트 종료 경고 정리**
  - Godot headless 테스트는 통과하지만 종료 시 리소스 leak warning이 출력된다.
  - 기능 실패는 아니지만 테스트 품질 관점에서 정리할 필요가 있다.
