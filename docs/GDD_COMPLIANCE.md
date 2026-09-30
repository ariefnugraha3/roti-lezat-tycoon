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
- **Missing**: the GDD asks for it, but the code does not do it yet.

Last full run (2026-09-30): 85 non-long tests passed, 0 failed (`--skip-long`). Soak results are
listed under GDD 94.

## Core loop and time

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 15.2 | 1 in-game hour = 120 s at 1×, 05:00/08:00/18:00 | `core/time_manager.gd` | TEST_TIME_001 | Tested |
| 71, 81.7 | Pause, 1×/2×/3×, menus freeze the timer, determinism across speeds | `simulation_root.gd` `advance`, `autoload/pause_manager.gd` | TEST_TIME_002, ACC_81_SPEED | Tested |
| 71.1, 81.8 | Smart Speed Safety drops to 1× on oven ready | `time_manager.gd` `smart_slowdown`, `production_manager.gd` | ACC_81_SPEED | Tested |
| 102 | Deterministic tick priority | `simulation_root.gd` `step` | TEST_TIME_002, TEST_SAVE_001 (golden determinism) | Tested |
| 102, 116 | Text IDs (customers, staff, recipes, weighted-pick keys) iterate in alphabetical order through `core/ids.gd`, because `Array.sort()` orders StringName by internal address and would differ between sessions | `core/ids.gd`, `rng_manager.gd`, `customer_manager.gd`, `staff_manager.gd`, `rotifood_manager.gd` | ACC_116_ID_ORDER | Tested |
| 15.4 | Skip to Open during preparation: confirm, then the normal ticks run fast (a time budget per frame) behind an overlay until 08:00, ending in exactly the state waiting would reach; stops early when an oven holds a tray the player must take out; hidden outside preparation and during the Day 1 storage lesson (maintainer decision 2026-09-30) | `simulation_root.gd` `skip_to_open_block`/`skip_to_open_step`, `production_manager.gd` `oven_needs_player`, `scenes/game_root.gd`, `ui/components/skip_overlay.gd`, `ui/hud/hud.gd` | ACC_15_SKIP_TO_OPEN (same fingerprint as waiting, oven stop, phase and tutorial rules), TEST_UI_SKIP_OPEN (button, confirm, overlay, control handed back) | Tested |
| 104 | 18:00 shutdown matrix | `simulation_root.gd` `close_day`, manager `shutdown()` | TEST_MARKET_001 (late order), TEST_FRESHNESS_001, LONGRUN day checks | Tested |
| 3.0, 49 | No game over; Pak Lurah bailout, Solo Mode | `gameplay/meta/bailout_manager.gd`, `ui/screens/bailout_screen.gd` | LONGRUN (bailout count) | Implemented |

