# Save Schema (implemented)

This document describes the save format that the code actually writes today. The
canonical requirements are in GDD v3.1 §34, §77 and §106. Where this document and
the GDD disagree, the GDD wins and the code must be fixed.

- **Current schema version:** `5` (`data/catalog/balance.json` → `save.schema_version`).
- **Writer / reader:** `autoload/save_manager.gd` (`SaveManager`).
- **Snapshot / restore:** `gameplay/simulation_root.gd` (`capture_save()` / `load_from_save()`).
- **Golden fixture:** `tests/fixtures/golden_v3_day4.json` (Day 4, 10:00, mid-service).
- **Legacy fixture:** `tests/fixtures/legacy_v1_day2.json` (schema v1, used to test migration).

## Files

| Path | Content |
|---|---|
| `user://saves/profile_N.json` | Main save for profile N (N = 1, 2, 3). |
| `user://saves/profile_N.backup.json` | The previous valid generation of the main save. |
| `user://saves/profile_N.tmp` | Exists only while an atomic write is in progress. |
| `user://settings.json` | Settings and accessibility, shared by all profiles (not a career save). |

On Web, `user://` is backed by IndexedDB; on Android it is app-private storage.

### Atomic write (`SaveManager.write_profile`)

1. Serialize with `JSON.stringify(data, "\t", true, true)`. Full float precision is
   required so positions and clocks come back exactly.
2. Refuse the write if any value is `NaN`. The previous files stay untouched.
3. Write `profile_N.tmp`, then re-read and validate it (migrate + schema check).
4. If the current main file is valid, it becomes `profile_N.backup.json`. A corrupt
   main file is deleted instead, so it never overwrites a good backup.
5. Rename `.tmp` to the main path.

### Read (`SaveManager.read_profile`)

The main file is tried first, then the backup. A stale `.tmp` is always ignored.
Every read goes through `migrate()` and `validate_save()`. The result reports
`used_backup` so the UI can tell the player.

### Autosave

`SaveManager.request_autosave(reason, critical)` debounces non-critical saves
(`save.autosave_debounce_seconds`). It writes only at a stable checkpoint, meaning
between simulation ticks. Critical saves happen on day settlement, the new day,
location upgrade and focus loss.

## Root shape (schema 6)

Every key below is present in every save. `REQUIRED_KEYS` in `save_manager.gd` lists
the ones that validation checks.

