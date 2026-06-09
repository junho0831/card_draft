import re

with open("docs/architecture.md", "r") as f:
    content = f.read()

new_content = content.replace("- `scripts/main.gd`: 화면 흐름, 전투 흐름, 서버 동기화 진입점.",
"""- `scripts/main.gd`: 메인 라우터, 상태 초기화, 서버 동기화 진입점.
- `scripts/ui/screens/*`: 전투(BattleScreen), 상점, 이벤트, 보상, 맵 등 화면별 캡슐화 모듈.""")

with open("docs/architecture.md", "w") as f:
    f.write(new_content)


with open("docs/ui-responsive.md", "r") as f:
    content = f.read()

new_content = content.replace("현재 루트 UI는 `ScrollContainer` 안에 `VBoxContainer`를 넣는다.\n\n이유:\n\n- 모바일 세로 화면에서 콘텐츠가 세로로 길어질 수 있다.\n- 웹 브라우저 창 크기가 작아져도 버튼이 화면 밖으로 완전히 사라지면 안 된다.\n- 전투 화면이나 덱 구성처럼 정보가 많은 화면은 스크롤 접근을 허용해야 한다.\n\n구현 위치:\n\n```text\nscripts/main.gd\nscripts/ui_factory.gd\n```",
"""현재 루트 UI는 `ScrollContainer` 안에 `VBoxContainer`를 넣는다.

이유:

- 모바일 세로 화면에서 콘텐츠가 세로로 길어질 수 있다.
- 웹 브라우저 창 크기가 작아져도 버튼이 화면 밖으로 완전히 사라지면 안 된다.
- 전투 화면이나 덱 구성처럼 정보가 많은 화면은 스크롤 접근을 허용해야 한다.

구현 위치:

```text
scripts/core/main.gd
scripts/ui/ui_factory.gd
scripts/ui/screens/*.gd
```""")

new_content = new_content.replace("- `main.gd`의 `_build_base_ui`\n- `main.gd`의 `_apply_root_layout`\n- `_notification`\n- `ui_factory.gd`의 `apply_root_layout`",
"""- `main.gd`의 `_build_base_ui`
- `main.gd`의 `_apply_root_layout`
- 각 screen 클래스의 `build` 또는 `_prepare_battle`
- `ui_factory.gd`의 `apply_root_layout`""")

with open("docs/ui-responsive.md", "w") as f:
    f.write(new_content)

print("Docs patched")
