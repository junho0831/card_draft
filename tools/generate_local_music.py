#!/usr/bin/env python3
"""Generate actual audio with an external ACE-Step checkout, without paid APIs.

Run with that checkout's Python environment. Model weights stay outside the game.
This script does not synthesize oscillators or automatically replace game assets.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model-root', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--duration', type=float, default=20)
    parser.add_argument('--seed', type=int, default=20260910)
    parser.add_argument('--caption', default=(
        'Instrumental dark fantasy tactical battle music. Expressive orchestral '
        'cellos and violas play a steady ostinato, warm French horns carry an original '
        'heroic melody, deep acoustic frame drums and delicate hammered dulcimer. '
        'Ruined castle at dusk, restrained tension, clear harmonic development, '
        'natural orchestral timbres, spacious cinematic mix, no vocals.'))
    args = parser.parse_args()
    root = args.model_root.resolve()
    output = args.output_dir.resolve()
    if not (root / 'acestep/handler.py').is_file():
        parser.error('model-root must be an ACE-Step 1.5 checkout')
    if not 10 <= args.duration <= 120:
        parser.error('duration must be between 10 and 120 seconds')
    output.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(root))
    os.environ['ACESTEP_INIT_LLM'] = 'false'
    os.environ['HF_HUB_DISABLE_XET'] = '1'
    os.environ['ACESTEP_PROJECT_ROOT'] = str(root)
    import torch
    from acestep.handler import AceStepHandler
    from acestep.inference import GenerationParams, GenerationConfig, generate_music

    torch.set_num_threads(min(4, os.cpu_count() or 1))
    handler = AceStepHandler()
    status, success = handler.initialize_service(
        project_root=str(root), config_path='acestep-v15-turbo', device='cpu',
        use_flash_attention=False, compile_model=False, quantization=None,
        prefer_source='huggingface', use_mlx_dit=False)
    print(status, flush=True)
    if not success:
        raise SystemExit('Model initialization failed')
    params = GenerationParams(
        caption=args.caption, lyrics='[Instrumental]', instrumental=True,
        bpm=96, keyscale='D minor', timesignature='4', duration=args.duration,
        inference_steps=8, seed=args.seed, thinking=False,
        use_cot_metas=False, use_cot_caption=False, use_cot_language=False)
    config = GenerationConfig(batch_size=1, seeds=[args.seed],
                              use_random_seed=False, audio_format='flac')
    started = time.monotonic()
    result = generate_music(handler, None, params, config, save_dir=str(output))
    record = {
        'model': 'ACE-Step/Ace-Step1.5', 'license': 'MIT',
        'code_revision': subprocess.check_output(
            ['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip(),
        'parameters': params.to_dict(), 'elapsed_seconds': time.monotonic() - started,
        'success': result.success, 'error': result.error,
        'audios': result.audios,
    }
    (output / 'generation.json').write_text(
        json.dumps(record, ensure_ascii=False, indent=2, default=str) + '\n')
    print(json.dumps(record, ensure_ascii=False, default=str), flush=True)
    if not result.success or not result.audios:
        raise SystemExit('Music generation failed; existing game assets unchanged')


if __name__ == '__main__':
    main()
