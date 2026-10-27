# Architecture

Roti Lezat Tycoon is a Godot 4.7 (GDScript, Compatibility renderer) bakery game. On the
branch `pivot-to-idle-game` it is an idle arcade bakery, and the design authority is
`docs/gdd-roti-lezat-idle-v1.md` (the idle GDD). It keeps the GDD v3.1 rules it lists in
its §0 (art, grid and navigation, characters, interiors, audio policy, save mechanics,
performance, English text, Decoration Mode, technical contract). This document
describes how the code implements it: who owns which state, how a tick runs, and how
data flows from catalogs to simulation, UI and saves. Numbers live in the data
catalogs, not here (GDD 126.1).

## 1. Top-level layout

| Folder | Role |
|---|---|
| `autoload/` | The seven global services of GDD 35.2 (below). None of them own gameplay state. |
| `core/` | Stateless helpers and the base classes shared by managers: `SimManager`, `TimeManager`, `RNGManager`, `Money`, `GridMath`, `Tx`, `Palette`, `InputActions`, `CommandLayer`. |
| `data/catalog/` | JSON catalogs, the single runtime authority for content and tuning (GDD 101, 134). The idle economy lives in `idle.json`. |
| `data/definitions/` | Typed definition classes built from the catalogs (`RecipeDefinition`, `EquipmentDefinition`, …). |
| `gameplay/` | The simulation: `SimulationRoot` and every manager, grouped by domain. |
| `procedural/` | The three visual factory layers of GDD 12.3: meshes, animation, UI. |
| `audio/` | `AudioGenerator`, which synthesizes every sound and music loop from code. |
| `ui/` | `ModalHost`, `ScreenRegistry`, the HUD and every screen. |
| `scenes/` | `main.tscn` → `PortraitShell` (the portrait frame, idle GDD §12.0) with `GameRoot` in its SubViewport. |
| `tests/` | Headless harness, suites, `SimBot`, `ModelSample`, `PacingTracker`, fixtures. |
| `tools/` | Release validator, string lint, compile check, icon generator, QA renders and probes. |

## 2. Autoloads (GDD 35.2, 98)

Autoloads are services. Gameplay state never lives in them, so tearing down a
`SimulationRoot` resets the game completely.

| Autoload | Responsibility |
|---|---|
| `GameLogger` | Leveled, categorized logging (GDD 117). It is named `GameLogger` because Godot 4.5+ has a built-in `Logger` class. |
| `DataRegistry` | Loads and validates every catalog at boot. Provides typed accessors, `bal(path)` and `idle(path)`/`idlef`/`idlei` tuning lookups (cached), and the English string table. |
| `EventBus` | Cross-layer signals: simulation → UI/audio/world view, plus UI request signals. |
| `SettingsManager` | `user://settings.json`: volumes, quality, text scale, number format, tutorial hints and accessibility (GDD 75). |
| `PauseManager` | A set of pause reasons (Pause menu, blocking modals, lifecycle). The simulation runs only when the set is empty. Losing focus pushes `lifecycle`; that time is counted as time away by `OfflineManager` (idle GDD §3.4, §9). |
| `SaveManager` | Three profiles, atomic writes, backup, validation, classic-save detection (idle GDD §15.3, v3.1 §106). It stamps the offline reference before each save and holds no state of its own. See `docs/SAVE_SCHEMA.md`. |
| `AudioManager` | Pooled voices, priorities, cooldowns, ducking, music states, captions, and the web audio unlock (GDD 33, 93). |

## 3. Simulation

### 3.1 SimulationRoot and managers

`gameplay/simulation_root.gd` is created per profile by `GameRoot` (or by a test).
It owns one instance of each manager as a child `SimManager` node:

