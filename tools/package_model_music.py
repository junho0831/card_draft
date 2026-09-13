#!/usr/bin/env python3
"""Loop and encode a generated score; no sound synthesis is performed here."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--generation-dir', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--name', choices=['menu_theme', 'battle_base', 'exploration', 'boss_theme'], required=True)
    args = parser.parse_args()
    record = json.loads((args.generation_dir / 'generation.json').read_text())
    if not record.get('success') or len(record.get('audios', [])) != 1:
        raise SystemExit('Expected one successful generation')
    source = Path(record['audios'][0]['path'])
    if not source.is_file():
        source = args.generation_dir / source.name
    if not source.is_file():
        raise SystemExit('Generated source audio is missing')
    duration = float(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1', str(source)], text=True))
    if duration < 10:
        raise SystemExit('Music is too short')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    target = args.output_dir / (args.name + '.ogg')
    import numpy as np
    import soundfile as sf
    # Crossfade existing audio samples; this creates no oscillators or notes.
    seam = 0.5
    samples, rate = sf.read(source, always_2d=True)
    if not np.isfinite(samples).all() or np.max(np.abs(samples)) < 1e-5:
        raise SystemExit('Invalid or silent source')
    n = round(rate * seam)
    fade = np.linspace(0, 1, n)[:, None]
    joined = samples[-n:] * (1 - fade) + samples[:n] * fade
    loop = np.concatenate([samples[n:-n], joined])
    with tempfile.TemporaryDirectory(prefix='.music-loop-', dir=args.output_dir) as temp:
        edited = Path(temp) / 'loop.wav'
        candidate = Path(temp) / target.name
        sf.write(edited, loop, rate, subtype='FLOAT')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(edited),
                        '-af', 'loudnorm=I=-18:TP=-2:LRA=11', '-ar', '48000',
                        '-codec:a', 'libvorbis', '-q:a', '5', str(candidate)], check=True)
        decoded, decoded_rate = sf.read(candidate, always_2d=True)
        if len(decoded) != len(loop) or decoded_rate != rate:
            raise SystemExit('Encoded loop length does not match edited source')
        if not np.isfinite(decoded).all() or not 0.03 < np.max(np.abs(decoded)) < 1.0:
            raise SystemExit('Invalid encoded music')
        candidate.replace(target)
    record['output_seconds'] = len(decoded) / decoded_rate
    record['output_peak'] = float(np.max(np.abs(decoded)))
    record['loop_boundary_jump'] = float(np.max(np.abs(decoded[0] - decoded[-1])))
    record['source_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
    record['output_sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()
    record['output_file'] = target.name
    record['loop_crossfade_seconds'] = seam
    record['model_revision'] = '19671f406d603126926c1b7e2adc169acbcade22'
    # Keep provenance portable; the tensor is not an audio source or metadata.
    for audio in record['audios']:
        audio.pop('tensor', None)
        audio['path'] = Path(audio['path']).name
    (args.output_dir / (args.name + '.json')).write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    print(target)


if __name__ == '__main__':
    main()
