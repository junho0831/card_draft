# Card Draft

`Card Draft`는 5칸 필드 전투를 사용하는 싱글플레이 로그라이크 덱빌딩 RPG 프로토타입이다.

## 현재 빌드

- 메인 흐름: `새 런 시작 -> 세력 선택 -> 맵 -> 전투 -> 카드 보상 -> 이벤트/상점/휴식 -> 보스 -> 결과`
- Act 2개: 국경지대, 황량한 무덤
- 기본 런 길이: 총 10개 노드, 목표 10–15분
  - 각 Act: `battle -> event/shop -> battle/elite -> rest/shop -> boss`
  - 기존 저장의 지도는 그대로 이어서 진행
- 스타터 4종 + 런 카드 풀 40장
- 유물 15개, 이벤트 5개
- 전투 규칙: 영웅 체력 0 승패, 첫 턴 기본 마나 2, 이후 턴마다 +1, 필드 5칸
- 빌드 태그: 화염, 드로우, 사망, 버프, 저체력, 소환
- 시작 세력과 필살기
  - 인간: 소환·버프 중심, `왕국의 집결`로 근위대 소환과 전열 공격력 강화
  - 엘프: 드로우·소환 중심, `바람의 순환`으로 카드 2장과 이번 턴 마나 2 획득
  - 언데드: 사망·소환 중심, `죽음의 계약`으로 직접 선택한 아군을 영웅 피해와 해골로 전환
  - 세력 필살기는 마나 없이 전투당 1회 사용하며 전투 저장에도 사용 여부를 기록
- 전투 조작감
	- 적 대표 유닛이 선봉으로 전투를 시작하며, 선봉을 처치해야 적 영웅을 직접 공격할 수 있음
	- 적 유닛 처치 시 턴당 첫 1회 마나 1을 돌려받고 초과 피해는 적 영웅에게 돌파 피해로 전달
	- 손패 카드는 고정 슬롯 기반으로 배치되어 카드를 사용해도 남은 카드가 매번 한쪽으로 밀리지 않음
	- 카드 hover 시 확대, 회전 복원, 보드 프리뷰, 간단 툴팁을 함께 표시
	- `900px` 이하 세로 화면은 가로 레일을 사용하며 첫 탭으로 중앙 선택·확대, 두 번째 탭으로 카드 사용
	- 공격/소환/처치/연계 순간에는 플로팅 텍스트, 화면 흔들림, 직접 제작한 효과음을 사용
- 짧은 전투 도전
	- 전투마다 `필살기 사용`, `2연계`, `영웅 피해 없이 승리` 중 하나만 표시
	- 달성 후 승리하면 일반 전투 10G, 보스 전투 15G를 추가로 획득
- 빌드 체감
  - 전투 중 같은 활성 빌드 태그 카드를 이어 쓰면 연계 카운터가 표시되고 추가 효과가 발동
  - 한 전투의 첫 3연계는 빌드별 피니시로 강화되며 저장 후 이어하기에도 사용 여부가 유지됨
  - 화염·드로우·사망·버프·저체력·소환 빌드마다 플레이 방식을 바꾸는 대표 장비 1장이 있음
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
  - 전투 중 손패/필드/턴/로그/적 행동 단계 복원 (시간 제한 없음)
  - 카드 제거/카드 강화 같은 서브 화면도 런 상태 기준으로 복원

## 실행

자세한 명령어와 저장 경로는 [게임 실행과 테스트 안내](docs/run-and-test.md)를 참고한다.

```bash
godot --path .
```

Godot 4.6 이상에서 이 폴더를 열고 실행한다.

시작 씬:

```text
res://src/core/Main.tscn
```

## 조작

- 메인 메뉴에서 `새 런 시작` 후 인간·엘프·언데드 중 하나를 선택하거나 `이어하기`
- 맵에서 밝게 표시된 현재 노드 `진입`
- 전투에서는 `다음 행동` 안내를 보고, 밝게 표시된 카드나 유닛부터 선택
- 전투 승리 후 카드 3장 중 1장 선택
- 카드 보상은 주력 강화, 보조 연계, 새로운 방향의 세 후보를 제시
- 엘리트·보스 보상에서는 유물 2개 중 1개를 고른 뒤 카드를 추가하거나 건너뛰기
- 보스 보상은 실제 처치한 보스 카드와 다른 카드 2장을 함께 제시
- 패배해도 일반전투 5, 엘리트 15, 보스 30 영혼석을 받고, 완주하면 100 추가
- 상점에서 카드/유물 구매 또는 카드 제거
- 휴식에서 회복 또는 카드 강화
- 런 종료 후 결과 화면에서 메인 메뉴 복귀

