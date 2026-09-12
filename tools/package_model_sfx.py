#!/usr/bin/env python3
"""Trim, fade and encode generated foley; never synthesize replacement sounds."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

LENGTHS = {'sword_hit': 1.2, 'card_play': 0.6, 'summon': 1.4, 'heal': 2.0,
           'spell_hit': 1.5, 'unit_death': 1.8, 'gold_gain': 1.3, 'ui_click': 0.25}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    import numpy as np
    import soundfile as sf
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for key, seconds in LENGTHS.items():
        source = args.source_dir / (key + '.wav')
        if not source.is_file():
            raise SystemExit('Missing generated effect: ' + str(source))
        record = json.loads(source.with_suffix('.json').read_text())
        samples, rate = sf.read(source, always_2d=True)
        peak = float(np.max(np.abs(samples)))
        if not np.isfinite(samples).all() or peak < 1e-5:
            raise SystemExit('Invalid generated effect: ' + key)
        # Select the strongest event, rather than an early low-level rustle
        # that can otherwise delay a sword hit by over half a second.
        window = max(1, round(rate * 0.01))
        blocks = samples[:len(samples) // window * window].reshape(-1, window, samples.shape[1])
        energy = np.mean(blocks * blocks, axis=(1, 2))
        strongest = int(np.argmax(energy)) * window
        lead = 1.5 if key == 'heal' else (0.04 if key == 'ui_click' else 0.12)
        start = max(0, strongest - round(rate * lead))
        start = min(start, max(0, len(samples) - round(rate * seconds)))
        clip = samples[start:start + round(rate * seconds)].copy()
        clip *= 10 ** (-4 / 20) / max(float(np.max(np.abs(clip))), 1e-5)
        fade_in = min(round(rate * 0.004), len(clip))
        fade_out = min(round(rate * 0.04), len(clip))
        clip[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
        clip[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
        target = args.output_dir / (key + '.ogg')
        with tempfile.TemporaryDirectory(prefix='foley-edit-') as temp:
            edited = Path(temp) / 'effect.wav'
            sf.write(edited, clip, rate, subtype='PCM_24')
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(edited),
                            '-codec:a', 'libvorbis', '-q:a', '5', str(target)], check=True)
        decoded, sr = sf.read(target)
        record.update({
            'file': target.name, 'output_seconds': len(decoded) / sr,
            'output_peak': float(np.max(np.abs(decoded))),
            'trim_start_seconds': start / rate,
            'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'model_revision': 'e35df4d82fbe87fcd5d14e5d100e349c0c3c076d',
        })
        target.with_suffix('.json').write_text(
            json.dumps(record, ensure_ascii=False, indent=2) + '\n')
        print(target)


if __name__ == '__main__':
    main()
