#!/usr/bin/env python3
"""Decode generated assets, verify provenance hashes, and write a listening page.

Requires NumPy and SoundFile (available in the local music model environment).
This checks signal integrity, not artistic quality or copyright exclusivity.
"""
import argparse
import base64
import hashlib
import html
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audio-dir', type=Path, default=Path('assets/audio/local_models_v1'))
    parser.add_argument('--preview-dir', type=Path, required=True)
    args = parser.parse_args()
    import numpy as np
    import soundfile as sf

    rows, cards = [], []
    names = {'menu_theme': '메뉴 · 잿불 속의 왕국', 'battle_base': '일반 전투',
             'exploration': '탐험 · 등불 아래의 여정', 'boss_theme': '보스 · 검은 왕의 공성전',
             'arrow_hit': '활 타격', 'heavy_hit': '중량 타격', 'ultimate': '필살기',
             'sword_hit': '검과 방패', 'card_play': '카드', 'summon': '소환 · 갑옷',
             'heal': '회복', 'spell_hit': '마법 타격', 'unit_death': '사망',
             'gold_gain': '골드 획득', 'ui_click': '버튼'}
    files = sorted(args.audio_dir.glob('*.ogg'))
    if not files:
        raise SystemExit('No audio assets found')
    for file in files:
        data = file.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        record = json.loads(file.with_suffix('.json').read_text())
        if digest != record.get('output_sha256'):
            raise SystemExit('Provenance hash mismatch: ' + file.name)
        samples, rate = sf.read(file, always_2d=True)
        peak = float(np.max(np.abs(samples)))
        rms = float(np.sqrt(np.mean(samples ** 2)))
        if not np.isfinite(samples).all() or not 1e-5 < peak < 1.0 or rms < 1e-5:
            raise SystemExit('Silent, clipped, or non-finite audio: ' + file.name)
        seconds = len(samples) / rate
        if abs(seconds - record['output_seconds']) > 0.01:
            raise SystemExit('Duration mismatch: ' + file.name)
        row = dict(file=file.name, seconds=seconds, peak=round(peak, 4),
                   rms=round(rms, 4), bytes=len(data), sha256=digest)
        rows.append(row)
        title = html.escape(names.get(file.stem, file.stem))
        audio = base64.b64encode(data).decode('ascii')
        cards.append(f'<article><h2>{title}</h2><p>{seconds:.1f}초 · {len(data)/1024:.0f} KB</p>'
                     f'<audio controls preload="none" src="data:audio/ogg;base64,{audio}"></audio></article>')
    report = {'audio_files': rows, 'total_bytes': sum(row['bytes'] for row in rows),
              'validation': 'decoded finite, non-silent, peak below 1.0, duration and provenance SHA-256 matched',
              'listening_review': 'Human listening and actual mobile device review remain separate.'}
    (args.audio_dir / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    args.preview_dir.mkdir(parents=True, exist_ok=True)
    page = '''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Card Draft · 사운드 미리듣기</title><style>
body{margin:0;padding:32px;background:#0b1019;color:#e6e4dc;font:16px system-ui;max-width:1120px;margin:auto}
h1{color:#e6c378}header p{color:#aeb9c9;line-height:1.7}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px}
article{background:#151f2c;border:1px solid #38465a;border-radius:12px;padding:20px}h2{font-size:18px;margin:0}article p{color:#9facbe;font-size:13px}audio{width:100%}
</style><header><h1>Card Draft · 사운드 미리듣기</h1><p>무료 로컬 생성 모델의 음원. 탐험 BGM과 중량 타격·필살기를 새로 제작했습니다.<br>한 번에 한 음원씩 재생합니다. 신호 검증과 실제 기기에서의 청감 평가는 별개입니다.</p></header><main>'''
    page += ''.join(cards) + '''</main><script>document.addEventListener('play',e=>{for(const a of document.querySelectorAll('audio'))if(a!==e.target)a.pause()},true)</script></html>'''
    (args.preview_dir / 'index.html').write_text(page)
    print(f'PASS {len(rows)} audio assets; {report["total_bytes"]} bytes; {args.preview_dir / "index.html"}')


if __name__ == '__main__':
    main()