## 주요 파일

- 메인 허브: `res://src/core/main.gd`
- 런 흐름 코디네이터: `res://src/core/run_flow_coordinator.gd`
- 전투 화면: `res://src/ui/screens/battle_screen.gd`
- 세력 선택 화면: `res://src/ui/screens/race_selection_screen.gd`
- 공통 UI 스타일: `res://src/ui/styles/ui_styles.gd`
- 전투 UI 스타일: `res://src/ui/styles/battle_styles.gd`
- 전투 충격/승리 FX: `res://src/ui/effects/battle_fx_layer.gd`
- 전투 도전 로직: `res://src/battle/battle_objective_service.gd`
- 3연계 피니시 로직: `res://src/battle/battle_combo_finisher.gd`
- 공통 Godot 테마: `res://assets/ui/main_theme.tres`
- 오디오 매니저: `res://src/services/audio_manager.gd`
- 런 저장/진행 상태: `res://src/services/run_state.gd`
- 카드 데이터: `res://data/cards.json`
- 유물 데이터: `res://data/relics.json`
- 이벤트 데이터: `res://data/events.json`
- 적 데이터: `res://data/enemies.json`
- Act 데이터: `res://data/acts.json`
- 런타임 효과음/BGM: `res://assets/audio/*.wav`
- 효과음 제작 스크립트: `res://tools/build_elevenlabs_sfx.py`, `res://tools/build_authored_sfx.py`, `res://tools/generate_game_sfx.gd`

## 효과음

전투 핵심 효과음은 ElevenLabs Text to Sound Effects로 만든 런타임 WAV를 우선 사용한다. 원본 MP3는 `res://assets/audio/source/raw/elevenlabs`, 최종 WAV는 `res://assets/audio`에 둔다. 모든 효과음은 리미터가 있는 `SFX` 버스를 사용하며, 강타·필살기·승리음은 클릭·hover보다 높은 재생 우선순위를 가진다.

```bash
ELEVENLABS_API_KEY=... python3 tools/build_elevenlabs_sfx.py
```

ElevenLabs 적용 대상:

- 카드 조작: `play`, `draw`
- 공격/소환: `hit_*`, `summon_*`
- 주문/장비: `spell_*`, `equipment_*`
- 전투 보상감: `combo`, `counter`, `impact_heavy`, `finisher`, `reward`, `victory_burst`
- `power_human`, `power_elf`, `power_undead`

`AudioManager`는 `res://assets/audio/{name}.wav`가 있으면 우선 사용하고, 파일이 없으면 fallback 스트림을 사용한다. 전투 BGM은 `battle_base`, `battle_tension`, `battle_lethal`, `battle_low_hp` 네 레이어를 판세에 따라 크로스페이드한다. API 키는 환경변수로만 사용하고 저장하지 않는다.

## 테스트

기본 개발 루프는 headless 회귀 테스트 하나만 실행한다.

```bash
godot --headless --path . -s res://tests/godot/run_tests.gd -- --test-data-dir=/tmp/card-draft-check
```

현재 포함:
- `RunState` 저장/진행 회귀
- `CardDatabase`의 `*_plus` 카드 복원 회귀
- `EventRunService` 이벤트 해결 로직 회귀
- `ShopRunService` 상점 구매/회복/제거 로직 회귀
- 카드 효과, 런 페이싱, 메인 플로우 smoke 테스트

UI를 바꾼 경우에만 반응형 캡처를 따로 확인한다.

반응형 기준은 `1920x1080`, `1280x720`, `1024x768`, `800x1280`, 모바일 웹 `390x844`다. `Canvas Items + Expand`는 최대 1.3배까지 자동 확대해 Full HD에서 조작 UI가 작아 보이지 않게 하면서 추가 전장 공간도 남긴다. 설정의 `UI 크기`에서 1280px 이상 큰 화면 표시를 `자동`, `크게`, `작게`로 보정할 수 있고, 작은 화면은 터치 가독성을 위해 기존 논리 픽셀을 유지한다. `900px` 이하 세로 전투는 카드 크기를 줄이는 대신 가로 레일, 중앙 스냅, 첫 탭 선택 확대를 사용한다.

```bash
godot --path . -s res://tests/godot/capture_ui_responsive.gd -- --test-data-dir=/tmp/card-draft-check
godot --path . -s res://tests/godot/validate_ui_captures.gd -- --test-data-dir=/tmp/card-draft-check
```

전투 재미/런 흐름을 확인할 때만 플레이스루 프로브를 실행한다.

