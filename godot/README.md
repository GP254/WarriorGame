# Ashen Banner — native mobile game

A playable Godot 4.7.1 development build for landscape iPhone and iPad. Version 0.4.1 includes a walk-up barracks with recruitment and adds eight-direction walking, circular touch controls, a redesigned realm map, and a persistent village society to the native campaign and battle loop. Further art, combat, balance, and physical-device work is needed before treating it as the final commercial release.

## Play

Open `project.godot` in Godot and press **F5**, or double-click `play-native.command` on this Mac. Enter Hearthhold, speak to a nearby resident, visit the smithy and market, or open the map to prepare a conquest. The macOS export is in `builds/AshenBanner-macOS.zip` when built.

On mobile, use the left stick to walk. The contextual button talks to residents or opens a nearby building. During combat, hold **Strike** or **Guard**; tap **Heavy**, **Dodge**, or **Rally**. Each combat button owns its touch independently, allowing movement and multiple simultaneous actions. Landscape supports both sides and places controls inside the device safe area.

Desktop controls: WASD or arrow keys to explore; E interacts. In battle: WASD moves, J strikes, K uses a heavy strike, L/Shift guards, Space dodges, and E rallies. Escape pauses or closes a panel. Resource production pauses while menus or transitions block the world.

## Implemented campaign

- Sixteen connected territories, four terrain biomes, and adjacent conquest rules. Walking to a district boundary opens a named loading transition for owned land or a deployment council for rival land.
- Small explorable settlements with building collision, roads, signs, resident routines, and dialogue reflecting current needs and work. The smithy opens equipment, the market collects supplies, and the hall improves the settlement.
- Four settlement stages. Repairs, houses, markets, the hall, granary, shrine, and towers change visibly; populations grow from 20 to 56 residents in a loaded district. All villages share a simple road structure with seeded placements and biome dressing.
- 256 deterministic villager appearances assembled from eight generated archetypes and 32 runtime clothing palettes, with generated eight-direction, four-frame walking cycles and occupation work animations. Player and army movement also selects eight-direction walking poses; attack/death animations retain their existing front/back families. These are visual combinations, not 256 independently drawn character sheets.
- A twelve-minute village day, hunger, energy, and social needs; pathfinding around buildings; homes, fields, bakery, herb garden, workshop, market, and material depot. Farmers supply grain, bakers make bread, couriers bring ore/timber, smiths forge tools, and traders sell surplus tools/cloth. Elders restore nearby social needs. Need-driven food, rest, and social breaks interrupt work. Player actions stock food or supply the forge; trade earnings join the regular market collection. Stocks and resident needs persist across travel and saves. Only the loaded village simulates, and menus pause it.
- An illustrated map with named settlements, ownership/conquest colours, selected-location resources, a fixed details panel, pan, pinch/scroll zoom, and home focus.
- Circular navigation/context/combat controls with circular hit regions, independent pointer ownership, and a proportional thumbstick with a remapped dead zone.
- A barracks northwest of the clan hall in every settlement, a recruiting officer, and animated training troops. Hire 1, 5, 10, or 25 warriors per purchase for 9 gold each, with exact pricing for partial batches at the 125-per-class limit. Recruits immediately inherit squad equipment, persist in saves, and appear in deployment. The Clan and Village panels also link to recruitment. Civilian jobs remain staffed.
- Four warrior classes, 200 purchasable weapons (50 each of swords, axes, spears, and bows), four armor choices, class-wide equipment assignment, leader selection, and recruitment up to 500 warriors plus the leader.
- Three deployment formations, automatic initial charge, direct leader control, and three enemy waves. Reinforcements arrive at 35 and 70 seconds. The initial army has 200 warriors; later territories have up to 440 enemies across the three waves.
- Timed light/heavy attack impacts, guard, dodge invulnerability, stamina, rally healing, spatial crowd separation, arrows, tower volleys, knockback, blood particles, and eight-frame falling animations. Death uses animated collapse and body momentum; articulated ragdolls and dismemberment are not implemented.
- Conquest rewards, a one-time welcome quest, recurring market production every 120 active seconds, settlement upgrades, and local autosave with a validated backup and atomic replacement.
- Procedural ambient wind, footsteps, UI, weapon impacts, guard, swing, and rally sound effects. Blood, camera movement, and sound can be switched off in Pause.

