# Tabletop UI Redesign

## Design Contract

- Audience: landscape phone players comparing cards and combat outcomes.
- First read: cards and battlefield, then current resources and the available action.
- Materials: painted graphite stone, engraved silver, jade/garnet details; amber reserved for primary actions.
- Layout: fixed five-slot enemy and player rows, hero anchors on the left, scrolling hand below, primary action lower right.
- Selection: race colors and ornament silhouettes remain; card type keeps its frame and icon; selected controls have non-color markers.
- Reading: titles 24, body 16, supporting text 14; compact cards show identity and core numbers, details expose full effects.
- States: 44-pixel minimum command targets, equal state padding, no hover scaling; safe areas apply to fixed docks.
- Agency review roles: Brand Guardian for cohesion, UI Designer for materials and hierarchy, UX Architect for shared layouts, Finish-Gate Reviewer for rendered defects and release evidence.

## Preserved Behavior

No card definitions, prices, reward generation, save schemas, battle calculations,
or audio were changed by this redesign. Existing uncommitted gameplay and CC0
audio changes remain in the checkout. New image generation is confined to the
tabletop backdrop; card illustrations remain the existing assets.

## Reproducible Checks

Run each with a unique temporary `--test-data-dir` to isolate personal saves.

```sh
godot --headless --path . -s res://tests/godot/run_tests.gd -- --test-data-dir=/tmp/card-draft-ui-unit
godot --headless --path . -s res://tests/godot/tabletop_layout_test.gd -- --test-data-dir=/tmp/card-draft-ui-layout
godot --headless --path . -s res://tests/godot/reward_economy_test.gd -- --test-data-dir=/tmp/card-draft-ui-economy
godot --path . -s res://tests/godot/reward_economy_layout_test.gd -- --test-data-dir=/tmp/card-draft-ui-economy-render
godot --path . -s res://tests/godot/settings_controls_test.gd -- --test-data-dir=/tmp/card-draft-ui-settings
godot --path . -s res://tests/godot/capture_battle_choices.gd -- --test-data-dir=/tmp/card-draft-ui-battle --landscape
godot --path . -s res://tests/godot/capture_ui_responsive.gd -- --test-data-dir=/tmp/card-draft-ui-screens --single-viewport mobile_932x430 932 430
```

Rendering checks require a real rendering backend, not `--headless`.
Assertions on comparison cells include pairwise overlap checks and are not
independent user scenarios. Passing bounds alone is not a visual finish gate.

## Physical Device

The connected iPhone 16 Pro Max was reported `unavailable` by `devicectl` during
this task. Updated on-device card selection, attack targeting, scrolling,
cancellation, and purchase are unverified. Desktop-rendered mobile viewports and
synthetic input must not be reported as physical-device verification.