| Key | Type | Owner / notes |
|---|---|---|
| `schema_version` | int | Always the current version when written. |
| `game_version` | string | `"1.0.0"`. |
| `catalog_versions` | object | `{catalog_schema_version, content_version}` from the catalogs (GDD 134.1). |
| `created_at`, `last_played_at` | string | ISO-8601 UTC. |
| `last_played_unix` | float | Sub-second timestamp that orders the Continue button. |
| `profile_id` | string | Must match the file's profile. A mismatched profile is rejected. |
| `bakery_name` | string | Player-chosen name. |
| `player` | object | `PlayerTaskManager.capture()`: `appearance`, `actor`, `commands`, `current`, `manning_lane`, `next_command_id`. Commands store logical targets (equipment iid, lane id), never world transforms (GDD 16.4). |
| `day`, `time_seconds`, `phase` | int, float, string | Mirrors of `clock` for headers. |
| `clock` | object | `TimeManager.capture()`: `day`, `time_seconds` (seconds since 00:00), `phase`, `speed`, `sim_seconds`. |
| `location_id` | string | Canonical location ID (GDD 78). Unknown IDs fail validation. |
| `active_floor_id` | string | The player's floor. |
| `economy` | object | `balance_kr` (a number, or the string `"INF"` after the overflow guard, GDD 73), `ledger_recent` (last 200 entries), `historical_totals` (per-category sums of rotated-out entries), `ledger_sequence`, `today`, `cogs_consumed_today`, `waste_cost_today`, `written_off_today`, `lifetime_earned`, `lifetime_spent`, `overflowed`. |
| `pricing` | object | Price overrides per recipe. A recipe at its default price has no entry. |
| `inventory` | object | Ingredient ID to on-hand units. |
| `display_inventory` | object | Display iid → `{tier, slots: [{recipe, stacks: [BreadStack]}]}`. `BreadStack` follows GDD 19.1: `recipe_id`, `quantity`, `slot_id`, `source_job_id`, `produced_at_game_time`, `bake_quality`, `age_ingame_hours`, `base_expiry_hours`, `freshness_state`, `display_tier`. |
| `production_jobs` | object | `jobs` (stage, timers, reserved ingredients, owner, mixer/oven iid, `burn_elapsed`, `table_age_hours`, `table_seq`, …; `owner_actor_id` is `player` or `kitchen`), `next_job_id`, `next_table_seq`, `completed_today`, `batches_burnt_today`. Dough and trays parked on the Holding Table are jobs in stage `DOUGH_ON_TABLE`/`TRAY_ON_TABLE` (GDD 5.1.3). |
| `equipment_states` | object | `items: [{iid, def_id, floor_id, grid_x, grid_y, rotation_quarters, placed, job_id}]`, `next_iid`, `utility_today`. Positions are grid coordinates, never world transforms (GDD 55 appendix no. 9). |
| `customers` | object | Active customers (state, patience, held lots, targets, `actor`) plus daily counters. Window shoppers (GDD 20.12) carry `window_shopper: true`, `look_cell`, `look_display` and `looks_left`; `next_window_num` and `window_shoppers_today` count them. Older saves without these fields load with no window shoppers. |
| `queues` | object | Per lane: `reservations`, `line`, `service_occupant`; `highest_occupancy_today`. |
| `cashier` | object | In-progress transactions per lane (`customer`, `duration`, `elapsed`, `manual`, `confirmed`). |
| `demand` | object | Next arrival times, pending pool, remaining Day 1–3 manifest rows, daily counters. `scripted_window_shoppers` and `next_window_shopper_at` schedule window shoppers; when an older save lacks them, the rest of that day has none. |
| `rotifood_orders` | object | Orders with items, locked unit prices, packed lots, `economy_committed`, driver phase and patience, plus daily counters. An order the player rejected (GDD 22.10) is `CANCELLED` with `cancel_reason` `rejected` and counts in `rejected_today`; older saves without it load with 0. |
| `supply_orders` | object | Purchase orders (`items`, `total_cost`, `arrival_game_time`, `state`, `inventory_committed`), `delivery_fifo`, couriers, `market_unlocked`. |
| `staff` | object | `contracts` (employed, on_duty, working, hired_day, batches_today), actors (with `seat_iid` while a baker sits on a staff chair), tasks, `lane_assign`, `wage_liability_today`, `wage_lines_today` (`staff_id`, `wage`). |
| `ratings` | object | `physical`, `rotifood`, day-start values, pending VIP outcomes. |
| `weather` | object | `today`, `tomorrow`, rolled multipliers. |
| `marketing` | object | Active campaign and its remaining days. |
| `tutorial` | object | Completed steps, `skipped`, the current prompt. |
| `decorations` | object | Owned items (uid, deco_id, floor, cell, slot, placed, `rot`), equipped cosmetics, `next_uid`. `slot` numbers a wall/counter spot of the current location (GDD 72.3); `cell` is a floor decoration's tile or a rug's anchor (smallest x/z); `rot` (0/1, missing in older saves = 0) turns a rug 90°. After load, decorations that break the slot rules go back to the inventory. |
| `flags` | object | `market_unlocked`, `bailout_pending`, `solo_mode`, `economy_overflowed`, `last_freshness_rollover_day`. The last one prevents double overnight aging (GDD 19.9). |
| `bailout` | object | Bailout counters, repeat visit and Solo Mode state (GDD 49). |
| `achievements` | object | Unlock day per achievement and progress trackers. |
| `statistics` | object | Lifetime stats, records, tier-reached days (GDD 92). |
| `recipe_analytics` | object | Per-recipe and daily analytics (GDD 92.4). |
| `reports` | object | `last_report` (`DayReportSnapshot`, GDD 46) and a bounded `history`. |
| `rng_states` | object | `master_seed`, `day_seed` and each of the eight streams' `seed` and `state`. All are **strings**, because JSON cannot hold 64-bit integers exactly (GDD 77.4, 116). |
| `ui_restore` | object | `game_speed`, `camera_zoom`. |

