# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Spec of record

Godot 4.7 project for **Roti Lezat Tycoon**, a bakery management tycoon game targeting Web (itch.io, HTML5) and Android from one codebase.

**The only authoritative specification is [docs/gdd-roti-lezaat-tycoon-ai-ready-v3.1-final.md](docs/gdd-roti-lezaat-tycoon-ai-ready-v3.1-final.md) (GDD v3.1 FINAL).** The older [docs/gdd-roti-lezaat-tycoon.md](docs/gdd-roti-lezaat-tycoon.md) is obsolete (maintainer decision, 2026-09-24): do not read it for requirements or cite it. On 2026-09-25, at the maintainer's request, its recipe data was copied into v3.1 (§61.5); anything else missing from v3.1 needs the maintainer's decision, not the old GDD.

v3.1 (~6,500 lines, narrative in Indonesian) has three layers: §1–12 product narrative, §13–95 technical specification (state machines, formulas, layout templates, save, tests), and §96–135 the hard implementation contract (engine lock, state-ownership matrix, test IDs, release validator, English content catalog). Read the relevant section before implementing any system — balance numbers, tier tables and flows are defined there and nowhere else. Per §126.1, reference canonical IDs/fields instead of copying numbers into code comments or other docs.

### Consistency status (2026-09-25)

All internal contradictions found in v3.1 were resolved in place on 2026-09-25. Each fact now has one home, and other sections point to it:

| Topic | Canonical source |
|---|---|
| IDs | §78 |
| Upgrade cost | §6 |
| Queue capacity | §57.6 |
| Furniture footprints | §60 |
| Price rules | §63.2 |
| "!" marker | §2 |
| Save paths and schema | §106 |
| Autoloads and managers | §35.2, §98 |
| RNG streams | §116 |
| Audio IDs | §93 |
| `BreadStack` | §19.1 |
| Recipe production data | §61.5 |
| Day 1–3 manifest | §20.3 |

The Day 1–3 manifest was copied from `scripts/data/opening_db.gd` with one change: the Day 1 16:30 office worker became a school child, because §2 bars office workers on Day 1.

The data gaps v3.1 used to have were also filled on 2026-09-25, each chosen for balance and then verified by script:

| Data | Section |
|---|---|
| Complete layout templates (counters, cashier points, passages, supply drop-off, portals) | §57 |
| Equipment purchase, replace and sell-back | §5.1.2 |
| RotiFood order generation, timing and tips | §22.9 |
| Physical rating deltas and starting ratings | §25.1–25.2 |
| Weather and holiday calendar | §26.6 |
| Archetype weights, preferences, budgets and quality rules | §20.11 |
| Recipe tags | §61.6 |
| Baker batch size | §23.7 |
| Decoration catalog | §72.1 |
| English strings | §127.7–127.11 |

A layout solver confirmed that every tier's template fits its slot counts. If a new question arises that v3.1 does not answer, do not invent the value silently. Quote the relevant passages (as §120.2 asks) and get a decision from the user.

## Project state

The code — about 30k lines of GDScript under `scripts/`, main scene `scenes/main.tscn`, seven autoloads — was written against the obsolete GDD and **has not been migrated to v3.1**. Existing behaviour is not evidence of what v3.1 requires. Known divergences include Indonesian IDs (`roti_tawar_polos`, `tepung_terigu`) and UI text, 2000 KR starting cash (v3.1: 1000), six slots per rack, recipe unlock prices, mixer/oven utility billed per real second, burn at 35% of bake time, a single RNG and a single save file, and no freshness, multi-floor or supply-courier systems. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) documents this pre-v3.1 implementation; where it disagrees with v3.1, v3.1 wins.

The GDD narrative is Indonesian, but **all player-facing text must be English** (§43, §127); proper nouns such as Budi, Pak Lurah and RotiFood stay as they are. Currency is **Koin Roti (KR)**.

## Commands

**Godot 4.7.2 lives at `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`** (note: the
`.exe` in the path is a *directory*). Use the `_console.exe` sibling when you need stdout/stderr — the
plain binary detaches from the console and you will see no output. It is **not** on `PATH`.

```bash
G='D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
"$G" --headless --path . --import          # reimport / regenerate .godot cache
"$G" --path .                              # open in editor
"$G" --headless --path . res://scenes/main.tscn
"$G" --headless --path . --export-release "Web" build/index.html
"$G" --headless --path . --export-release "Android" build/game.aab
```

### Test suite (run all four after any change)

```bash
"$G" --headless --path . --script res://tools/validate.gd        # every .gd compiles + no external assets
"$G" --headless --path . --script res://tools/data_audit.gd      # ~976 asserts: data layer vs the OBSOLETE GDD's tables
"$G" --headless --path . res://tools/procgen_test.tscn           # ~1041 asserts: factories actually run
"$G" --headless --path . res://tools/sim_test.tscn               # headless multi-day simulation
```

**Tests that touch autoloads MUST run as a scene, not via `--script`.** In `--script` mode Godot does
not register autoloads, so `Palette` / `GameConfig` / `AudioBus` resolve as unknown identifiers and
whole factories fail to compile *silently* — loops just skip and the run still reports "0 failures".
`validate.gd` and `data_audit.gd` are safe as `--script` only because they touch no autoload.

Note also that `ResourceLoader.load()` returns a non-null GDScript even when the file has a parse
error; `validate.gd` calls `script.reload()` because that is the only call that actually reports it.

`data_audit.gd` still checks the obsolete GDD, so a green run says nothing about v3.1 compliance; it has
to be re-targeted during migration. v3.1 §107 and §133 also require a headless harness with fixed test
IDs and `res://tools/release_validator.gd` — neither exists yet.

