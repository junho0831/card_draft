#!/usr/bin/env python3
"""Build a local review sheet from the actual published expansion assets."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/frontier-100'
OUT.mkdir(parents=True, exist_ok=True)
cards = [c for c in json.loads((ROOT / 'data/cards.json').read_text()) if c.get('expansion') == 'frontier_100']
races = {'human': '인간', 'elf': '엘프', 'undead': '언데드', 'neutral': '중립', 'common': '중립'}
esc = html.escape
items = []
for card in cards:
    art = '../../assets/card_art/cards/' + card['id'] + '.png'
    race = races.get(card['race'], card['race'])
    stats = f"공격 {card['attack']} · 체력 {card['health']}" if card['type'] == 'unit' else ''
    items.append(f'''<article data-race="{esc(race)}"><a href="{art}"><img loading="lazy" src="{art}" alt="{esc(card['name'])}"></a><p class="eyebrow">{race} · 비용 {card['cost']} · {esc(card['impact_profile'])}</p><h2>{esc(card['name'])}</h2><p>{stats}</p><p>{esc(card['text'])}</p><small>{esc(card['id'])}</small></article>''')
audio = []
for key, label in [('arrow_hit', '화살'), ('ice_hit', '얼음'), ('shadow_hit', '암흑'), ('lightning_hit', '번개')]:
    if (ROOT / f'assets/audio/local_models_v1/{key}.ogg').is_file():
        audio.append(f'<label>{label}<audio controls preload="none" src="../../assets/audio/local_models_v1/{key}.ogg"></audio></label>')
page = '''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>변경 원정 · 제작 검토</title><style>
*{box-sizing:border-box}body{margin:0;background:#0d121a;color:#e8e2d5;font:16px/1.6 system-ui,sans-serif}header,main{max-width:1450px;margin:auto;padding:28px}h1{font-size:36px;margin:0}header p{color:#b1becd}nav{position:sticky;top:0;z-index:1;padding:12px;background:#131b27;display:flex;gap:8px;flex-wrap:wrap}button{min-height:44px;padding:8px 20px;border:1px solid #647286;border-radius:5px;background:#1c293c;color:inherit;cursor:pointer}button[aria-pressed=true]{border-color:#e0bf72;background:#544427}#cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:20px}article{background:#151e2a;border:1px solid #354458;border-radius:8px;overflow:hidden;padding-bottom:16px}article img{width:100%;aspect-ratio:2/3;object-fit:cover;display:block}article h2,article p,article small{margin:8px 16px;display:block}article h2{font-size:20px}.eyebrow,small{color:#b7a579;font-size:13px}article[hidden]{display:none}#audio{display:flex;gap:20px;flex-wrap:wrap;padding-bottom:24px}audio{display:block;width:280px}a{color:#dabf80}section{margin-bottom:28px}</style><header><p class="eyebrow">CARD DRAFT · 변경 원정</p><h1>새 카드 100장</h1><p>실제 게임 데이터와 개별 원본 이미지로 만든 검토 화면입니다. 이미지를 누르면 원본을 확인할 수 있습니다. 게임의 카드 프레임·2.5D 기울이기·타격 애니메이션은 Godot에서 별도로 표시됩니다.</p></header><main><section id="audio">AUDIO</section><nav><button aria-pressed="true">전체</button><button aria-pressed="false">인간</button><button aria-pressed="false">엘프</button><button aria-pressed="false">언데드</button><button aria-pressed="false">중립</button></nav><p id="count">100장</p><section id="cards">CARDS</section></main><script>document.querySelectorAll('nav button').forEach(button=>button.onclick=()=>{document.querySelectorAll('nav button').forEach(b=>b.setAttribute('aria-pressed',b===button));let count=0;document.querySelectorAll('article').forEach(c=>{c.hidden=button.textContent!=='전체'&&c.dataset.race!==button.textContent;if(!c.hidden)count++});document.getElementById('count').textContent=count+'장';});</script></html>'''
(OUT / 'index.html').write_text(page.replace('AUDIO', ''.join(audio)).replace('CARDS', ''.join(items)))
print(OUT / 'index.html')
