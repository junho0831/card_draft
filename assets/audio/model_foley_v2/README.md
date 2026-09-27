# Model Foley v2

Only `sword_hit.ogg` is complete and enabled. Heavy and spell replacements were
stopped at the user's request and retain their existing model-generated assets.
The rejected procedural `dry_combat_v1` pack is not included or selected.

This is a new MOSS-SoundEffect v2.0 inference, not oscillator/noise synthesis.
The adjacent JSON records the prompt, seed, 32 inference steps, code and model
revisions, original WAV hash, editing settings and runtime Ogg hash.
Model license: Apache-2.0. Model weights are not shipped in the game.

The generated 3-second source was edited to a 0.38-second contact with short
boundary fades and restrained volume. No synthesized layers or reverb were
added. Existing battle events that share sword_hit use the new recording;
background music and other effects are unchanged apart from mix headroom.

Generation tools: `tools/generate_local_sfx.py` with
`tools/content/dry_foley_prompts.json`, followed by `tools/package_model_sfx.py`
with `--key sword_hit --dry`. Raw masters and installed model files remain in
the user's external cache, not in the game repository.

Source model: https://huggingface.co/OpenMOSS-Team/MOSS-SoundEffect-v2.0