## Production, freshness and burn

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 18, 2 | Storage → mixer → oven → display, holding until pickup | `production/production_manager.gd`, `actors/player_task_manager.gd` | TEST_PRODUCTION_001, TEST_UI_SMOKE_001 | Tested |
| 5.1, 18.5, 61.5, 101.3 | Stage duration = base × equipment ratio × batch duration factor ÷ staff speed, prep in MIXING; reference times get faster each tier and `process_multiplier` matches them (checked at boot) | `production_manager.gd`, `data_registry.gd` | TEST_PRODUCTION_003 | Tested |
| 18.9 | x3/x5 multiply ingredients and yield, but durations only ×1.2/×1.4 (`production.batch_duration_factor`) | `production_manager.gd`, `autoload/data_registry.gd` `batch_duration_factor` | ACC_18_BATCH_DURATION, TEST_PRODUCTION_003 | Tested |
| 62 | Perfect/overbake/burnt windows per oven tier, burnt earns nothing and blocks the oven | `production_manager.gd` | TEST_PRODUCTION_002 | Tested |
| 16.5, 62 | Dough in hand (player or baker) replaces a burnt tray: the tray is discarded as waste and the dough goes in. Sellable trays are never replaced, so all-ovens-burnt can no longer soft-lock the kitchen | `production_manager.gd` `free_oven_for`/`insert_oven`, `actors/player_task_manager.gd` `_at_oven` | ACC_62_BURNT_SWAP | Tested |
| 38.3, 103 | Atomic ingredient consume and refund before MIXING | `economy/inventory_manager.gd` | TEST_INVENTORY_001 | Tested |
| 19.7 | Freshness states, display aging rates, 11 h overnight once, held bread keeps aging | `production/display_inventory_manager.gd`, `bread_stack.gd` | TEST_FRESHNESS_001, TEST_SAVE_002 | Tested |
| 5.1.3 | Holding Table: one bundled table per location (kitchen, movable, never sold or put away), player only, no item limit, not a shop shelf; one tap parks the carried dough or tray, and an empty-handed tap takes the item closest to spoiling that has somewhere to go (otherwise an oven/shelf-full icon); "!" marker; items do not count toward the job cap or block an upgrade | `production/production_manager.gd` (table section), `actors/player_task_manager.gd` `_at_table`, `equipment_manager.gd` `is_fixture`, `simulation_root.gd` `_ensure_table`, `world/world_view.gd` `_update_table`, `procedural/meshes/equipment_factory.gd` `build_holding_table` | ACC_TABLE_PUT_TAKE, ACC_TABLE_RULES, ACC_LAYOUT_SOLVER | Tested; the look is checked with `tools/world_snapshot.tscn` (`world_table*`) |
| 19.7.6 | Table contents age only on the table: bread at `holding_table.bread_aging_rate`, dough 2×; age survives pick-up and put-back; spoiled items are discarded as waste with a notice; 11 h overnight with the display rollover; bread keeps its table age on the shelf; dough bakes fresh | `production_manager.gd` `age_table`, `display_inventory_manager.gd` `place(age_hours)`, `simulation_root.gd` `_begin_day` | ACC_TABLE_SPOILAGE, ACC_TABLE_PUT_TAKE | Tested |
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
| 84.4 | Estimated-wait lane choice, tie-breaks, no lane hopping; with every checkout at 3 s the estimate depends only on the queue length and the walk | `queue_manager.gd` | TEST_CASHIER_001 | Tested |
| 103.1 | Cashier transaction order | `customers/cashier_manager.gd` | TEST_ECONOMY_001 (ledger), smoke | Tested |
| 2, 21.4–21.6 | Every transaction, by the player or any cashier tier and for every customer type, lasts exactly 3 s and is packing from its first moment (maintainer decision 2026-09-30; before, packing was only the last 3 s of a 10.5 s manual checkout), with coins only after packing. The customer holds loose bread before and leaves with the bag after. The packing choreography: the bag snaps open, each bread hops from beside the bag into it, the ribbon ties with a sparkle, the bag is offered while the customer reaches out, then the cashier waits for payment. Beats follow `pack_phases`, cashier hands stay in sync, and `cashier_pack` plays once | `cashier_manager.gd` `packing_progress`, `world/pack_bag_rig.gd`, `world/world_view.gd` `_update_packing`, `world/actor_view.gd`, `procedural/animation/anim_system.gd` `pack`/`receive`/`pack_phases` | ACC_21_PACKING, ACC_21_PACK_CHOREOGRAPHY, TEST_CASHIER_001 | Tested (timing, order and beats); the look is checked with `tools/world_snapshot.tscn` (`pack_sequence.png`) |
| 22, 103.2 | RotiFood without reservation, atomic pack, single commit | `delivery/rotifood_manager.gd` | TEST_ROTIFOOD_001, TEST_SAVE_002 | Tested |
| 22.9 | RotiFood picks menu recipes weighted by price acceptance (`rotifood.price_sensitivity`), so overpriced bread is rarely ordered (maintainer decision 2026-09-29) | `delivery/rotifood_manager.gd` `menu_weight` | ACC_22_ROTIFOOD_WEIGHTS | Tested |
| 55.3 | Dedicated RotiFood queue at Tier 3+ | `queue_manager.gd` | ACC_55_OJOL_QUEUE | Tested |
| 20.3 | Day 1–3 fixed manifest | `data/catalog/opening.json`, `demand_manager.gd` | SMOKE_002 | Tested |
| 65, 66 | Day 4+ demand formula and arrival schedule | `demand_manager.gd` | LONGRUN soaks | Implemented |