| Domain | Managers (file) | Owns |
|---|---|---|
| Clock & RNG | `TimeManager`, `RNGManager` (`core/`) | Day and the 24-hour clock (nights 22:00–06:00); the RNG streams of GDD 116. |
| Economy | `EconomyManager`, `UpgradeManager`, `IdleEconomyManager` (`gameplay/economy/`) | Balance and ledger; every level (stations, counter, recipes, staff, global), recipe unlocks, opening stations and model evolution (idle §8); the analytic KR/s model (idle §9.1), which never touches the simulation. |
| Production | `EquipmentManager`, `ProductionManager`, `DisplayInventoryManager` (`gameplay/production/`) | Equipment instances; production jobs (mix → bake → shelf, idle §4.3), including dough and trays parked on the Holding Table; display slots with their recipe (`assign`, or Auto) and `BreadStack`s, which never age. Storage, the Holding Table and staff chairs are building fixtures (`EquipmentManager.is_fixture`). |
| World | `WorldManager`, `DecorationManager` (`gameplay/world/`) | Location, per-floor `FloorGrid`, placement validation (`find_spot`, `auto_place`), routes, exclusive points; decorations and their bonuses (idle §8.8). |
| Actors | `PlayerTaskManager`, `KitchenBrain` (`gameplay/actors/`) | The owner, who works automatically (serves lane A when buyers wait, otherwise cooks), the tap focus and Semangat boost (idle §5.1–5.2). `KitchenBrain` is the shared, stateless job picker for the owner and bakers (idle §4.3). |
| Customers | `QueueManager`, `CashierManager`, `CustomerManager`, `DemandManager` (`gameplay/customers/`) | Lanes and reservations; transactions; walk-in customers and window shoppers; arrivals and the pending pool. |
| Delivery | `RotiFoodManager` (`gameplay/delivery/`) | RotiFood orders, accepted and packed automatically, and their drivers. |
| Staff | `StaffManager` (`gameplay/staff/`) | Contracts (hire once, no wages), staff actors and tasks, cashier lane assignment, staff chairs. |
| Meta | `gameplay/meta/`: `ReputationManager`, `WeatherManager`, `PrestigeManager` (franchise stars, perks, branch number), `StatisticsManager`, `AchievementManager`, `TutorialManager` (onboarding, idle §13), `OfflineManager` (idle §9.2–9.4), `BoostManager` (coffee, promotions, achievement boosts, idle §11) | Their respective systems. |

Every field has exactly one owning manager (GDD 98). Other managers call its methods
and never write its fields directly.

### 3.2 The tick (GDD 102)

`SimulationRoot.advance(real_delta)` accumulates real time and runs fixed ticks of
`sim.tick_seconds` (0.05 sim-s). Nothing runs while any pause reason is active. One
`step(dt)` calls the managers in this fixed order:

```
time.advance (→ at 00:00 weather, statistics, RotiFood prune) → production → player → staff
→ lane rebalancing → demand → customers → cashier → rotifood → boosts → tutorial
```

Economy, reputation, statistics and achievements are updated inside those calls, at
the moment each event commits. Presentation never runs inside a tick. The world view,
HUD and audio read state every frame and react to `EventBus` signals. Iteration inside
a manager uses sorted IDs, never node order (`TEST_TIME_002`). Text IDs are sorted with
`Ids.sort` (`core/ids.gd`), because a plain `Array.sort()` orders StringName by internal
address and the run would change between sessions (`ACC_116_ID_ORDER`).

One real second advances `clock.sim_seconds_per_real_second` sim-seconds, and each
sim-second advances the in-game clock by `clock.ingame_seconds_per_sim_second`, so one
in-game minute takes one real second. There is one speed (idle §0.2). Real-time
systems (boost timers, promotion cooldowns) convert with `DataRegistry.real_seconds`.

### 3.3 The 24-hour shop (idle §3)

There are no phases, no opening or closing and no Daily Summary. The shop is open around
the clock; nights (`night.from_hour`–`night.to_hour`) bring fewer walk-ins and RotiFood
orders. At 00:00 the day number goes up, the weather is rolled and old RotiFood records
are pruned. A new game starts at `clock.start_seconds`.

### 3.4 Key flows

- **Production** (idle §4.3): an idle worker (the owner or a baker) asks
  `KitchenBrain.choose`: carried items are delivered first, then a finished tray is
  taken out, then dough goes into a free oven, then something on the Holding Table that
  now has a destination, then a new batch for the shelf slot with the lowest fill ratio.
  `plan_batch` picks the largest batch multiple that fits the slot's room and is
  affordable; the ingredient cost is paid when the job is created. Stations hold their
  contents without a time limit; nothing burns or goes stale.
- **Owner** (idle §5.1): `PlayerTaskManager` serves lane A while buyers wait there (or
  during a counter focus), otherwise works the kitchen. A tap on a station gives it the
  owner's focus and a Semangat boost (`tap.progress_seconds × tap_power`).
