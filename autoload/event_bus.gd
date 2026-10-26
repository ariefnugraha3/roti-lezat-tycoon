extends Node
## EventBus — sinyal global (GDD 35.4). Simulasi hanya MEMANCARKAN; UI, audio,
## dan visual berlangganan (GDD 35.5: simulasi tidak bergantung pada node UI).
## Mutasi state tidak pernah dilakukan lewat sinyal (GDD 97.2 aturan 8).

# --- GDD 35.4 minimum -------------------------------------------------------
signal time_changed(day: int, time_seconds: float)
signal production_job_created(job_id: int)
signal station_completed(equipment_id: int, stage: StringName)
signal bread_added_to_display(equipment_id: int, recipe_id: StringName, quantity: int)
signal customer_spawned(customer_id: int)
signal customer_abandoned(customer_id: int)
signal sale_completed(amount_kr: float, channel: StringName)
signal delivery_order_created(order_id: int)
signal delivery_order_completed(order_id: int)
signal balance_changed(balance_kr: float)
signal reputation_changed(reputation: float)
signal staff_state_changed(staff_id: StringName)
signal weather_changed(today: StringName, tomorrow: StringName)

# --- Alur hari & sesi -------------------------------------------------------
signal day_started(day: int)
signal profile_loaded(profile_id: StringName)
signal profile_unloaded()

# --- Umpan balik & presentasi (P7, GDD 102) ---------------------------------
## Umpan balik tap gagal/berhasil di dunia (GDD 16.7). kind: path_blocked,
## hands_full, station_busy, missing_ingredients, display_full, ...
signal feedback(kind: StringName, world_cell: Vector2i, floor_id: StringName)
## Notifikasi berprioritas P0..P4 (GDD 131).
signal notify(priority: int, key: String, params: Dictionary, icon: StringName)
## Permintaan bunyi dari simulasi; AudioManager yang memutuskan (GDD 93).
signal sfx(event_id: StringName, floor_id: StringName)
signal music_state_changed(state: StringName)
signal achievement_unlocked(achievement_id: StringName)
signal tutorial_step_changed(step_id: StringName)
signal economy_overflowed()
signal location_changed(location_id: StringName)
signal active_floor_changed(floor_id: StringName)
signal coin_popup(amount_kr: float, world_cell: Vector2i, floor_id: StringName)
## Ketukan Semangat berhasil pada stasiun `equipment_id` (-1 = kasir, GDD idle 5.2).
signal tap_boost(equipment_id: int, world_cell: Vector2i, floor_id: StringName)
## Resep pilihan petak rak berubah (layar Menu, GDD idle 4.2).
signal slot_recipes_changed(equipment_id: int)
## Level dibeli (GDD idle 8): kind station/counter/recipe/staff/global.
signal level_up(kind: StringName, id: Variant, level: int, milestone: bool)
## Model stasiun berevolusi ke tier baru (GDD idle 8.2, 14).
signal station_evolved(equipment_id: int, from_tier: int, to_tier: int)
signal station_opened(equipment_id: int)
signal recipe_unlocked(recipe_id: StringName)

# --- Permintaan UI dari lapisan tugas pemain (bukan mutasi) -----------------
signal storage_door(equipment_id: int, open: bool)
