# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Godot 4.7 project for **Roti Lezat Tycoon**, a bakery management tycoon game targeting Web (itch.io, HTML5) and Android from one codebase.

The repository currently contains **no scenes and no scripts** — only `project.godot`, `icon.svg`, and the design document. `project.godot` has no `run/main_scene` set. The spec of record is [docs/gdd-roti-lezaat-tycoon.md](docs/gdd-roti-lezaat-tycoon.md) (~900 lines, written in Indonesian); read the relevant section there before implementing any system, since nearly all balance numbers, tier tables, recipes, and flows are specified in it and exist nowhere else.

In-game text and the GDD are Indonesian. Currency is **Koin Roti (KR)**.

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

### Test suite (run all three after any change)

```bash
"$G" --headless --path . --script res://tools/validate.gd        # every .gd compiles + no external assets
"$G" --headless --path . --script res://tools/data_audit.gd      # ~976 asserts: data layer vs GDD tables
"$G" --headless --path . res://tools/procgen_test.tscn           # ~1041 asserts: factories actually run
"$G" --headless --path . res://tools/sim_test.tscn               # headless multi-day simulation
```

**Tests that touch autoloads MUST run as a scene, not via `--script`.** In `--script` mode Godot does
not register autoloads, so `Palette` / `GameConfig` / `AudioBus` resolve as unknown identifiers and
whole factories fail to compile *silently* — loops just skip and the run still reports "0 failures".
`validate.gd` and `data_audit.gd` are safe as `--script` only because they touch no autoload.

Note also that `ResourceLoader.load()` returns a non-null GDScript even when the file has a parse
error; `validate.gd` calls `script.reload()` because that is the only call that actually reports it.

No linter or CI is configured. Export presets (`export_presets.cfg`) do not exist yet.

## Non-negotiable architectural constraint: 100% procedural assets

Per GDD §4 and §12.2, **every visual in the game is generated in code**. No `.png`, `.jpg`, `.gltf`, `.fbx`, or `.obj` may be added to the project. Do not suggest importing art, downloading assets, or using placeholder sprites — generate geometry and UI instead. This is what keeps the web bundle under the 30–40 MB target and the VRAM footprint viable on entry-level Android.

Visual generation is split into three factory layers (GDD §12.3):

- **`ProceduralMeshFactory`** — assembles 3D objects from `BoxMesh`/`CylinderMesh`/`SphereMesh`/`TorusMesh` + `SurfaceTool`. Equipment, bread meshes, and chibi characters are all *parameterized by tier*, so the same generator emits a Tier 1 wooden oven and a Tier 5 conveyor oven. Bread material carries a baking-shade parameter (raw → golden → burnt). Budget 500–2000 tris per assembled object; `StandardMaterial3D` with solid colors and vertex coloring only.
- **`ProceduralAnimationSystem`** — no skeletal rigs. Locomotion is trigonometric (`sin(time * speed)` for limb swing and head nod); reactions and UI feedback use `Tween` squash & stretch.
- **`ProceduralUIFactory`** — all UI from `StyleBoxFlat` (16–24 px corner radius) plus icons drawn in `CanvasItem._draw()` (`draw_circle`, `draw_arc`, `draw_line`, `draw_colored_polygon`). Particles are `CPUParticles2D`/`CPUParticles3D` built in script.

## Renderer mismatch to resolve

`project.godot` currently sets `renderer/rendering_method="mobile"` with the d3d12 driver. GDD §12.2 mandates the **Compatibility renderer (`gl_compatibility`, OpenGL ES 3.0 / WebGL 2.0)** because the Mobile/Vulkan path does not export usefully to HTML5 and stutters on low-end Android. Raise this with the user before building anything rendering-dependent — the existing setting looks like an unchanged editor default, not a decision.

Stretch settings (`canvas_items` / `expand`) already match the GDD. Landscape orientation and the 1280x720 reference resolution (GDD §12.5) are not yet configured.

## Core simulation structure

The game is a **daily cycle state machine** (GDD §2, §11.6):

1. **Prep 04:00–08:00** — the player drives a **player character** (Pria/Wanita, chosen on "Main Baru") who physically walks the kitchen. The chain is one tap per station: tap the **Storage** (fridge + cabinet, `PlayerTaskSystem.STATION_STORAGE`) → character walks there, doors swing open, recipe list appears → pick a recipe → a **"!" bubble appears over the NEXT station**, never the one that just finished → tap it → character walks over (collecting dough/tray from the previous station on the way) and starts the machine → a countdown-free progress bar floats above it. After the oven the bubble lands on the **display rack**, and tapping it opens a slot picker so the player chooses exactly which slot the bread goes in. Multiple orders run in parallel — only the character's legs queue; mixers and ovens keep ticking on their own. See `docs/ARCHITECTURE.md` §7.0.1.
2. **Sell 08:00–18:00** — the store opens automatically at 08:00 whether or not baking finished. Two demand streams run concurrently: walk-in customers who pick from the display and queue at a cashier, and **online delivery orders (ojol)** arriving on the cashier tablet for driver pickup. Baking continues during this phase, and unattended ovens burn.
3. **Close 18:00** — Daily Summary screen → optionally Market (ingredients, equipment, recipes, store upgrade) / staff management / marketing campaign → night transition back to 04:00.

Cross-cutting systems that all touch this loop: real-time utility cost accrued per second of equipment uptime and billed at Daily Summary; staff automation (cashier and baker assistants with per-hire work speed and daily salary); two independent reputation tracks (physical store rating and "RotiFood Stars" delivery rating); weather and season modifiers (rain spikes delivery volume, GDD §10).

Tapping the **cashier counter** posts the player character at the till; while standing there, *they* serve the walk-in queue. With no Asisten Kasir hired, `CustomerSim`'s manual lane only advances while `PlayerTaskSystem.manning_lane()` points at it (GDD §3.0.C Mode Solo) — walk away and the queue stalls, so early game forces a real choice between baking and serving.

Manual production and hired staff coexist: jobs the player starts carry `"manual": true` and stop at every stage boundary waiting for a tap, while hired Asisten Dapur keep auto-producing exactly as before (GDD §3.2) — that is what "automation" buys.

**There is no Game Over.** Hitting 0 KR with no usable ingredients triggers the Pak Lurah bailout event (GDD §3.0) rather than a fail state — build economy code around recovery, not termination.

## Tier is the central progression variable

Location tier (1–5, GDD §6) is a single number that gates nearly everything else: mixer/oven/display/cashier slot counts, max bakers and cashiers, customer queue capacity, and which recipe set is unlockable (GDD §5.3.1–5.3.5). Equipment tiers (GDD §5.1) and ingredient prices (GDD §5.2, fixed — deliberately no market fluctuation) are separate tables. Implement these as data-driven tables transcribed from the GDD rather than scattered constants, since the mesh factories, UI, and economy all read the same tier values.

## Input and save constraints

- Every gameplay action must be reachable with **one tap or one left-click**. No keyboard control may be required; keyboard shortcuts are web-only quality-of-life extras. Interactive hitboxes minimum 48x48 dp, with safe-area margins for notched phones (GDD §7, §12.4).
- Saves are JSON at `user://savegame.json` — IndexedDB on web, app-private storage on Android. The format must tolerate loading older saves after updates (GDD §12.6).
- Web export needs a "tap to start" splash so browser audio autoplay policy doesn't block the soundscape (GDD §12.1).