No linter or CI is configured. Export presets (`export_presets.cfg`) do not exist yet.

## Engine lock (v3.1 §96, §128)

Godot 4.7-stable Standard, GDScript only, Compatibility renderer; no C#, GDExtension or third-party addons, and no APIs newer than 4.7. The installed binary is 4.7.2-stable. `project.godot` already uses `gl_compatibility` with the 1280×720 `canvas_items`/`expand` stretch setup; Android landscape orientation is not configured yet.

## Non-negotiable architectural constraint: 100% procedural assets

Per v3.1 §4, §12.2 and §111, **every visual in the game is generated in code**. No `.png`, `.jpg`, `.gltf`, `.fbx`, or `.obj` may be added to the project. Do not suggest importing art, downloading assets, or using placeholder sprites — generate geometry and UI instead. This is what keeps the web bundle under the 30–40 MB target and the VRAM footprint viable on entry-level Android. Audio must be original and reproducible from scripts in the repository (§111.1; today it is synthesized at runtime in `scripts/audio/synth.gd`), and fonts are Godot's built-in default (§111.2).

Visual generation is split into three factory layers (§12.3):

- **`ProceduralMeshFactory`** — assembles 3D objects from `BoxMesh`/`CylinderMesh`/`SphereMesh`/`TorusMesh` + `SurfaceTool`. Equipment, bread meshes, and chibi characters are all *parameterized by tier*, so the same generator emits a Tier 1 wooden oven and a Tier 5 conveyor oven. Bread material carries a baking-shade parameter (raw → golden → burnt). Budget 500–2000 tris per assembled object; `StandardMaterial3D` with solid colors and vertex coloring only.
- **`ProceduralAnimationSystem`** — no skeletal rigs. Locomotion is trigonometric (`sin(time * speed)` for limb swing and head nod); reactions and UI feedback use `Tween` squash & stretch.
- **`ProceduralUIFactory`** — all UI from `StyleBoxFlat` (16–24 px corner radius) plus icons drawn in `CanvasItem._draw()` (`draw_circle`, `draw_arc`, `draw_line`, `draw_colored_polygon`). Particles are `CPUParticles2D`/`CPUParticles3D` built in script.

## Core loop (v3.1 §2, §15)

The game is a **daily cycle state machine**; 1 in-game hour = 180 real seconds at 1× (§15.2).

1. **Prep 05:00–08:00** — the player drives a **player character** (male or female, cosmetic only, §31.3) who physically walks the kitchen. Production is one tap per station: Storage (opens the Recipe Book) → Mixer → Oven → Display, where a slot picker places the bread (§2, §16, §18). Finished equipment holds its contents until picked up, the character carries one item at a time, and only the character's legs queue while mixers and ovens keep working. The "!" marker stays on the finished station until its content is picked up (tap it again), and only then moves to the next station (§2, §12.3, §18.6). In current code this lives in `PlayerTaskSystem` (`scripts/sim/player_task.gd`, e.g. `STATION_STORAGE`); see ARCHITECTURE.md §7.0.1.
2. **Sell 08:00–18:00** — the store opens automatically at 08:00. Walk-in customers take bread from the display and then queue at a cashier; RotiFood delivery orders run in parallel (§20–§22). Baking continues, and unattended ovens burn (§62).
3. **Close 18:00** — deterministic shutdown (§104) → Daily Summary (§11, §46) → after-hours management → night transition to 05:00.

Without an on-duty Cashier Assistant the player character must stand at the counter for the walk-in queue to move (§2, §21.4), so early game forces a choice between baking and serving. In current code, `CustomerSim`'s manual lane only advances while `PlayerTaskSystem.manning_lane()` points at it, and player-started jobs carry `"manual": true` and wait for a tap at each stage boundary while hired bakers auto-produce.

Cross-cutting systems, all specified in v3.1: utility cost from equipment active time (§86); staff automation with a fixed roster and wage liability fixed at 05:00 (§3.1–3.5, §87); two independent ratings (§9, §25); weather and holiday modifiers (§10, §26); market purchases with 3-hour daytime courier delivery from Day 4 (§5.2, §24A); freshness and shelf life (§19.7, §61.3).

**There is no Game Over.** Running out of money and usable ingredients triggers the Pak Lurah bailout (§3.0, §49) rather than a fail state — build economy code around recovery, not termination.

## Tier is the central progression variable

Location tier (1–5, §6, §57) gates mixer/oven/display/cashier slot counts, staff caps and queue capacity; upgrading costs only KR (§64). There is no recipe unlocking: a recipe can be made whenever its ingredients and minimum equipment are available (§61.1). Equipment tiers (§5.1, §60, §86) and fixed ingredient prices (§5.2 — deliberately no market fluctuation) are separate tables. Implement all of this as data catalogs validated at boot (§101, §134) rather than scattered constants, since the mesh factories, UI and economy all read the same tier values.

## Input, save and platform constraints

- Every gameplay action must be reachable with **one tap or one left-click**; keyboard shortcuts are optional extras. Touch targets at least 48×48 logical px, with safe-area margins (§7, §12.4, §29, §100, §130.4).
- Saves are versioned JSON with migrations, atomic temp-file writes and one backup generation (§34, §77, §106); `user://` maps to IndexedDB on web. v3.1 requires three independent profiles at `user://saves/profile_N.json` plus a backup, with settings in `user://settings.json` (§89.3, §106). Current code still uses a single `user://savegame.json`.
- The web build needs a "tap to start" screen so browser autoplay policy doesn't block audio (§12.1, §33.4). Losing app or tab focus pauses the simulation with no offline progression (§90, §113).
- v1.0 is fully offline: no ads, IAP, login, backend or telemetry (§12.7, §112).
