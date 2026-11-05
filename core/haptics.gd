class_name Haptics
extends RefCounted
## Getar singkat di HP (v3.1 75.4 "Vibration/Haptics"; GDD idle 20 no. 55).
## Dipicu suara umpan balik yang sudah ada (EventBus.sfx): ketukan Semangat dan
## roti emas, naik level, milestone, hadiah koin, pencapaian, pindah lokasi, dan
## Waralaba. Suara lain tidak bergetar. Mati lewat Settings > Accessibility >
## Vibration. Hanya Android dan Chrome Android (navigator.vibrate); Safari iPhone
## tidak punya API getar, jadi pengaturannya tidak ditampilkan di sana.

## Lama getar (ms) per suara umpan balik.
const PULSE_MS: Dictionary = {
	&"tap_boost_pop": 12,
	&"level_up": 20,
	&"milestone_fanfare": 45,
	&"coin_shower": 40,
	&"achievement_unlock": 45,
	&"location_upgrade": 70,
	&"franchise_jingle": 80,
}
## Jeda minimum antara dua getar (ms): beli Max atau rentetan pencapaian tidak
## menjadi dengung panjang.
const MIN_GAP_MS: int = 90

## Test: anggap perangkat bisa bergetar, tanpa benar-benar menggetarkan apa pun.
static var force_supported: bool = false
## Jumlah dan lama getar terakhir yang dikirim (test).
static var pulses: int = 0
static var last_ms: int = 0
static var _last_at: int = -1000000


## Perangkat ini bisa bergetar: aplikasi Android/iOS atau browser Android.
static func supported() -> bool:
	return force_supported or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android")


static func on_sfx(event_id: StringName, _floor_id: StringName = &"") -> void:
	pulse(int(PULSE_MS.get(event_id, 0)))


## Getarkan `ms` milidetik bila didukung dan diizinkan Settings. true bila terkirim.
static func pulse(ms: int) -> bool:
	if ms <= 0 or not supported() or not SettingsManager.get_bool("haptics"):
		return false
	var now: int = Time.get_ticks_msec()
	if now - _last_at < MIN_GAP_MS:
		return false
	_last_at = now
	pulses += 1
	last_ms = ms
	if not force_supported:
		Input.vibrate_handheld(ms)
	return true


## Test: lupakan getar sebelumnya (jeda minimum ikut direset).
static func reset() -> void:
	pulses = 0
	last_ms = 0
	_last_at = -1000000
