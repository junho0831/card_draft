#!/usr/bin/env python3
"""Validate provenance, decodability, duration and peak of the CC0 pack."""
from array import array
import hashlib
import json
import math
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1] / 'assets/audio/community_v1'
entries = json.loads((root / 'manifest.json').read_text())
assert len(entries) == 13 and len({e['key'] for e in entries}) == 13
for entry in entries:
    path = root / entry['file']
    assert entry['license'] == 'CC0-1.0'
    assert entry['source_page'].startswith(('https://kenney.nl/assets/', 'https://opengameart.org/content/'))
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['output_sha256'], path.name
    info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(path)]))['streams'][0]
    samples = array('f', subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-']))
    assert samples and all(math.isfinite(x) for x in samples), path.name
    peak = max(abs(x) for x in samples)
    duration = len(samples) / int(info['sample_rate']) / int(info['channels'])
    assert 0.001 < peak < 1, (path.name, peak)
    # FFmpeg may retain one Vorbis packet of decoder padding (~46 ms).
    assert abs(duration - entry['duration_seconds']) < 0.05, (path.name, duration)
    print(f'PASS {path.name}: {duration:.3f}s, peak {20*math.log10(peak):.2f} dBFS, SHA256 verified')
