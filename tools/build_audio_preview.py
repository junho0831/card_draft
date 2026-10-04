#!/usr/bin/env python3
"""Build a listening page from the CC0 manifests used in game."""
import html
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / "build/cc0-audio-preview/index.html"
out.parent.mkdir(parents=True, exist_ok=True)
labels = {
    "ui_click": "클릭", "card_play": "카드 넘김", "gold_gain": "골드",
    "sword_hit": "검", "heavy_hit": "강타·돌", "arrow_hit": "화살",
    "wind_hit": "바람", "bone_hit": "뼈", "blood_hit": "혈기", "poison_hit": "독",
    "spell_hit": "불", "ice_hit": "얼음", "lightning_hit": "번개", "shadow_hit": "암흑",
    "heal": "빛·회복", "summon": "소환", "ultimate": "결정타", "unit_death": "퇴장",
    "menu_theme": "메뉴", "battle_base": "전투", "exploration": "탐험",
}
entries = {}
for directory in ["community_v1", "combat_edited_v1"]:
    for entry in json.loads((root / "assets/audio" / directory / "manifest.json").read_text()):
        entries[entry["key"]] = (directory, entry)
rows = []
for key, (directory, entry) in entries.items():
    rows.append(
        f'<article><h2>{labels[key]}</h2><p>{html.escape(entry["author"])} · CC0 · '
        f'{entry["duration_seconds"]:.2f}초</p><audio controls preload="none" '
        f'src="../../assets/audio/{directory}/{entry["file"]}"></audio>'
        f'<a href="{html.escape(entry["source_page"])}">출처·라이선스</a></article>'
    )
out.write_text('''<!doctype html><html lang="ko"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Card Draft CC0 음원</title><style>
body{background:#17191b;color:#f0f0f0;font:16px system-ui;max-width:1100px;margin:auto;padding:24px}
h1{font-size:28px}h2{font-size:18px}p{color:#c4c7c9}a{color:#8cd9bc}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(260px,100%),1fr));gap:16px}
article{border:1px solid #4b5054;border-radius:6px;padding:16px;min-width:0}
audio{width:100%;margin-bottom:12px}</style><h1>Card Draft · CC0 음원</h1><main>'''
    + "".join(rows)
    + '''</main><script>document.querySelectorAll('audio').forEach(a=>a.addEventListener('play',()=>
document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()})))</script></html>''')
print(out)
