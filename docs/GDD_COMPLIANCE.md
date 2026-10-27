# Idle GDD Compliance Checklist

This checklist maps each system of the idle GDD (`docs/gdd-roti-lezat-idle-v1.md`) to the
code that implements it and the tests that verify it. The idle GDD replaces GDD v3.1 on
this branch; the v3.1 rules it keeps (art direction, grid and navigation, modal stack,
input, camera, characters, interiors and neighbourhoods, audio policy, save mechanics,
performance, English text, accessibility, layout templates, Decoration Mode, technical
contract) are listed with their v3.1 section numbers. Implementation decisions that
the GDD left open are recorded in idle GDD §20.

**Status legend**

- **Tested**: an automated test in `tests/suites/` asserts the rule.
- **Implemented**: the code exists and runs in the smoke, UI and soak tests, but no
  test asserts this specific rule.
- **Not verified**: needs target hardware, an actual export, or a manual check that
  has not been done yet.
- **Open**: needs a maintainer decision.

Last full run: see the latest commit message. `--skip-long` runs every suite except the
soaks; `ACC_IDLE_PACING` and the soaks are long tests.

## Loop, time and automation (idle §2–§5)

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 2.3, 3.1 | The shop runs itself 24 hours a day; a new game left alone keeps selling and never stalls | `gameplay/simulation_root.gd`, `core/time_manager.gd` | ACC_IDLE_NO_INPUT, SMOKE_002, TEST_TIME_001 | Tested |
| 0.2, 3.4 | One speed (1 real s = 1 in-game min); only Pause stops the clock; focus loss pauses and saves, focus return resumes at once | `simulation_root.gd` `advance`, `autoload/pause_manager.gd`, `scenes/game_root.gd` | ACC_IDLE_ONE_SPEED, TEST_TIME_002, TEST_LIFECYCLE_001 | Tested |
| 3.2 | Nights 22:00–06:00 with fewer arrivals and RotiFood orders | `time_manager.gd` `is_night`, `simulation_root.gd` `night_*_mult` | TEST_TIME_001, ACC_IDLE_MODEL_MATCH | Tested |
| 4.3 | Kitchen workers fill the emptiest slot; batch = largest multiple that fits the slot's room | `gameplay/actors/kitchen_brain.gd` | ACC_IDLE_AUTOMATION, TEST_PRODUCTION_001 | Tested |
| 4.5, 18.9 | Stage durations from the recipe, batch factor and station level | `production/production_manager.gd` | TEST_PRODUCTION_003, ACC_18_BATCH_DURATION | Tested |
| 4.6 | No burnt or stale state; finished stations hold their contents without limit | `production_manager.gd`, `display_inventory_manager.gd` | ACC_IDLE_NO_BURN_NO_STALE | Tested |
| 5.1 | The owner works automatically; a tap on the counter sends them to lane A for the focus time | `actors/player_task_manager.gd` | ACC_IDLE_AUTOMATION, ACC_21_PLAYER_AND_CASHIER | Tested |
| 5.2 | Semangat tap boost and its minimum gap | `player_task_manager.gd`, `ui/hud/hud.gd` | ACC_IDLE_TAP_BOOST | Tested |
| 5.3, 5.5 | Bakers and cashiers work on their own; hiring from a rising cost list; no wages or tiers | `staff/staff_manager.gd` | TEST_STAFF_001, ACC_23_BAKER_WORKS, ACC_3_STAFF_EQUAL, ACC_7_STAFF_HIRE_FROM_DETAIL | Tested |
| 6.5 | RotiFood accepted and packed automatically | `delivery/rotifood_manager.gd` | ACC_IDLE_AUTOMATION, TEST_ROTIFOOD_001 | Tested |

## Economy and levels (idle §7–§8)

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 7.1 | A new game opens with `start_kr` in one ledger entry | `economy/economy_manager.gd` `open_run` | ACC_IDLE_STARTING_CASH, SMOKE_001 | Tested |
| 7.2 | Unit price = base × recipe level × shelf bonus × decor × franchise × boost | `simulation_root.gd` `recipe_price`/`unit_price` | ACC_IDLE_PRESTIGE, ACC_IDLE_DECOR_BONUS, ACC_IDLE_BOOSTS | Tested |
| 7.4 | Ledger categories, rounding, reconciliation | `economy_manager.gd` | TEST_ECONOMY_001 | Tested |
| 7.5 | Big numbers K…T, aa…; scientific option; finite to 1e300; overflow guard ends at ∞ | `core/tx.gd`, `economy_manager.gd` | ACC_IDLE_BIG_NUMBERS | Tested |
| 8.1–8.9 | Cost formulas, ×1/×10/Max, caps, extra instances, opening stations (blocked with no free spot), unlocks, hires, locations, global upgrades | `economy/upgrade_manager.gd` | ACC_IDLE_COSTS, ACC_IDLE_SHOP_SHEET | Tested |
| 8.2, 8.5 | Milestone multipliers; model evolution (nearest legal spot, or waiting) | `upgrade_manager.gd` `evolve` | ACC_IDLE_MILESTONES | Tested |
| 8.7 | Moving location while open keeps every level | `simulation_root.gd` `upgrade_location` | TEST_UPGRADE_001, ACC_105_UPGRADE_WITH_DECOR | Tested |
| 8.8 | Decoration bonuses, once per type per run; prices × `decor.price_mult_by_tier` | `world/decoration_manager.gd` | ACC_IDLE_DECOR_BONUS | Tested |

