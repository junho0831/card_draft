# Representative Card Portraits V2

Generated on 2026-09-27 with the built-in `image_gen` tool. The tool did not
expose an underlying model identifier. Original images remain unchanged in
`assets/card_art/cards/` and the sample atlas.

## Scope

Five representative unit cards, not the entire collection. New portrait files
contain artwork only. Card frames and race emblems remain vector/code assets;
names, cost, rules, attack and health remain live Godot controls. Base and
upgraded cards share the same illustration. No balance data was modified.

| File | Subject | Direction |
| --- | --- | --- |
| militia.png | Human militia soldier | Gold cloth, practical steel, spear and wooden shield, kingdom outpost |
| forest_archer.png | Elf archer | Pointed ears, green cloak, wooden bow, sunlit forest temple |
| bone_soldier.png | Skeleton soldier | Ivory skull, violet tabard, weathered iron, moonlit crypt |
| stone_golem.png | Stone elemental | Gray stone body, cyan eyes and quartz, ancient sanctuary |
| mercenary.png | Neutral mercenary | Weathered veteran, gray steel, round iron buckler, trading crossroads |

## Generation Brief

Individual opaque portrait 2:3 illustrations. Cohesive painterly-realistic
collectible-card finish, crisp focal subject, broad silhouettes legible at
68 pixels, natural light, restrained backgrounds. Waist-up three-quarter
compositions with faces near the upper center and central square-crop safety.
No card layout, text, numbers, watermark, UI, badges or frame baked into the
art. Later images used earlier images only as art-direction references.

Generated source basenames, in table order:

- exec-7cbe0b8c-9c3c-43ca-adf7-2203127d3375.png
- exec-5e58d548-7adc-49c5-917b-26b825f6cd47.png
- exec-ddb5d248-2cba-42ba-b0da-bba13cb22066.png
- exec-186aa527-a9ed-4d0b-9e18-270595eb29ca.png
- exec-cde32893-409d-4e06-a068-df85818a0346.png

## Verification

Run from the project root:

```sh
godot --path . -s res://tests/godot/card_portrait_integration_test.gd -- --test-data-dir=/tmp/card-portrait-review
```

The test checks portrait routing/cache reuse, upgraded-card artwork, live
labels and statistics, and unchanged fallback artwork. A graphical run also
saves `card_portraits.png` in the test directory. Use `--headless` for checks
without a capture.