```bash
godot --path . -s res://tests/godot/playthrough_probe.gd -- --test-data-dir=/tmp/card-draft-check
```

## 문서

- [게임 실행과 테스트 안내](docs/run-and-test.md)
- 전략 업데이트 검증 기록: `res://docs/strategy-verification.md`
- 현재 코드 기준 게임 기획서: `res://docs/game-design.md`
- 개발 메모: `res://docs/knowledge.md`
- 카드 제작 가이드: `res://docs/card-authoring.md`
- UI/반응형 가이드: `res://docs/ui-responsive.md`

## 전략 전투 업데이트

- 제한 시간 없이 장비·시체 폭발·언데드 필살기 대상을 직접 선택한다. 선택 취소, Esc, 우클릭은 자원을 소비하지 않는다.
- 전장 중앙에 다음 공격과 보스 패턴을 예고한다. 예고는 현재 전장 기준이며 추가 카드 효과는 미확정이다.
- 복수 태그 카드로 새 연계를 시작하면 선택한 전략의 주력 태그가 활성 상태일 때 우선한다. 전략이 없는 기존 런은 소환 우선 규칙을 유지한다. 이미 이어지는 태그가 있으면 그 연계를 유지한다.
- 드로우 연계 마나 환급은 턴당 한 번이다. 강화 카드의 실제 효과와 설명을 함께 갱신한다.
- 테스트는 `--test-data-dir`가 지정된 별도 경로만 사용한다. 자동 플레이는 세 세력의 일반/엘리트 경로 여섯 런을 실행하고 `playthrough_metrics.json`에 턴 수와 피니시 등을 기록한다.

## 처음 배우는 런

새 사용자는 세력 선택에서 `단계별로 배우기`가 켜져 있다. `바로 시작`은 모든 규칙이 열린 일반 런으로 시작한다. 기존 저장은 변경하지 않는다.

첫 1막은 소환·공격 → 장비 선택 → 장비·2연계 → 휴식·강화 → 보스·필살기·3연계 순서다. 첫 전투는 유닛 덱으로 진행하며, 고른 장비는 두 번째 전투 첫 손패에 보장한다. 보스에서 나머지 시작 카드를 열고, 보스 보상 이후 시작 유물과 일반 경로를 개방한다. 학습 중에는 선택적 전투 도전과 상세 빌드 패널을 숨긴다.

완료한 학습 단계는 프로필에 저장된다. 재시작하면 배운 단계의 안내는 생략하고, 첫 보스를 마친 다음 런부터 일반 진행이 기본이다. 학습 구간 자동 플레이는 아래 명령으로 세 세력을 검증한다.

```bash
godot --headless --path . -s res://tests/godot/playthrough_probe.gd -- --test-data-dir=/tmp/card-draft-learning --guided
```

두 번째 전투의 안내는 실제 행동에 맞춰 바뀐다. 아군이 없으면 소환, 마나가 부족하면 턴 종료, 장착할 수 있으면 대상 선택을 안내한다. 장비를 실제로 사용한 뒤에는 유닛 두 장으로 소환 2연계를 시도하도록 안내하고, 사용 완료 상태도 런 저장에 남긴다. 대상 선택 취소는 장비 사용으로 기록하지 않는다.


## 세력별 시작 전략

일반 런과 `바로 시작 · 전략 고르기`에서는 세력별 두 전략 중 하나를 고른다. 각 전략의 장점·약점·첫 행동과 시작 유물을 확인하고, `덱 10장 펼쳐보기`로 구성을 볼 수 있다. 하단 시작 버튼을 눌러야 런이 저장된다.

| 세력 | 전략 | 주력 태그 | 시작 유물 |
| --- | --- | --- | --- |
| 인간 | 군단 / 정예 | 소환 / 버프 | 검투사 투구 / 전술 교본 |
| 엘프 | 순환 / 기습 | 드로우 / 소환 | 세계수 잎 / 전장의 북 |
| 언데드 | 희생 / 혈투 | 사망 / 저체력 | 사령술사의 반지 / 피의 성배 |

학습 런은 기존 구성과 단계별 개방을 유지한다. 보상은 실제 덱·유물 점수로 결정하므로 다른 전략을 섞을 수 있다. 이어하기는 저장된 구성을 사용하며 기존 런을 자동 변환하지 않는다.

정의는 `data/starting_strategies.json`, 비교 결과와 구성 보정 사유는 [시작 전략 비교](docs/starting-strategy-comparison.md), 실행 명령은 [실행과 테스트](docs/run-and-test.md)를 참고한다.
