# CC0 community audio — 2026-09-28

2026-10-04: combat playback now prefers the shorter CC0 edits in
`../combat_edited_v1/`. UI and all three music tracks still use this pack.
Older model packs are no longer runtime fallbacks. The text below records
the original September import, not the current complete sound selection.

Ten Kenney recordings and three RandomMind compositions. These are downloaded
works, not newly synthesized or AI-generated sounds. Only gain, encoding and
music fades were changed. Source URLs, author names, CC0 links, source/output
SHA-256 hashes and exact edits are in `manifest.json`. Kenney's supplied licenses
are preserved alongside the files (line endings and trailing whitespace normalized). RandomMind's individual source pages each
label the work CC0; CC0 permits commercial use and redistribution.

Menu uses the author's loop version. Battle and exploration repeat full songs
with short edge fades; seamless musical looping is not claimed. New recordings
have priority over the previous packs; magic, healing, summons and other events
without a replacement retain their existing sounds. This does not relicense
those older packs.

Rebuild from downloaded, extracted source files with:

```sh
python3 tools/import_community_audio.py --source-dir /path/to/library
```

See `docs/community-audio.md` for source selection, exclusions and validation.
