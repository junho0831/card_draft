# Card Draft 반응형 UI

이 문서는 PC, 웹, 태블릿, 모바일에서 유지해야 할 UI 계약만 기록한다.

## 기준

기본 viewport는 `1280x720`이며 `Canvas Items + Expand`를 사용한다.

```text
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

검증 크기:

| 크기 | 용도 |
| --- | --- |
| 1920x1080 | 데스크톱 |
| 1280x720 | 기본 웹/가로 화면 |
| 1024x768 | 작은 가로 태블릿 |
| 800x1280 | 세로 태블릿 |
| 390x844 | 모바일 웹 |

자동 UI 확대는 최대 1.3배다. `UI 크기` 설정의 크게/작게 보정은 1280x720 이상 PC·웹에서만 적용한다.

## 재배치

- 창 크기와 방향 변경은 0.2초 디바운스 후 현재 화면을 다시 만든다.
- 주요 폭 기준은 `600`, `860`, `900`, `1080`, `1400`, 높이 기준은 `760`이다.
- 전투는 손패, 필드, 선택, 타이머, 로그를 유지하고 표시 노드만 재생성한다.
- 전투 입력이 잠긴 동안에는 재배치를 미룬다.
- 작은 화면에서는 계속 축소하지 않고 세로 스크롤과 가로 스와이프를 사용한다.

## 레이아웃

- 루트는 `ScrollContainer` 안의 `VBoxContainer`를 기본으로 한다.
- 공통 셸은 `UiFactory.begin_screen()`과 `make_screen_panel()` 또는 `make_scroll_panel()`을 사용한다.
- 화면별 고정 폭 계산을 추가하지 않는다.
- 넓은 화면의 2열은 860px 아래에서 1열로 바꾼다.
- 모바일 터치 버튼 높이는 최소 48px, 세력 시작 버튼은 64px를 유지한다.
- 전투 본문은 논리 폭 1320px로 제한하고 가로 행동 도크는 420px를 유지한다.
- 필드와 손패 카드는 고정 크기를 유지하고 넘치는 내용은 스와이프로 접근한다.

관련 구현:

```text
src/core/main.gd
src/ui/ui_factory.gd
src/ui/components/card_view.gd
src/ui/styles/ui_tokens.gd
src/ui/styles/ui_styles.gd
src/ui/styles/battle_styles.gd
src/ui/screens/*.gd
```

## 카드와 버튼

카드 정보 순서:

```text
비용/이름 -> 아트 -> 타입/세력 -> 핵심 효과
```

- `CardView` 모드는 `hand`, `field`, `reward`, `shop`, `collection`만 사용한다.
- 세력·공용 스킨은 구조가 아니라 프레임과 이름 띠에 적용한다.
- 상태색 우선순위는 `타겟/선택 -> 추천 -> 사용 가능 -> 세력색`이다.
- 버튼 역할은 `primary`, `secondary`, `danger`, `power`로 통일한다.
- 버튼 안에 긴 설명을 넣지 않는다.
- 손패는 `_hand_slot`을 유지하며 카드를 사용해도 남은 카드가 갑자기 이동하지 않아야 한다.
- 900px 이하 세로 화면은 첫 탭 선택·확대, 두 번째 탭 사용 방식의 손패 레일을 사용한다.

## 화면별 필수 조건

- 메인 메뉴: 주 행동이 첫 화면에 보이고 860px 아래에서는 1열이다.
- 세력 선택: 카드 전체가 클릭 대상이며 모바일 시작 버튼은 쉽게 닿아야 한다.
- 맵: 현재 진입 가능한 노드와 현재 빌드가 먼저 보인다.
- 전투: 목표, 적/내 필드, 손패, 필살기, 턴 종료에 접근할 수 있어야 한다.
- 보상: 카드 3장, 추천 이유, 선택 버튼이 같은 카드 안에서 읽혀야 한다.
- 상점: 가격과 구매 가능 상태가 카드 설명보다 먼저 구분돼야 한다.
- 이벤트·휴식: 선택의 비용과 결과가 버튼 밖 설명으로 보인다.
- 결과: 승패, 최종 빌드, 획득 보상, 새 런 행동을 제공한다.

1280x720에서는 전장과 핵심 행동 버튼이 첫 화면에 남아야 한다. 800x1280과 390x844에서는 세로 스크롤을 허용하되 필드 카드와 손패 카드가 겹치면 안 된다.

## 검증

기본 회귀:

```bash
/opt/homebrew/bin/godot --headless -s res://tests/godot/run_tests.gd
```

UI 변경 시:

```bash
/opt/homebrew/bin/godot --path . -s res://tests/godot/capture_ui_responsive.gd
/opt/homebrew/bin/godot --path . -s res://tests/godot/validate_ui_captures.gd
```

캡처 스크립트는 화면 이름과 `active_screen` 일치를 확인하고 draw 완료 후 PNG를 저장한다. 검은 이미지, 10KB 이하 파일, 이전 화면 잔상은 실패다.

수동 체크:

- 버튼과 라벨이 잘리거나 한 글자씩 줄바꿈되지 않는다.
- 손패 사용 전후 남은 카드 슬롯이 유지된다.
- hover 확대가 다른 카드나 행동 버튼을 가리지 않는다.
- 공용 카드의 `공용 · 모든 세력` 문구가 잘리지 않는다.
- 세로 화면에서 전장, 행동 버튼, 손패를 스크롤로 모두 사용할 수 있다.