## Load reconstruction (GDD 77.2, 81 no. 16)

`load_from_save()` restores every manager, then rebuilds derived state:

- Occupancy and navigation grids are rebuilt from equipment and decoration positions.
- Orphaned production jobs are recovered (`ProductionManager.recover_orphans`).
- Actors are snapped to canonical cells. Queued customers and drivers go to their
  queue slot, and a player command that was in progress restarts from its logical
  target. World transforms are therefore not guaranteed to be identical after a load.
  Every timer, stage, amount of money, stock unit, queue reservation, order and RNG
  state is identical (see `TEST_SAVE_001`, `TEST_SAVE_002`).
- A tray the player was placing (`PLACEMENT_UI`) returns to `CARRIED_TO_DISPLAY`.

## Migrations

`SaveManager.migrate()` upgrades one version at a time:

| From → to | Change |
|---|---|
| 1 → 2 | Adds `rng_states` (streams re-derived from the old `master_seed`), `recipe_analytics`, `statistics`. |
| 2 → 3 | Adds `catalog_versions`, `ui_restore`, `active_floor_id`, `flags.last_freshness_rollover_day` (= day − 1) and `flags.economy_overflowed`. |
| 3 → 4 | Version bump only. Job fields `table_age_hours`/`table_seq` and `next_table_seq` default to 0/1. A save without a Holding Table gets one created and auto-placed in the kitchen on load (`SimulationRoot._ensure_table`). |
| 4 → 5 | Staff rework (GDD 3, 23; maintainer decision 2026-10-02). Drops the bakers' `mode`, `target_recipe` and `batch` and the staff `tasks`; jobs owned by a baker become kitchen orders (`owner_actor_id = "kitchen"`), staff claims are cleared and the job field `protected` is dropped. On load, staff above the new limits are dismissed newest hire first (`StaffManager.enforce_capacity`), staff chairs are created and auto-placed (`SimulationRoot._ensure_chairs`), and furniture that now covers a new lane cell, or lost its access tile, is re-placed with its contents (`WorldManager.release_conflicts`). |

| 5 → 6 | Roster cut (GDD 3.5, 106; maintainer decision 2026-10-04): five cashier and five baker candidates remain. Every hired candidate who was removed becomes the first remaining candidate of the same role who is not hired yet (catalog order, earliest hire first; `SaveManager.RETIRED_STAFF`). The ID is renamed everywhere in the save (contracts, staff actors, lane assignments, job claims, wage lines). A removed hire with no free candidate left is dismissed without cost, since it would be over every staff limit. |

A save whose `schema_version` is newer than the game is refused. It is never
downgraded or overwritten.

## Settings (`user://settings.json`)

Written by `autoload/settings_manager.gd` using the same temp-file pattern. The file
holds `settings_version` (1) and the keys in `SettingsManager.DEFAULTS`: the volume
channels, display and quality options, Smart Speed, confirmation threshold, tutorial
hints and the accessibility options of GDD 75. Out-of-range or unknown values fall
back to safe defaults. A corrupt file is replaced by the defaults and does not stop
the game from booting.

## Updating the golden fixture

The fixture is regenerated only when a gameplay change is intended:

```bash
"$G" --headless --path . res://tests/test_runner.tscn -- --only=TEST_SAVE_001 --update-fixtures
```

Review the diff of `tests/fixtures/*.json` before committing it.