- **Customers** (GDD 20, 84): `DemandManager` produces arrivals (a Poisson process from
  `base_arrivals_per_hour × reputation × decor × boost × night × weather`). An arrival
  needs a queue reservation (`QueueManager.reserve`), otherwise it waits in the pending
  pool. An admitted customer walks from an end of the pavement to the door
  (`APPROACHING`, `StreetPaths`), then chooses a recipe and walks to the nearest display
  with it, takes the bread, queues and pays. Window shoppers only look (GDD 20.12).
- **Checkout lanes** (GDD 21.2–21.3): two lanes at Tiers 1–3, three at Tiers 4–5. Lane A
  is the owner's; every other lane belongs to one cashier. `CustomerManager.rebalance_lanes`
  evens the lines each tick before admission.
- **RotiFood** (idle §6.5): orders take their bread from the shelves all at once when it
  is there, are packed automatically by a free cashier or the owner, and are handed to
  the driver.
- **Levels** (idle §8): `UpgradeManager.offer(kind, id)` describes one upgrade (level,
  cap, base, growth, steps); `offer_cost`, `buy` (×1/×10/Max) and `buy_offer` spend
  through the ledger. Crossing a station threshold evolves the model
  (`evolve`: the next tier's definition, at the same place, the nearest legal spot, or
  waiting). Opening a station needs a free legal spot (`open_station_block`).
- **Location move** (idle §8.7): `SimulationRoot.upgrade_location` sends customers out,
  parks carried items on the Holding Table, lifts decorations, migrates the equipment
  with deterministic auto-placement and puts decorations back where they fit. On any
  failure it restores a snapshot.
- **Franchise** (idle §10): `SimulationRoot.franchise` adds the new stars, bumps the
  branch number, resets the run (economy, levels, stations, recipes, staff, reputation,
  boosts, global upgrades up to Lv 5), keeps stars, perks, statistics, achievements,
  decorations, the clock and the tutorial, applies the perks to the new branch, and
  saves. `GameRoot.do_franchise` rebuilds the world and HUD behind the loading screen.
- **KR/s model** (idle §9.1): `IdleEconomyManager.compute` estimates units per hour as the
  smallest of demand, queue capacity, machine capacity (with per-batch hand-off gaps
  along the real kitchen routes) and owner/staff time, separately for day and night,
  times the net profit per unit. It feeds the HUD, offline earnings, "Best value first"
  (`ranked_offers`, `delta_rate`) and `delta_unlock`. `ACC_IDLE_MODEL_MATCH` keeps it
  within ±20% of the live simulation (`tools/model_probe.tscn`).
- **Offline** (idle §9.2–9.4): `OfflineManager` keeps `last_active_unix` and the saved
  KR/s. `GameRoot.check_offline` (on load) and `_on_lifecycle_resumed` call `settle`;
  short absences are credited with a toast, longer ones wait in `pending` for the
  Welcome Back popup's Collect.
- **Boosts** (idle §11): `BoostManager` holds one income boost (coffee or achievement
  reward; a new one adds time) and one promotion with per-promotion cooldowns, all in
  real seconds of active play. `GameRoot.check_daily_gift` pours the coffee once per
  device date.
- **Street arrivals** (GDD 20.1, 22.6): buyers, window shoppers and RotiFood drivers walk
  in from the pavement (`core/street_paths.gd`); drivers set off early by the length of
  the walk. Whoever leaves through the door is released by the simulation;
  `WorldView._start_leaver` keeps their `ActorView` walking to the end of the pavement as
  a view only.

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
- Portrait frame (idle §12.0): `PortraitShell` (`scenes/portrait_shell.gd`) computes the
  frame box (720 logical px wide, 9:16–9:21) from the window, renders `GameRoot` in a
  `SubViewport` with `size_2d_override` 720 × H at the screen's real pixels, and draws
  the gingham `TableclothSides` outside it; taps on the tablecloth never reach the game.
  `core/web_platform.gd` is the only code that calls JavaScript (phone detection,
  fullscreen from a released tap); `ui/components/orientation_hint.gd` shows the
  one-time "Turn your phone upright" hint on sideways phone browsers.
