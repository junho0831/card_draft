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
  "art_id": "flame_swordsman",
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
- `art_id`: 카드별 이미지 파일 이름. `assets/card_art/cards/{art_id}.png`와 맞춰야 한다.
- `art`: 기존 카드 아트 시트 fallback 인덱스. 개별 이미지가 없을 때만 사용한다.
- `build_tags`: 빌드 방향. `fire`, `draw`, `death`, `buff`, `low_hp`, `summon` 중 선택한다.
- `text`: 카드 설명.
- `attack`: 유닛 카드에만 필요하다.
- `health`: 유닛 카드에만 필요하다.

`build_tags`는 단순 분류가 아니라 보상 추천, 빌드 점수, 전투 연계 카운터에 모두 사용된다. 같은 활성 태그 카드를 한 턴에 연속으로 쓰면 연계가 발동하므로, 새 카드는 “이 카드가 어떤 태그 연계를 이어주는가”까지 고려해서 작성한다.

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
  "art_id": "stone_guardian",
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
  "art_id": "small_flame",
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
  "art_id": "training_blade",
  "build_tags": ["buff"],
  "text": "가장 앞의 아군 유닛 공격력 +1"
}
```

## 카드 아트

카드 아트는 카드별 개별 이미지 파일을 우선 사용한다.

```text
assets/card_art/cards/{art_id}.png
```

예:

```json
{
  "id": "fireball",
  "art_id": "fireball",
  "art": 7
}
```

위 카드는 먼저 아래 파일을 찾는다.

```text
assets/card_art/cards/fireball.png
```

파일이 없으면 `art` 숫자를 사용해 기존 시트에서 이미지를 잘라 표시한다.

fallback 시트:

```text
assets/card_art/season1_sample_sheet.png
```

`art`는 기존 저장/화면 호환용 fallback이므로 새 카드는 `art_id`와 이미지 파일을 반드시 함께 추가한다.

## 효과 추가 규칙

현재 카드 효과는 JSON만으로 자동 실행되지 않는다.

효과 처리 위치:

- 카드 사용 효과: `src/battle/battle_card_effects.gd`
- 전투 흐름과 피해 계산: `src/ui/screens/battle_screen.gd`
- 유물/빌드 활성 효과: `src/services/relic_service.gd`, `src/ui/screens/battle_screen.gd`

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
- 빌드 앵커 카드는 한 장만 골라도 플레이 방식이 보이도록 만든다.
  - `fire`: 두 번째 화염 주문, 폭발 피해, 마무리 피해.
  - `draw`: 드로우 후 바로 쓸 수 있는 비용/마나 보상.
  - `death`: 아군 사망, 희생, 부활, 저주 압박.
  - `buff`: 선봉 성장, +1/+1, 광역 강화.
  - `low_hp`: 체력 손실을 보상으로 바꾸는 반격/회복.
  - `summon`: 작은 유닛 전개, 토큰, 즉시 공격.

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
- 현재 태그 연계에 들어갔을 때 플레이 감각이 명확하다.
- `art_id`가 있고 `assets/card_art/cards/{art_id}.png` 파일이 있다.
- fallback용 `art` 인덱스가 현재 아트 시트 범위 안에 있다.
- 새 효과라면 `src/battle/battle_card_effects.gd`에 효과 로직을 추가했다.
- `text`가 실제 효과와 일치한다.
- 보상 화면의 선택 이유가 어색하지 않도록 `main.gd`의 빌드 설명 helper와 태그를 확인했다.
- JSON 유효성 검사를 통과했다.
