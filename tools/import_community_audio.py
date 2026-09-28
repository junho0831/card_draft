#!/usr/bin/env python3
"""Package existing CC0 recordings; never synthesizes or generates audio.
Usage: python3 tools/import_community_audio.py --source-dir /path/to/library
Source files and download URLs are recorded in the output manifest.
Requires ffmpeg and ffprobe; standard library only.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PACKS = {
    'kenney-interface': ('https://kenney.nl/assets/interface-sounds', 'https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip'),
    'kenney-rpg': ('https://kenney.nl/assets/rpg-audio', 'https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip'),
    'kenney-impact': ('https://kenney.nl/assets/impact-sounds', 'https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip'),
}
SFX = {
    'ui_click': ('kenney-interface', 'click_001'),
    'card_play': ('kenney-rpg', 'bookFlip1'),
    'gold_gain': ('kenney-rpg', 'handleCoins'),
    'sword_hit': ('kenney-rpg', 'knifeSlice'),
    'heavy_hit': ('kenney-impact', 'impactPunch_heavy_000'),
    'arrow_hit': ('kenney-impact', 'impactWood_light_002'),
    'wind_hit': ('kenney-rpg', 'cloth1'),
    'bone_hit': ('kenney-impact', 'impactWood_heavy_002'),
    'blood_hit': ('kenney-impact', 'impactPunch_medium_002'),
    'poison_hit': ('kenney-rpg', 'creak1'),
}
MUSIC = {
    'menu_theme': ('menu', 'medieval-the-bards-tale', 'Loop_The_Bards_Tale.wav'),
    'battle_base': ('battle', 'medieval-battle', 'battle_1.wav'),
    'exploration': ('exploration', 'medieval-exploration', 'Exploration.wav'),
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def probe(path):
    return json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'json', str(path)]))['format']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    args = parser.parse_args()
    dest = ROOT / 'assets/audio/community_v1'
    dest.mkdir(parents=True, exist_ok=True)
    records = []
    for key in [*SFX, *MUSIC]:
        if key in SFX:
            pack, name = SFX[key]
            src = args.source_dir / pack / 'Audio' / (name + '.ogg')
            page, download = PACKS[pack]
            author = 'Kenney'
            filters = 'volume=0.7'
            edit = 'Original duration and pitch; gain 0.7; Ogg Vorbis quality 5.'
        else:
            name, slug, filename = MUSIC[key]
            src = args.source_dir / 'oga' / (name + '.wav')
            page = 'https://opengameart.org/content/' + slug
            download = 'https://opengameart.org/sites/default/files/' + filename
            author = 'RandomMind'
            duration = float(probe(src)['duration'])
            filters = 'loudnorm=I=-20:TP=-3:LRA=11'
            if key != 'menu_theme':
                filters += f',afade=t=in:d=0.1,afade=t=out:st={duration-0.8}:d=0.8'
            edit = 'Full track; loudnorm -20 LUFS / -3 dBTP; 44.1 kHz stereo Ogg quality 5. ' + ('Author loop retained.' if key == 'menu_theme' else '100 ms intro / 800 ms outro fades; full-song repeat, not a seamless musical loop.')
        target = dest / (key + '.ogg')
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(src), '-af', filters + (',asetpts=N/SR/TB' if key in MUSIC else ''), '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '5', str(target)], check=True)
        records.append(dict(key=key, file=target.name, author=author, license='CC0-1.0', license_url='https://creativecommons.org/publicdomain/zero/1.0/', source_page=page, download_url=download, source_file=str(src.relative_to(args.source_dir)), source_sha256=sha(src), output_sha256=sha(target), duration_seconds=float(probe(target)['duration']), processing=edit, reviewed_on='2026-09-28'))
    for pack in PACKS:
        license_text = (args.source_dir / pack / 'License.txt').read_text()
        (dest / (pack + '-LICENSE.txt')).write_text('\n'.join(line.rstrip() for line in license_text.splitlines()).strip() + '\n')
    (dest / 'manifest.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
    print(f'Packaged {len(records)} CC0 assets into {dest}')

if __name__ == '__main__':
    main()
