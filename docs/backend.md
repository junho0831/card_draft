# Card Draft 백엔드 MVP

## 현재 역할

백엔드는 Godot 로컬 MVP의 진행 데이터를 서버로 옮기기 위한 저장소다.

현재 서버가 담당하는 것:

- 게스트 유저 생성.
- 카드 데이터 제공.
- 골드와 랭크 점수 저장.
- 보유 카드 수량 저장.
- 덱 저장과 선택 덱 관리.
- AI 매치 생성 기록.
- 전투 결과에 따른 보상과 랭크 점수 계산.

현재 서버가 아직 담당하지 않는 것:

- 실제 PvP 매칭.
- 실시간 전투 동기화.
- 서버 권위 전투 판정.
- JWT, OAuth 같은 정식 인증.
- 시즌 초기화, MMR, 승급전.

## 실행 방법

백엔드는 `/server` 폴더에 있다.

먼저 PostgreSQL과 Redis를 실행한다.

```bash
cd /Users/parkjunho/card-draft/server
docker compose up -d
```

그 다음 Spring Boot 서버를 실행한다.

```bash
./gradlew bootRun
```

서버 기본 주소:

```text
http://127.0.0.1:8080
```

Godot 클라이언트는 서버가 켜져 있으면 자동으로 서버를 사용한다. 서버가 꺼져 있으면 기존 `user://profile.json` 기반 로컬 MVP로 계속 실행된다.

## 주요 API

상세 요청/응답 예시는 `res://docs/api.md`에 정리되어 있다.

게스트 로그인:

```http
POST /api/guest-login
```

카드 목록:

```http
GET /api/cards
```

프로필:

```http
GET /api/profile
X-User-Id: {userId}
```

보유 카드:

```http
GET /api/collection
X-User-Id: {userId}
```

덱:

```http
GET /api/decks
POST /api/decks
PUT /api/decks/{deckId}
POST /api/decks/{deckId}/select
```

AI 매치:

```http
POST /api/matches/ai
POST /api/matches/{matchId}/result
```

## DB 구조

Flyway 마이그레이션 파일:

```text
server/src/main/resources/db/migration/V1__initial_schema.sql
```

테이블:

- `users`: 플레이어명, 골드, 랭크 점수.
- `cards`: 카드 마스터 데이터.
- `user_cards`: 유저별 보유 카드 수량.
- `decks`: 덱 메타 정보와 선택 여부.
- `deck_cards`: 덱에 들어간 카드 수량.
- `matches`: AI 매치 기록과 보상 결과.

## 카드 데이터 동기화

서버는 시작 시 아래 파일을 읽어 `cards` 테이블에 seed한다.

```text
server/src/main/resources/cards.json
```

현재 이 파일은 Godot의 `data/cards.json`을 복사한 것이다. 카드 수치나 텍스트를 바꾸면 두 파일을 같이 맞춰야 한다.

## 보상 규칙

- 일반전 승리: 골드 30, 랜덤 카드 1장.
- 일반전 패배: 골드 10.
- 랭크전 승리: 골드 20, 랭크 점수 +25, 랜덤 카드 1장.
- 랭크전 패배: 골드 10, 랭크 점수 -10.
- 랭크 점수는 0 아래로 내려가지 않는다.

## 테스트

서버 단위 테스트:

```bash
cd /Users/parkjunho/card-draft/server
./gradlew test
```

서버 패키징 확인:

```bash
./gradlew bootJar
```
