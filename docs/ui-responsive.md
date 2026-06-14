# Card Draft UI 반응형 가이드

## 목적

이 문서는 Godot UI가 데스크톱, 웹, 모바일 크기에서 잘리지 않게 만들기 위한 기준이다.

현재 프로젝트는 PC 실행뿐 아니라 웹 빌드나 모바일 비율에서도 화면이 깨지지 않는 것을 목표로 한다. 작은 화면에서는 모든 정보를 한 화면에 억지로 넣지 않고, 스크롤로 접근 가능하게 만든다.

## 기준 해상도

기본 디자인 기준:

```text
1280 x 720
```

검증에 사용할 대표 크기:

```text
390 x 844   모바일 세로
780 x 1280  태블릿/모바일 큰 화면
1280 x 720  데스크톱 기본
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

- 기준 해상도는 1280x720으로 둔다.
- 화면이 커지면 UI가 확장된다.
- 화면 비율이 달라도 캔버스가 잘리지 않게 한다.

## 루트 레이아웃 원칙

현재 루트 UI는 `ScrollContainer` 안에 `VBoxContainer`를 넣는다.

이유:

- 모바일 세로 화면에서 콘텐츠가 세로로 길어질 수 있다.
- 웹 브라우저 창 크기가 작아져도 버튼이 화면 밖으로 완전히 사라지면 안 된다.
- 전투 화면이나 덱 구성처럼 정보가 많은 화면은 스크롤 접근을 허용해야 한다.

구현 위치:

```text
scripts/core/main.gd
scripts/ui/ui_factory.gd
scripts/ui/screens/*.gd
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
  - 전투 목표는 `적 영웅 처치`로 고정한다.
  - 적 영웅 HP는 크게 표시한다.
  - 사용 가능한 카드는 밝게, 불가능한 카드는 어둡게 표시한다.
  - 공격 가능한 유닛, 선택된 유닛, 공격 대상은 서로 다른 문구와 색으로 구분한다.
  - 최상단은 `현재 목표`, 그 아래는 `다음 행동`으로 고정한다.
  - 전장 아래에는 플레이어 HP, 현재 빌드, 마나, 턴 종료, 영웅 공격을 한 덩어리로 둔다.
  - 빌드 점수는 전투 중에도 숨기지 않는다. 플레이어가 이번 런 방향을 계속 확인할 수 있어야 한다.
  - 영웅 공격은 승리로 가는 행동이므로 일반 턴 버튼과 다른 붉은 계열로 분리한다.
- 보상
  - 선택 가능한 카드 3장이 중심이다.
  - 현재 빌드와 맞는 추천 카드는 테두리와 문구로 강조한다.
  - 건너뛰기는 보조 버튼으로 어둡게 둔다.

## 8개 핵심 화면 UX 구조

Card Draft의 화면은 전체 런 흐름을 설명하는 설계도처럼 동작해야 한다. 모든 핵심 화면은 `지금 무엇을 해야 하는가`와 `이번 런은 어떤 빌드인가`를 우선 노출한다.

공통 제작 기준:

- Practical game UI.
- Realistic layout.
- Implementable in Godot.
- Focus on UX hierarchy.
- High readability.
- Dark fantasy, black stone, gold trim, dark blue panels.
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

- 현재 전투 화면은 정보량이 많아 모바일에서는 스크롤 접근을 허용한다.
- 다음 단계에서는 모바일 전투 전용 레이아웃을 별도로 두는 것이 좋다.
- 예: 상대 필드, 내 필드, 손패를 세로 섹션으로 분리.

## QA 체크리스트

기본 실행:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --quit-after 2
```

모바일 세로:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --resolution 390x844 --quit-after 2
```

태블릿/큰 모바일:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --resolution 780x1280 --quit-after 2
```

데스크톱:

```bash
/opt/homebrew/bin/godot --headless --path /Users/parkjunho/card-draft --resolution 1280x720 --quit-after 2
```

수동 확인:

- 메인 메뉴에서 버튼이 화면 밖으로 사라지지 않는다.
- 프로필 요약이 한 글자씩 세로로 떨어지지 않는다.
- 모드 선택 화면이 작은 폭에서도 보인다.
- 알림/보상 화면이 작은 폭에서도 보인다.
- 덱 구성과 전투 화면은 필요한 경우 스크롤로 접근 가능하다.
- 버튼 텍스트가 버튼 밖으로 넘치지 않는다.

## 다음 개선 후보

- 덱 구성 화면 모바일 탭 UI.
- 전투 화면 모바일 전용 레이아웃.
- 카드 hand 영역 가로 스크롤.
- 필드 슬롯 compact 크기.
- 웹 빌드 후 브라우저 실제 크기에서 스크린샷 검증.
