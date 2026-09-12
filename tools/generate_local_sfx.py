#!/usr/bin/env python3
"""Generate isolated game sound effects with the Apache-2.0 MOSS model."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import types

PROMPTS = {
    'sword_hit': 'A single heavy steel sword strikes a wooden shield. Sharp metallic clang, deep wooden impact, a short natural decay. Isolated close-up sound effect, no speech or music.',
    'card_play': 'One playing card slides across a wooden table and lands with a crisp papery snap. Close-up dry foley, isolated single action, no speech or music.',
    'summon': 'A heavy armored knight takes one step onto a stone floor. Weighty boot impact with chainmail and plate armor rattling briefly. Isolated close-up sound effect, no speech or music.',
    'heal': 'A gentle shimmering magical chime swells softly and fades into tiny sparkling bells. One short warm healing spell, no speech or background music.',
    'spell_hit': 'A single magical fireball bursts with a fast rushing flame, heavy fiery impact and brief crackling embers. Isolated fantasy sound effect, no speech or music.',
    'unit_death': 'Bones and pieces of armor collapse onto a stone floor in one short heavy clatter, then settle. Close-up dry sound effect, no voice or music.',
    'gold_gain': 'A small handful of gold coins falls into a leather pouch with bright metal clinks and a soft leather rustle. Single isolated sound effect, no speech or music.',
    'ui_click': 'One small mechanical wooden button clicks firmly with a short dry tick. Clean isolated interface sound, no speech or music.',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model-root', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--key', choices=[*PROMPTS, 'all'], default='sword_hit')
    parser.add_argument('--seed', type=int, default=20260911)
    parser.add_argument('--steps', type=int, default=100)
    parser.add_argument('--skip-existing', action='store_true')
    args = parser.parse_args()
    root = args.model_root.resolve()
    output = args.output_dir.resolve()
    if not (root / 'moss_soundeffect_v2').is_dir():
        parser.error('model-root must be a MOSS-TTS checkout')
    output.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(root))
    os.environ['TORCHDYNAMO_DISABLE'] = '1'
    os.environ['HF_HUB_DISABLE_XET'] = '1'
    import torch
    import numpy as np
    import soundfile as sf
    from moss_soundeffect_v2 import MossSoundEffectPipeline

    torch.set_num_threads(min(4, os.cpu_count() or 1))
    pipe = MossSoundEffectPipeline.from_pretrained(
        root / 'checkpoints', torch_dtype=torch.float32, device='cpu')
    # Only hidden states are consumed by this audio model. Skip vocabulary
    # logits and right padding inside the causal text encoder, then restore
    # its original output shape for the unchanged audio conditioning path.
    def encode_hidden(encoder, ids, mask=None):
        length = int(mask.sum(dim=1).max()) if mask is not None else ids.shape[1]
        length = max(1, length)
        with torch.inference_mode():
            hidden = encoder.model.model(
                input_ids=ids[:, :length],
                attention_mask=mask[:, :length] if mask is not None else None,
                use_cache=False, return_dict=True).last_hidden_state
        return torch.nn.functional.pad(hidden, (0, 0, 0, ids.shape[1] - length))
    pipe.text_encoder.forward = types.MethodType(encode_hidden, pipe.text_encoder)
    keys = list(PROMPTS) if args.key == 'all' else [args.key]
    for index, key in enumerate(keys):
        seed = args.seed + index
        existing = output / (key + '.wav')
        metadata = output / (key + '.json')
        if args.skip_existing and existing.is_file() and metadata.is_file():
            saved = json.loads(metadata.read_text())
            if saved.get('sha256') == hashlib.sha256(existing.read_bytes()).hexdigest():
                print('Keeping completed effect: ' + key, flush=True)
                continue
        print('Generating ' + key, flush=True)
        started = time.monotonic()
        # The upstream convenience call forces BF16 autocast even on CPU. This
        # machine has no native BF16, so use the same engine in float32 instead.
        with torch.inference_mode():
            audio = pipe.engine(
                prompt=PROMPTS[key] + ' duration: 3.0s', negative_prompt='',
                num_samples=3 * pipe.sample_rate, num_channels=1,
                num_inference_steps=args.steps, cfg_scale=4.0, sigma_shift=5.0,
                seed=seed)
        samples = audio[0].detach().float().cpu().numpy().T
        if not np.isfinite(samples).all() or np.max(np.abs(samples)) < 1e-5:
            raise SystemExit('Invalid or silent generation; game assets unchanged')
        target = output / (key + '.wav')
        sf.write(target, samples, pipe.sample_rate, subtype='PCM_24')
        record = {
            'model': 'OpenMOSS-Team/MOSS-SoundEffect-v2.0', 'license': 'Apache-2.0',
            'code_revision': subprocess.check_output(
                ['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip(),
            'prompt': PROMPTS[key], 'seed': seed, 'steps': args.steps,
            'seconds': 3, 'elapsed_seconds': time.monotonic() - started,
            'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'file': str(target),
        }
        (output / (key + '.json')).write_text(
            json.dumps(record, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps(record, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
