#!/usr/bin/env python3
"""Generate isolated game sound effects with the Apache-2.0 MOSS model."""
import argparse
import gc
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import types

PROMPTS = {
    'ice_hit': 'A single icicle spear strikes frozen stone and shatters into sharp glassy ice fragments, with a brief cold airy hiss. Isolated fantasy impact, no voice or music.',
    'shadow_hit': 'A short dark magical impact: a hollow rushing breath collapsing into a dry low thump and a brief rattling decay. No voice, no music, isolated sound effect.',
    'lightning_hit': 'One short bright electrical arc snaps into a metal target, a sharp crack followed by brief sizzling sparks. Isolated fantasy lightning hit, no voice or music.',
    'arrow_hit': 'A single arrow strikes a wooden target. A sharp dry wooden thunk with a brief rustling vibration. Loud clear isolated close-up sound effect, no speech or music.',
    'heavy_hit': 'A massive iron war hammer strikes a metal shield with one deep crushing impact and a brief resonant metallic rattle. Powerful isolated close-up impact, no speech or music.',
    'ultimate': 'A short magical energy surge rises into one immense thunderous explosion with shimmering sparks and a low rumbling tail. Isolated fantasy ultimate ability, no speech or music.',
    'sword_hit': 'A single heavy steel sword strikes a wooden shield. Sharp metallic clang, deep wooden impact, a short natural decay. Isolated close-up sound effect, no speech or music.',
    'card_play': 'One playing card slides across a wooden table and lands with a crisp papery snap. Close-up dry foley, isolated single action, no speech or music.',
    'summon': 'A heavy armored knight takes one step onto a stone floor. Weighty boot impact with chainmail and plate armor rattling briefly. Isolated close-up sound effect, no speech or music.',
    'heal': 'A gentle shimmering magical chime swells softly and fades into tiny sparkling bells. One short warm healing spell, no speech or background music.',
    'spell_hit': 'A single magical fireball bursts with a fast rushing flame, heavy fiery impact and brief crackling embers. Isolated fantasy sound effect, no speech or music.',
    'unit_death': 'Bones and pieces of armor collapse onto a stone floor in one short heavy clatter, then settle. Close-up dry sound effect, no voice or music.',
    'gold_gain': 'A small handful of gold coins falls into a leather pouch with bright metal clinks and a soft leather rustle. Single isolated sound effect, no speech or music.',
    'ui_click': 'One small mechanical wooden button clicks firmly with a short dry tick. Clean isolated interface sound, no speech or music.',
}


def usable_audio(samples, rate):
    import numpy as np
    interior = samples[round(rate * 0.02):-round(rate * 0.02)]
    return (len(interior) > 0 and np.isfinite(samples).all()
            and np.max(np.abs(interior)) >= 0.03
            and np.sqrt(np.mean(interior ** 2)) >= 0.0005)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model-root', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--key', choices=[*PROMPTS, 'all'], default='sword_hit')
    parser.add_argument('--keys', nargs='+', choices=list(PROMPTS), help='Generate selected effects without reloading the model')
    parser.add_argument('--threads', type=int, default=2, help='CPU worker threads; 2 suits dual-core laptops')
    parser.add_argument('--seed', type=int, default=20260911)
    parser.add_argument('--steps', type=int, default=100)
    parser.add_argument('--skip-existing', action='store_true')
    parser.add_argument('--prompt-file', type=Path, help='JSON overrides for selected sound prompts')
    parser.add_argument('--cache-prompts', action='store_true', help='Release the text encoder after encoding selected prompts')
    args = parser.parse_args()
    prompts = dict(PROMPTS)
    if args.prompt_file:
        overrides = json.loads(args.prompt_file.read_text())
        if not isinstance(overrides, dict) or any(key not in PROMPTS or not isinstance(value, str) or not value.strip() for key, value in overrides.items()):
            parser.error('prompt-file must map known sound keys to nonempty text')
        prompts.update(overrides)
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

    torch.set_num_threads(max(1, min(args.threads, os.cpu_count() or 1)))
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
    keys = args.keys or (list(PROMPTS) if args.key == 'all' else [args.key])
    if args.cache_prompts:
        cache = {}
        requested = [(prompts[key] + ' duration: 3.0s', True) for key in keys] + [('', False)]
        for prompt, positive in requested:
            print('Encoding prompt: ' + prompt[:64], flush=True)
            with torch.inference_mode():
                cache[(prompt, positive)] = pipe.prompter.encode_prompt(prompt, positive=positive, device='cpu')
        def cached_prompt(prompter, prompt, positive=True, device='cpu'):
            if positive is None:
                positive = bool(prompt)
            return cache[(prompt, positive)].to(device)
        pipe.prompter.encode_prompt = types.MethodType(cached_prompt, pipe.prompter)
        pipe.engine.text_encoder = None
        pipe.prompter.text_encoder = None
        gc.collect()
        print('Text encoder released; original conditioning tensors cached', flush=True)
    failed = []
    for index, key in enumerate(keys):
        seed = args.seed + index
        existing = output / (key + '.wav')
        metadata = output / (key + '.json')
        if args.skip_existing and existing.is_file() and metadata.is_file():
            saved = json.loads(metadata.read_text())
            previous, previous_rate = sf.read(existing, always_2d=True)
            if (saved.get('sha256') == hashlib.sha256(existing.read_bytes()).hexdigest()
                    and saved.get('prompt') == prompts[key]
                    and saved.get('seed') == seed and saved.get('steps') == args.steps
                    and usable_audio(previous, previous_rate)):
                print('Keeping completed effect: ' + key, flush=True)
                continue
        print('Generating ' + key, flush=True)
        started = time.monotonic()
        # The upstream convenience call forces BF16 autocast even on CPU. This
        # machine has no native BF16, so use the same engine in float32 instead.
        with torch.inference_mode():
            audio = pipe.engine(
                prompt=prompts[key] + ' duration: 3.0s', negative_prompt='',
                num_samples=3 * pipe.sample_rate, num_channels=1,
                num_inference_steps=args.steps, cfg_scale=4.0, sigma_shift=5.0,
                seed=seed)
        samples = audio[0].detach().float().cpu().numpy().T
        if not usable_audio(samples, pipe.sample_rate):
            failure = {'key': key, 'seed': seed, 'steps': args.steps,
                       'finite': bool(np.isfinite(samples).all()),
                       'peak': float(np.max(np.abs(samples))),
                       'rms': float(np.sqrt(np.mean(samples ** 2)))}
            print('Rejected generation: ' + json.dumps(failure), flush=True)
            failed.append(key)
            continue
        target = output / (key + '.wav')
        sf.write(target, samples, pipe.sample_rate, subtype='PCM_24')
        record = {
            'model': 'OpenMOSS-Team/MOSS-SoundEffect-v2.0', 'license': 'Apache-2.0',
            'cpu_threads': torch.get_num_threads(),
            'cached_prompt_embeddings': args.cache_prompts,
            'code_revision': subprocess.check_output(
                ['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip(),
            'prompt': prompts[key], 'seed': seed, 'steps': args.steps,
            'seconds': 3, 'elapsed_seconds': time.monotonic() - started,
            'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'file': str(target),
        }
        (output / (key + '.json')).write_text(
            json.dumps(record, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps(record, ensure_ascii=False), flush=True)

    if failed:
        raise SystemExit('No assets written for rejected effects: ' + ', '.join(failed))


if __name__ == '__main__':
    main()
