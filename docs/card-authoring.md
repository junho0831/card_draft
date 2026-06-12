# Card Draft 카드 제작 가이드

## 목적

이 문서는 새 카드를 추가하거나 기존 카드를 수정할 때 따라야 할 기준이다.

현재 MVP의 카드는 JSON 데이터로 정의하지만, 카드 효과 처리는 아직 코드에 일부 하드코딩되어 있다. 따라서 카드 수치만 바꾸는 작업과 새 효과를 추가하는 작업을 구분해야 한다.

## 카드 데이터 위치

현재 카드는 로컬 Godot 런에서만 사용한다.

```text
data/cards.json
```

## 기본 JSON 구조

카드는 JSON 배열 안의 객체 하나로 작성한다.

```json
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
  "build_tags": ["fire", "buff"],
  "text": "균형 잡힌 인간 전투 유닛"
}
```

## 필드 규칙

- `id`: 내부 식별자. 영어 `snake_case`를 사용한다.
- `name`: 화면에 표시할 카드 이름.
- `type`: `unit`, `spell`, `equipment` 중 하나.
- `race`: `인간`, `엘프`, `언데드`, `중립` 중 하나.
- `attr`: `화염`, `물`, `바람`, `대지`, `암흑`, `빛` 중 하나.
- `cost`: 마나 비용.
- `art`: 카드 아트 시트 인덱스.
- `build_tags`: 빌드 방향. `fire`, `draw`, `death`, `buff`, `low_hp`, `summon` 중 선택한다.
- `text`: 카드 설명.
- `attack`: 유닛 카드에만 필요하다.
- `health`: 유닛 카드에만 필요하다.

## ID 네이밍

권장:

```text
flame_swordsman
forest_archer
dark_bargain
```

금지:

```text
FlameSwordsman
flame-swordsman
불꽃검사
card001
```

ID는 효과 처리, 런 덱 저장, 보유 카드 수량의 기준 키로 쓰인다. 한번 출시한 ID는 가급적 바꾸지 않는다.

## 카드 타입별 예시

유닛 카드:

```json
{
  "id": "stone_guardian",
  "name": "대지 수호자",
  "type": "unit",
  "race": "중립",
  "attr": "대지",
  "cost": 3,
  "attack": 2,
  "health": 4,
  "art": 1,
  "build_tags": ["buff"],
  "text": "단단한 방어 유닛"
}
```

주문 카드:

```json
{
  "id": "small_flame",
  "name": "작은 불꽃",
  "type": "spell",
  "race": "중립",
  "attr": "화염",
  "cost": 1,
  "art": 9,
  "build_tags": ["fire"],
  "text": "가장 앞의 적 유닛에게 피해 2"
}
```

장착 카드:

```json
{
  "id": "training_blade",
  "name": "훈련용 검",
  "type": "equipment",
  "race": "중립",
  "attr": "빛",
  "cost": 2,
  "art": 11,
  "build_tags": ["buff"],
  "text": "가장 앞의 아군 유닛 공격력 +1"
}
```

## 아트 인덱스

현재 아트는 한 장짜리 시트를 잘라 쓴다.

```text
assets/card_art/season1_sample_sheet.png
```

현재 설정:

- 4열
- 3행
- 총 12칸
- 인덱스는 왼쪽 위부터 0으로 시작한다.

예:

- `art: 0`: 첫 번째 줄 첫 번째 이미지.
- `art: 4`: 두 번째 줄 첫 번째 이미지.
- `art: 11`: 세 번째 줄 네 번째 이미지.

현재 샘플 카드셋은 12장을 초과하므로 기존 아트 12칸을 여러 카드가 재사용하고 있다.

장기적으로는 아래 중 하나로 정리하는 것이 좋다.

- 더 큰 아트 시트로 교체하고 `CARD_ART_COLS`, `CARD_ART_ROWS`를 수정한다.
- 카드별 개별 이미지 파일 로딩 구조로 바꾼다.

## 효과 추가 규칙

현재 카드 효과는 JSON만으로 자동 실행되지 않는다.

효과 처리 위치:

- 카드 사용 효과: `scripts/battle/battle_card_effects.gd`
- 전투 흐름과 피해 계산: `scripts/ui/screens/battle_screen.gd`
- 유물/빌드 활성 효과: `scripts/services/relic_service.gd`, `scripts/ui/screens/battle_screen.gd`

현재 하드코딩된 효과 예:

- `forest_archer`: 소환 시 카드 1장 드로우.
- `captain_order`: 아군 전체 공격력 +1.
- `elven_insight`: 카드 2장 드로우.
- `dark_bargain`: 내 영웅 체력 2 지불, 카드 2장 드로우.
- `fireball`: 가장 앞의 적 유닛 또는 영웅에게 피해 4.
- `healing_potion`: 내 영웅 체력 5 회복.
- `training_sword`: 가장 앞의 아군 유닛 공격력 +2.
- `grave_knight`: 사망 시 영웅 체력 2 회복.
- `call_of_dead`: 해골 병사 2장 소환.
- `corpse_explosion`: 아군 하나를 처치하고 모든 적에게 피해 2.

새 효과 카드를 만들 때는 카드 JSON을 추가한 뒤 `battle_card_effects.gd`에 카드 ID 분기를 추가한다.

## 밸런스 기준

간단 기준:

- 1코스트 유닛: 총합 2스탯 기준.
- 2코스트 유닛: 총합 4스탯 기준.
- 3코스트 유닛: 총합 6스탯 기준.
- 4코스트 유닛: 총합 8스탯 기준.
- 좋은 효과가 있으면 스탯 총합을 낮춘다.
- 2장 드로우는 기본 3코스트.
- 전체 공격력 버프는 최소 3코스트.
- 로그라이크 보상 카드는 완전한 대칭 밸런스보다 빌드 방향성이 먼저다.
- `build_tags`가 없는 카드는 보상 추천과 빌드 점수에 거의 기여하지 못하므로 새 카드에는 태그를 넣는다.

## 검증 명령

카드 JSON 유효성 확인:

```bash
cd /Users/parkjunho/card-draft
python3 -m json.tool data/cards.json >/dev/null
```

Godot 카드 로드 확인:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --quit-after 2
```

## 카드 추가 체크리스트

- `id`가 영어 `snake_case`인지 확인했다.
- `data/cards.json`에 카드를 추가했다.
- 유닛 카드라면 `attack`, `health`가 있다.
- 주문/장착 카드라면 불필요한 `attack`, `health`를 넣지 않았다.
- `build_tags`가 현재 빌드 축과 맞는다.
- `art` 인덱스가 현재 아트 시트 범위 안에 있다.
- 새 효과라면 `scripts/battle/battle_card_effects.gd`에 효과 로직을 추가했다.
- `text`가 실제 효과와 일치한다.
- JSON 유효성 검사를 통과했다.
