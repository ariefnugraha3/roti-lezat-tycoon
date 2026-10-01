# Architecture

Roti Lezat Tycoon is a Godot 4.7 (GDScript, Compatibility renderer) bakery tycoon. The
only design authority is `docs/gdd-roti-lezaat-tycoon-ai-ready-v3.1-final.md` (GDD v3.1).
This document describes how the code implements it: who owns which state, how a tick
runs, and how data flows from catalogs to simulation, UI and saves. Numbers live in
the data catalogs, not here (GDD 126.1).

## 1. Top-level layout

| Folder | Role |
|---|---|
| `autoload/` | The seven global services of GDD 35.2 (below). None of them own gameplay state. |
| `core/` | Stateless helpers and the base classes shared by managers: `SimManager`, `TimeManager`, `RNGManager`, `Money`, `GridMath`, `Tx`, `Palette`, `InputActions`, `CommandLayer`. |
| `data/catalog/` | JSON catalogs, the single runtime authority for content and tuning (GDD 101, 134). |
| `data/definitions/` | Typed definition classes built from the catalogs (`RecipeDefinition`, `EquipmentDefinition`, …). |
| `gameplay/` | The simulation: `SimulationRoot` and every manager, grouped by domain. |
| `procedural/` | The three visual factory layers of GDD 12.3: meshes, animation, UI. |
| `audio/` | `AudioGenerator`, which synthesizes every sound and music loop from code. |
| `ui/` | `ModalHost`, `ScreenRegistry`, the HUD and every screen. |
| `scenes/` | `main.tscn` → `GameRoot`, the application shell. |
| `tests/` | Headless harness, suites, `SimBot`, fixtures. |
| `tools/` | Release validator, string lint, compile check, icon generator. |

## 2. Autoloads (GDD 35.2, 98)

Autoloads are services. Gameplay state never lives in them, so tearing down a
`SimulationRoot` resets the game completely.

| Autoload | Responsibility |
|---|---|
| `GameLogger` | Leveled, categorized logging (GDD 117). It is named `GameLogger` because Godot 4.5+ has a built-in `Logger` class. |
| `DataRegistry` | Loads and validates every catalog at boot and derives price bounds (GDD 63.2). Provides typed accessors, `bal(path)` tuning lookups (cached), and the English string table. |
| `EventBus` | Cross-layer signals: simulation → UI/audio/world view, plus UI request signals. |
| `SettingsManager` | `user://settings.json`: volumes, quality, accessibility, Smart Speed (GDD 75). |
| `PauseManager` | A set of pause reasons (user, modal, lifecycle). The simulation runs only when the set is empty (GDD 71, 90). |
| `SaveManager` | Three profiles, atomic writes, backup, migration and validation (GDD 106). It asks `SimulationRoot` for snapshots and holds no state of its own. See `docs/SAVE_SCHEMA.md`. |
| `AudioManager` | Pooled voices, priorities, cooldowns, ducking, music states, captions, and the web audio unlock (GDD 33, 93). |

## 3. Simulation

### 3.1 SimulationRoot and managers

`gameplay/simulation_root.gd` is created per profile by `GameRoot` (or by a test).
It owns one instance of each manager as a child `SimManager` node:

| Domain | Managers (file) | Owns |
|---|---|---|
| Clock & RNG | `TimeManager`, `RNGManager` (`core/`) | Day, time, phase, speed; the eight RNG streams of GDD 116. |
| Economy | `EconomyManager`, `InventoryManager`, `PricingManager` (`gameplay/economy/`) | Balance and ledger; ingredient stock; price overrides. |
| Production | `EquipmentManager`, `ProductionManager`, `DisplayInventoryManager` (`gameplay/production/`) | Equipment instances and utility; production jobs (GDD 18), including dough and trays parked on the Holding Table (stages `DOUGH_ON_TABLE`/`TRAY_ON_TABLE`, aged and discarded by `ProductionManager.age_table`, GDD 5.1.3, 19.7.6); display slots and `BreadStack`s with freshness (GDD 19). Storage and the Holding Table are building fixtures (`EquipmentManager.is_fixture`): one per location, never sold or put away, outside slot limits. |
| World | `WorldManager`, `DecorationManager` (`gameplay/world/`) | Location, per-floor `FloorGrid`, placement validation, routes, exclusive points; decorations. |
| Actors | `PlayerTaskManager` (`gameplay/actors/`) | The player character and its command queue (GDD 16). |
| Customers | `QueueManager`, `CashierManager`, `CustomerManager`, `DemandManager` (`gameplay/customers/`) | Lanes and reservations; transactions; walk-in customers; arrivals and the pending pool. |
| Delivery & supply | `RotiFoodManager` (`gameplay/delivery/`), `SupplyOrderManager` (`gameplay/supply/`) | RotiFood orders and drivers; market orders and couriers. |
| Staff | `StaffManager` (`gameplay/staff/`) | Contracts, duty, wage liability, staff actors and tasks. |
| Meta | `gameplay/meta/`: reputation, weather, marketing, bailout, statistics, analytics, achievements, tutorial, alerts, day reports | Their respective GDD systems. |

