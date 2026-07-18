# Card Draft 개발 메모

현재 코드 구조와 유지보수 규칙을 빠르게 찾기 위한 문서다. 날짜별 작업 기록은 Git 이력으로 관리한다.

## 프로젝트 구조

```text
src/core/       앱 조립과 런 화면 전환
src/services/   저장, 데이터, 오디오, 런 서비스
src/battle/     카드 효과, 연계 피니시, 전투 도전
src/ui/screens/ 화면별 UI
src/ui/styles/  공통 토큰, 버튼, 전투·종족 스타일
src/ui/components/ 재사용 카드 컴포넌트
src/ui/effects/ 전투 시각 효과
data/           카드, 유물, 적, 이벤트, Act JSON
assets/         카드 아트, UI 테마, WAV 효과음
tests/godot/    기본 회귀와 선택형 화면 검증
```

## 핵심 파일

- `src/core/main.gd`: 앱 허브와 공통 화면 셸
- `src/core/run_flow_coordinator.gd`: 새 런, 이어하기, 화면 라우팅
- `src/services/run_state.gd`: 런 저장과 복원
- `src/services/run_generator.gd`: Act와 세력별 시작 덱
- `src/battle/battle_card_effects.gd`: 카드 효과
- `src/battle/battle_combo_finisher.gd`: 빌드 3연계 피니시
- `src/battle/battle_objective_service.gd`: 전투당 도전
- `src/services/relic_service.gd`: 유물 데이터와 전투 훅
- `src/services/audio_manager.gd`: WAV 로드, fallback 합성, 재생 우선순위
- `src/ui/screens/battle_screen.gd`: 전투 상태 연결과 표시
- `src/ui/ui_factory.gd`: 공통 UI 생성 진입점
- `src/ui/styles/ui_tokens.gd`: 간격, 크기, 상태색
- `src/ui/styles/card_race_styles.gd`: 세력·공용 카드 스킨
- `src/ui/components/card_view.gd`: 공통 카드 표면
- `src/ui/effects/battle_fx_layer.gd`: 공격과 승리 효과

## 데이터와 저장

- 원본 데이터: `data/cards.json`, `relics.json`, `events.json`, `enemies.json`, `acts.json`
- 런 저장: `user://run_state.json`
- 설정·메타·컬렉션: `user://meta_profile.json`
- 효과음: `assets/audio/*.wav`

카드·유물 JSON schema는 저장 호환성을 위해 임의로 변경하지 않는다. 내부 `중립` 값은 유지하고 UI에서만 `공용`으로 변환한다.

## 런타임 규칙

- 런은 세력 선택 후 5노드 Act를 진행한다.
- 구버전 저장에 `race_id`가 없으면 인간으로 복원한다.
- 전투는 `battle_snapshot`으로 손패, 필드, 덱, 버림 더미, 턴, 연계, 필살기 상태를 복원한다.
- 카드 제거·강화 같은 하위 화면은 `pending_subscreen`으로 복원한다.
- 세력별 시작 덱은 세력 카드 9장과 공용 카드 1장이다.
- `build_tags`는 `fire`, `draw`, `death`, `buff`, `low_hp`, `summon`만 사용한다.
- 빌드 점수 5부터 활성화하며 첫 3연계 피니시는 전투당 한 번이다.
- 승리 조건은 적 영웅 체력 0 하나다.

## UI 규칙

- 카드 정보 순서는 `비용/이름 -> 아트 -> 타입/세력 -> 핵심 효과`다.
- `CardView`의 `hand`, `field`, `reward`, `shop`, `collection` 모드를 사용하고 화면별 카드 구조를 다시 만들지 않는다.
- 카드 상태 우선순위는 `타겟/선택 -> 추천 -> 사용 가능 -> 세력색`이다.
- 버튼 역할은 `primary`, `secondary`, `danger`, `power`로 제한한다.
- 손패 카드는 `_hand_slot`을 유지해 사용 후 남은 카드 위치가 갑자기 바뀌지 않게 한다.
- 세로 화면 손패는 첫 탭 선택·확대, 두 번째 탭 사용 방식의 가로 레일을 사용한다.
- 창 크기나 방향이 바뀌면 전투 상태를 유지한 채 표시 노드만 다시 만든다.

## 오디오와 효과

- `tools/generate_game_sfx.gd`가 44.1kHz 16-bit mono WAV를 생성한다.
- 파일이 없으면 `AudioManager`가 같은 계열의 fallback 스트림을 만든다.
- 모든 효과음은 리미터가 있는 `SFX` 버스로 출력한다.
- 승리·피니시·강타·필살기는 UI 소리보다 우선하며 재생 중 click/hover를 낮춘다.
- 강한 화면 효과는 연계, 처치, 강타, 승리에 집중한다.

## 검증

기본 개발 루프는 하나만 실행한다.

```bash
/opt/homebrew/bin/godot --headless -s res://tests/godot/run_tests.gd
```

UI를 변경한 경우에만 다음을 추가한다.

```bash
/opt/homebrew/bin/godot --path . -s res://tests/godot/capture_ui_responsive.gd
/opt/homebrew/bin/godot --path . -s res://tests/godot/validate_ui_captures.gd
```

런 흐름을 변경한 경우에만 `playthrough_probe.gd`를 사용한다.

## 남은 구조 과제

- 손패 드래그와 드래그 중 타깃 프리뷰
- `battle_screen.gd`의 UI 생성·전투 진행·추천 판단 분리
- 카드, 유물, 보스, 골드 경제 반복 조정
- 실제 웹 빌드와 다양한 모바일 브라우저 검증
