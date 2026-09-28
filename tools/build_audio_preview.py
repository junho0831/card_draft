#!/usr/bin/env python3
"""Build a local listening page from the shipped manifest and impact mappings."""
import html
import json
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
out = root / 'build/community-audio-preview-2026-09-28/index.html'
out.parent.mkdir(parents=True, exist_ok=True)
entries = json.loads((root / 'assets/audio/community_v1/manifest.json').read_text())
labels = {'ui_click':'클릭','card_play':'카드 넘김','gold_gain':'골드','sword_hit':'검','heavy_hit':'강타·돌','arrow_hit':'화살','wind_hit':'바람','bone_hit':'뼈','blood_hit':'혈기','poison_hit':'독','menu_theme':'메뉴','battle_base':'전투','exploration':'탐험'}
rows=[]
for e in entries:
    rows.append(f'<article><h2>{labels[e["key"]]}</h2><p>{e["author"]} · CC0 · {e["duration_seconds"]:.2f}초</p><audio controls preload="none" src="../../assets/audio/community_v1/{e["file"]}"></audio><p><a href="{html.escape(e["source_page"])}">출처·라이선스</a></p></article>')
profiles = re.findall(r'"(\w+)": \{"color":"[a-f0-9]+", "motif":"(\w+)", "sound":"(\w+)"\}',(root / 'src/battle/card_impact_profiles.gd').read_text())
cards=json.loads((root/'data/cards.json').read_text())
comparison=[]
for key,motif,sound in profiles:
    directory='community_v1' if (root/f'assets/audio/community_v1/{sound}.ogg').exists() else 'local_models_v1'
    examples=' · '.join(c['name'] for c in cards if c.get('impact_profile') == key)[:100]
    comparison.append(f'<article><h2>{key} · {motif}</h2><p>{html.escape(examples)}</p><audio controls preload="none" src="../../assets/audio/{directory}/{sound}.ogg"></audio><p>{"새 CC0 효과음" if directory == "community_v1" else "기존 효과음 유지"}</p></article>')
out.write_text('''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Card Draft 음원·카드 효과 비교</title><style>body{background:#101721;color:#e7eaf0;font:16px system-ui;max-width:1150px;margin:auto;padding:28px}h1,h2{color:#efd59b}p{color:#acbace;line-height:1.7}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px}article{background:#182332;border:1px solid #344355;border-radius:14px;padding:20px}article h2{font-size:19px}audio{width:100%}a{color:#92caff}</style><h1>147종 카드 · 12개 효과 계열</h1><p>같은 공격 방식은 같은 소리와 형태로 연결합니다. 한 번에 한 음원만 재생합니다.<br>검·화살·바람, 뼈·혈기·독 소리를 비교해 보세요. 기존 마법 효과음은 유지했습니다.</p><main>'''+''.join(comparison)+'''</main><h1>무료 음원 라이브러리 · 13개</h1><p>BGM 3곡 + 효과음 10개. 새 합성 없이 배포 음원을 편집했습니다. 메뉴는 제공된 루프, 전투·탐험은 전체 곡 반복입니다.</p><main>'''+''.join(rows)+'''</main><h2>미적용 후보</h2><p><a href="https://sonniss.com/gameaudiogdc/">Sonniss</a>와 <a href="https://pixabay.com/music/main-title-medieval-castle-loop-366828/">Pixabay</a>는 후보만 검토했습니다. 이 페이지의 기존 마법 효과음은 CC0 라이브러리 13개에 포함되지 않습니다.</p><script>document.querySelectorAll('audio').forEach(a=>a.addEventListener('play',()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()})))</script></html>''')
print(out)
