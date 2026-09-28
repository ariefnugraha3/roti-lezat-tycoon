# GDD v3.1 Compliance Checklist

This checklist maps each major system of GDD v3.1 FINAL to the code that implements it
and the tests that verify it (GDD 121 item 16).

**Status legend**

- **Tested**: an automated test in `tests/suites/` asserts the rule.
- **Implemented**: the code exists and runs in the smoke, UI and soak tests, but no
  test asserts this specific rule.
- **Not verified**: needs target hardware, an actual export, or a manual check that
  has not been done yet.
- **Open**: the GDD leaves a question that needs a maintainer decision.

Last full run (2026-09-29): 54 non-long tests passed, 0 failed (`--skip-long`). Soak results are
listed under GDD 94.

## Core loop and time

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 15.2 | 1 in-game hour = 120 s at 1×, 05:00/08:00/18:00 | `core/time_manager.gd` | TEST_TIME_001 | Tested |
| 71, 81.7 | Pause, 1×/2×/3×, menus freeze the timer, determinism across speeds | `simulation_root.gd` `advance`, `autoload/pause_manager.gd` | TEST_TIME_002, ACC_81_SPEED | Tested |
| 71.1, 81.8 | Smart Speed Safety drops to 1× on oven ready | `time_manager.gd` `smart_slowdown`, `production_manager.gd` | ACC_81_SPEED | Tested |
| 102 | Deterministic tick priority | `simulation_root.gd` `step` | TEST_TIME_002, TEST_SAVE_001 (golden determinism) | Tested |
| 104 | 18:00 shutdown matrix | `simulation_root.gd` `close_day`, manager `shutdown()` | TEST_MARKET_001 (late order), TEST_FRESHNESS_001, LONGRUN day checks | Tested |
| 3.0, 49 | No game over; Pak Lurah bailout, Solo Mode | `gameplay/meta/bailout_manager.gd`, `ui/screens/bailout_screen.gd` | LONGRUN (bailout count) | Implemented |

## Production, freshness and burn

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 18, 2 | Storage → mixer → oven → display, holding until pickup | `production/production_manager.gd`, `actors/player_task_manager.gd` | TEST_PRODUCTION_001, TEST_UI_SMOKE_001 | Tested |
| 5.1, 18.5, 61.5, 101.3 | Stage duration = base × equipment ratio × batch duration factor ÷ staff speed, prep in MIXING; reference times get faster each tier and `process_multiplier` matches them (checked at boot) | `production_manager.gd`, `data_registry.gd` | TEST_PRODUCTION_003 | Tested |
| 18.9 | x3/x5 multiply ingredients and yield, but durations only ×1.2/×1.4 (`production.batch_duration_factor`) | `production_manager.gd`, `autoload/data_registry.gd` `batch_duration_factor` | ACC_18_BATCH_DURATION, TEST_PRODUCTION_003 | Tested |
| 62 | Perfect/overbake/burnt windows per oven tier, burnt earns nothing and blocks the oven | `production_manager.gd` | TEST_PRODUCTION_002 | Tested |
| 38.3, 103 | Atomic ingredient consume and refund before MIXING | `economy/inventory_manager.gd` | TEST_INVENTORY_001 | Tested |
| 19.7 | Freshness states, display aging rates, 11 h overnight once, held bread keeps aging | `production/display_inventory_manager.gd`, `bread_stack.gd` | TEST_FRESHNESS_001, TEST_SAVE_002 | Tested |
| 85 | Display slots, slot picker, FIFO take | `display_inventory_manager.gd`, `ui/screens/slot_picker_screen.gd` | TEST_PRODUCTION_001, TEST_UI_SMOKE_001 | Tested |
| 61.1, 81.9 | No recipe unlocks; ingredients + equipment only | `production_manager.gd` `make_block_reason` | ACC_81_RECIPES | Tested |

