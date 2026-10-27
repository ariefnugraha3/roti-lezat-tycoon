# Save Schema (implemented)

This document describes the save format that the code writes on the idle branch. The
requirements are in the idle GDD (`docs/gdd-roti-lezat-idle-v1.md`) §15.3, which keeps
the atomic-write and three-profile mechanics of GDD v3.1 §34, §77 and §106. Where this
document and the GDD disagree, the GDD wins and the code must be fixed.

- **Game mode / schema:** `"game_mode": "idle"`, `"schema_version": 1`
  (`SimulationRoot.GAME_MODE`, `SimulationRoot.SCHEMA_VERSION`). The idle schema starts
  at 1; there are no migrators yet.
- **Writer / reader:** `autoload/save_manager.gd` (`SaveManager`).
- **Snapshot / restore:** `gameplay/simulation_root.gd` (`capture_save()` / `load_from_save()`).
- **Golden fixture:** `tests/fixtures/golden_idle_v1.json` (a SimBot scenario, `TEST_SAVE_001`).
- **Classic fixture:** `tests/fixtures/classic_v3_day4.json` (a v3.1 tycoon save, used to
  check that classic saves are recognised and refused).

## Files

| Path | Content |
|---|---|
| `user://saves/profile_N.json` | Main save for profile N (N = 1, 2, 3). |
| `user://saves/profile_N.backup.json` | The previous valid generation of the main save. |
| `user://saves/profile_N.tmp` | Exists only while an atomic write is in progress. |
| `user://settings.json` | Settings and accessibility, shared by all profiles (not a career save). |

On Web, `user://` is backed by IndexedDB; on Android it is app-private storage.

### Atomic write (`SaveManager.write_profile`)

1. Serialize with `JSON.stringify(data, "\t", true, true)`. Full float precision keeps
   positions and clocks as close as JSON allows (Godot can print the last digit of a
   tiny value such as `-9.7e-17` differently after a reload, so comparisons of saves
   go through `TestSuite.diff_state`, never raw text).
2. Refuse the write if any value is `NaN`. The previous files stay untouched.
3. Write `profile_N.tmp`, then re-read and validate it (migrate + schema check).
4. If the current main file is valid, it becomes `profile_N.backup.json`. A corrupt
   main file is deleted instead, so it never overwrites a good backup.
5. Rename `.tmp` to the main path.

### Read (`SaveManager.read_profile`)

The main file is tried first, then the backup. A stale `.tmp` is always ignored.
Every read goes through `migrate()` and `validate_save()`. The result reports
`used_backup` so the UI can tell the player. Any save whose `game_mode` is not
`"idle"` (a v3.1 tycoon save) is reported as `classic` (`SaveManager.is_classic`): the Main Menu shows it as "Classic save (not
supported)" with a Delete button, and it is never loaded or migrated (idle GDD §15.3).

### Autosave and the offline reference

`SaveManager.request_autosave(reason, critical)` debounces non-critical saves
(`save.autosave_debounce_seconds`) and writes only at a stable checkpoint, between
ticks. `GameRoot` also requests one every `clock.autosave_interval_seconds` of play.
Critical saves happen on focus loss, location moves and both sides of a franchise.

`SaveManager.save_now()` calls `SimulationRoot.note_active()` first, which stamps
`offline.last_active_unix` and `offline.rate_kr_per_s` (idle GDD §9.2). While the app
is in the background `OfflineManager` is frozen, so a save there keeps the moment the
player left. Saves made by tests through `capture_save()` never read the wall clock,
which keeps fixtures deterministic.

## Root shape (idle schema 1)

`REQUIRED_KEYS` in `save_manager.gd` lists the keys that validation checks.

