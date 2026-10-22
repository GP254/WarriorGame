> **Native mobile game:** The Godot iPhone/iPad project is in [`godot/`](godot/README.md). Open `godot/project.godot` or run `godot/play-native.command`. The documentation below describes the earlier browser prototype.

# Ashen Banner

A playable fictional pixel-art clan conquest game. Build a warband, equip squads, conquer neighboring territories, and fight as the clan leader in large battles.

## Run

```sh
npm install
npm run dev
```

Open the localhost address printed by Vite. `npm run build` type-checks and produces `dist/`. `npm test` runs the gameplay regression tests.

## Current build: 0.2

- Explorable, pannable campaign map with 16 connected territories, resources, conquest rewards, and local saves.
- Four warrior classes. Start with 200 troops; recruit up to 125 per class, for 500 soldiers plus your leader. Select deployment counts and formation before each battle.
- High rear-overhead battle camera, scroll zoom, army overview, and minimap. Enemy forces range from 160 to 440.
- Four new 8×8 animation sheets: 256 frames in total. Each class has eight-frame run, light attack, heavy attack, and death sequences from both rear and front overhead views.
- Attacks resolve during their contact frame. Guarding, stamina, light combos, heavy cleaves, dodging, hit recovery, knockback, crowd separation, arrow flight, and fortress volleys affect combat.
- Animated collapses leave bodies. Blood particles, persistent stains, and ballistic debris can be turned off.
- 200 generated weapon icons: 50 swords, 50 axes, 50 polearms, 50 bows. Four armor upgrades. Purchases equip an entire squad.
- Spatial bins for local combat and crowd collision queries, with staggered target selection for large armies.

## Controls

| Action | Control |
|---|---|
| Move leader | WASD / arrow keys |
| Light attack / combo | J, hold to repeat |
| Heavy attack | K |
| Guard | L / Shift, hold |
| Dodge | Space |
| Rally nearby allies | E |
| Zoom battlefield | Mouse wheel |
| Army overview / leader camera | Tab |
| Pause / close menu | Escape |

On-screen combat buttons and touch movement controls are included. The opening charge is automatic; then the leader is under your control. Warriors regroup after a loss, so defeat does not erase your equipment or territory.

## Artwork

All world, terrain, warrior, and weapon raster artwork was made with built-in ChatGPT image generation and is saved in `public/assets/`. Interface glyphs, HUD, particles, and combat rendering are code.

- `animation-prompts.json`: exact prompts for the replacement overhead character animation sheets and overhead terrain.
- `prompts.json`: exact prompts for the initial world, weapons, and retained concept assets.
- `ironward-v2.png`, `ravager-v2.png`, `pikewarden-v2.png`, `duskranger-v2.png`: eight columns and eight rows. Rows 0–3 are rear run/light/heavy/death; rows 4–7 are front versions.
- `terrain-v2.png`: autumn, snow, marsh, and volcanic overhead terrain quadrants.
- Initial `warriors.png` and `battlefields.png` remain as source/concept art; old battlefield art is used only in campaign destination cards.

## Development checks

`tests/battle-bench.html`, served by Vite, runs a separate 941-unit scenario (501 allies, 440 enemies). It does not read or write campaign saves. The benchmark leader has inflated health so the simulation can be observed. This override exists only in the test page.

Tests cover campaign reachability and rewards, purchases, save validation/migration, 941-unit spatial queries, attack windup and single contact, guard/dodge, crowd-hit recovery, deaths, blood settings, rally range, and animation frame selection.

## Scope and next work

This is an early playable game foundation. Falls use authored frame sequences with knockback and physics-driven debris; they are not articulated ragdoll physics. Generated poses still need hand-tuned frame alignment and extra facing directions. Unit appearance follows the equipped weapon family so it does not change body during an attack; class stats remain independent. Each weapon currently uses its family's combat animation rather than a bespoke animation for every one of the 200 items. Armor upgrades affect stats but do not yet replace every armor sprite.

The 16 locations currently share four biome terrain bases with different armies, rewards, and fortification rules. Bespoke layouts, destructible walls, cover/pathfinding, and individual environmental art for every location remain future work. The simulation and controls should be tuned through playtesting before adding more content.

Saves use browser local storage (`ashen-banner-v2`), and build 0.1 saves migrate to the larger army scale while preserving resources, equipment, and territory. Display fonts load from Google Fonts with local fallbacks.