## Customers, queues, cashier, RotiFood

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 57.6, 83 | Queue admission requires a reservation, exclusive slots | `customers/queue_manager.gd` | TEST_QUEUE_001 | Tested |
| 67 | Pending pool 30 s physical / 40 s driver, silent cancel | `customers/demand_manager.gd`, `delivery/rotifood_manager.gd` | TEST_QUEUE_002 | Tested |
| 84.2–84.3 | Target display, revalidation, deterministic substitution score | `customers/customer_manager.gd` | TEST_CUSTOMER_001 | Tested |
| 84.1 | Quantity distributions | `customer_manager.gd` `_pick_quantity` | TEST_CUSTOMER_002 | Tested |
| 58 | Patience values, drain and modifiers | `customer.gd`, `customer_manager.gd` | ACC_55_PATIENCE | Tested |
| 84.4 | Estimated-wait lane choice, tie-breaks, no lane hopping | `queue_manager.gd` | TEST_CASHIER_001 | Tested |
| 103.1 | Cashier transaction order | `customers/cashier_manager.gd` | TEST_ECONOMY_001 (ledger), smoke | Tested |
| 2, 21.4–21.6 | Every transaction lasts at least 3 s and ends with a 3 s packing phase (paper bag on the counter, cashier packing pose, `cashier_pack` once), coins only after packing, customer holds loose bread before and leaves with the bag after | `cashier_manager.gd` `packing_progress`, `world/world_view.gd` `_update_packing`, `world/actor_view.gd`, `procedural/animation/anim_system.gd` `pack` | ACC_21_PACKING, TEST_CASHIER_001 | Tested (timing and order); the look is checked with `tools/world_snapshot.tscn` |
| 22, 103.2 | RotiFood without reservation, atomic pack, single commit | `delivery/rotifood_manager.gd` | TEST_ROTIFOOD_001, TEST_SAVE_002 | Tested |
| 55.3 | Dedicated RotiFood queue at Tier 3+ | `queue_manager.gd` | ACC_55_OJOL_QUEUE | Tested |
| 20.3 | Day 1–3 fixed manifest | `data/catalog/opening.json`, `demand_manager.gd` | SMOKE_002 | Tested |
| 65, 66 | Day 4+ demand formula and arrival schedule | `demand_manager.gd` | LONGRUN soaks | Implemented |

## Economy, market, staff

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 1, 55.1 | Starting cash 1,000 KR in the ledger | `economy/economy_manager.gd` | SMOKE_001, ACC_55_STARTING_CASH | Tested |
| 24, 99 | Whole-KR half-up rounding, ledger reconciliation, settlement write-off | `economy_manager.gd`, `core/money.gd` | TEST_ECONOMY_001 | Tested |
| 63.2 | Price bounds and steps | `autoload/data_registry.gd` `_derive_prices`, `pricing_manager.gd` | TEST_ECONOMY_001 | Tested |
| 5.2, 24A, 55.5–55.9, 70 | Daytime courier +3 h, FIFO staging, capacity incl. in-transit, after-hours instant | `supply/supply_order_manager.gd` | TEST_MARKET_001/002, ACC_55_COURIERS, ACC_55_CAPACITY | Tested |
| 3.1–3.5, 87 | Hiring after hours, caps per tier, wage liability fixed at 05:00 | `staff/staff_manager.gd` | TEST_STAFF_001 | Tested |
| 23 | Baker AI priorities, auto-retrieve | `staff_manager.gd`, `production_manager.gd` | LONGRUN (managed bot hires bakers) | Implemented |
| 86 | Utility cost from active equipment time | `production/equipment_manager.gd` | LONGRUN, summary | Implemented |
| 73 | Overflow guard, saved as `"INF"` | `economy_manager.gd`, `save_manager.gd` | TEST_LONGRUN_500 | Tested (long) |
| 48 | Marketing campaigns | `gameplay/meta/marketing_manager.gd`, `ui/screens/marketing_screen.gd` | UI smoke (screen opens) | Implemented |
| 26 | Weather and holidays | `gameplay/meta/weather_manager.gd`, `data/catalog/weather.json` | none | Implemented |
| 9, 25 | Ratings and events | `gameplay/meta/reputation_manager.gd` | LONGRUN day checks (range) | Implemented |

## World, placement, floors, upgrade

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 57, appendix | Tier layouts and dimensions | `data/catalog/locations.json`, `world/floor_grid.gd` | ACC_SPATIAL, ACC_LAYOUT_SOLVER | Tested |
| 56.1, 81.1, 81.4 | Placement validation, protected paths, access tile | `world/world_manager.gd` | ACC_81_PLACEMENT, ACC_SPATIAL | Tested |
| 72, 81.14 | Decoration Mode pauses; IN_USE cannot move | `ui/screens/decoration_screen.gd`, `equipment_manager.gd` | ACC_81_IN_USE, UI smoke | Tested |
| 17.4 | Red preview with reason; keep-clear tiles striped in Decoration Mode and a "would block the walkway" warning on rejected placement | `world_manager.gd` `keep_clear_cells`, `world_view.gd` `show_tile_overlay`, `decoration_screen.gd` | ACC_DECOR_KEEP_CLEAR (marks match validation on every tile of every tier), UI smoke | Tested |
| 68, 30.3 | Instant portal, off-floor simulation, customers never upstairs | `world_manager.gd` `find_route`, `actors/sim_actor.gd` | TEST_MULTIFLOOR_001 | Tested |
| 30 | Camera: floor framing, follows player on large floors, 0.20 s crossfade, off-floor alerts | `world/camera_rig.gd`, `world/world_view.gd`, `meta/alert_manager.gd` | TEST_CAMERA_001 | Tested |
| 47, 105 | Upgrade: money only, no loss, rollback snapshot | `simulation_root.gd` `upgrade_location` | TEST_UPGRADE_001 | Tested |