| Key | Type | Owner / notes |
|---|---|---|
| `game_mode` | string | Always `"idle"`. |
| `schema_version` | int | Always the current version when written. |
| `game_version` | string | `SaveManager.GAME_VERSION`. |
| `catalog_versions` | object | `{catalog_schema_version, content_version}` from the catalogs. |
| `created_at`, `last_played_at` | string | ISO-8601 UTC. |
| `last_played_unix` | float | Sub-second timestamp that orders the Continue button. |
| `profile_id` | string | Must match the file's profile. A mismatched profile is rejected. |
| `bakery_name` | string | Player-chosen name; kept across franchises. |
| `player` | object | `PlayerTaskManager.capture()`: `appearance`, `actor`, `focus_iid`, `focus_cashier`, `focus_until` (the owner's tap focus, idle GDD §5.1). |
| `day`, `time_seconds` | int, float | Mirrors of `clock` for headers. |
| `clock` | object | `TimeManager.capture()`: `day`, `time_seconds` (seconds since 00:00), `sim_seconds`. The clock runs 24 hours a day (idle GDD §3.1). |
| `location_id` | string | Canonical location ID. Unknown IDs fail validation. |
| `economy` | object | `balance_kr` (a number, or `"INF"` after the overflow guard), `ledger_recent` (last 200 entries), `historical_totals` (per-category sums of older entries), `ledger_sequence`, `overflowed`. |
| `upgrades` | object | `UpgradeManager.capture()`: `stations` (iid → level), `counter` (level), `recipes` (recipe ID → level; **the keys are the unlocked recipes**, idle GDD §15.3 `recipes_unlocked`), `staff` (staff ID → level), `global` (upgrade ID → level). |
| `display_inventory` | object | Display iid → `{tier, slots: [{assign, recipe, stacks}]}`. `assign` is the recipe the player set for that slot, or `""` for Auto (idle GDD §15.3 `slot_recipes`). `BreadStack`: `recipe_id`, `quantity`, `slot_id`, `source_job_id`, `produced_at_game_time`. There is no freshness, age or quality any more. |
| `production_jobs` | object | `jobs` (stage, `stage_duration`/`stage_elapsed`, batch, mixer/oven iid, target slot, `claimed_by`, `carrier_id`, `table_seq`, …), `next_job_id`, `next_table_seq`. No burn stage exists. |
| `equipment_states` | object | `items: [{iid, def_id, floor_id, grid_x, grid_y, rotation_quarters, placed, job_id}]`, `next_iid`. `def_id` carries the evolved model tier. |
| `customers` | object | Active customers (state, patience, held lots, targets, `actor`) and `next_num`/`next_window_num`. |
| `queues` | object | Per lane: reservations, line and service occupant; `highest_occupancy`. |
| `cashier` | object | In-progress transactions per lane. |
| `demand` | object | Next walk-in, RotiFood and window-shopper times and the pending pool. |
| `rotifood_orders` | object | Orders (items, prices, packed lots, driver state) and `next_order_id`. Orders are accepted and packed automatically. |
| `staff` | object | `contracts` (`employed`, `hired_day`) and actors. No wages, duty or tiers. |
| `reputation` | object | `reputation` (stars, idle GDD §6.3). |
| `weather` | object | `today`, `tomorrow`, `physical_mult`, `delivery_mult`. |
| `franchise` | object | `PrestigeManager.capture()`: `stars`, `run_index`, `perks` (unlocked perk IDs, derived from stars), `recipes_ever`. |
| `offline` | object | `OfflineManager.capture()`: `last_active_unix` (0 = unknown), `rate_kr_per_s` (model KR/s without boosts), `pending` (`{amount, seconds, away}` waiting for Collect, or `{}`). |
| `boosts` | object | `BoostManager.capture()`: `income_mult`, `income_left` (real seconds), `promo_id`, `promo_left`, `cooldowns` (promotion → real seconds), `last_gift_date` (device date of the last coffee). |
| `tutorial` | object | Onboarding steps already shown (`done`), `skipped`, and the current `prompt` (`key`, `target`, `style`). |
| `decorations` | object | Owned items (uid, deco_id, floor, cell, slot, placed, `rot`), `equipped` cosmetics, `next_uid`, `bonus_active` (decorations whose bonus is on in this run, idle GDD §8.8). |
| `flags` | object | `economy_overflowed`. |
| `achievements` | object | `unlocked`: achievement ID → day. Kept across franchises. |
| `stats` | object | `stats` (every key of `StatisticsManager.STAT_KEYS`, among them `run_earned_kr`, `alltime_earned_kr`, `offline_seconds_total`, `offline_earned_kr`, `franchise_count`), `records`, `tier_reached_day`. |
| `rng_states` | object | `master_seed`, `day_seed` and each stream's `seed` and `state`, all as **strings** because JSON cannot hold 64-bit integers exactly. |

Removed with the idle pivot (idle GDD §15.3): `inventory`, `supply_orders`, `pricing`,
`bailout`, `reports`, the Day 1–3 manifest, wage liability, utilities, the day phase,
`marketing`, `recipe_analytics`, `ratings` (replaced by `reputation`) and every
freshness or quality field of a bread stack. `ACC_IDLE_SAVE` checks both lists.

## Load reconstruction

`load_from_save()` restores every manager, then rebuilds derived state:

- Occupancy and navigation grids are rebuilt from equipment and decoration positions;
  furniture that conflicts with the layout is re-placed, and decorations that break the
  slot rules go back to the inventory.
- The Holding Table and the staff chairs are created if missing.
- Orphaned production jobs are recovered (`ProductionManager.recover_orphans`).
- Actors are snapped to canonical cells, and claims in progress restart from their
  logical target. World transforms are therefore not guaranteed to be identical after a
  load; every timer, stage, amount of money, stock unit, queue reservation, order and
  RNG state is (`TEST_SAVE_001`, `ACC_IDLE_SAVE`).

## Migrations

None yet: the idle schema is version 1. `SaveManager.migrate()` refuses a save newer
than the game and any idle save with an older version than it knows how to read. A
future migrator upgrades one version at a time and is listed here.

## Settings (`user://settings.json`)

Written by `autoload/settings_manager.gd` using the same temp-file pattern. The file
holds `settings_version` and the keys in `SettingsManager.DEFAULTS`. Out-of-range or
unknown values fall back to safe defaults. A corrupt file is replaced by the defaults
and does not stop the game from booting.

## Updating the golden fixture

The fixture is regenerated only when a gameplay or bot change is intended:

```bash
"$G" --headless --path . res://tests/test_runner.tscn -- --only=TEST_SAVE_001 --update-fixtures
```

Review the diff of `tests/fixtures/*.json` before committing it.
