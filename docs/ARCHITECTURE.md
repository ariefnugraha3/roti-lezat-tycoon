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
| Staff | `StaffManager` (`gameplay/staff/`) | Contracts, duty, wage liability (one wage per location tier), staff actors and tasks, cashier lane assignment, kitchen orders, staff chairs. |
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
→ display (aging) → player → staff → lane rebalancing → demand → customers → cashier → rotifood → alerts
```

Economy, reputation and statistics are updated inside those calls, at the moment
each event commits. Presentation never runs inside a tick. The world view, HUD and
audio read state every frame and react to `EventBus` signals. Iteration inside a
manager uses sorted IDs, never node order, so the same ticks give the same result
at any speed (`TEST_TIME_002`). Text IDs are sorted with `Ids.sort` (`core/ids.gd`).
A plain `Array.sort()` orders StringName by internal address, so the order, and
with it the whole run, would change between sessions (`ACC_116_ID_ORDER`).

At 1×, `SimulationRoot.advance` turns each real second into
`clock.sim_seconds_per_real_second` sim-seconds, and each sim-second advances the in-game
clock by `clock.ingame_seconds_per_sim_second` (GDD 15.2, 99.1).

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
  tap at each stage. Staff are equal since 2026-10-02 (no tiers, perks, work speed
  or auto-retrieve). Bakers only make what the player orders with Ask a Baker in the
  Recipe Book: `StaffManager.order_recipe` creates a job owned by `KITCHEN_ID`, and any
  baker on duty works its steps. Idle bakers also pick up the player's finished
  dough and trays (GDD 23.3), but skip any station a player command targets
  (`PlayerTaskManager.has_command_for`), and drop a step the moment such a command
  appears. Tapping the station again cancels the command (`cancel_command_for`).
  Bakers with nothing to do walk to a staff chair and sit (`SimActor.seat_iid`, drawn
  by `ActorView.set_seat` and `ProceduralAnimationSystem.sit`). With no baker on duty,
  kitchen jobs pass to the player.
- **Customers** (GDD 20, 84): `DemandManager` produces arrivals (the Day 1–3
  manifest, then a Poisson process). An arrival needs a queue reservation
  (`QueueManager.reserve`), otherwise it goes to the pending pool (30 s, or 40 s
  for drivers). A customer chooses a recipe and walks to the nearest display with it.
  Stock is revalidated and taken on arrival. Substitution uses the GDD 84.3 score.
  The customer then queues. The service point frees the slot, and the cashier
  completes the transaction in the GDD 103.1 order.
- **Checkout lanes** (GDD 21.2–21.3): two lanes at Tiers 1–3, three at Tiers 4–5.
  Lane A (`main`) is the player's and is open while the player stands at its cashier
  point (`is_manning_lane` checks the real position) or when no other lane is open;
  every other lane belongs to one cashier and is open while that cashier is on duty.
  `CustomerManager.rebalance_lanes`, run each tick before admission, moves unserved
  customers out of closed lanes and evens open lanes (front of line first) with
  `QueueManager.move_actor`, which moves the reservation without freeing a slot to a
  new arrival. Customers mid-checkout and RotiFood drivers never move.
- **Window shoppers** (GDD 20.12) are `Customer` objects with `window_shopper = true`
  and ids `w…`, which sort after the buyers' `c…`. `DemandManager` admits them from the
  Day 1–3 manifest or a Poisson process drawn from `cosmetic_rng`, without a queue
  reservation or a pending pool. `CustomerManager` walks them to a free spot in front of
  or beside a display, lets them look, and walks them out. They step aside when a buyer
  heads for their tile. Nothing a buyer does depends on them.
- **RotiFood** (GDD 22): orders never reserve stock. `pack` takes every item or
  none. Handover credits the sale once (`economy_committed`). `reject` (GDD 22.10)
  cancels an unpacked order at the player's request, sends any driver away and
  applies `rating.rotifood_events.order_rejected`; the popup asks first through
  `ModalHost.confirm`.
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
- UI kit (GDD 130.6): flat since 2026-10-02. With `ProceduralUIFactory.flat_style` on
  (the release setting), `panel()`, `cushion()` (`_flat_button_box`), badges, chips,
  popups, `IconCanvas` and the backdrop skip every shadow, lip, gloss, outline,
  gradient and paper grain, and `lip()`, `press_shift()` and `content_lift()` return 0,
  so content centres on the face. The rest of this bullet describes the cushion style,
  which is still in the code behind that flag.
  `ProceduralUIFactory` owns every style. `cushion()` builds the
  button StyleBoxFlat for a state, `apply_kind()` restyles an existing button (tabs,
  speed buttons), and `button()` adds the `ButtonGloss` overlay and moves custom
  content down with the face while pressed. Screens build popups only through
  `UIScreen.make_popup` → `popup()` (ribbon title, round close button), tabs through
  `tab_bar()`, switches through `toggle()`, and HUD values through `chip()`. `IconCanvas`
  draws each icon three times (shadow, outline, fill); only primitives in the icon's
  base colour, or colours registered with `_shade()`, get the outline.
- HUD (GDD 7): `HUD` refreshes its values 5 times a second, but rebuilds a list of
  tappable rows (RotiFood orders, floor alerts) only when a signature of its content
  changes. A button freed between press and release loses the tap. The RotiFood
  orders panel sits right above the Quick Menu, and `_fit_right_panels` keeps it as
  wide as the Display Stock panel and moves that panel up only to avoid an overlap.
  `RotiFoodButton` (`ui/components/rotifood_button.gd`) rings while an order waits to
  be packed. Its shake and pop run on a `Body` child, so they never fight the button's
  own press bounce. Quick Menu tiles are sized when the HUD is built, from the longest
  label at the current text scale (`_quick_tile_size`, `wrap_width`), so a two-line
  label always fits above the tile's lip. `_place_above_quick` keeps the RotiFood panel,
  the tutorial hint and the after-hours buttons above the bottom panels whatever
  their height.
- Procedural factories (GDD 12.3): `ProceduralMeshFactory`, `BreadFactory`, `EquipmentFactory`,
  `CharacterFactory`, `RoomFactory`, `DecorFactory`, `NeighborhoodFactory` (meshes); `ProceduralAnimationSystem`, `FX`
  (animation and particles); `ProceduralUIFactory`, `IconCanvas`, `BreadArt` (UI). Their shared
  caches are released by `ProceduralCaches.clear_all()` on exit. `BreadArt` builds each
  recipe picture once per `visual_profile_id` as a list of solid shapes in unit space
  (`shapes()`), so tests can check them, and scales that list in `_draw()`.
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
  customers" timer. `ActorView` owns the idle timer (a gesture every 7.5 s: the player
  wipes the face, staff take turns through `staff_idle_gestures` via
  `set_idle_gestures`; only the player dozes with floating "Z", at
  `DataRegistry.player_doze_after_seconds`, when the last thought ends). The teacup
  and coin are children of the `ActorView`, placed at the right hand each frame
  (`_update_props`), and notes, steam and flour puffs float like the "Z"
  (`_update_floaters`). Both timers use real seconds and stop while the game is
  paused. `WorldView._update_staff_lines` shows idle staff's lines (GDD 31.8) in one
  `ThoughtBubble` per staff member: at most one line a minute each, and only after a
  few seconds of idling. The guided Day 1 tutorial (GDD 88.1) is a step machine in
  `TutorialManager` (`GUIDED` prompts, `FLOW` transitions on world events,
  `guided_step` saved); `allows_tap` holds back only what a step needs. The UI shows
  the steps: `HUD` pulses the Decoration Mode button (`TutorialPulse`),
  `DecorationScreen` shows the tip and pulses Done and reports `decor_opened`/
  `decor_closed`, and `RecipeBookScreen` runs a `CoachMarks` spotlight tour that
  looks its targets up by node name every frame. After the holding table the
  steps go on to Skip to Open (the `HUD` pulses its button), the opening tour, and
  the first customer. Steps whose state is already reached skip themselves
  (`TutorialManager._resolve`). A prompt with a `spotlight` (the opening tour, the
  first customer, and one-off tips for the first window shopper who leaves, the
  first surprise and the first RotiFood order) opens `TutorialSpotlight`, a system
  overlay that pauses the game and hosts `CoachMarks` over HUD panels or world
  models; `WorldView.screen_rect_of` projects a model's meshes to a screen rect
  every frame. The view-side `SurpriseDirector` reports its first scene with
  `TutorialManager.on_surprise`, the only way a surprise touches the simulation
  (a tip record). `CustomerOrderScreen` spotlights OK while the player learns to
  serve. When the shop closes on Day 1 the steps continue after hours:
  `DailySummaryScreen` spotlights Manage Staff once its tip is closed, and
  `StaffScreen` and `MarketingScreen` report `*_opened`/`*_closed` and run their
  own `CoachMarks` tours while their step is active (`TutorialManager.staff_tour`,
  `marketing_tour`). Later features are introduced once, on first contact (GDD
  88.4): `TutorialManager` raises spotlights from sim events (store open, day
  start, a Food Vlogger entering, a stack going stale with its shelf as
  `target_iid`, an achievement, Pak Lurah's visit), and screens ask
  `TutorialManager.screen_tour(id)` before running their own one-off tour, then
  `mark_tour(id)`. A `CoachMarks` step may carry an `enter` callable, which the
  Market tour uses to switch tabs. `SimBot` plays the same steps through the sim API (it re-places a shelf
  where it stands, parks the second tray on the holding table, and closes tips
  that pause the game like a player). `WorldView.highlight` marks the tutorial target (GDD 27.5):
  besides the gold floor ring, every mesh of the target model gets
  `ProceduralMeshFactory.flash_material()` as `material_overlay`, and `_update_blink`
  pulses its alpha each frame (steady with Reduced Motion) and re-applies it when the
  model is rebuilt. `SurpriseDirector` (`gameplay/world/surprise_director.gd`, a
  child of `WorldView`) plays the shop's surprise moments (GDD 31.9) with temporary
  `ActorView`s and `CritterFactory` models (`procedural/meshes/critter_factory.gd`)
  driven by unregistered `SimActor`s: routes only read the public nav graph, the
  schedule comes from a local `RandomNumberGenerator` seeded from the master seed and
  day, and nothing is saved. In Decoration Mode `WorldView` hides station markers and draws the held
  item at its candidate spot (`hold`/`release_hold`, GDD 72.2): the real model is
  re-posed (or a temporary one is built for an item in storage), lifted, re-applied
  after every rebuild, and put back on Cancel; the simulation layout changes only when
  the screen calls `place`. `hold_top` anchors the floating action toolbar and
  `hold_hit` tells `CommandLayer` (through the screen's `press_override`) whether a
  drag should move the held item instead of the camera.
- Shader compilation (GDD 89.5): WebGL compiles a shader the first time a material
  combination is drawn. `ShaderWarmup` (`gameplay/world/shader_warmup.gd`) draws one
  sample of every late-appearing visual below the floor during the `ui_loading_ovens`
  stage and after a location upgrade. `MaterialKeep` (`procedural/material_keep.gd`)
  keeps one material per feature combination alive for the whole process, because
  BaseMaterial3D frees a shader when its last material goes and would compile it again.
  Placement ghosts and tile overlays share one unshaded material
  (`ProceduralMeshFactory.overlay_material`/`tint_material`). Thin glass is unshaded
  and bread uses Lambert, so the whole game needs at most 12 shader combinations.
  None of them is lit and transparent, the slowest kind to compile in a browser.
  It draws placed decorations with `DecorFactory` (one cached prototype per item,
  placed copies share meshes), swings the pendulums, makes decorations pickable, and
  shows the wall/counter slot markers the screen taps (`show_slot_markers`,
  `slot_at_screen`).
- The room interior follows the location tier (GDD 32.3). `RoomFactory.interior_style`
  returns the floor pattern and colours per zone (checker, staggered planks from
  `EquipmentFactory._plank_plane`, or marble with brass `_inlay` lines), the wall,
  wainscot, rail, low wall, frame, curtain and zone-line colours. `build_floor` passes
  that style to the floor, wall, window, partition, portal and entrance builders.
  `EquipmentFactory.build_divider_counter` builds a different counter body per tier
  (`_counter_wood`, `_counter_glass`, `_counter_slats`, `_counter_marble`,
  `_counter_heritage`) around the same register, tablet and surface anchors.
  `build_holding_table(tier)` builds a different table per tier (`_table_*`) around
  the same Top anchor; `WorldView._equipment_model` passes the location tier.
- The neighbourhood outside the shop (GDD 32.5) is drawn by `NeighborhoodFactory`
  (`procedural/meshes/neighborhood_factory.gd`). It builds the Tier 1 kampung street,
  the Tier 2 shophouse street, the Tier 3 city avenue, the Tier 4 premium district
  and the Tier 5 heritage city square as one vertex-coloured `MeshBuilder` mesh with
  the shared matte material (`Street`). A location with an upper floor also gets
  `OwnBuilding`, the shop's own ground floor. Tiers without a street (`has_street`)
  get `null` and keep the plain background. `WorldView` builds it in `rebuild_all`
  only when the location changes, so a decoration change does not rebuild it.
  `_apply_floor_visibility` calls `show_for_floor`: on the shop floor the street
  stands at street level. From a floor above it drops `STOREY` per level
  (`floor_level` reads the number in `floor_N`) and shows `OwnBuilding` under the
  room. An unknown floor hides it. Nothing in it is pickable and the simulation
  never sees it. Vertex colours fade into
  `Palette.BG` with distance (`MeshBuilder.fade_to`, radii from `fade_radii`, further
  out for a bigger floor), so long pieces such as the road are cut into `PIECE`-long
  strips. Objects in front of and beside the shop stay low or
  far enough that the locked camera always sees the whole floor on screen.
  `ACC_32_NEIGHBORHOOD_CLEAR` projects every triangle along the camera ray, for every
  floor and its drop, to prove it.
- Outdoor life (GDD 32.6–32.10) is presentation only and reads the simulation without
  writing to it:
  - `Daylight` (`gameplay/world/daylight.gd`) samples warm keyframes by clock and rain.
    `WorldView.apply_daylight` (10 times a second) sets the sun and lamp lights that
    `RoomFactory` put on each floor, the ambient light and the background, and toggles
    the street's `LampGlow` mesh, which `NeighborhoodFactory` builds from the lamp
    heads it recorded, using the SHADOW material.
  - `StreetLife` (`gameplay/world/street_life.gd`, a child of `WorldView`) runs the
    lanes from `NeighborhoodFactory.traffic(tier)`. Vehicles are `TrafficFactory`
    meshes (MATTE, riders included) under a `Traffic` node inside the neighbourhood, so
    they drop with the street on upper floors. They come in four fade levels, built at
    most one per frame and cached. Walkers are a pool of `ActorView`s that are never
    registered with the simulation. Its own RNG is seeded from the master seed, the day
    and the tier. It moves in real seconds, stops while paused, and its density follows
    the quality preset (`density`, `max_walkers`).
  - Rain: `WorldView._build_neighborhood` rebuilds the street wet
    (`MeshBuilder.darken_ground`, puddles from `puddle_spots`) when the weather changes
    at 05:00. `StreetLife` adds ripples, raincoats and, where `umbrella_lift` allows,
    umbrellas.
  - `WorldView.ambience_for(rain, tier)` adds the tier's street loop.
    `StreetLife._chime` plays the Tier 5 clock tower once per in-game hour.
  - `HolidayFactory` builds the holiday bunting (on the store floor node) and banners
    (in the neighbourhood). `WorldView._apply_holiday` places them on every rebuild and
    day change.
- Skip to Open (GDD 15.4) is not a presentation trick: `GameRoot` runs
  `SimulationRoot.skip_to_open_step` (ordinary ticks, a time budget per frame) behind
  `ui/components/skip_overlay.gd` instead of `advance`, so the result equals waiting.
- Close Early (GDD 15.5) is the opposite: it does not simulate the skipped hours.
  `SimulationRoot.close_early` takes the rating penalty, moves the clock to 18:00 and
  calls the normal `close_day(early)`, so the 18:00 shutdown matrix (GDD 104) and the
  settlement run exactly once. The report carries `closed_early_at` and
  `close_early_penalty`.
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
- `tools/length_probe.tscn` (headless) measures the game length (GDD 2, target about 26
  in-game days): a bot plays a new game through the UI APIs until it owns Tier 5, Tier 5
  equipment in every slot and every shop decoration, printing one line per day and
  `RESULT ... goal_day=N`. Use `--seed=N --variant=typical|eager --days=N`, and run
  several seeds in parallel.
- `tools/ui_resolution_sweep.tscn` (windowed) opens the menu and in-game screens at the
  GDD 110 window sizes and text scales, saves half-size PNGs to `LINEUP_OUT`, and prints
  `SWEEP OFF` for every visible control outside the screen and `SWEEP done, N issues`
  at the end. It uses its own save folder.
- `.github/workflows/tests.yml` runs the compile check, the tests without the soaks
  and the quick release validator on every push and pull request to `main`.