## Economy, market, staff

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 1, 55.1 | Starting cash 1,000 KR in the ledger | `economy/economy_manager.gd` | SMOKE_001, ACC_55_STARTING_CASH | Tested |
| 24, 99 | Whole-KR half-up rounding, ledger reconciliation, settlement write-off | `economy_manager.gd`, `core/money.gd` | TEST_ECONOMY_001 | Tested |
| 63.2 | Price bounds and steps | `autoload/data_registry.gd` `_derive_prices`, `pricing_manager.gd` | TEST_ECONOMY_001 | Tested |
| 63.2 | Days 1–3 (manifest) sell at the reference price: the slider is read-only and stored overrides do not apply; it unlocks in the Day 3 after-hours (maintainer decision 2026-09-29) | `pricing_manager.gd` `prices_locked`, `ui/screens/recipe_book_screen.gd` | ACC_63_PRICE_LOCK | Tested |
| 5.1.2 | The Market sells equipment only up to the store tier (buy and Replace); locked cards say which store tier they need; owned equipment is unaffected (maintainer decision 2026-09-29) | `production/equipment_manager.gd` `tier_allowed`, `ui/screens/market_screen.gd` | ACC_5_TIER_GATE | Tested |
| 5.2, 24A, 55.5–55.9, 70 | Daytime courier +3 h, FIFO staging, capacity incl. in-transit, after-hours instant | `supply/supply_order_manager.gd` | TEST_MARKET_001/002, ACC_55_COURIERS, ACC_55_CAPACITY | Tested |
| 3.1–3.5, 87 | Hiring after hours, caps per tier, wage liability fixed at 05:00 | `staff/staff_manager.gd` | TEST_STAFF_001 | Tested |
| 3.1, 20 | Cashier tiers no longer differ in speed (every checkout 3 s). Perks instead (maintainer decision 2026-09-30, "patient + friendly"): Tier 2 calms its queue by 8% (×0.92 patience drain), Tier 3 keeps ×0.85, Tier 4 calms by 15% (×0.85) and each of its sales lifts the Store Rating 1.5× (`successful_sale` and `fast_service`, not penalties), Tier 5 keeps its 5% tip chance. The Staff card spells every perk out. Unknown perk keys and out-of-range values fail the boot validation | `data/catalog/staff.json` `special`, `customer_manager.gd` `_drain`, `cashier_manager.gd` `_complete`, `ui/screens/staff_screen.gd` `perk_lines`, `data_registry.gd` | ACC_3_CASHIER_PERKS (drain ratios, rating ratio from twin sims, card lines) | Tested |
| 23 | Baker AI priorities, auto-retrieve | `staff_manager.gd`, `production_manager.gd` | LONGRUN (managed bot hires bakers) | Implemented |
| 23.3 | Bakers only start a batch whose mixing and baking (their speed, the free mixer, the slowest usable oven) finish by `staff_ai.baker_finish_by_seconds`, trying smaller batches first, so the kitchen is empty at closing and a location upgrade is not blocked (maintainer decision 2026-09-29) | `staff_manager.gd` `finishes_before_cutoff`, `_plan_new_job` | ACC_23_BAKER_CUTOFF | Tested |
| 18.8, 87.2 | Auto-retrieve protects a tray only for a baker still on shift; claims drop at 18:00 and the same baker reclaims the tray the next day; a fired or benched baker's protected trays revert to a failed roll and their unfinished jobs pass to the player; the 18:00 or leave-of-duty handoff parks trays that no shelf takes, and dough with no free mixer, on the Holding Table. Before this, a tray protected for a fired baker locked its oven and every location upgrade for good | `production_manager.gd` `_on_bake_complete`, `staff_manager.gd` `_drop_carried`/`_hand_over_jobs`/`_choose_task` | ACC_18_RETRIEVE_ABSENT_BAKER, ACC_18_RETRIEVE_NEXT_DAY, ACC_87_STAFF_HANDOFF | Tested |
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
| 72.2 | Decoration Mode without a side panel: a top bar (hint, floors, Done), bottom tabs that open an item tray, and an action toolbar (Rotate, Put Away, Cancel) floating right above the selected furniture with a tail pointing at it; Rotate turns placed furniture in place; tapping another piece switches, tapping the selected one or Back finishes; the selected piece is lifted and station markers hide (maintainer decision 2026-09-30) | `ui/screens/decoration_screen.gd`, `world/world_view.gd` `set_lift`/`top_of_iid`, `world/camera_rig.gd` `focus_free_pan` | TEST_UI_SMOKE_001 (toolbar above the selection, fixture without Put Away, switch and finish taps, rotate in place, Back), ACC_7_MARKER_REBUILD | Tested; the look was checked from 1280×720 screenshots |
| 72.1, 72.3 | Every placeable decoration (23 items, 22 visual profiles) has its own procedural model inside the triangle budget (no text; the pendulum clock swings, the lamp bulb glows, the coin jar glass is see-through, tier plaques carry 2/3/4 stars) and is drawn where it is placed (maintainer decision 2026-09-30) | `procedural/meshes/decor_factory.gd`, `world/world_view.gd` `_rebuild_decor`/`_animate_swing` | TEST_VIS_DECOR_MODELS, TEST_VIS_DECOR_WORLD | Tested; the look was checked from 1600×900 screenshots at Tier 1, 3 and 5 |
| 72.3 | Decoration slots per store tier (wall/counter/floor/rug: 2/1/1/1, 3/1/2/1, 4/2/3/1, 6/2/4/2, 8/3/6/2), all on the shop floor; wall spots between the windows of the two full walls (store side first), one counter spot per register counter at the end away from the paper bag and the tablet; rugs cover `overlay_size_tiles`, rotate, may lie on walkways, never block and never overlap; loading and moving shop put back decorations that break the rules, oldest first (maintainer decision 2026-09-30) | `world/decor_slots.gd`, `world/decoration_manager.gd` `cap`/`check_place`/`validate_overlay`/`rotate_overlay`/`enforce_rules`, `data/catalog/locations.json` `decor_slots`, `data_registry.gd` | ACC_72_DECOR_SLOTS, ACC_72_DECOR_CAPS, ACC_72_DECOR_RUGS, ACC_72_DECOR_ENFORCE | Tested |
| 72.2, 72.3 | Decoration Mode for decorations: selecting one moves the view to the shop floor and lights free wall/counter slot markers (its own spot in gold); a tap on a marker hangs or moves it; rugs preview their footprint and Rotate; a full type shows "No free spot left" with the shop's cap; placed decorations are tapped to select and lift like furniture; the tray starts with the slot usage ("Wall 1/2") | `ui/screens/decoration_screen.gd`, `world/world_view.gd` `show_slot_markers`/`slot_at_screen`/`pick`/`set_decor_lift` | TEST_UI_DECOR_SLOTS, TEST_VIS_DECOR_WORLD | Tested |
| 4.1, 21.4 | Right-wall windows face the room (their glass and curtains used to face into the wall) and the room's wall clock faces the room with a swinging pendulum (it used to show its back); the paper bag stands beside the register in the middle of the counter (on two-tile counters it used to sit inside the register) | `procedural/meshes/room_factory.gd`, `world/world_view.gd` `_build_pack_bag` | TEST_VIS_DECOR_WORLD | Tested; checked in screenshots |
| 17.4 | Red preview with reason; keep-clear tiles striped in Decoration Mode and a "would block the walkway" warning on rejected placement | `world_manager.gd` `keep_clear_cells`, `world_view.gd` `show_tile_overlay`, `decoration_screen.gd` | ACC_DECOR_KEEP_CLEAR (marks match validation on every tile of every tier), UI smoke | Tested |
| 68, 30.3 | Instant portal, off-floor simulation, customers never upstairs | `world_manager.gd` `find_route`, `actors/sim_actor.gd` | TEST_MULTIFLOOR_001 | Tested |
| 30 | Camera: floor framing, follows player on large floors, 0.20 s crossfade, off-floor alerts | `world/camera_rig.gd`, `world/world_view.gd`, `meta/alert_manager.gd` | TEST_CAMERA_001 | Tested |
| 47, 105 | Upgrade: money only, no loss, rollback snapshot | `simulation_root.gd` `upgrade_location` | TEST_UPGRADE_001 | Tested |

