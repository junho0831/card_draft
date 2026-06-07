# Card Draft

`Card Draft`는 5칸 필드 전투를 사용하는 싱글플레이 로그라이크 덱빌딩 RPG 프로토타입이다.

## 현재 빌드

- 메인 흐름: `새 런 시작 -> 맵 -> 전투 -> 카드 보상 -> 이벤트/상점/휴식 -> 보스 -> 다음 Act`
- Act 2개: 국경지대, 죽음의 성
- 스타터 4종 + 런 카드 풀 20장
- 유물 15개, 이벤트 5개
- 전투 규칙: 영웅 체력 0 승패, 마나 1부터 시작, 턴마다 +1, 필드 5칸
- 런 저장: `user://run_state.json`
- 메타/설정용 로컬 프로필: `user://meta_profile.json`

## 실행

Godot 4.6 이상에서 이 폴더를 열고 실행한다.

시작 씬:

```text
res://scenes/Main.tscn
```

## 조작

- 메인 메뉴에서 `새 런 시작` 또는 `이어하기`
- 맵에서 현재 노드 `진입`
- 전투 승리 후 카드 3장 중 1장 선택
- 상점에서 카드/유물 구매 또는 카드 제거
- 휴식에서 회복 또는 카드 강화
- 런 종료 후 결과 화면에서 메인 메뉴 복귀

## 주요 파일

- 메인 허브/전투/UI 흐름: `res://scripts/main.gd`
- 카드 데이터: `res://data/cards.json`
- 유물 데이터: `res://data/relics.json`
- 이벤트 데이터: `res://data/events.json`
- 적 데이터: `res://data/enemies.json`
- Act 데이터: `res://data/acts.json`

## 문서

- MVP 개요: `res://docs/mvp.md`
- 개발 메모: `res://docs/knowledge.md`
