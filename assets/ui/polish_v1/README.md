# Shared Fantasy UI Materials

Created on 2026-10-11 with Codex's built-in image-generation tool. These are UI
materials only. Existing card illustrations, backgrounds and audio remain intact.
No text, numbers, prices or gameplay data are baked into these PNGs.

## Assets

| File | Purpose | Source Output |
| --- | --- | --- |
| frame_unit.png | Riveted unit frame | exec-e3820407-e25c-41bd-b122-fe633350d30a.png |
| frame_spell.png | Rounded rune spell frame | exec-2bb65439-259f-427e-8993-6c1f06cb5210.png |
| frame_equipment.png | Beveled forged equipment frame | exec-2d0b0f2e-4ea8-4a0c-b32a-187083a2fde3.png |
| button_silver.png | Secondary action | exec-d8f13433-b7b2-4110-8390-e41ce21f24ef.png |
| button_gold.png | Primary action | exec-7c083c72-7031-490a-b4c0-8a9a99c5905d.png |
| detail_border.png | Shared detail perimeter | exec-0e89aa39-02c8-4a87-91ac-7fc0270c2b88.png |
| corner_human.png | Shield, crown and acanthus | exec-2826c8a4-976b-433b-a71f-24e7cbfb9c90.png |
| corner_elf.png | Green leaf and vine | exec-e729d91f-b107-4269-b5c6-9cac4f22bea8.png |
| corner_undead.png | Bone, skull and wine enamel | exec-495245aa-0e22-4253-9de1-1599e1314c31.png |
| corner_spirit.png | Teal crystal and icy branches | exec-b7a98dd1-4c3b-421c-9071-f54ced6054dd.png |
| corner_neutral.png | Diamond rivet and plain filigree | exec-fb1f35f9-fcf1-4f0c-b4bb-786d74eb1267.png |

Source outputs live in the task's generated-images directory, not in the export.
Each asset was generated separately, not cropped from a mockup or sprite sheet.
The preview concept is not a game resource and its invented labels/prices are not
used in production. Audio's existing CC0 policy is unaffected.

## Prompt Set

### Card Frames

Use case: stylized-concept. Asset type: Godot 2D UI transparent PNG frame.

Variations: portrait 2:3 UNIT with square reinforced riveted corners and heraldic
grooves; SPELL with rounded rune upper corners and a tiny arcane bottom crest;
EQUIPMENT with beveled angular corners, small rivets and a forge bottom crest.

Match premium realistic painterly medieval fantasy board-game UI, natural etched
brushed silver with subtle tarnish and soft warm reflected light. Straight-on
orthographic view. Fill the canvas with the frame outer bounds; perimeter
thickness only 3% of frame width, no drop shadow outside. The entire inner 90%
is genuinely transparent, not black or grey. NO artwork, card text, numbers,
symbols resembling text, cost badges, name banner, background, people, parchment,
watermark. All details confined to border and small corners. Both center and
outside must have real alpha transparency. Keep long sides and center of
top/bottom straight and repeating so this asset works as a nine-slice frame,
no central decorations extending into illustration. One single frame only,
not a sheet or mockup.

### Buttons and Detail Border

Use case: stylized-concept. Asset type: one transparent production Godot 2D UI
PNG, straight-on orthographic, realistic painterly fantasy board-game interface
matching the earlier generated silver card frames.

Variations: 4:1 chamfered silver button with a charcoal softly textured uniform
center; 4:1 muted gold leaf button with triangular end caps and a uniform center;
16:9 thin silver rectangular perimeter with four small heraldic corners,
straight long edges and a transparent center.

One single asset filling the canvas, nothing else. No text, letters, numbers,
logos, icons, environment, people, cast shadow or surrounding background. Real
alpha transparency outside the button/frame. Fine material grain and engraved
highlights only, natural silver or gold, not vector geometric flat shapes,
not futuristic, not overly ornate. Perimeter thin, corners occupy under 8% width.

### Race Corners

Use case: stylized-concept. Asset type: ONE transparent 2D fantasy card corner
ornament PNG, 1:1 square canvas. Create a top-left L-shaped thin metal corner
inset, featuring the race motif listed above. The horizontal arm runs along the
TOP edge and vertical arm along the LEFT edge, their junction is in the top-left,
large remaining bottom-right area is genuinely alpha-transparent. Matching
realistic painterly engraved metal UI of the earlier silver unit card frame.
Elegant but legible when displayed at 24 pixels. Ornament contained in outer 25%
on each edge, no extensions into card artwork. One object only, no sheet,
no background, no frame on other sides, no text, no logo, no cast shadow,
no glow. Bounds fill canvas at top and left. Keep lower right empty and transparent.

## Rendering

- UiStyles caches packed button textures once; it ignores stray transparent
  canvas padding by finding the solid central strip. Source PNGs stay unchanged.
- Buttons and dialog perimeters use StyleBoxTexture nine-slicing.
- CardFrameOrnaments separates source patches from display margins, skips the
  center, and mirrors a race corner into the four corners.
- Existing illustrations retain aspect-cover cropping, never stretching.
- Race color, type icon/frame and selection outline are separate layers.