## Save, profiles, lifecycle

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 106 | Schema v4 (Holding Table stages and fields), golden fixture roundtrip | `autoload/save_manager.gd`, `simulation_root.gd` | TEST_SAVE_001, ACC_TABLE_RULES | Tested |
| 34.4, 77, 132 | Atomic write, backup fallback, NaN refusal, idempotent transactions | `save_manager.gd` | TEST_SAVE_002 | Tested |
| 81.15–81.16 | OVERBAKING timer identical after load; canonical queue reconstruction | `production_manager.gd`, `customer_manager.gd` `reconstruct` | TEST_SAVE_002 | Tested |
| 34.5 | Migrations v1→v2→v3→v4; a v3 save gains a placed Holding Table on load | `save_manager.gd` `migrate`, `simulation_root.gd` `_ensure_table` | TEST_SAVE_001 (legacy fixture), ACC_TABLE_RULES | Tested |
| 89.3 | Three isolated profiles, Continue picks the latest | `save_manager.gd` | TEST_PROFILE_001 | Tested |
| 90, 113 | Focus-loss pause, no offline progress | `pause_manager.gd`, `scenes/game_root.gd` | TEST_LIFECYCLE_001 | Tested |
| 116, 77.4 | Eight separated RNG streams, saved states | `core/rng_manager.gd` | TEST_RNG_001 | Tested |

