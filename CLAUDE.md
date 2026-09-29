# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Spec of record

Godot 4.7 project for **Roti Lezat Tycoon**, a bakery management tycoon game targeting Web (itch.io, HTML5) and Android from one codebase.

**The only authoritative specification is [docs/gdd-roti-lezaat-tycoon-ai-ready-v3.1-final.md](docs/gdd-roti-lezaat-tycoon-ai-ready-v3.1-final.md) (GDD v3.1 FINAL).** The older [docs/gdd-roti-lezaat-tycoon.md](docs/gdd-roti-lezaat-tycoon.md) is obsolete (maintainer decision, 2026-09-24): do not read it for requirements or cite it. On 2026-09-25, at the maintainer's request, its recipe data was copied into v3.1 (§61.5); anything else missing from v3.1 needs the maintainer's decision, not the old GDD. On 2026-09-28 the maintainer lowered the §130.2 eye line from ~65% to ~45% of head height for a more chibi look. On 2026-09-29 the maintainer made three timing changes. The clock now runs at 1 in-game hour = 2 real minutes (§15.2). The §5.1 equipment reference times were replaced. Every §61.5 recipe duration was halved, so the reference table sets only the speed-up between tiers (§18.5). The same day, the maintainer moved the RotiFood last-order time to 16:55 (§22.9) and decided that dough in hand replaces a burnt tray (§16.5, §62). Later that day the maintainer set the target game length: a typical player at about 2× owns every location, all Tier 5 equipment and all shop decor in about 6 hours (roughly 26 in-game days), after which they simply enjoy being rich. Four rules were approved for it. The Market sells equipment only up to the store tier (§5.1.2). Prices stay at the reference price on Days 1–3 (§63.2). RotiFood picks menu recipes by price acceptance (§22.9). Bakers only start batches that finish by 17:30, so the kitchen is empty at closing (§23.3).

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

The Day 1–3 manifest was copied from the pre-v3.1 `scripts/data/opening_db.gd` (since removed) with one change: the Day 1 16:30 office worker became a school child, because §2 bars office workers on Day 1.

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

On 2026-09-25/26 the code was rebuilt against v3.1 (~29k lines of GDScript, main scene `scenes/main.tscn` → `GameRoot`, seven autoloads per §35.2). The old `scripts/` tree and its tools were removed. The procedural mesh, UI and audio generators were kept and moved to `procedural/` and `audio/`. Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for ownership and data flow, [docs/SAVE_SCHEMA.md](docs/SAVE_SCHEMA.md) for the save format, and [docs/GDD_COMPLIANCE.md](docs/GDD_COMPLIANCE.md) for what is tested, merely implemented, not verified, or open. Where any doc disagrees with v3.1, v3.1 wins.

Layout: `autoload/` (services, no gameplay state), `core/` (helpers, `TimeManager`, `RNGManager`, `SimManager` base), `data/catalog/*.json` (the runtime authority for all content and tuning, validated at boot by `DataRegistry`), `data/definitions/`, `gameplay/` (`SimulationRoot` plus one manager per domain), `procedural/`, `audio/`, `ui/`, `tests/`, `tools/`.

Deliberate deviation: the logging autoload is `GameLogger`, not `Logger`, because Godot 4.5+ ships a built-in `Logger` class.

The GDD narrative is Indonesian, but **all player-facing text must be English** (§43, §127); proper nouns such as Budi, Pak Lurah and RotiFood stay as they are. Code calls `Tx.t(key, params)`, and keys live in `data/catalog/strings_en.json`. Currency is **Koin Roti (KR)**.

## Commands

**Godot 4.7.2 lives at `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`** (note: the
`.exe` in the path is a *directory*). Use the `_console.exe` sibling when you need stdout/stderr — the
plain binary detaches from the console and you will see no output. It is **not** on `PATH`.

```bash
G='D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
"$G" --headless --path . --import          # reimport; REQUIRED after adding a class_name
"$G" --path .                              # open in editor
"$G" --path . res://scenes/main.tscn       # run the game
"$G" --headless --path . --export-release "Web" build/web/index.html
"$G" --headless --path . --export-debug "Android Debug APK" build/android/roti-lezat-tycoon-debug.apk
"$G" --headless --path . --export-release "Android Release AAB" build/android/roti-lezat-tycoon.aab
```