Every field has exactly one owning manager (GDD 98). Other managers call its methods
and never write its fields directly.

### 3.2 The tick (GDD 102)

`SimulationRoot.advance(real_delta)` accumulates real time × speed and runs fixed
ticks of `clock.sim_tick_seconds` (0.05 s). At most 16 ticks run per frame, and
nothing runs while any pause reason is active. One `step(dt)` calls the managers in
this fixed order:

```
time.advance → (18:00 → close_day) → production → equipment (utility) → supply
→ display (aging) → player → staff → demand → customers → cashier → rotifood → alerts
```

Economy, reputation and statistics are updated inside those calls, at the moment
each event commits. Presentation never runs inside a tick. The world view, HUD and
audio read state every frame and react to `EventBus` signals. Iteration inside a
manager uses sorted IDs, never node order, so the same ticks give the same result
at any speed (`TEST_TIME_002`). Text IDs are sorted with `Ids.sort` (`core/ids.gd`).
A plain `Array.sort()` orders StringName by internal address, so the order, and
with it the whole run, would change between sessions (`ACC_116_ID_ORDER`).

One sim-second is one real second at 1×. Each sim-second advances the in-game clock by
`clock.ingame_seconds_per_sim_second` (GDD 15.2, 99.1).

### 3.3 Day flow (GDD 15, 104)

- **05:00 `_begin_day`**: daily resets, the overnight freshness rollover (exactly
  once), weather, bailout grant, staff wage liability locked, Day 1–3 opening stock,
  and demand planning.
- **08:00**: `TimeManager` switches the phase to `open`.
- **18:00 `close_day`**: the GDD 104 shutdown matrix. Customers return held bread,
  unpacked or unhandled RotiFood orders are cancelled, supply orders are committed,
  staff go home. Then settlement (utility, wages), the day report, analytics and
  achievements, market unlock after Day 3, and a critical autosave.
- **After hours**: management (hire, market, equipment, upgrade). Then
  `continue_to_next_day` starts the next day at 05:00.

### 3.4 Key flows

- **Production** (GDD 18): `create_job` deducts ingredients atomically → `start_mixing`
  → the mixer holds the dough until pickup → `insert_oven` → `READY_PERFECT` →
  `OVERBAKING` → `BURNT` using the oven tier's windows (GDD 62) → `pickup_tray` →
  `place_from_tray`, one slot at a time, via the slot picker. Player jobs wait for a
  tap at each stage. Bakers follow the GDD 23.3 priorities.
- **Customers** (GDD 20, 84): `DemandManager` produces arrivals (the Day 1–3
  manifest, then a Poisson process). An arrival needs a queue reservation
  (`QueueManager.reserve`), otherwise it goes to the pending pool (30 s, or 40 s
  for drivers). A customer chooses a recipe and walks to the nearest display with it.
  Stock is revalidated and taken on arrival. Substitution uses the GDD 84.3 score.
  The customer then queues. The service point frees the slot, and the cashier
  completes the transaction in the GDD 103.1 order.
- **Window shoppers** (GDD 20.12) are `Customer` objects with `window_shopper = true`
  and ids `w…`, which sort after the buyers' `c…`. `DemandManager` admits them from the
  Day 1–3 manifest or a Poisson process drawn from `cosmetic_rng`, without a queue
  reservation or a pending pool. `CustomerManager` walks them to a free spot in front of
  or beside a display, lets them look, and walks them out. They step aside when a buyer
  heads for their tile. Nothing a buyer does depends on them.
- **RotiFood** (GDD 22): orders never reserve stock. `pack` takes every item or
  none. Handover credits the sale once (`economy_committed`).
- **Supply** (GDD 5.2.3, 70): daytime purchases pay immediately and arrive 3 in-game
  hours later. Stock commits when the courier drops the package, with one courier at
  the staging point at a time. After-hours purchases commit instantly.
- **Upgrade** (GDD 47, 105): the upgrade needs no production jobs and nothing
  carried. The code takes a snapshot, charges the upgrade, migrates the equipment
  with deterministic auto-placement, and checks protected paths. On any failure it
  restores the snapshot, so nothing is lost.

