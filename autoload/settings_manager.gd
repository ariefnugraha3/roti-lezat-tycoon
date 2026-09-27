extends Node
## SettingsManager — pengaturan & aksesibilitas (GDD 44, 75), disimpan terpisah
## dari profil karier di user://settings.json (GDD 106). File rusak diganti
## default aman tanpa menghentikan boot (GDD 114 tahap 2).

signal settings_changed(key: String)

const PATH: String = "user://settings.json"
const TMP_PATH: String = "user://settings.json.tmp"
const VERSION: int = 1

const DEFAULTS: Dictionary = {
	"master_volume": 100,
	"music_volume": 75,
	"sfx_volume": 90,
	"ui_volume": 80,
	"ambient_volume": 70,
	"mute_when_unfocused": true,
	"fullscreen": false,
	"resolution_scale": 100,
	"ui_scale": 100,
	"brightness": 100,
	"fps_cap": 60,
	"quality": "auto",
	"smart_speed": true,
	"edge_scroll": false,
	"confirm_expensive": true,
	"confirm_threshold": 5000,
	"tutorial_hints": true,
	"reduced_motion": false,
	"screen_shake": 30,
	"haptics": true,
	"high_contrast_markers": false,
	"patience_bar_large": false,
	"text_scale": 100,
	"hold_to_confirm": false,
	"sound_captions": false,
}

## Batas nilai untuk validasi (GDD 75).
const RANGES: Dictionary = {
	"master_volume": [0, 100], "music_volume": [0, 100], "sfx_volume": [0, 100],
	"ui_volume": [0, 100], "ambient_volume": [0, 100],
	"resolution_scale": [70, 100], "ui_scale": [80, 150], "brightness": [80, 120],
	"screen_shake": [0, 100], "text_scale": [100, 150], "confirm_threshold": [0, 1000000000],
}
const CHOICES: Dictionary = {
	"fps_cap": [30, 60, 0],
	"quality": ["auto", "quality_low", "quality_medium", "quality_high"],
	"resolution_scale": [70, 85, 100],
	"text_scale": [100, 125, 150],
}

var values: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply_all()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func get_bool(key: String) -> bool:
	return bool(get_value(key))


func get_int(key: String) -> int:
	return int(get_value(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("[UI] unknown setting %s" % key)
		return
	values[key] = _sanitize(key, value)
	_apply(key)
	save_settings()
	settings_changed.emit(key)


func load_settings() -> void:
	values = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(PATH):
		return
	var text: String = FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("[SAVE] settings.json is corrupt; using safe defaults")
		return
	var data: Dictionary = parsed
	var stored: Dictionary = data.get("values", {})
	for k: Variant in stored.keys():
		var key: String = str(k)
		if DEFAULTS.has(key):
			values[key] = _sanitize(key, stored[k])


func save_settings() -> void:
	var payload: Dictionary = {"settings_version": VERSION, "values": values}
	var f: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SAVE] could not write settings")
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP_PATH), ProjectSettings.globalize_path(PATH))


func reset_defaults() -> void:
	values = DEFAULTS.duplicate(true)
	apply_all()
	save_settings()
	settings_changed.emit("")


func apply_all() -> void:
	for k: String in DEFAULTS.keys():
		_apply(k)


## Pengali ukuran huruf UI (100% / 125% / 150%, GDD 28.5).
func text_scale() -> float:
	return float(get_int("text_scale")) / 100.0


func reduced_motion() -> bool:
	return get_bool("reduced_motion")


func _sanitize(key: String, value: Variant) -> Variant:
	var def: Variant = DEFAULTS[key]
	if def is bool:
		return bool(value)
	if def is String:
		var s: String = str(value)
		if CHOICES.has(key) and not (CHOICES[key] as Array).has(s):
			return def
		return s
	var n: int = int(value)
	if CHOICES.has(key):
		var allowed: Array = CHOICES[key]
		if not allowed.has(n):
			# Pilih nilai sah terdekat.
			var best: int = int(allowed[0])
			for a: Variant in allowed:
				if absi(int(a) - n) < absi(best - n):
					best = int(a)
			n = best
	if RANGES.has(key):
		var r: Array = RANGES[key]
		n = clampi(n, int(r[0]), int(r[1]))
	return n


func _apply(key: String) -> void:
	if not is_inside_tree():
		return
	match key:
		"fullscreen":
			if DisplayServer.get_name() == "headless":
				return
			if OS.has_feature("mobile"):
				return
			var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if get_bool(key) else DisplayServer.WINDOW_MODE_WINDOWED
			if DisplayServer.window_get_mode() != mode:
				DisplayServer.window_set_mode(mode)
		"fps_cap":
			Engine.max_fps = get_int(key)
		"ui_scale":
			get_tree().root.content_scale_factor = float(get_int(key)) / 100.0
		"resolution_scale":
			get_tree().root.scaling_3d_scale = float(get_int(key)) / 100.0
		_:
			pass
