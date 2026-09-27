extends Node
## EventBus — sinyal global (GDD 35.4). Simulasi hanya MEMANCARKAN; UI, audio,
## dan visual berlangganan (GDD 35.5: simulasi tidak bergantung pada node UI).
## Mutasi state tidak pernah dilakukan lewat sinyal (GDD 97.2 aturan 8).

# --- GDD 35.4 minimum -------------------------------------------------------
signal time_changed(day: int, time_seconds: float)
signal shop_opened(day: int)
signal shop_closed(day: int)
signal production_job_created(job_id: int)
signal station_completed(equipment_id: int, stage: StringName)
signal bread_added_to_display(equipment_id: int, recipe_id: StringName, quantity: int)
signal customer_spawned(customer_id: int)
signal customer_abandoned(customer_id: int)
signal sale_completed(amount_kr: float, channel: StringName)
signal delivery_order_created(order_id: int)
signal delivery_order_completed(order_id: int)
signal balance_changed(balance_kr: float)
signal rating_changed(physical: float, rotifood: float)
signal staff_state_changed(staff_id: StringName)
signal weather_changed(today: StringName, tomorrow: StringName)
signal day_settled(day: int)

# --- Alur hari & sesi -------------------------------------------------------
signal phase_changed(phase: StringName)
signal day_started(day: int)
signal speed_changed(speed: int)
signal profile_loaded(profile_id: StringName)
signal profile_unloaded()
signal simulation_rebuilt()

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
signal off_floor_alerts_changed()
signal supply_delivered(order_id: int)
signal coin_popup(amount_kr: float, world_cell: Vector2i, floor_id: StringName)

# --- Permintaan UI dari lapisan tugas pemain (bukan mutasi) -----------------
## Karakter tiba di Storage: buka Recipe Book.
signal recipe_book_requested()
## Karakter tiba di rak sambil membawa loyang: buka Display Slot Picker.
signal slot_picker_requested(equipment_id: int)
## Pembeli terdepan siap dilayani manual: buka popup pesanan.
signal customer_order_requested(customer_id: int)
signal rotifood_order_requested(order_id: int)
signal display_detail_requested(equipment_id: int)
signal daily_summary_ready(day: int)
signal bailout_cutscene_requested(repeat_visit: bool)
signal storage_door(equipment_id: int, open: bool)