## 4. World, grid and navigation (GDD 17, 56, 57, 60, 68)

- `FloorDefinition` (from `locations.json`) lists zones, protected cells, staff-only
  cells, counters, lanes (queue slots, service point, cashier point), the RotiFood
  counter, supply drop-off and portal.
- `FloorGrid` holds the tile flags of GDD 56.1.1 and two `AStarGrid2D` graphs: staff
  (the whole floor) and public (store zone only). The stair-door cell can be passed
  by staff (GDD 56.1 `STAIR_DOOR_POINT`).
- `WorldManager.validate_placement` rejects out-of-bounds or wrong-zone placements,
  overlaps, reserved cells and a missing access tile. A BFS then checks that every
  critical node is still connected before the placement commits.
- `WorldManager.keep_clear_cells(floor)` lists the tiles that must stay clear
  (walkway, queue, service points, access tiles, and chokepoints whose blocking
  alone breaks a required path). Chokepoints come from one Tarjan articulation
  pass per nav graph, sharing `_floor_targets()` with the connectivity check.
  Decoration Mode stripes these tiles and warns when a placement would block the
  walkway.
- Decorations (GDD 72.1, 72.3) all go on the shop floor, capped per type by the
  location's `decor_slots`. `DecorSlots` (`gameplay/world/decor_slots.gd`) derives the
  wall spots (between the windows of the two full walls) and the counter spots (the end
  of each register counter away from the paper bag) from the layout template, so saves
  store only a slot number. `DecorationManager.check_place` is the one validation for
  every type (cap, slot, floor tile, rug footprint); `enforce_rules()` runs after load
  and after moving shop and puts back what no longer fits, oldest uid first. Rugs never
  enter `decor_at`, so they never block anyone.
- Routes are cell paths smoothed by line of sight. Between floors a route has one
  instant portal waypoint (GDD 68). Positions are logical metres (0.5 m per tile).

## 5. Presentation

- `GameRoot` (`scenes/game_root.gd`) is the shell: splash, main menu, new game or
  load, building and tearing down `SimulationRoot` + `WorldView` + `HUD`, routing
  world taps, the music state, and lifecycle handling. New game and load run in
  stages behind `ui/components/loading_screen.gd` (GDD 89.5): each heavy stage gets
  a frame so the bar is drawn, and `playing` turns true only when the overlay fades.
- Phone browsers (GDD 12.5): `core/web_platform.gd` is the only code that calls
  JavaScript (`JavaScriptBridge`): phone detection, portrait check, fullscreen plus
  landscape lock. `ui/components/orientation_guard.gd` covers the game and pauses it
  while the phone is upright; the Tap to Start tap (on release) requests fullscreen.
- `WorldView` (`gameplay/world/world_view.gd`) mirrors the simulation. It builds
  rooms and equipment with the factories, pools actor views, shows station markers,
  bread and ghosts, and does picking. `CameraRig` frames floors that fit the viewport
  whole and follows the player on larger floors. A floor change uses a 0.20 s
  crossfade (GDD 30).
- UI: `ModalHost` keeps a stack of `UIScreen`s registered in `ScreenRegistry`. A
  blocking screen pushes a pause reason and cleans up in `on_closed()`. Every visible
  text goes through `Tx.t(key, params)` → `strings_en.json` (GDD 43, 127).
- UI kit (GDD 130.6): `ProceduralUIFactory` owns every style. `cushion()` builds the
  button StyleBoxFlat for a state, `apply_kind()` restyles an existing button (tabs,
  speed buttons), and `button()` adds the `ButtonGloss` overlay and moves custom
  content down with the face while pressed. Screens build popups only through
  `UIScreen.make_popup` → `popup()` (ribbon title, round close button), tabs through
  `tab_bar()`, switches through `toggle()`, and HUD values through `chip()`. `IconCanvas`
  draws each icon three times (shadow, outline, fill); only primitives in the icon's
  base colour, or colours registered with `_shade()`, get the outline.
- Procedural factories (GDD 12.3): `ProceduralMeshFactory`, `BreadFactory`, `EquipmentFactory`,
  `CharacterFactory`, `RoomFactory`, `DecorFactory` (meshes); `ProceduralAnimationSystem`, `FX`
  (animation and particles); `ProceduralUIFactory`, `IconCanvas` (UI). Their shared
  caches are released by `ProceduralCaches.clear_all()` on exit.