## UI, text, input, accessibility

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 28 | Screen inventory | `ui/screen_registry.gd`, `ui/screens/*` | TEST_UI_SMOKE_001 | Tested (opens without errors) |
| 89.5, 114 | Staged loading for New Game and Load/Continue: English stage text and a forward-only bar (sim, save, today's music and ambience, world, HUD, then world frames until two in a row are stable); each heavy stage gets a frame so the bar is drawn; the clock does not move until the overlay fades; a failed save read closes the overlay and shows the error screen (maintainer decision 2026-09-30) | `scenes/game_root.gd` `_begin_loading`/`_loading_stage`/`_warm_audio`/`_settle_frames`, `ui/components/loading_screen.gd` | TEST_UI_LOADING_STAGES | Tested; the look was checked from 1280×720 screenshots |
| 43, 127 | English text from the catalog, key completeness | `core/tx.gd`, `data/catalog/strings_en.json`, `tools/string_lint.gd` | TEST_UI_001 | Tested |
| 7, 29, 100 | One tap/click per action, command layer | `core/command_layer.gd`, `core/input_actions.gd` | UI smoke (world tap) | Implemented |
| 12.4, 110 | 48 px targets, safe area, resolution matrix | `procedural/ui/ui_factory.gd`, `ui/hud/hud.gd` | 1280×720 manual check | Not verified (other resolutions and devices) |
| 7 | HUD layout | `ui/hud/hud.gd` | UI smoke | Implemented. **Deviation by maintainer decision (2026-09-27):** the clock, speed and daily-demand panel sits bottom-left instead of the top |
| 44, 75 | Settings and accessibility | `autoload/settings_manager.gd`, `ui/screens/settings_screen.gd` | UI smoke (screen opens) | Implemented |
| 27, 88 | Tutorial Day 1–3 | `gameplay/meta/tutorial_manager.gd`, `ui/screens/tutorial_modal.gd` | UI smoke | Implemented |
| 131 | Notification orchestration (visible toast cap, coalescing) | `ui/hud/hud.gd` | none | Implemented |
| 7, 18.6 | Station "!" markers and progress bars are rebuilt with the furniture. They hang on the floor node, and until 2026-09-30 a layout rebuild (an achievement skin mid-day, Decoration Mode, a purchase) left the old ones behind, so a progress bar stayed frozen over the station | `world/world_view.gd` `rebuild_furniture`/`_update_markers` | ACC_7_MARKER_REBUILD | Tested |
| 46 | Daily Summary snapshot | `gameplay/meta/day_report_manager.gd`, `ui/screens/daily_summary_screen.gd` | UI smoke, TEST_ECONOMY_001 | Implemented |

## Presentation, assets, audio

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 4, 12.2, 111 | 100% procedural assets, no external files | `procedural/`, `audio/`, `tools/generate_icon.gd` | release_validator (asset scan) | Tested |
| 31, 130.2, 12.2 | Character rig (31.1 hierarchy, arms ride on `Body`), golden proportions (0.90 m, head 42%, torso 30%, legs 28%, eye line ~45%), hair and hat brims never cover eyes or brows, five expressions, carry pose, 500–2000 triangles and at most 14 draw calls per character | `procedural/meshes/character_factory.gd`, `procedural/meshes/mesh_builder.gd`, `procedural/animation/anim_system.gd` `set_carry_pose` | ACC_31_CHARACTER_RIG, ACC_130_PROPORTIONS, ACC_31_HAIR_CLEAR, ACC_31_DETERMINISM, ACC_31_EXPRESSIONS; `tools/character_lineup.tscn` screenshots | Tested (geometry and rig); the look itself is reviewed from lineup screenshots |
| 31.6 | Idle player/staff: a face wipe with a cloth every 15 real seconds until they doze with floating "Z" letters (staff at 25 s, the player at 85 s in any phase); real-time, paused with the game, reset by any activity, never for customers; while the player's sleep is held back the wipes keep coming (maintainer decision 2026-09-30) | `world/actor_view.gd`, `anim_system.gd` `wipe_face`/`doze`, `character_factory.gd` `wipe_cloth`/`sleep_z`, `data_registry.gd` `player_doze_after_seconds` | ACC_31_IDLE_GESTURES | Tested |
| 31.7, 127.12 | Player thought bubbles every 20 real seconds (20/40/60/80) while the open shop has no customers and no active RotiFood order; hidden at once when someone arrives; the player falls asleep exactly when the fourth bubble ends (85 s of quiet) and never under a bubble | `world/world_view.gd` `_update_thoughts`, `ui/components/thought_bubble.gd` | ACC_31_THOUGHTS, ACC_31_DOZE_AFTER_THOUGHTS | Tested |
| 32, 130 | Furniture visuals, rest of the golden visual spec | `procedural/meshes/*` | Manual screenshots at Tier 1/3/5 | Not verified against every GDD 130 detail |
| 33, 76, 93 | Generated audio events, mixing priorities | `audio/audio_generator.gd`, `autoload/audio_manager.gd` | none | Implemented (not listened to by a person) |
| 33.6 | Music beds are assembled a slice per frame (identical to building at once; within a sample of the old generator); a music change keeps the old bed playing until the new one is ready; beds are prewarmed ahead (menu on Tap to Start, morning in the Main Menu, the day's beds after loading) (maintainer decision 2026-09-30). Before, a bed built in one go froze the screen after Tap to Start, after loading and at 08:00/18:00 | `audio/music_build.gd`, `autoload/audio_manager.gd` `request_stream`/`step_jobs`/`prewarm_music`, `scenes/game_root.gd` | ACC_33_MUSIC_BUILD, ACC_33_MUSIC_NO_STALL; in the Web build (headless Chrome) the longest frame after Tap to Start fell from 1,630 ms to 109 ms | Tested |
| 33, 35.2 | Music/SFX/UI/Ambient buses sit after Master in order and send to it. They are created with `set_bus_count`, because on Web (Sample playback, Godot 4.7.2) `AudioServer.add_bus()` inserts the JavaScript bus in front of Master; `set_bus_send` then loops Master back into the other buses, and Web Audio silences the loop, so the whole game was mute in browsers (found 2026-09-29) | `autoload/audio_manager.gd` `_ensure_buses` | ACC_33_AUDIO_BUSES (order, sends, no `add_bus` calls); a headless Chrome check confirmed menu music reaches the audio output after "Tap to Start" | Tested |
| 91, 115 | Procedural caches, pooling, release on exit | `procedural/procedural_caches.gd`, `world/world_view.gd` | release_validator (no leaks at exit) | Tested |

## Platform, build, release

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 96, 128.1 | Godot 4.7-stable, GDScript, Compatibility renderer, no addons | `project.godot` | release_validator | Tested |
| 108, 128 | Web, Android APK and AAB presets, no secrets, landscape, package ID | `export_presets.cfg` | release_validator (preset checks) | Tested (presets). Web export completes (2026-09-29, private playtest build approved by the maintainer; about 40 MB, 10.5 MB zipped); verified in desktop Chrome (headless) and by the maintainer on an Android phone browser, where the portrait view led to the 2026-09-30 phone rules (12.5). GitHub Pages deployment: `.github/workflows/deploy-web.yml` (manual trigger), run by the maintainer since 2026-09-29. Android: **Not verified** (no Android SDK on this machine; still on hold) |
| 12.5, 128.3 | Phone browsers: a "Rotate your phone" screen covers the game and pauses it while the phone is upright; Tap to Start (on finger lift) enters fullscreen and locks landscape where the browser allows; Settings offers "Play in full screen"; desktop browsers and the Android app are unchanged (maintainer decision 2026-09-30) | `core/web_platform.gd`, `ui/components/orientation_guard.gd`, `scenes/game_root.gd` `_on_splash_input`, `ui/screens/settings_screen.gd`, `autoload/settings_manager.gd` | ACC_12_ORIENTATION_GUARD, TEST_UI_SPLASH_TAP; headless Chrome with Android emulation showed the rotate screen upright, the splash sideways, and a fullscreen canvas in `landscape-primary` after the tap | Tested; not yet tried on a real phone or on iPhone Safari |
| 12.7, 112 | Fully offline, no network | whole codebase | release_validator (network scan) | Tested |
| 109, 37 | Performance budgets on entry-level Android and web | — | none | Not verified (needs devices) |
| 129 | Runtime hard limits | `balance.json` `limits` read by `audio_manager.gd` (SFX and music voices), `hud.gd` (toasts, coalescing), `world_view.gd` (world alerts, pooled bodies), `fx.gd` (transient effects), `decoration_manager.gd`, analytics; visible actors via `queue.max_visible_customer_actors`; ledger hot entries | ACC_129_LIMITS (effect cap), ACC_129_FX_TEARDOWN (effects freed before their auto-free timer) | Implemented; effect limits tested |
| 133 | Release validator | `tools/release_validator.gd` | itself | Tested |
| 107 | Required test IDs | `tests/suites/*` | all | Tested |

## Long-session stability (GDD 94)

| Test | What it checks | Status |
|---|---|---|
| TEST_LONGRUN_100 | 100 managed days at the canonical tick: invariants, no leftover transient state at 05:00, node and object counts stable | Passed 2026-09-29 again after the balance rules and staff-handover fixes (1,003 checks; Tier 3 with 81,038 KR on day 101); see open decisions 3 and 4 |
| TEST_LONGRUN_500 | 500 days (0.25 s tick): no NaN/INF, ledger reconciles, overflow guard survives save/load | Passed 2026-09-26 (5,013 checks; reached Tier 4, memory flat at ~73 MB) |
| TEST_LONGRUN_1000 | 1,000 days with save → load every day: logical state preserved, save size bounded | Passed 2026-09-27 (11,003 checks; non-history save 48.5 KB at day 200 → 52.1 KB at day 1000; reached Tier 5) |

## Open decisions

1. **Daily Summary on Day 1–3.** Decided by the maintainer on 2026-09-27: the free
   tutorial stock keeps counting as COGS ("Ingredients Used"), as GDD 24.4 defines.
   The current behaviour is correct and stays.
2. **Project license.** `LICENSES.md` says all rights are reserved until the
   maintainer chooses a license.
3. **Economy after the timing changes (GDD 15.2, 18.5, 5.1, 61.5).** Resolved on
   2026-09-29. The TEST_LONGRUN_100 bot did not go broke because of the economy. The
   day after it moved to Tier 3, all three ovens held burnt trays while the player
   carried dough. Trainee bakers never take trays out (0% auto-retrieve), the player's
   hands were full, and dough can only go into an oven, so the kitchen was
   soft-locked for good. The idle ovens kept charging utility (about 338 KR a day),
   which held the balance at 0. The faster timings only made the pile-up more likely.
   The maintainer chose the fix: dough in hand replaces a burnt tray (GDD 16.5, 62;
   ACC_62_BURNT_SWAP). The same investigation found that text-ID sorting depended on
   memory addresses, which let the same seed play out differently between sessions.
   It is fixed (ACC_116_ID_ORDER). After the fixes, with the RotiFood cutoff at 16:55
   (GDD 22.9), TEST_LONGRUN_100 passes and the bot keeps growing at Tier 3 (78,533 KR on
   day 101). TEST_LONGRUN_500/1000 have not been re-run since 2026-09-28.
4. **Game length (resolved 2026-09-29).** The maintainer's target: a typical player at
   about 2× owns every location, every slot at Tier 5 and all shop decor in about 6 hours,
   then just enjoys being rich. A throwaway simulator played new games through the same
   APIs as the UI. Before the changes an optimal bot finished in 12–13 in-game days (about
   5 h at 1×, 1.7 h at 3×), mainly by buying high-tier equipment in the Garage, charging
   1.8× to the price-blind Day 1–3 manifest customers, and stocking 1.8× "bait" bread that
   RotiFood ordered anyway. The maintainer approved the Market tier gate (5.1.2), the
   Day 1–3 price lock (63.2) and price-weighted RotiFood menus (22.9). The runs also
   exposed two soft-locks, both fixed. First, a tray protected for a fired or benched baker
   locked its oven and every location upgrade (18.8, 87.2). Second, bakers left unfinished
   batches at 18:00 on most evenings, which blocked upgrades. The maintainer chose the
   17:30 baker cutoff (23.3). With these rules and **no change to any cost**, a "typical
   player" bot (reference prices, the two most profitable recipes, upgrade then re-equip,
   spend only with a cushion) finished in 20–26 days (mean 23.3 over six seeds), and the
   optimal bot in 18–19 days. At 2× plus about a minute of menus per day, with a human
   assumed about 15% slower than the bot, that is about 6 hours. The maintainer's own
   playtest is the real check. Re-run on 2026-09-30 after every checkout became 3 s:
   the typical bot finished in 20–25 days (mean 22.8 over the same six seeds) and the
   optimal bot in 18 days, so the target still holds. Re-run again after the Tier 2/4
   cashier perks (the bots hire both tiers): typical 20–27 days (mean 23.5), optimal 17.
   The shifts are within seed-to-seed noise; the target still holds.
5. **Cashier tiers after the 3 s checkout (resolved 2026-09-30).** Every checkout became
   3 s, so cashier speed no longer set the tiers apart and Tier 2 and Tier 4 had no
   advantage over Tier 1. The maintainer chose "patient + friendly" (GDD 3.1): Tier 2
   calms its queue by 8%, Tier 4 by 15% and lifts the rating 1.5× per sale; wages and the
   other tiers are unchanged (ACC_3_CASHIER_PERKS). Hendra's bio no longer mentions the
   removed Indecisive Shopper perk.
6. **Placed decorations were not drawn (resolved 2026-09-30).** The maintainer asked for
   a model for every decoration and slot rules capped by store tier (GDD 72.3). All 23
   placeable decorations now have models and are drawn; the caps, slots, rugs and
   old-save clean-up are tested (ACC_72_DECOR_*, TEST_VIS_DECOR_*, TEST_UI_DECOR_SLOTS).