The official 4.7.2 export templates were installed on 2026-09-29 (`%APPDATA%\Godot\export_templates\4.7.2.stable`, SHA-512 checked against the release), so the Web export works here. It writes `build/web/` (about 40 MB, almost all engine `.wasm`; the game `.pck` is under 1 MB), and `/build/` is git-ignored (a local `build/.gdignore` stops the editor from importing the exported icons). Serve it with `python -m http.server 8000` from `build/web`, because `index.html` does not run from `file://`. There is no Android SDK, so Android exports still fail.

`.github/workflows/deploy-web.yml` publishes the Web build to GitHub Pages at https://ariefnugraha3.github.io/roti-lezat-tycoon/. It downloads the official Godot 4.7.2 editor and templates on Linux, verifies them against `SHA512-SUMS.txt`, imports, exports, and deploys. It runs only on a manual *Run workflow*, and the repository's Pages source must be set to *GitHub Actions*.

### Tests (run after any change)

```bash
"$G" --headless --path . res://tests/test_runner.tscn -- --skip-long         # the §107 suites minus the soaks (~3 min)
"$G" --headless --path . res://tests/test_runner.tscn -- --only=TEST_SAVE    # by ID prefix (--id=X for an exact ID)
"$G" --headless --path . res://tests/test_runner.tscn                        # everything, including soaks (hours)
"$G" --headless --path . res://tools/compile_check.tscn                      # every script compiles
"$G" --headless --path . res://tools/release_validator.tscn -- --quick       # §133 gate without tests and exports
```

- **Run tests and tools as scenes, never `--script`.** In `--script` mode Godot does not register autoloads, so scripts that use `DataRegistry`, `EventBus` and the rest fail to compile *silently*.
- The runner installs a custom `Logger`. Any engine or script error during a test fails it, unless the test sets `"expect_errors": true`. A GDScript runtime error does not throw, so without this a crashed test would look green.
- `SimBot` (`tests/sim_bot.gd`) plays through the same APIs as the UI.
- Save comparisons use `logical_state()`, because loading snaps actors to canonical cells (§77.2, §81 no. 16).
- The golden fixture changes whenever simulation or bot behaviour changes. Regenerate it on purpose with `-- --only=TEST_SAVE_001 --update-fixtures` and review the diff.
- JSON numbers load as floats. `Array.has(3)` is false for `[3.0]`, so compare catalog arrays with `int()`. This exact bug once disabled the 2×/3× speed buttons.
- Never call `sort()` on arrays of StringName IDs in simulation code; use `Ids.sort` (`core/ids.gd`). `Array.sort()` orders StringName by internal address, so the same seed played out differently between sessions (`ACC_116_ID_ORDER`).
- Never call `AudioServer.add_bus()`; add buses with `AudioServer.set_bus_count()` (`AudioManager._ensure_buses`). On Web, Godot 4.7.2 plays audio in Sample mode, and there `add_bus()` inserts the JavaScript bus in front of Master. `set_bus_send` then routes Master back into the other buses, Web Audio silences the loop, and the whole game is mute in browsers while desktop sounds fine (`ACC_33_AUDIO_BUSES`).

No linter or CI is configured.

## Engine lock (v3.1 §96, §128)

Godot 4.7-stable Standard, GDScript only, Compatibility renderer; no C#, GDExtension or third-party addons, and no APIs newer than 4.7. The installed binary is 4.7.2-stable. `project.godot` uses `gl_compatibility` (desktop and mobile), the 1280×720 `canvas_items`/`expand` stretch setup, and landscape orientation. `export_presets.cfg` holds the Web (single-threaded), Android debug APK and Android release AAB presets, with no signing secrets.

## Non-negotiable architectural constraint: 100% procedural assets

Per v3.1 §4, §12.2 and §111, **every visual in the game is generated in code**. No `.png`, `.jpg`, `.gltf`, `.fbx`, or `.obj` may be added to the project. Do not suggest importing art, downloading assets, or using placeholder sprites — generate geometry and UI instead. This is what keeps the web bundle under the 30–40 MB target and the VRAM footprint viable on entry-level Android. Audio must be original and reproducible from scripts in the repository (§111.1; it is synthesized at runtime in `audio/audio_generator.gd`), and fonts are Godot's built-in default (§111.2). `icon.svg` is generated by `tools/generate_icon.gd`, and the release validator fails if it differs.

Visual generation is split into three factory layers (§12.3):