## iOS / iPadOS build

`builds/ios/AshenBanner.xcodeproj` is the exported Xcode project. It targets iPhone and iPad, iOS 16+, both landscape orientations, and the Compatibility renderer. The bundle ID is `com.ashenbanner.game`.

Regenerate the project and build an unsigned simulator app:

```sh
./tools/build-ios.sh
```

This script replaces only generated export files in `builds/ios`. Keep changes to game logic, assets, and export configuration in this Godot project. It sets the simulator architecture to the host architecture; this Intel Mac requires `x86_64`. The installed export template's simulator archive was verified on this Intel host; Apple Silicon simulator support needs verification on that host.

To test on a physical device, open the exported project in Xcode, select the device, and configure a development signing team for this bundle ID. No App Store upload or distribution has been performed. The project includes a generated app icon; Godot resizes its source to Apple's required icon dimensions during export.

To update only game content after changing scripts or assets:

```sh
godot --headless --path . --export-pack iOS builds/ios/AshenBanner.pck
```

Then rebuild in Xcode so the updated pack is copied into the app.

## Verification

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/regression.gd -- --test
godot --headless --path . --script res://tests/village_life.gd -- --test
godot --headless --path . --script res://tests/barracks.gd -- --test
godot --headless --path . --script res://tests/battle_balance.gd -- --test
godot --path . --script res://tests/visual_review.gd -- --review
```

Regression checks cover catalog links, all 200 sprite regions, 256 villager variants, progression, purchase validation, duplicate rewards, production cooldowns, corrupt-save recovery, every district spawn and exit, touch ownership, pause/resume, guarding, dodging, attack windup, lethal hits, conquest, loading transitions, and leaving battle results. Tests use an isolated save filename and never overwrite a real campaign.

Debug exports also support `-- --review --device-review` to capture the village, armory, map, deployment, battle, and upgraded village on the running device. This requires a debug build and test-mode state. Results and viewport captures are written into the app's Documents directory, with copied review artifacts under `artifacts/` in this workspace.

`artifacts/battle-balance.json` records the deterministic opening-battle simulation and a 941-unit stress scenario. The version 0.3 baseline opening battle lasted 91.8 seconds. The 941-unit stress case averaged about 54 ms per simulation tick on this Intel Mac, exceeding a 30 Hz budget; maximum crowd counts need further optimization. Simulation timings are desktop diagnostics, not physical-iPhone frame-rate claims. High-end crowd counts still require device profiling and tuning. Version 0.4 passed 366 campaign/combat checks and 166 directional-art, village-economy, persistence, pathfinding, circular-input, and map-gesture checks. Version 0.4.1 also passed 81 barracks checks covering all 16 regions, recruitment pricing/caps, save/reload, and deployment. See the current build and simulator logs in `artifacts/` for platform verification. Some headless shutdowns report ObjectDB cleanup warnings; these are retained in the test artifacts.

## Art and reference

Raster art comes from built-in ChatGPT image generation. Source prompts and provenance are in `assets/art/*prompts.json`; generated images are copied into this project. Original atlases are preserved. `data/weapon-regions.json` stores measured sprite boundaries so irregular generated spacing does not clip neighboring weapons. `tools/measure_weapon_regions.py` reads pixels to measure bounds; it does not modify the images. The new `data/character-regions.json` similarly measures walking/work sprites and adds runtime transparent margins to keep feet aligned without clipping generated irregular spacing. Its measurement tool leaves all image pixels unchanged. The bow source contains 60 drawings, of which 50 are assigned to the catalog.

Motorvale (`Documents/GearWorks`) informed the small-district structure, building collision, y-sorting, nearby-NPC interaction, camera behavior, and touch reset handling. This project uses its own game code and assets. Motorvale was not modified.

## Remaining production work

The next substantial passes are physical iPhone/iPad performance and thermal testing, longer campaign/economy playtesting, distinct authored landmarks for each territory, more dialogue and quests, directional animation cleanup, visible per-item equipment on warriors, and the requested articulated falling/gore system. Sound is currently a small procedural effects set. The 200 weapons have catalog stats and icons; they share four combat animation families. Signing, release distribution, and final store assets remain separate from this development build.