## Analytic model and offline (idle §9)

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 9.1 | Steady-state KR/s within ±20% of the live simulation at the Tier 1–5 sample shops | `economy/idle_economy_manager.gd`, `tests/model_sample.gd`, `tools/model_probe.tscn` | ACC_IDLE_MODEL_MATCH | Tested |
| 9.2–9.4 | Offline earnings, cap and efficiency, thresholds, clock going backwards, stats | `meta/offline_manager.gd` | ACC_IDLE_OFFLINE | Tested |
| 9.5 | Welcome Back popup with Collect, coin shower and Pak Lurah | `ui/screens/welcome_back_screen.gd`, `game_root.gd` `check_offline` | ACC_IDLE_WELCOME_BACK | Tested |

## Franchise, boosts, achievements, onboarding (idle §10, §11, §13)

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 10.1–10.5 | Stars, condition, reset/keep list, perks | `meta/prestige_manager.gd`, `simulation_root.gd` `franchise` | ACC_IDLE_PRESTIGE | Tested |
| 10.6 | Franchise sheet, confirm, Pak Lurah cutscene, new branch behind the loading screen | `ui/screens/franchise_screen.gd`, `franchise_cutscene.gd`, `game_root.gd` `do_franchise` | ACC_IDLE_FRANCHISE_FLOW | Tested |
| 11.1–11.2 | Coffee once per device day, promotions with cost and cooldown, boosts only while playing | `meta/boost_manager.gd`, `ui/screens/upgrades_screen.gd`, `hud.gd` | ACC_IDLE_BOOSTS, ACC_IDLE_BOOST_UI | Tested |
| 11.3 | Rain and holiday multipliers | `world/weather_manager.gd`, `data/catalog/weather.json` | ACC_IDLE_MODEL_MATCH (neutral weather), soaks | Implemented |
| 11.4 | Idle milestones with badges and a ×2 boost; kept across franchises | `meta/achievement_manager.gd`, `data/catalog/achievements.json` | ACC_IDLE_ACHIEVEMENTS, ACC_72_BADGES | Tested |
| 13 | Onboarding steps once on their triggers, never holding the economy | `meta/tutorial_manager.gd`, `game_root.gd` `_show_tutorial_prompt` | ACC_IDLE_ONBOARDING, ACC_IDLE_BOOST_UI | Tested |
| 1.4 | Pacing targets for a typical player (median of three SimBot seeds), franchise, second run ≤ 70% | `tests/sim_bot.gd`, `tests/pacing_tracker.gd`, `tools/idle_probe.tscn`, `data/catalog/idle.json` | ACC_IDLE_PACING (long) | Tested; measured times in idle GDD §20 no. 40; the second recipe is measured as affordable (open decision 2) |

## Portrait UI (idle §12)

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 12.0.2 | Portrait frame 720 wide, 9:16–9:21, taps on the tablecloth ignored | `scenes/portrait_shell.gd` | ACC_IDLE_PORTRAIT_FRAME | Tested |
| 12.0.3 | Gingham tablecloth with lace outside the frame | `ui/components/tablecloth_sides.gd` | ACC_IDLE_TABLECLOTH_SIDES | Tested |
| 12.0.4 | `KEEP_WIDTH` camera; Tier 1–3 floors whole between the HUD bars | `world/camera_rig.gd` | ACC_IDLE_PORTRAIT_CAMERA, TEST_CAMERA_001 | Tested |
| 12.0.6 | One-time "Turn your phone upright" hint on sideways phone browsers | `ui/components/orientation_hint.gd` | ACC_12_ORIENTATION_HINT | Tested |
| 12.0.7 | Every screen fits the frame with no sideways scroll on the whole matrix at 100/125/150% | every screen | ACC_IDLE_PORTRAIT_UI; `tools/ui_resolution_sweep.tscn` (renders) | Tested |
| 12.1 | HUD: KR, KR/s, boost chips, reputation, stars, tab bar with green dots, level chips | `ui/hud/hud.gd`, `ui/components/level_chips.gd` | ACC_IDLE_LEVEL_CHIPS, ACC_IDLE_BOOST_UI | Tested |
| 12.2 | Upgrade card above its station | `ui/screens/upgrade_card.gd` | ACC_IDLE_UPGRADE_CARD | Tested |
| 12.3 | Upgrades, Menu, Staff, Shop, Franchise, Stats sheets | `ui/screens/*` | ACC_IDLE_UPGRADES_SHEET, ACC_IDLE_MENU_SLOTS, ACC_IDLE_MENU_RECIPES, ACC_7_STAFF_NO_SIDE_SCROLL, ACC_IDLE_SHOP_SHEET, ACC_IDLE_FRANCHISE_FLOW, TEST_UI_SMOKE_001 | Tested |