- **`ProceduralMeshFactory`** — assembles 3D objects from `BoxMesh`/`CylinderMesh`/`SphereMesh`/`TorusMesh` + `SurfaceTool`. Equipment, bread meshes, and chibi characters are all *parameterized by tier*, so the same generator emits a Tier 1 wooden oven and a Tier 5 conveyor oven. Bread material carries a baking-shade parameter (raw → golden → burnt). Budget 500–2000 tris per assembled object; `StandardMaterial3D` with solid colors and vertex coloring only.
- **`ProceduralAnimationSystem`** — no skeletal rigs. Locomotion is trigonometric (`sin(time * speed)` for limb swing and head nod); reactions and UI feedback use `Tween` squash & stretch.
- **`ProceduralUIFactory`** — all UI from `StyleBoxFlat` (16–24 px corner radius) plus icons drawn in `CanvasItem._draw()` (`draw_circle`, `draw_arc`, `draw_line`, `draw_colored_polygon`). Particles are `CPUParticles2D`/`CPUParticles3D` built in script.

## Core loop (v3.1 §2, §15)

The game is a **daily cycle state machine**; 1 in-game hour = 120 real seconds at 1× (§15.2).

1. **Prep 05:00–08:00** — the player drives a **player character** (male or female, cosmetic only, §31.3) who physically walks the kitchen. Production is one tap per station: Storage (opens the Recipe Book) → Mixer → Oven → Display, where a slot picker places the bread (§2, §16, §18). Finished equipment holds its contents until picked up, the character carries one item at a time, and only the character's legs queue while mixers and ovens keep working. The "!" marker stays on the finished station until its content is picked up (tap it again), and only then moves to the next station (§2, §12.3, §18.6). In code this is `PlayerTaskManager` (`gameplay/actors/player_task_manager.gd`) with `ProductionManager`.
2. **Sell 08:00–18:00** — the store opens automatically at 08:00. Walk-in customers take bread from the display and then queue at a cashier; RotiFood delivery orders run in parallel (§20–§22). Baking continues, and unattended ovens burn (§62).
3. **Close 18:00** — deterministic shutdown (§104) → Daily Summary (§11, §46) → after-hours management → night transition to 05:00.

A **Holding Table** in the kitchen (§5.1.3, §19.7.6) lets the player park carried dough or trays when ovens or shelves are full. It is player-only, has no item limit, and is not a shop shelf. Its contents spoil: bread at the base rate, dough twice as fast, and 11 hours overnight. In code these are production jobs in stages `DOUGH_ON_TABLE`/`TRAY_ON_TABLE`; saves are schema 4.

Without an on-duty Cashier Assistant the player character must stand at the counter for the walk-in queue to move (§2, §21.4), so early game forces a choice between baking and serving. In code, the manual lane only advances while `PlayerTaskManager.manning_lane` points at it (`CashierManager`), and player-owned jobs wait for a tap at each stage boundary while hired bakers auto-produce (`StaffManager`).

Cross-cutting systems, all specified in v3.1: utility cost from equipment active time (§86); staff automation with a fixed roster and wage liability fixed at 05:00 (§3.1–3.5, §87); two independent ratings (§9, §25); weather and holiday modifiers (§10, §26); market purchases with 3-hour daytime courier delivery from Day 4 (§5.2, §24A); freshness and shelf life (§19.7, §61.3).

**There is no Game Over.** Running out of money and usable ingredients triggers the Pak Lurah bailout (§3.0, §49) rather than a fail state — build economy code around recovery, not termination.

## Tier is the central progression variable

Location tier (1–5, §6, §57) gates mixer/oven/display/cashier slot counts, staff caps, queue capacity and the highest equipment tier the Market sells (§5.1.2); upgrading costs only KR (§64). There is no recipe unlocking: a recipe can be made whenever its ingredients and minimum equipment are available (§61.1). Equipment tiers (§5.1, §60, §86) and fixed ingredient prices (§5.2 — deliberately no market fluctuation) are separate tables. Implement all of this as data catalogs validated at boot (§101, §134) rather than scattered constants, since the mesh factories, UI and economy all read the same tier values.

## Input, save and platform constraints

- Every gameplay action must be reachable with **one tap or one left-click**; keyboard shortcuts are optional extras. Touch targets at least 48×48 logical px, with safe-area margins (§7, §12.4, §29, §100, §130.4).
- Saves are versioned JSON with migrations, atomic temp-file writes and one backup generation (§34, §77, §106); `user://` maps to IndexedDB on web. Three independent profiles live at `user://saves/profile_N.json` plus a backup, with settings in `user://settings.json` (§89.3, §106), all implemented in `SaveManager`.
- The web build needs a "tap to start" screen so browser autoplay policy doesn't block audio (§12.1, §33.4). Losing app or tab focus pauses the simulation with no offline progression (§90, §113).
- v1.0 is fully offline: no ads, IAP, login, backend or telemetry (§12.7, §112).
