class_name Tx
extends RefCounted
## Pintu tunggal teks yang terlihat pemain (GDD 43, 127). Semua string berasal
## dari data/catalog/strings_en.json lewat DataRegistry; skrip tidak boleh
## menulis kalimat panjang secara langsung.


## Teks untuk `key`, dengan placeholder {nama} diganti dari `params`.
static func t(key: String, params: Dictionary = {}) -> String:
	return DataRegistry.text(key, params)


static func kr(v: float) -> String:
	return Money.fmt(v, DataRegistry.economy_sci_threshold())


static func kr_signed(v: float) -> String:
	return Money.fmt_signed(v, DataRegistry.economy_sci_threshold())


## Jam in-game "HH:MM" dari detik sejak 00:00.
static func clock(time_seconds: float) -> String:
	var total_min: int = int(floor(time_seconds / 60.0))
	var h: int = (total_min / 60) % 24
	var m: int = total_min % 60
	return "%02d:%02d" % [h, m]


static func rating(v: float) -> String:
	return "%.1f" % v


static func percent(v: float) -> String:
	return "%d%%" % int(Money.round_half_up(v * 100.0))


static func recipe_name(recipe_id: StringName) -> String:
	return t(String(recipe_id))


static func item_name(id: StringName) -> String:
	return t(String(id))