## Save, profiles, lifecycle

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 106 | Schema v3, golden fixture roundtrip | `autoload/save_manager.gd`, `simulation_root.gd` | TEST_SAVE_001 | Tested |
| 34.4, 77, 132 | Atomic write, backup fallback, NaN refusal, idempotent transactions | `save_manager.gd` | TEST_SAVE_002 | Tested |
| 81.15–81.16 | OVERBAKING timer identical after load; canonical queue reconstruction | `production_manager.gd`, `customer_manager.gd` `reconstruct` | TEST_SAVE_002 | Tested |
| 34.5 | Migrations v1→v2→v3 | `save_manager.gd` `migrate` | TEST_SAVE_001 (legacy fixture) | Tested |
| 89.3 | Three isolated profiles, Continue picks the latest | `save_manager.gd` | TEST_PROFILE_001 | Tested |
| 90, 113 | Focus-loss pause, no offline progress | `pause_manager.gd`, `scenes/game_root.gd` | TEST_LIFECYCLE_001 | Tested |
| 116, 77.4 | Eight separated RNG streams, saved states | `core/rng_manager.gd` | TEST_RNG_001 | Tested |

## UI, text, input, accessibility

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 28 | Screen inventory | `ui/screen_registry.gd`, `ui/screens/*` | TEST_UI_SMOKE_001 | Tested (opens without errors) |
| 43, 127 | English text from the catalog, key completeness | `core/tx.gd`, `data/catalog/strings_en.json`, `tools/string_lint.gd` | TEST_UI_001 | Tested |
| 7, 29, 100 | One tap/click per action, command layer | `core/command_layer.gd`, `core/input_actions.gd` | UI smoke (world tap) | Implemented |
| 12.4, 110 | 48 px targets, safe area, resolution matrix | `procedural/ui/ui_factory.gd`, `ui/hud/hud.gd` | 1280×720 manual check | Not verified (other resolutions and devices) |
| 7 | HUD layout | `ui/hud/hud.gd` | UI smoke | Implemented. **Deviation by maintainer decision (2026-09-27):** the clock, speed and daily-demand panel sits bottom-left instead of the top |
| 44, 75 | Settings and accessibility | `autoload/settings_manager.gd`, `ui/screens/settings_screen.gd` | UI smoke (screen opens) | Implemented |
| 27, 88 | Tutorial Day 1–3 | `gameplay/meta/tutorial_manager.gd`, `ui/screens/tutorial_modal.gd` | UI smoke | Implemented |
| 131 | Notification orchestration (visible toast cap, coalescing) | `ui/hud/hud.gd` | none | Implemented |
| 46 | Daily Summary snapshot | `gameplay/meta/day_report_manager.gd`, `ui/screens/daily_summary_screen.gd` | UI smoke, TEST_ECONOMY_001 | Implemented |

## Presentation, assets, audio

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 4, 12.2, 111 | 100% procedural assets, no external files | `procedural/`, `audio/`, `tools/generate_icon.gd` | release_validator (asset scan) | Tested |
| 31, 130.2, 12.2 | Character rig (31.1 hierarchy, arms ride on `Body`), golden proportions (0.90 m, head 42%, torso 30%, legs 28%, eye line ~45%), hair and hat brims never cover eyes or brows, five expressions, carry pose, 500–2000 triangles and at most 14 draw calls per character | `procedural/meshes/character_factory.gd`, `procedural/meshes/mesh_builder.gd`, `procedural/animation/anim_system.gd` `set_carry_pose` | ACC_31_CHARACTER_RIG, ACC_130_PROPORTIONS, ACC_31_HAIR_CLEAR, ACC_31_DETERMINISM, ACC_31_EXPRESSIONS; `tools/character_lineup.tscn` screenshots | Tested (geometry and rig); the look itself is reviewed from lineup screenshots |
| 31.6 | Idle player/staff: face wipe with a cloth after 15 real seconds, dozing with floating "Z" after 25; real-time, paused with the game, reset by any activity, never for customers | `world/actor_view.gd`, `anim_system.gd` `wipe_face`/`doze`, `character_factory.gd` `wipe_cloth`/`sleep_z` | ACC_31_IDLE_GESTURES | Tested |
| 31.7, 127.12 | Player thought bubbles at 10/20/30/40 real seconds while the open shop has no customers and no active RotiFood order; hidden at once when someone arrives | `world/world_view.gd` `_update_thoughts`, `ui/components/thought_bubble.gd` | ACC_31_THOUGHTS | Tested |
| 32, 130 | Furniture visuals, rest of the golden visual spec | `procedural/meshes/*` | Manual screenshots at Tier 1/3/5 | Not verified against every GDD 130 detail |
| 33, 76, 93 | Generated audio events, mixing priorities | `audio/audio_generator.gd`, `autoload/audio_manager.gd` | none | Implemented (not listened to) |
| 91, 115 | Procedural caches, pooling, release on exit | `procedural/procedural_caches.gd`, `world/world_view.gd` | release_validator (no leaks at exit) | Tested |