## Save (idle §15)

| GDD | Rule | Code | Tests | Status |
|---|---|---|---|---|
| 15.3 | Idle schema 1, idle fields, removed fields; roundtrip; classic v3.1 saves refused | `autoload/save_manager.gd`, `simulation_root.gd`, `docs/SAVE_SCHEMA.md` | ACC_IDLE_SAVE, TEST_SAVE_001, TEST_SAVE_002, TEST_PROFILE_001 | Tested |
| 15.4 | Deterministic live simulation per seed; offline is analytic | `core/rng_manager.gd`, `core/ids.gd` | TEST_RNG_001, ACC_116_ID_ORDER, TEST_SAVE_001 | Tested |

## Kept from GDD v3.1

| v3.1 | Rule | Tests | Status |
|---|---|---|---|
| 17, 56, 57, 60 | Grid, placement, protected paths, layout templates | ACC_LAYOUT_SOLVER, ACC_81_PLACEMENT, ACC_DECOR_KEEP_CLEAR, ACC_SPATIAL | Tested |
| 21, 57.6, 83 | Queues, lanes, reservations, lane split | TEST_QUEUE_001, TEST_QUEUE_002, ACC_21_LANES_PER_TIER, ACC_21_QUEUE_SPLIT, ACC_21_CASHIER_LANES_SERVE | Tested |
| 20, 84 | Customers, targets, quantities, window shoppers, walking in from the street | TEST_CUSTOMER_001, TEST_CUSTOMER_002, ACC_20_WINDOW_SHOPPER*, ACC_20_STREET_* | Tested |
| 28.2 | Modal stack (overlays, keep_open) | TEST_UI_SMOKE_001, ACC_IDLE_WELCOME_BACK, ACC_IDLE_FRANCHISE_FLOW | Tested |
| 31 | Characters, idle gestures, staff lines, surprises | ACC_31_* | Tested |
| 32 | Interiors, neighbourhoods, daylight, street life, rain, holidays | ACC_32_* | Tested |
| 33 | Audio buses, music beds built in slices, prebuilt sounds | ACC_33_* | Tested |
| 68 | Multi-floor locations | TEST_MULTIFLOOR_001 | Tested |
| 72 | Decoration Mode (Sims-style hold, drag, tap-through, slots, rugs, badges) | ACC_72_* , TEST_UI_DECOR_SLOTS, TEST_VIS_DECOR_* | Tested |
| 89.5, 109 | Loading stages, shader warm-up, few shader combinations, baked models and draw-call budget | TEST_UI_LOADING_STAGES, ACC_89_*, ACC_109_* | Tested |
| 129 | Transient effect limits | ACC_129_LIMITS, ACC_129_FX_TEARDOWN | Tested |
| 130.6 | Flat UI kit, scrollbar gap, recipe art | ACC_130_FLAT_UI, ACC_130_SCROLLBAR_GAP, ACC_7_RECIPE_ART | Tested |
| 43, 127 | English text from the catalog | TEST_UI_001 (`tools/string_lint.gd`) | Tested |
| 94 | Long sessions | TEST_LONGRUN_100/500/1000 (long) | Tested when the soaks are run |

## Platform and release

| Rule | Check | Status |
|---|---|---|
| Web export completes (single-threaded) | `tools/release_validator.tscn` (full run), `.github/workflows/deploy-web.yml` | Tested by the full validator |
| Android export | No Android SDK on the development machine | Not verified |
| Performance on entry-level Android and phone browsers | Needs hardware | Not verified |

## Open decisions

| No | Topic | Status |
|---|---|---|
| 1 | Project license | Open (maintainer) |
| 2 | Second recipe (idle §1.4 target 5–8 min) | Open (maintainer). With the idle §4.4/§8.5 formulas a recipe level costs `base × level_cost_mult × 1.12^(L−1)` and raises the price by a share of the same base, while the ingredient cost stays fixed. So the first recipe, once levelled, always earns more per bread than any newly unlocked recipe at Lv 1, Auto keeps selling it, and unlocking a second recipe never pays. A "best value" bot therefore never unlocks one; it becomes affordable at the time `MILESTONE second_recipe_affordable` reports (idle §20). Making the recipe ladder matter needs a formula change, e.g. level costs that do not scale with the base price, or a price multiplier per recipe tier. |
| 3 | Late-game reputation | Open (maintainer). Auto picks the highest net profit per bread (idle §4.2); at Tier 5 that can be a slow recipe the kitchen cannot supply, so KR/s jumps while reputation sinks to about ★1 under idle §6.6 (idle §20 no. 42). |