- Characters (GDD 31, 130.2): `CharacterFactory` places one `Node3D` pivot per animated
  segment (`Body` with `Apron`, `ArmL`, `ArmR`; `Head` with `Face`; `LegL`, `LegR`) and
  stitches every static shape of a segment into a single vertex-coloured mesh with
  `MeshBuilder` (ellipsoids, tapered capsules, lathes, shell sections, tori). Eyes,
  brows and mouth stay separate because expressions scale and rotate them. That keeps a
  character at 12–14 draw calls and under 2,000 triangles. Every committed mesh carries
  `tris` and `aabb` metas so headless tests can check budgets and proportions.
  `ProceduralAnimationSystem.set_carry_pose()` swings both arms forward while an actor
  carries dough, a tray, a parcel or a customer's loose bread.
- Presentation-only behaviour (GDD 21.4, 31.6, 31.7) never touches the simulation:
  `WorldView` reads `CashierManager.packing_progress()` and drives a `PackBagRig`
  (`gameplay/world/pack_bag_rig.gd`) on the counter: bag opening, bread hopping in,
  ribbon and offer. It passes the same progress to the cashier's `pack` pose and the
  customer's `receive` pose, so hands and bag share the `pack_phases` beats. It also tells each player/staff
  `ActorView` whether it is busy, and drives the player's `ThoughtBubble`
  (`ui/components/thought_bubble.gd`, screen space) from the real-time "open shop, no
  customers" timer. `ActorView` owns the idle timer (a face wipe every 7.5 s, then dozing
  with floating "Z": staff at 12.5 s, the player at `DataRegistry.player_doze_after_seconds`,
  when the last thought ends); both timers use real seconds and stop while the game is
  paused. In Decoration Mode `WorldView` hides station markers, lifts the selected
  furniture (`set_lift`) and gives `top_of_iid` to the screen's floating action toolbar.
  It draws placed decorations with `DecorFactory` (one cached prototype per item,
  placed copies share meshes), swings the pendulums, makes decorations pickable, and
  shows the wall/counter slot markers the screen taps (`show_slot_markers`,
  `slot_at_screen`).
- Skip to Open (GDD 15.4) is not a presentation trick: `GameRoot` runs
  `SimulationRoot.skip_to_open_step` (ordinary ticks, a time budget per frame) behind
  `ui/components/skip_overlay.gd` instead of `advance`, so the result equals waiting.
- Audio: `AudioGenerator.build(generator_id)` renders each event in
  `audio_events.json`. `AudioManager` plays it. Music beds come from
  `audio/music_build.gd`, which renders a bed a slice at a time; `AudioManager` runs
  those jobs within a per-frame budget (`request_stream`, `prewarm_music`) and keeps
  the old bed playing until the new one is ready (GDD 33.6).

## 6. Data catalogs (GDD 101, 134)

`data/catalog/*.json`: ingredients, recipes, equipment, customers, staff, locations,
weather, marketing, opening (Day 1–3 manifest), balance (all tunables),
achievements, decorations, audio_events, quality_presets, strings_en. Each file
carries `catalog_schema_version` and `content_version`. `DataRegistry._validate*`
enforces GDD 133.1 at boot, and a failed validation shows the error screen instead
of starting a broken game.

## 7. Tests and tools

- `tests/test_runner.tscn` runs every suite in `tests/suites/`. A custom `Logger`
  turns any engine or script error during a test into a failure. Options:
  `--only=<prefix>`, `--skip-long`, `--update-fixtures`. The report is written to
  `user://test_report.json`.
- `tests/sim_bot.gd` (`SimBot`) plays through the same APIs as the UI. With
  `manage = true` it also hires, buys equipment and upgrades, for the soaks.
- `tools/release_validator.tscn` is the GDD 133 release gate.
  `tools/string_lint.gd` handles key completeness and the English lint.
  `tools/generate_icon.gd` generates `icon.svg`. `tools/compile_check.tscn` checks
  that every script compiles. `tools/character_lineup.tscn` (run windowed, not
  headless) renders every character variant from the front, 3/4, back, a face
  close-up with all five moods, and the gameplay camera to PNGs in `LINEUP_OUT`
  (default `user://lineup`), plus a triangle and draw-call report, and a poses page
  (packing, face wipe, dozing, carried bread and bag, thought bubble) with a
  window-shopper row (head sweep and hand-on-chin at several moments).
  `tools/world_snapshot.tscn` (also windowed) plays a real day with `SimBot` and
  captures the shop at the gameplay camera: the packing sequence at the counter
  (`pack_seq_*.png` plus a `pack_sequence.png` strip), packing in the overview and close-up,
  a window shopper looking at the display, the quiet-shop thought bubble, the dozing player, and the Holding Table with dough
  and trays at different freshness (with and without its marker).