- `WorldView` (`gameplay/world/world_view.gd`) mirrors the simulation. It builds
  rooms and equipment with the factories, pools actor views, shows station markers,
  bread and ghosts, and does picking. `CameraRig` frames floors that fit the viewport
  whole and follows the player on larger floors. A floor change uses a 0.20 s
  crossfade (GDD 30).
- Baked models (GDD 109.3): `procedural/meshes/mesh_bake.gd` stitches the static parts
  of an assembled model into one vertex-coloured `ArrayMesh` with one surface per
  material group, using the same shader combination as the parts. Furniture comes
  from `EquipmentFactory.build_cached` (one baked prototype per model, duplicated),
  bread from `BreadFactory.build_cached` and `slot_cached` (a display slot of up to
  three breads is one mesh), and `WorldView._bake_room` bakes each counter, the
  tablet and the stairs door on their own (their boxes are used for taps and tutorial
  spotlights) and the rest of a floor as one mesh. Moving parts keep their own nodes
  (`MeshBake.KEEP_NAMES`/`KEEP_PREFIXES`); display slots (`Slot*`) are left alone.
  `ShaderWarmup` places the baked models, so their prototypes are ready at loading.
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
- HUD (idle §12.1): `HUD` refreshes its values 5 times a second: KR, KR/s from the model,
  boost chips with their time left, reputation, Franchise Stars and the clock, a tab bar
  (Upgrades, Menu, Staff, Shop, Decor, Franchise) with a green dot when something inside
  is affordable (`has_affordable`), toasts, and `LevelChips` (projected 2D "Lv n" chips
  over every station, pooled and never rebuilt on refresh). Big screens are `UISheet`
  bottom sheets (non-blocking, one at a time, detail pages with Back); small popups
  (confirm, Welcome Back, cutscenes, tips) are cards or system overlays. Never rebuild a
  list of tappable buttons on every refresh: a button freed between press and release
  loses the tap.
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
  few seconds of idling. Onboarding (idle §13) is `TutorialManager.step`: every 0.5
  sim-s it checks the triggers (first sale, an affordable oven upgrade, first upgrade,
  first hire, an affordable recipe, Tier 2 in reach, franchising available) and shows
  each step once as a Pak Lurah popup (`TutorialModal`), a `TutorialSpotlight` over HUD
  panels or world models, or a hint above the tab bar with a pulsing tab or level chip
  (`HUD.show_tutorial_hint`, `TutorialPulse`). Hints the player has carried out close
  themselves. `WorldView.highlight` marks a world target (GDD 27.5): besides the gold
  floor ring, every mesh of the target model gets
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
    meshes (MATTE) under a `Traffic` node inside the neighbourhood, so they drop with
    the street on upper floors. Their riders are the shoppers' `CharacterFactory`
    models, posed and baked into the vehicle mesh. A vehicle is assembled from a plan
    (`TrafficFactory.plan`: the body, then one rider per `plan_step`, each character
    built in `MeshBuilder.capture` mode so nothing is uploaded and read back from the
    GPU), and each frame (pedalling or walking legs, four for bicycles, onthel, becak
    and the cart) at each of four fade levels is assembled from it (`frame_arrays`,
    `mesh_from`). All of this runs in steps within `WORK_USEC` per frame (at least
    one step); `_warm_step` prepares the tier's plans in the background, and a plan is
    dropped once all its meshes exist. Walkers are a pool of `ActorView`s that are never
    registered with the simulation. Its own RNG is seeded from the master seed, the day
    and the tier. It moves in real seconds, stops while paused, and its density follows
    the quality preset (`density`, `max_walkers`). Parked vehicles in the street mesh
    use the same `TrafficFactory` builders at `detail` 0.
  - Rain: `WorldView._build_neighborhood` rebuilds the street wet
    (`MeshBuilder.darken_ground`, puddles from `puddle_spots`) when the weather changes
    at 05:00. `StreetLife` adds ripples, raincoats and, where `umbrella_lift` allows,
    umbrellas.
  - `WorldView.ambience_for(rain, tier)` adds the tier's street loop.
    `StreetLife._chime` plays the Tier 5 clock tower once per in-game hour.
  - `HolidayFactory` builds the holiday bunting (on the store floor node) and banners
    (in the neighbourhood). `WorldView._apply_holiday` places them on every rebuild and
    day change.