## Platform, build, release

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 96, 128.1 | Godot 4.7-stable, GDScript, Compatibility renderer, no addons | `project.godot` | release_validator | Tested |
| 108, 128 | Web, Android APK and AAB presets, no secrets, landscape, package ID | `export_presets.cfg` | release_validator (preset checks) | Tested (presets); **exports Not verified**: on hold by maintainer decision (2026-09-27) until the game itself is finished |
| 12.7, 112 | Fully offline, no network | whole codebase | release_validator (network scan) | Tested |
| 109, 37 | Performance budgets on entry-level Android and web | — | none | Not verified (needs devices) |
| 129 | Runtime hard limits | `balance.json` `limits` read by `audio_manager.gd` (SFX and music voices), `hud.gd` (toasts, coalescing), `world_view.gd` (world alerts, pooled bodies), `fx.gd` (transient effects), `decoration_manager.gd`, analytics; visible actors via `queue.max_visible_customer_actors`; ledger hot entries | ACC_129_LIMITS (effect cap), ACC_129_FX_TEARDOWN (effects freed before their auto-free timer) | Implemented; effect limits tested |
| 133 | Release validator | `tools/release_validator.gd` | itself | Tested |
| 107 | Required test IDs | `tests/suites/*` | all | Tested |

## Long-session stability (GDD 94)

| Test | What it checks | Status |
|---|---|---|
| TEST_LONGRUN_100 | 100 managed days at the canonical tick: invariants, no leftover transient state at 05:00, node and object counts stable | Passed 2026-09-29 with the 2026-09-28/29 timing changes (1,003 checks); see open decision 3 |
| TEST_LONGRUN_500 | 500 days (0.25 s tick): no NaN/INF, ledger reconciles, overflow guard survives save/load | Passed 2026-09-26 (5,013 checks; reached Tier 4, memory flat at ~73 MB) |
| TEST_LONGRUN_1000 | 1,000 days with save → load every day: logical state preserved, save size bounded | Passed 2026-09-27 (11,003 checks; non-history save 48.5 KB at day 200 → 52.1 KB at day 1000; reached Tier 5) |

## Open decisions

1. **Daily Summary on Day 1–3.** Decided by the maintainer on 2026-09-27: the free
   tutorial stock keeps counting as COGS ("Ingredients Used"), as GDD 24.4 defines.
   The current behaviour is correct and stays.
2. **Project license.** `LICENSES.md` says all rights are reserved until the
   maintainer chooses a license.
3. **Economy after the timing changes (GDD 15.2, 18.5, 5.1, 61.5).** On 2026-09-28,
   x3 batches were set to ×1.2 and x5 to ×1.4 of the base stage time (previously ×3 and
   ×5). On 2026-09-29, the clock became 1 in-game hour = 120 s, the §5.1 reference
   times were replaced, and every §61.5 recipe duration was halved. In TEST_LONGRUN_100
   (2026-09-29) the managed bot reaches 50,704 KR by day 41 at Tier 2 and upgrades to
   Tier 3 by day 51. From then on it sits at 0 KR at every 10-day checkpoint to day 101.
   The run with only the batch change hit the same wall from day 61. Before any of
   these changes, the same run reached 110,515 KR by day 101. The soak still passes its
   stability checks. Suspected cause, not yet confirmed: Auto bakers now produce much
   faster than before and overproduce against demand. TEST_LONGRUN_500/1000 have not
   been re-run since 2026-09-28. Waiting on the maintainer: keep the balance as is, or
   investigate and tune the baker AI.
