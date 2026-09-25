# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.7 project for **Roti Lezat Tycoon**. The main scene is `scenes/main.tscn`, configured in `project.godot`. Runtime code lives in `scripts/`, organized by domain: `core/` for autoload state and config, `sim/` for game simulation, `ui/` for screens and routing, `data/` for database tables, `procgen/` for procedural visuals, `world/` for actors and shop scene behavior, and `audio/` for generated sound. Validation and headless test scenes live in `tools/`. Design and architecture references are in `docs/`. The only authoritative design spec is `docs/gdd-roti-lezaat-tycoon-ai-ready-v3.1-final.md` (GDD v3.1 FINAL); `docs/gdd-roti-lezaat-tycoon.md` is obsolete and must not be used. The current code predates v3.1 and has not been migrated to it yet.

## Build, Test, and Development Commands

Godot is expected at `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.

```powershell
$G="D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
& $G --headless --path . --import
& $G --path .
& $G --headless --path . res://scenes/main.tscn
& $G --headless --path . --script res://tools/validate.gd
& $G --headless --path . --script res://tools/data_audit.gd
& $G --headless --path . res://tools/procgen_test.tscn
& $G --headless --path . res://tools/sim_test.tscn
```

Run all four validation/test commands after code changes. Use scene-based tests for anything that needs autoloads.

## Coding Style & Naming Conventions

Use GDScript with tabs for indentation, explicit types where practical, and `snake_case` for files, variables, and functions. Constants use `UPPER_SNAKE_CASE`; autoload singletons use `PascalCase` names such as `GameState` and `EventBus`. Keep gameplay IDs lowercase and stable. Existing IDs such as `tepung_terigu` predate GDD v3.1, whose canonical English IDs are listed in its §78; coordinate renames with the maintainer, because the code has not been migrated yet. Prefer data-driven tables in `scripts/data/` over scattered constants.

## Testing Guidelines

`tools/validate.gd` checks script parsing and rejects external asset types. `tools/data_audit.gd` verifies data against the obsolete GDD's tables and still needs re-targeting to v3.1. `procgen_test.tscn` exercises factories, and `sim_test.tscn` runs a headless multi-day simulation. Name new test tools descriptively under `tools/`, and choose `.tscn` tests when autoload access is required.

## Commit & Pull Request Guidelines

Recent commits are short imperative summaries, such as `init project` and `update gdd`. Keep commits focused and concise. Pull requests should describe the changed gameplay/system behavior, list the test commands run, link any relevant issue or GDD section, and include screenshots or clips for visible UI/world changes.

## Asset & Configuration Rules

The project is intentionally 100% procedural. Do not add `.png`, `.jpg`, `.gltf`, `.fbx`, audio files, fonts, or other external assets unless the project policy changes. Saves must remain JSON-safe; avoid storing engine-only values like `Color` or `Vector2i` in `GameState`.
