# Card Draft 실행 Runbook

## Godot만 실행

서버 없이 게임 흐름만 확인할 때 사용한다.

```bash
/opt/homebrew/bin/godot --path /Users/parkjunho/card-draft
```

headless 검증:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --quit-after 2
```

서버가 꺼져 있으면 Godot는 자동으로 로컬 `user://profile.json` 저장 방식을 사용한다.

## 백엔드 포함 실행

Docker Desktop을 먼저 켠다.

PostgreSQL과 Redis 실행:

```bash
cd /Users/parkjunho/card-draft/server
docker compose up -d
```

서버 실행:

```bash
./gradlew bootRun
```

Godot 실행:

```bash
/opt/homebrew/bin/godot --path /Users/parkjunho/card-draft
```

메인 메뉴 하단에 `서버 연결: Spring Boot 백엔드`가 보이면 서버 저장 모드다.

## 서버 상태 확인

컨테이너:

```bash
cd /Users/parkjunho/card-draft/server
docker compose ps
```

서버 카드 API:

```bash
curl -s http://127.0.0.1:8080/api/cards | python3 -m json.tool
```

## 테스트

카드 JSON 유효성:

```bash
cd /Users/parkjunho/card-draft
python3 -m json.tool data/cards.json >/dev/null
python3 -m json.tool server/src/main/resources/cards.json >/dev/null
```

백엔드 단위 테스트:

```bash
cd /Users/parkjunho/card-draft/server
./gradlew test
```

백엔드 패키징:

```bash
./gradlew bootJar
```

Godot headless:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --quit-after 2
```

상점 수동 테스트:

- 메인 메뉴에서 `상점` 버튼이 보이는지 확인한다.
- 골드가 부족한 상태에서 구매 버튼이 비활성화되는지 확인한다.
- 전투 보상으로 골드를 얻은 뒤 `랜덤 카드 1장`을 구매한다.
- 구매 후 골드가 줄고 카드 보유 수량이 증가하는지 확인한다.
- `종족 카드 1장`에서 인간/엘프/언데드 필터가 바뀌는지 확인한다.
- 카드가 4장 이상 보유되어도 덱 구성에서는 동일 카드 3장 제한이 유지되는지 확인한다.

## 자주 나는 문제

### Docker 데몬이 꺼져 있음

증상:

```text
Cannot connect to the Docker daemon
```

해결:

- Docker Desktop을 실행한다.
- Docker가 완전히 켜진 뒤 `docker compose up -d`를 다시 실행한다.

### 8080 포트 충돌

증상:

```text
Port 8080 was already in use
```

해결:

```bash
cd /Users/parkjunho/card-draft/server
SERVER_PORT=8081 ./gradlew bootRun
```

단, 현재 Godot 클라이언트는 `http://127.0.0.1:8080`을 기본값으로 사용한다. 포트를 바꾸면 `scripts/main.gd`의 API base URL도 같이 바꿔야 한다.

### DB 초기화가 필요함

로컬 데이터를 완전히 지우고 다시 시작하려면:

```bash
cd /Users/parkjunho/card-draft/server
docker compose down -v
docker compose up -d
./gradlew bootRun
```

### 서버 카드 데이터와 Godot 카드 데이터가 다름

현재 카드 데이터는 두 곳에 있다.

```text
data/cards.json
server/src/main/resources/cards.json
```

카드를 수정하면 두 파일을 같이 맞춘다. 이후 단계에서는 서버 카드 API를 Godot 카드 로더의 우선 소스로 바꾸는 것이 좋다.