- Audio: `AudioGenerator.build(generator_id)` renders each event in
  `audio_events.json`. `AudioManager` plays it. Music beds come from
  `audio/music_build.gd`, which renders a bed a slice at a time; `AudioManager` runs
  those jobs within a per-frame budget (`request_stream`, `prewarm_music`) and keeps
  the old bed playing until the new one is ready (GDD 33.6).

## 6. Data catalogs (GDD 101, 134)

`data/catalog/*.json`: idle (the idle economy: levels, costs, milestones, locations,
reputation, offline, prestige and perks, boosts and promotions, global upgrades, tap,
night), balance (clock, queues, production and other v3.1 tunables still in use),
recipes, equipment, ingredients (batch costs), customers, staff, locations, weather,
achievements, decorations (with bonuses), audio_events, quality_presets, strings_en.
Each file carries `catalog_schema_version` and `content_version`. `DataRegistry._validate*`
checks them at boot (`_validate_idle` for idle.json), and a failed validation shows the
error screen instead of starting a broken game.

## 7. Tests and tools

- `tests/test_runner.tscn` runs every suite in `tests/suites/`. A custom `Logger`
  turns any engine or script error during a test into a failure. Options:
  `--only=<prefix>`, `--id=<exact>`, `--skip-long`, `--update-fixtures`. Before quitting
  it stops every sound, because a playback still running at shutdown is reported as
  leaked objects.
- `tests/sim_bot.gd` (`SimBot`) plays through the same APIs as the UI. It closes
  onboarding tips; with `manage = true` it plays like a typical player: it moves to the
  next location when it can, hires and opens stations, and otherwise buys the best value
  (Δ KR/s ÷ cost) among level upgrades, recipe unlocks and "chasing a recipe" (raising
  the best mixer and oven to the tool tier a more profitable recipe needs). It saves up
  for the next location when that is the best value and costs at most
  `save_location_minutes` of income, and for the best purchase when it is at most
  `wait_best_minutes` away.
- `tests/model_sample.gd` builds the Tier 1–5 sample shops of `ACC_IDLE_MODEL_MATCH`
  and measures the live net income; `tests/pacing_tracker.gd` records the active-play
  time of every idle GDD §1.4 milestone.
- `tools/idle_probe.tscn` (headless) plays a new game with `SimBot` and prints one line
  every few minutes and the milestone times (`--minutes`, `--seed`, `--manage`,
  `--franchise=N` to sell at N stars and measure the second run, `--max-tier`,
  `--set="path=json;…"` to try idle.json values without editing the catalog).
- `tools/model_probe.tscn` (headless) compares the KR/s model with the live shop at the
  sample shops (`--hours`, `--warm`, `--seed`, `--bare` for a brand-new shop).
- `tools/release_validator.tscn` is the release gate. `tools/string_lint.gd` handles key
  completeness and the English lint. `tools/generate_icon.gd` generates `icon.svg`.
  `tools/compile_check.tscn` checks that every script compiles.
  `tools/character_lineup.tscn`, `tools/world_snapshot.tscn` and
  `tools/vehicle_lineup.tscn` (windowed) render characters, the shop and vehicles to
  PNGs in `LINEUP_OUT`.
- `tools/ui_resolution_sweep.tscn` (windowed) opens the menu and in-game screens on the
  idle §12.0.7 portrait matrix and text scales, saves half-size PNGs to `LINEUP_OUT`,
  and prints `SWEEP OFF` for every visible control outside the frame and
  `SWEEP done, N issues` at the end (`--res=`, `--scales=`, `--screens=` filters). The
  same check runs headless in `ACC_IDLE_PORTRAIT_UI`.
- Performance tools (GDD 109.3): `tools/render_probe.tscn` (windowed) prints draw calls,
  objects and triangles per tier; `tools/bake_compare.tscn` compares baked and unbaked
  models; `tools/sim_profile.tscn -- --tier=N [--detail]` times every manager;
  `tools/soak_trace.tscn -- --days=N` prints a per-day state hash to prove an
  optimization changes nothing; `tools/loading_probe.tscn` times the loading stages.
- `.github/workflows/tests.yml` runs the compile check, the tests without the soaks and
  the quick release validator on every push and pull request to `main`.
