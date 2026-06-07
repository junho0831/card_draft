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

- `res://scripts/main.gd`
  - 메인 메뉴, 런 허브, 전투, 보상, 상점, 이벤트, 휴식 흐름
- `res://scripts/run_state.gd`
  - 로컬 런 저장/로드
- `res://scripts/run_generator.gd`
  - Act 로드와 시작 덱 생성
- `res://scripts/battle_card_effects.gd`
  - 카드별 전투 효과 처리
- `res://scripts/relic_service.gd`
  - 유물 로드와 전투 훅 처리
- `res://scripts/event_service.gd`
  - 이벤트 로드와 랜덤 선택
- `res://scripts/enemy_service.gd`
  - 일반 적/엘리트/보스 데이터 로드

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

- 전투 UI는 기존 `main.gd` 전투를 런 기준으로 재사용한다.
- 스타터 덱은 `민병대 x3 / 초보 검병 x3 / 작은 불꽃 x2 / 응급 치료 x2`다.
- 스타터 카드는 보상/상점 풀에서 제외한다.
- 유물은 전투 훅 기반으로 적용한다.
- 보스/엘리트는 카드 보상 외에 유물 보상이 붙을 수 있다.
- 상점은 런 내 카드/유물/제거/회복 전용이다.
- 메타 진행은 현재 `영혼석`, `시작 체력`, `시작 골드`, `두 번째 기회`까지만 로컬로 반영한다.
- 현재 서버 관련 코드와 `/server` 모듈은 남겨두되, 런 코어는 로컬 기준으로 동작한다.
