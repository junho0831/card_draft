# Card Draft API 문서

## 기본 규칙

기본 주소:

```text
http://127.0.0.1:8080
```

게스트 로그인 이후 API는 아래 헤더를 사용한다.

```http
X-User-Id: {userId}
Content-Type: application/json
```

에러 응답은 기본적으로 아래 형태다.

```json
{
  "error": "에러 메시지"
}
```

## 게스트 로그인

```http
POST /api/guest-login
```

요청:

```json
{
  "playerName": "플레이어"
}
```

응답:

```json
{
  "userId": "00000000-0000-0000-0000-000000000000"
}
```

서버는 게스트 유저를 만들면서 초기 카드와 스타터 덱을 같이 지급한다.

## 카드 목록

```http
GET /api/cards
```

응답:

```json
[
  {
    "id": "flame_swordsman",
    "name": "불꽃 검사",
    "type": "unit",
    "race": "인간",
    "attr": "화염",
    "cost": 2,
    "attack": 2,
    "health": 2,
    "art": 0,
    "text": "균형 잡힌 인간 전투 유닛",
    "rarity": "일반",
    "enabled": true
  }
]
```

## 프로필

```http
GET /api/profile
X-User-Id: {userId}
```

응답:

```json
{
  "userId": "00000000-0000-0000-0000-000000000000",
  "playerName": "플레이어",
  "gold": 0,
  "rankPoints": 0,
  "rankName": "브론즈",
  "ownedCardCount": 30,
  "selectedDeckId": "11111111-1111-1111-1111-111111111111"
}
```

## 보유 카드

```http
GET /api/collection
X-User-Id: {userId}
```

응답:

```json
{
  "flame_swordsman": 3,
  "shield_guard": 3,
  "captain_order": 3
}
```

## 덱 목록

```http
GET /api/decks
X-User-Id: {userId}
```

응답:

```json
[
  {
    "id": "11111111-1111-1111-1111-111111111111",
    "name": "스타터 덱",
    "selected": true,
    "cardIds": [
      "flame_swordsman",
      "flame_swordsman"
    ]
  }
]
```

`cardIds`는 실제 덱 카드 배열이다. 같은 카드가 3장 들어가면 같은 ID가 3번 들어간다.

## 덱 생성

```http
POST /api/decks
X-User-Id: {userId}
```

요청:

```json
{
  "name": "내 덱",
  "cardIds": [
    "flame_swordsman",
    "flame_swordsman"
  ]
}
```

검증 규칙:

- 정확히 30장.
- 동일 카드 최대 3장.
- 보유 수량 초과 금지.
- 존재하지 않는 카드 금지.

생성된 덱은 MVP 기준으로 바로 선택 덱이 된다.

## 덱 수정

```http
PUT /api/decks/{deckId}
X-User-Id: {userId}
```

요청과 검증 규칙은 덱 생성과 같다. 수정된 덱은 MVP 기준으로 바로 선택 덱이 된다.

## 덱 선택

```http
POST /api/decks/{deckId}/select
X-User-Id: {userId}
```

응답 본문은 없다. 해당 덱만 선택 상태가 된다.

## AI 매치 생성

```http
POST /api/matches/ai
X-User-Id: {userId}
```

요청:

```json
{
  "mode": "casual",
  "deckId": "11111111-1111-1111-1111-111111111111"
}
```

`mode` 값:

- `casual`: 일반전.
- `ranked`: 랭크전.

응답:

```json
{
  "matchId": "22222222-2222-2222-2222-222222222222",
  "mode": "casual",
  "opponentType": "ai",
  "opponentName": "AI 상대"
}
```

## 전투 결과 제출

```http
POST /api/matches/{matchId}/result
X-User-Id: {userId}
```

요청:

```json
{
  "result": "win"
}
```

`result` 값:

- `win`: 승리.
- `loss`: 패배.

응답:

```json
{
  "summary": "일반전 승리\n골드 +30\n카드 획득: 불꽃 검사\n",
  "goldDelta": 30,
  "rankDelta": 0,
  "rewardCardId": "flame_swordsman",
  "rewardCardName": "불꽃 검사",
  "profile": {
    "userId": "00000000-0000-0000-0000-000000000000",
    "playerName": "플레이어",
    "gold": 30,
    "rankPoints": 0,
    "rankName": "브론즈",
    "ownedCardCount": 31,
    "selectedDeckId": "11111111-1111-1111-1111-111111111111"
  },
  "collection": {
    "flame_swordsman": 4
  }
}
```

같은 매치에 결과를 두 번 제출하면 실패한다.

## curl 테스트 예시

게스트 로그인:

```bash
USER_ID=$(curl -s -X POST http://127.0.0.1:8080/api/guest-login \
  -H 'Content-Type: application/json' \
  -d '{"playerName":"플레이어"}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["userId"])')
```

프로필 확인:

```bash
curl -s http://127.0.0.1:8080/api/profile \
  -H "X-User-Id: $USER_ID" | python3 -m json.tool
```

카드 목록 확인:

```bash
curl -s http://127.0.0.1:8080/api/cards | python3 -m json.tool
```
