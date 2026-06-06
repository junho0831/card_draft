# Card Draft

`Card Draft`는 필드 전투 중심 온라인 TCG를 검증하기 위한 Godot MVP 프로토타입이다.

## 현재 빌드

- 메인 메뉴, 모드 선택, 덱 구성, 카드 보관함, 설정, 보상 화면을 포함한 로컬 MVP.
- 일반전/랭크전 모두 현재는 AI 매칭 연출 후 간단 AI와 전투한다.
- 영웅 체력은 20으로 시작.
- 마나는 1부터 시작하고, 플레이어 턴마다 1씩 증가하며, 최대 10.
- 플레이어당 유닛 필드는 5칸.
- 유닛 전투는 양쪽이 동시에 피해를 준다.
- 인간, 엘프, 언데드, 중립 샘플 카드는 `res://data/cards.json`에서 로드한다.
- 샘플 카드 이미지는 `res://assets/card_art/season1_sample_sheet.png`에서 로드한다.
- 오른쪽 패널에서 남은 내 덱 구성과 게임 로그를 확인할 수 있다.
- 로컬 진행 데이터는 가능하면 `user://profile.json`에 저장한다.
- Spring Boot 백엔드가 켜져 있으면 프로필, 보유 카드, 덱, 보상, 랭크를 서버에 저장한다.
- 백엔드가 꺼져 있으면 기존 로컬 MVP 저장 방식으로 자동 fallback한다.

## 실행 방법

Godot 4.6 이상에서 이 폴더를 열고 프로젝트를 실행한다. 현재 시작 씬은 아래와 같다.

```text
res://scenes/Main.tscn
```

백엔드까지 같이 확인하려면 먼저 서버를 실행한다.

```bash
cd /Users/parkjunho/card-draft/server
docker compose up -d
./gradlew bootRun
```

서버 기본 주소는 `http://127.0.0.1:8080`이다.

## 조작 방법

- 메인 메뉴의 `게임 시작`에서 일반전 또는 랭크전을 선택한다.
- `덱 구성`에서 보유 카드 안에서 30장 덱을 저장한다.
- `카드 보관함`에서 보유 카드 수량을 확인한다.
- `설정`에서 전투 연출과 AI 턴 속도를 조정한다.
- 손패 카드를 클릭하면 카드를 사용한다.
- 공격 가능한 내 유닛을 클릭하면 공격 유닛으로 선택한다.
- 상대 유닛을 클릭하면 해당 유닛을 공격한다.
- `상대 영웅 공격`을 클릭하면 상대 영웅을 공격한다.
- `턴 종료`를 클릭하면 AI 턴으로 넘어간다.
- 유닛 전투 또는 영웅 공격이 발생하면 중앙에 짧은 전투 연출이 표시된다.

## 설계 메모

MVP에서는 카드 효과를 의도적으로 작게 유지한다. 온라인 PvP, 덱 편집, 카드 인벤토리, 퀘스트, 랭크 시즌, 서버 저장을 추가하기 전에 기본 필드 전투 루프가 재미있는지 먼저 검증한다.

## 문서

- 전체 개발 메모: `res://docs/knowledge.md`
- 백엔드 개요: `res://docs/backend.md`
- API 상세: `res://docs/api.md`
- 실행 Runbook: `res://docs/runbook.md`
- 구조 문서: `res://docs/architecture.md`
- 카드 제작 가이드: `res://docs/card-authoring.md`
- UI 반응형 가이드: `res://docs/ui-responsive.md`
- 밸런스 기준: `res://docs/balance.md`
- MVP 기획: `res://docs/mvp.md`
# card_draft
