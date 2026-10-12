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
assets/         카드 아트, UI 테마, 음악·효과음
tests/godot/    기본 회귀와 선택형 화면 검증
```

## 핵심 파일

- `src/core/main.gd`: 앱 허브와 공통 화면 셸
- `src/core/run_flow_coordinator.gd`: 새 런, 이어하기, 화면 라우팅
- `src/services/run_state.gd`: 런 저장과 복원
- `src/services/run_generator.gd`: Act와 세력별 시작 덱
- `src/services/build_rules.gd`: 화면과 독립된 빌드 태그·점수·활성화·주력/보조 선택 규칙
- `src/battle/battle_action_preview.gd`: 공격·카드 효과 미리보기와 결과 문구, 실제 피해 계산을 전달받아 사용
- `src/battle/battle_card_effects.gd`: 카드 효과
- `src/battle/battle_combo_finisher.gd`: 빌드 3연계 피니시
- `src/battle/battle_objective_service.gd`: 전투당 도전
- `src/services/relic_service.gd`: 유물 데이터와 전투 훅
- `src/services/audio_manager.gd`: CC0 Ogg 로드, SFX/BGM 버스와 재생 우선순위
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
- 효과음: `assets/audio/combat_edited_v1/` 우선, `assets/audio/community_v1/` 대체
- BGM: `community_v1`의 `menu_theme`, `exploration`, `battle_base`
- 출처·해시: 각 팩의 `manifest.json`, [커뮤니티 오디오](community-audio.md)

카드·유물 JSON schema는 저장 호환성을 위해 임의로 변경하지 않는다. 내부 `중립` 값은 유지하고 UI에서만 `공용`으로 변환한다.

## 런타임 규칙

- 런은 세력 선택 후 5노드 Act를 진행한다.
- 구버전 저장에 `race_id`가 없으면 인간으로 복원한다.
- 전투는 `battle_snapshot`으로 손패, 필드, 덱, 버림 더미, 턴, 연계, 필살기 상태를 복원한다.
- 카드 제거·강화 같은 하위 화면은 `pending_subscreen`으로 복원한다.
- 일반 런의 시작 구성은 `data/starting_strategies.json`을 따른다. 학습·전략 생략 호출은 기존 구성 경로를 사용한다.
- `build_tags`는 `fire`, `draw`, `death`, `buff`, `low_hp`, `summon`만 사용한다.
- 빌드 점수 5부터 활성화하며 첫 3연계 피니시는 전투당 한 번이다.
- `BattleMomentumService`가 적 선봉 배치, 턴당 첫 처치 마나 환급, 초과 피해 돌파를 계산한다.
- 승리 조건은 적 영웅 체력 0 하나다.

## UI 규칙

- 카드 정보 순서는 `비용/이름 -> 아트 -> 타입/세력 -> 핵심 효과`다.
- `CardView`의 `hand`, `field`, `reward`, `shop`, `collection` 모드를 사용하고 화면별 카드 구조를 다시 만들지 않는다.
- 카드 상태 우선순위는 `타겟/선택 -> 추천 -> 사용 가능 -> 세력색`이다.
- 버튼 역할은 `primary`, `secondary`, `danger`, `power`로 제한한다.
- 손패 카드는 `_hand_slot`을 유지해 사용 후 남은 카드 위치가 갑자기 바뀌지 않게 한다.
- 현재 가로 캔버스의 터치 규칙은 [모바일 조작](mobile-controls.md)을 따른다.
- 창 크기나 방향이 바뀌면 전투 상태를 유지한 채 표시 노드만 다시 만든다.

## 오디오와 효과

- 정상 실행은 CC0 Ogg만 읽는다. 효과음 누락은 오류와 빈 스트림으로 처리하며 합성하지 않는다.
- `tools/package_combat_audio.py`는 CC0 원본의 편집·패키징·해시 검증을 담당한다. 이전 합성·모델 제작 도구는 현재 재생 경로와 별개다.
- `src/battle/card_impact_profiles.gd`가 카드 피해의 12개 소리·시각 계열을 정의한다.
- 효과음은 `SFX`, 음악은 `MusicMix`와 상위 `BGM` 버스를 사용한다. 사용자 음량과 일시적인 음악 감쇠를 분리한다.
- 전투 상태별 슬롯은 같은 전투곡을 사용하며 음량으로 상태를 표현한다. 과거 합성 음악 레이어 방식으로 설명하지 않는다.
- 상세 연결과 검증은 [사운드와 애니메이션](audio-and-animation.md)을 참고한다.

## 검증

기본 개발 루프는 하나만 실행한다.

```bash
godot --headless --path . -s res://tests/godot/run_tests.gd -- --test-data-dir=/tmp/card-draft-check
```

UI를 변경한 경우에만 다음을 추가한다.

```bash
godot --path . -s res://tests/godot/capture_ui_responsive.gd -- --test-data-dir=/tmp/card-draft-check
godot --path . -s res://tests/godot/validate_ui_captures.gd -- --test-data-dir=/tmp/card-draft-check
```

런 흐름을 변경한 경우에만 `playthrough_probe.gd`를 사용한다.

## 계산 로직 수정 위치

빌드 판정 변경은 `build_rules.gd`, 피해 미리보기 변경은 `battle_action_preview.gd`에서 시작한다. `main.gd`와 `battle_screen.gd`의 기존 진입점은 위임 메서드로 유지해 화면과 테스트 호출부의 호환성을 보존한다. 미리보기 모듈은 호출 시 전달받은 문맥을 보관하지 않으며, 실제 피해 실행과 같은 계산 함수를 사용한다.

## 남은 구조 과제

- `battle_screen.gd`의 UI 생성·전투 진행·추천 판단 분리
- 카드, 유물, 보스, 골드 경제 반복 조정
- 실제 웹 빌드와 다양한 모바일 브라우저 검증
