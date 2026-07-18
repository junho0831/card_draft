# Card Draft UI 반응형 가이드

## 목적

이 문서는 Godot UI가 데스크톱, 웹, 모바일 크기에서 잘리지 않게 만들기 위한 기준이다.

현재 프로젝트는 PC, 태블릿, 390px급 모바일 웹을 함께 지원한다. 작은 화면에서는 데스크톱 UI를 축소하지 않고, 핵심 게임 영역은 크게 유지하며 보조 정보는 세로 스크롤과 가로 스와이프로 접근한다.

## 기준 해상도

기본 디자인 기준:

```text
1280 x 720
```

검증에 사용할 대표 크기:

```text
1920 x 1080  큰 데스크톱
1280 x 720   데스크톱 기본/웹 창
800 x 1280   태블릿 세로
390 x 844    모바일 웹 세로
```

## Godot stretch 설정

현재 `project.godot` 설정:

```text
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

의도:

- `Canvas Items + Expand`로 카드와 텍스트를 네이티브 해상도로 선명하게 렌더링하면서 화면비가 달라질 때 사용 가능한 영역을 확장한다.
- 기본 창 크기는 1280x720으로 두고, 이보다 작은 창은 런타임 보정으로 축소하지 않아 기존 모바일 가독 크기와 breakpoint를 유지한다.
- 자동 확대는 최대 1.3배로 제한한다. 1920x1080에서는 약 1477x831 논리 레이아웃을 사용해 글자와 카드를 충분히 키우면서도 추가 전장 공간을 확보한다.
- 설정의 `UI 크기`는 PC/웹에서 자동 배율에 `크게` 1.1배 또는 `작게` 0.9배 보정을 적용한다. 1280x720보다 작은 태블릿·모바일은 터치 가독 크기를 유지하기 위해 이 보정을 적용하지 않는다.
- 울트라와이드에서는 최대 배율을 유지하면서 추가 가로 공간을 레이아웃에 제공한다.
- 공통 콘텐츠는 중앙 정렬되며, 넓은 논리 화면에서는 폭의 약 94%를 사용한다.
- 화면이 커지면 UI가 확장된다.
- 화면 비율이 달라도 캔버스가 잘리지 않게 한다.

## 실행 중 자동 크기 조절

- 창 크기와 브라우저 표시 영역이 바뀔 때 루트 폭은 즉시 새 크기에 맞춘다.
- 가로/세로 방향 또는 `600`, `860`, `900`, `1080`, `1400` 폭 기준과 `760` 높이 기준을 넘으면 현재 화면을 새 레이아웃으로 다시 만든다.
- 연속 resize 이벤트는 `0.2초` 동안 모아 한 번만 처리해 브라우저 창을 드래그할 때 UI가 반복 생성되지 않게 한다.
- 전투 화면은 플레이어/적 상태, 손패, 필드, 선택 상태, 타이머, 로그를 유지한 채 표시 노드만 다시 만든다.
- 전투 애니메이션으로 입력이 잠긴 순간에는 해제가 끝날 때까지 재배치를 미룬다.
- 작은 화면에서 카드와 버튼을 계속 축소하지 않는다. 최소 가독 크기를 유지하고 필드·손패는 가로 스와이프, 전체 화면은 세로 스크롤로 접근한다.
- 전투 본문은 논리 폭 1320px로 중앙 제한한다. Full HD 자동 배율에서는 실제 약 1716px 폭이며, 과도한 좌우 여백 없이 내·적 전장에 집중하게 한다.
- 필드 슬롯 크기는 항상 고정하고 배치된 유닛 카드만 내부에서 1.06배 강조한다. 플레이어의 다음 빈 칸만 `다음 소환`으로 표시하고 나머지 빈 칸은 약한 자리 표시자로 유지한다.
- 가로 전투의 필살기·추천 행동·턴 종료 영역은 420px 도크 폭을 유지해 손패 수와 무관하게 버튼 위치가 움직이지 않게 한다.
- 세력 선택 버튼은 화면 구간에 따라 56~68px 높이를 유지하고, 모바일의 고정 시작 버튼은 64px 높이로 확보해 세 세력을 쉽게 선택하게 한다.
- 인간·엘프·언데드 세력 카드는 버튼뿐 아니라 색 테두리 안의 이미지·설명·유물 영역 전체를 클릭 대상으로 사용한다.

## 루트 레이아웃 원칙

현재 루트 UI는 `ScrollContainer` 안에 `VBoxContainer`를 넣는다.

이유:

- 모바일 세로 화면에서 콘텐츠가 세로로 길어질 수 있다.
- 웹 브라우저 창 크기가 작아져도 버튼이 화면 밖으로 완전히 사라지면 안 된다.
- 전투 화면이나 덱 구성처럼 정보가 많은 화면은 스크롤 접근을 허용해야 한다.

구현 위치:

```text
src/core/main.gd
src/ui/ui_factory.gd
src/ui/styles/ui_styles.gd
src/ui/styles/battle_styles.gd
src/ui/screens/*.gd
```

관련 함수:

- `main.gd`의 `_build_base_ui`
- `main.gd`의 `_apply_root_layout`
- 각 screen 클래스의 `build` 또는 `_prepare_battle`
- `ui_factory.gd`의 `apply_root_layout`
- `ui_factory.gd`의 `begin_screen`
- `ui_factory.gd`의 `make_screen_panel`
- `ui_factory.gd`의 `make_scroll_panel`
- `ui_factory.gd`의 `make_action_bar`

## 폭 계산 규칙

고정 폭을 그대로 쓰지 않는다.

권장:

```gdscript
var panel := ui.make_responsive_panel(color, get_viewport_rect().size.x, 520)
```

현재 helper:

```gdscript
func responsive_width(viewport_width: float, preferred_width: int) -> float:
	return min(float(preferred_width), max(MIN_RESPONSIVE_WIDTH, viewport_width - (SCREEN_MARGIN * 2.0 + 12.0)))
```

의미:

- 넓은 화면에서는 원하는 폭을 사용한다.
- 작은 화면에서는 화면 폭에서 여백을 뺀 폭으로 줄인다.
- 너무 작아지는 것은 280px에서 막는다.

## 가운데 패널 규칙

메뉴/설정/리스트/보상 계열 화면은 먼저 `ui_factory.gd`의 `begin_screen`으로 화면 셸을 시작하고, 본문은 `make_screen_panel` 또는 `make_scroll_panel`에 넣는다.

권장:

```gdscript
var body := ui.begin_screen(root_box, "카드 보관함", _make_profile_summary())
var panel_data := ui.make_scroll_panel(color, get_viewport_rect().size.x, 760, 8, 420)
body.add_child(panel_data["panel"])
```

모드 선택, 알림, 보상처럼 가운데 성격의 화면도 직접 패널을 조립하지 않고 공통 셸 안에서 같은 방식으로 구성한다.

권장:

```gdscript
var body := ui.begin_screen(root_box, "알림")
var panel := ui.make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), get_viewport_rect().size.x, 520)
body.add_child(panel)
```

비권장:

```gdscript
var panel := _make_panel_container(Color(0.12, 0.135, 0.16, 1.0))
panel.custom_minimum_size = Vector2(620, 0)
panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
```

고정 폭 `620` 같은 값은 모바일이나 작은 웹 창에서 화면 잘림을 만든다.

추가 원칙:

- 새 화면 추가 시 `main.gd`에서 직접 `PanelContainer`, `ScrollContainer`, `HBoxContainer`를 조립하지 않는다.
- 메뉴/설정/리스트/보상 계열 화면은 `ui_factory.gd` 공통 셸을 사용한다.
- 개별 화면에서 별도 반응형 폭 계산을 다시 만들지 않는다.

## 초보자 유도 UI

Card Draft는 복잡한 설명보다 화면의 우선순위로 플레이어를 안내한다. 새 화면을 추가할 때는 아래 기준을 먼저 적용한다.

- 핵심 화면에는 `ui.make_guidance_banner()`로 `다음 행동`을 표시한다.
- 지금 누를 수 있는 가장 중요한 버튼은 `ui.style_primary_button()`을 사용한다.
- 주요 진행 버튼 문구에는 `▶`를 붙여 행동 가능성을 보여준다.
- 클릭할 수 없는 항목은 숨기기보다 어둡게 처리해서 상태 차이를 알 수 있게 한다.
- 안내 문구는 규칙 설명이 아니라 행동 문장으로 쓴다.
  - 좋은 예: `카드 1장을 골라 현재 빌드를 강화`
  - 나쁜 예: `이 화면은 전투 보상 시스템입니다`

화면별 적용 기준:

- 메인 메뉴
  - `새 런 시작` 또는 `이어하기`가 가장 강하게 보여야 한다.
- 맵
  - 현재 진입 가능한 노드는 밝고 크게 보인다.
  - 완료/잠김 노드는 어둡게 보인다.
- 전투
	- 기본 승리 목표는 `적 영웅 처치`로 고정하고, 보조 도전은 한 줄로만 표시한다.
  - 적 영웅 HP는 크게 표시한다.
  - 사용 가능한 카드는 밝게, 불가능한 카드는 어둡게 표시한다.
  - 공격 가능한 유닛, 선택된 유닛, 공격 대상은 서로 다른 문구와 색으로 구분한다.
  - 최상단은 `현재 목표`, 그 아래는 `다음 행동`으로 고정한다.
  - 전장 아래에는 플레이어 HP, 현재 빌드, 마나, 턴 종료, 영웅 공격을 한 덩어리로 둔다.
  - 빌드 점수는 전투 중에도 숨기지 않는다. 플레이어가 이번 런 방향을 계속 확인할 수 있어야 한다.
  - 영웅 공격은 승리로 가는 행동이므로 일반 턴 버튼과 다른 붉은 계열로 분리한다.
  - 손패는 현재 `Control` 기반 수동 배치다.
	- 각 손패 카드는 `_hand_slot`으로 고정 슬롯을 유지해 카드 사용 후 남은 카드가 매번 한쪽으로 밀리지 않아야 한다.
	- 새로 뽑은 카드는 중앙 우선 슬롯 순서로 빈자리에 들어간다.
	- `900px` 이하 세로 화면은 첫 탭 선택·중앙 확대, 두 번째 탭 사용 방식의 가로 레일을 사용한다.
  - 작은 화면에서는 세로 스크롤을 허용하되 전장, 손패 핵심 카드, 턴 버튼이 서로 겹치지 않아야 한다.
- 보상
  - 선택 가능한 카드 3장이 중심이다.
  - 현재 빌드와 맞는 추천 카드는 테두리와 문구로 강조한다.
  - 건너뛰기는 보조 버튼으로 어둡게 둔다.

## 카드 UI 기준

현재 카드 UI는 `카드 한 장 안에서 역할이 다른 정보들을 분리`하는 방향으로 설계한다.

현재 구현 기준:

- 공통 스타일 모듈: `src/ui/styles/ui_styles.gd`
- 전투 스타일 모듈: `src/ui/styles/battle_styles.gd`
- 카드 이름 스타일: `ui_factory.gd`의 `style_card_title()`
- 카드 효과 스타일: `ui_factory.gd`의 `style_card_rules()`
- 전투 손패 렌더링: `battle_screen.gd`의 `_render_hand()`

현재 화면 원칙:

- 상단 헤더에는 비용, 추천 여부, 이름을 둔다.
- 이름 아래에는 종족/속성 같은 짧은 분류 줄을 둔다.
- 카드 핵심 효과는 한 줄 요약을 먼저 보여준다.
- 원문 설명은 더 작고 덜 밝게 보여준다.
- 사용 가능 여부는 카드 하단 상태 바로 즉시 알려준다.

즉, 카드에서 플레이어가 먼저 읽어야 하는 순서는 아래와 같다.

1. 이 카드가 뭔가
2. 지금 쓸 수 있는가
3. 쓰면 무슨 일이 생기는가

후속 개선 목표:

- 드래그 중 타깃 프리뷰

## 8개 핵심 화면 UX 구조

Card Draft의 화면은 전체 런 흐름을 설명하는 설계도처럼 동작해야 한다. 모든 핵심 화면은 `지금 무엇을 해야 하는가`와 `이번 런은 어떤 빌드인가`를 우선 노출한다.

공통 제작 기준:

- Practical game UI.
- Realistic layout.
- Implementable in Godot.
- Focus on UX hierarchy.
- High readability.
- Dark TCG, readable battlefield, restrained fantasy accent, strong card silhouettes.
- `epic`, `masterpiece`, `cinematic poster`, `concept art`처럼 포스터형 화면을 유도하는 방향은 피한다.

화면별 필수 정보:

- 메인 메뉴: 이어하기, 새 런 시작, 카드 컬렉션, 유물, 메타 진행, 현재 런 요약, 최근 기록, 빌드 통계.
- 맵: 현재 갈 수 있는 노드, 잠긴 노드, 노드 범례, 현재 목표, 예상 보상, 현재 빌드.
- 카드 보상: 카드 3장, 현재 빌드 점수, 추천 카드 강조, 건너뛰기.
- 상점: 구매 가능한 카드/유물/회복/제거, 현재 골드, 구매 가능 여부, 덱 확인.
- 전투: 현재 목표, 다음 행동, 적 영웅 HP, 적/내 필드 5칸, 플레이어 HP, 빌드 점수, 마나, 손패, 로그, 턴 종료, 영웅 공격.
- 이벤트: 상황 설명, 선택지 2-3개, 예상 보상 또는 비용, 결과 문구.
- 휴식: 회복, 강화/정비 선택지, 떠나기.
- 런 결과: 승패, 플레이 요약, 획득 보상, 최종 빌드, 메인 메뉴, 새 런 시작.

## 2열/1열 전환

메인 화면은 넓은 화면에서는 2열을 사용한다.

- 왼쪽: 카드 쇼케이스와 상태 정보.
- 오른쪽: 메뉴 버튼.

작은 화면에서는 1열로 전환한다.

현재 기준:

```gdscript
const COMPACT_BREAKPOINT := 860.0

func is_compact(viewport_width: float) -> bool:
	return viewport_width < COMPACT_BREAKPOINT
```

작은 화면에서 새 화면을 만들 때는 아래 원칙을 따른다.

- 2열 `HBoxContainer`를 고정하지 않는다.
- 폭이 좁으면 `VBoxContainer`로 전환한다.
- 카드나 타일 크기도 compact 값에 따라 줄인다.

## 버튼 규칙

공통 버튼은 `UiFactory.add_menu_button`을 사용한다.

현재 기준:

- 최소 폭: 220px
- 높이: 48px
- 가로 확장 허용

주의:

- 버튼 텍스트가 너무 길면 줄바꿈되거나 잘릴 수 있다.
- 모바일에서는 버튼 텍스트를 짧게 쓴다.
- 예: `보상 선택 - 카드 1장 추가` 정도는 가능하지만, 긴 설명문을 버튼 안에 넣지 않는다.

## 라벨 규칙

라벨은 기본적으로 자동 줄바꿈을 허용한다.

```gdscript
label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
```

단, 한 줄로 보여야 하는 짧은 상태 값은 줄바꿈을 끈다.

```gdscript
label.autowrap_mode = TextServer.AUTOWRAP_OFF
```

주의:

- 부모 폭이 너무 좁으면 한 글자씩 세로로 떨어질 수 있다.
- 프로필 요약, 상태 배지, 작은 타일 값은 최소 폭과 `AUTOWRAP_OFF`를 같이 고려한다.

## 패널 크기 규칙

권장:

- 화면 중심 패널: `ui.make_center_panel`
- 화면 폭에 맞는 패널: `ui.make_responsive_panel`
- 화면 셸 시작: `ui.begin_screen`
- 메뉴 본문 패널: `ui.make_screen_panel`
- 스크롤 본문 패널: `ui.make_scroll_panel`
- 하단 공통 버튼 바: `ui.make_action_bar`
- 2열/1열 전환: `ui.make_responsive_box`
- 필터 버튼 묶음: `ui.make_filter_bar`
- 정보가 많은 화면: `ScrollContainer`
- 전투/덱 구성처럼 넓은 화면: 스크롤 허용

비권장:

- `custom_minimum_size = Vector2(620, 0)` 같은 고정 폭.
- 모바일에서 2열 고정.
- 텍스트가 긴 버튼.
- 카드 목록을 스크롤 없이 한 화면에 전부 배치.

## 화면별 기준

메인 메뉴:

- 데스크톱: 쇼케이스와 메뉴 2열.
- 모바일/좁은 웹: 쇼케이스와 메뉴 1열.
- 상태 타일과 카드 미리보기는 compact 크기를 사용한다.

모드 선택:

- `begin_screen` + `make_screen_panel` 사용.
- 긴 안내문은 라벨 줄바꿈 허용.
- 버튼은 가로 확장.

덱 구성:

- 카드 목록은 스크롤 컨테이너 안에 둔다.
- 선택 덱 패널은 데스크톱에서 오른쪽에 둔다.
- 모바일에서 완전한 사용성을 높이려면 다음 단계에서 카드 목록과 선택 덱을 탭 구조로 분리하는 것이 좋다.

전투 화면:

- PC/태블릿은 전장과 손패를 같은 첫 화면에 유지한다.
- 1920x1080과 1280x720에서는 전장, 손패, 턴 버튼이 첫 화면에서 사용 가능해야 한다.
- 800x1280에서는 세로 스크롤을 허용하되 필드 카드 이름/아트/공체/선택 상태가 읽혀야 한다.
- 390x844에서는 필드 기본 3칸과 큰 손패 카드를 유지하고, 4칸 이상 필드와 손패는 가로 스와이프로 탐색한다.
- 모바일 터치 버튼은 최소 48px 높이를 사용한다.
- 손패 카드는 고정 슬롯 기반이므로 카드 사용 후 남은 카드가 위치를 급격히 바꾸면 실패로 본다.

## QA 체크리스트

기본 실행:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --quit-after 2
```

태블릿 세로:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --resolution 800x1280 --quit-after 2
```

모바일 웹 세로:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --resolution 390x844 --quit-after 2
```

작은 데스크톱:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --resolution 1280x720 --quit-after 2
```

데스크톱:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --resolution 1920x1080 --quit-after 2
```

기본 회귀:

```bash
/opt/homebrew/bin/godot --headless -s res://tests/godot/run_tests.gd
```

렌더링 캡처는 UI 변경 시에만 실행한다.

```bash
/opt/homebrew/bin/godot --path /Users/parkjunho/card-draft -s res://tests/godot/capture_ui_responsive.gd
/opt/homebrew/bin/godot --path /Users/parkjunho/card-draft -s res://tests/godot/validate_ui_captures.gd
```

세로 캡처는 처음부터 세로 레이아웃으로 생성하지 않고, 1280x720 화면을 만든 뒤 목표 크기로 변경한다. 따라서 실행 중 창 크기/방향 변경 시 자동 재배치 경로도 함께 검증한다.

전체 화면 흐름을 바꾼 경우에만 추가 캡처를 실행한다.

```bash
/opt/homebrew/bin/godot --path /Users/parkjunho/card-draft -s res://tests/godot/capture_ui_screens.gd
```

수동 확인:

- 메인 메뉴에서 버튼이 화면 밖으로 사라지지 않는다.
- 프로필 요약이 한 글자씩 세로로 떨어지지 않는다.
- 모드 선택 화면이 작은 폭에서도 보인다.
- 알림/보상 화면이 작은 폭에서도 보인다.
- 덱 구성과 전투 화면은 필요한 경우 스크롤로 접근 가능하다.
- 버튼 텍스트가 버튼 밖으로 넘치지 않는다.
- 손패 카드를 사용해도 남은 카드가 매번 한쪽으로 밀리지 않는다.
- 카드 hover 확대가 전장/버튼/다른 카드 텍스트를 과하게 가리지 않는다.

## 다음 개선 후보

- 덱 구성 화면 모바일 탭 UI.
- 손패 드래그 사용과 드래그 중 타깃 상세 프리뷰.
- 필드 슬롯과 손패 hover가 겹치는 구간의 추가 조정.
- 웹 빌드 후 브라우저 실제 크기에서 스크린샷 검증.
