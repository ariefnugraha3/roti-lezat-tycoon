class_name EventManager
extends SimManager
## Event musiman (GDD idle 21.6): event mengikuti tanggal perangkat, seperti
## Kopi Pak Lurah, dari daftar `events.list`. Event bertanggal tetap memakai
## jendela "MM-DD" (boleh melewati tahun baru); Imlek dan Lebaran memakai tabel
## tanggal per tahun (`dates`) dengan jendela hari sebelum/sesudahnya.
##
## Selama event: tiga roti unggulan dijual ×`events.featured_mult` (ikut model
## KR/s dan penghasilan offline, seperti roti favorit), hadiah tujuan yang terbit
## ×`events.goal_reward_mult`, dan toko berhias untaian bendera warna event.
## Beberapa event boleh bersamaan (mis. Imlek dan Valentine); efeknya digabung.
##
## Simulasi tidak membaca jam perangkat: GameRoot memberi tanggalnya
## (`set_date`, dari BoostManager.today()), jadi tes dan probe tanpa tanggal
## tidak punya event.

## Tes selain tes event mematikannya (TestRunner): hasilnya tidak boleh
## bergantung pada tanggal tes dijalankan.
static var enabled: bool = true

## Tanggal perangkat sekarang ("" = tidak diketahui: tidak ada event).
var date: String = ""
## Event yang sudah diumumkan (toast), "id|tahun-mulai", supaya toast tidak
## berulang setiap kali profil dimuat.
var announced: Dictionary = {}
var _active: Array[Dictionary] = []
var _featured: Dictionary = {}


func new_game() -> void:
	date = ""
	announced.clear()
	_active.clear()
	_featured.clear()


## Setel tanggal perangkat. true bila daftar event aktif berubah.
func set_date(d: String) -> bool:
	if d == date:
		return false
	var before: String = _ids()
	date = d
	_active.clear()
	if enabled:
		_active = events_on(d)
	_featured.clear()
	for ev: Dictionary in _active:
		for rid: Variant in ev.get("featured", []):
			_featured[StringName(str(rid))] = true
	sim.idle_economy.invalidate()
	return _ids() != before


func _ids() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for ev: Dictionary in _active:
		parts.append(str(ev["id"]))
	return ",".join(parts)


## Event yang sedang berjalan (urut katalog).
func active() -> Array[Dictionary]:
	return _active


func is_featured(recipe_id: StringName) -> bool:
	return _featured.has(recipe_id)


func featured_mult(recipe_id: StringName) -> float:
	return DataRegistry.idlef("events.featured_mult") if is_featured(recipe_id) else 1.0


func goal_reward_mult() -> float:
	return DataRegistry.idlef("events.goal_reward_mult") if not _active.is_empty() else 1.0


## Event yang belum diumumkan untuk tanggal sekarang; menandainya sudah diumumkan.
func take_announcements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in _active:
		var key: String = "%s|%s" % [ev["id"], str(ev["start"])]
		if not announced.has(key):
			announced[key] = true
			out.append(ev)
	return out


# ===========================================================================
# KALENDER
# ===========================================================================

## Nomor hari (hari sejak 1970-01-01) dari "YYYY-MM-DD"; -1 bila tidak sah.
static func day_number(d: String) -> int:
	if d.length() != 10:
		return -1
	var u: int = Time.get_unix_time_from_datetime_string(d + "T00:00:00")
	return int(floor(float(u) / 86400.0))


static func _date_of(day_no: int) -> String:
	return Time.get_date_string_from_unix_time(day_no * 86400)


## Event yang berjalan pada tanggal `d`: salinan entri katalog dengan "start"
## dan "end" (hari pertama dan terakhir jendela yang memuat `d`).
static func events_on(d: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = day_number(d)
	if n < 0:
		return out
	var year: int = int(d.substr(0, 4))
	for x: Variant in DataRegistry.idle("events.list"):
		var ev: Dictionary = x
		var w: Vector2i = _window(ev, n, year)
		if w.x >= 0:
			var e2: Dictionary = ev.duplicate()
			e2["start"] = _date_of(w.x)
			e2["end"] = _date_of(w.y)
			out.append(e2)
	return out


## Jendela event `ev` (hari pertama, hari terakhir) yang memuat hari `n`, atau
## (-1, -1).
static func _window(ev: Dictionary, n: int, year: int) -> Vector2i:
	if ev.has("dates"):
		var before: int = int(ev.get("before", 0))
		var after: int = int(ev.get("after", 0))
		for dv: Variant in ev["dates"]:
			var c: int = day_number(str(dv))
			if c >= 0 and n >= c - before and n <= c + after:
				return Vector2i(c - before, c + after)
		return Vector2i(-1, -1)
	# Jendela "MM-DD".."MM-DD"; yang melewati tahun baru dicek dari tahun lalu.
	for y: int in [year - 1, year]:
		var a: int = day_number("%04d-%s" % [y, str(ev["from"])])
		var b: int = day_number("%04d-%s" % [y if str(ev["to"]) >= str(ev["from"]) else y + 1, str(ev["to"])])
		if a >= 0 and b >= 0 and n >= a and n <= b:
			return Vector2i(a, b)
	return Vector2i(-1, -1)


## Nama event aktif digabung ("Lunar New Year & Sweetheart Week").
func names() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for ev: Dictionary in _active:
		parts.append(Tx.t(str(ev["id"])))
	return " & ".join(parts)


## Hari terakhir event aktif yang paling lama.
func last_end() -> String:
	var out: String = ""
	for ev: Dictionary in _active:
		if str(ev["end"]) > out:
			out = str(ev["end"])
	return out


## Roti unggulan semua event aktif, urut katalog resep.
func featured() -> Array[StringName]:
	var out: Array[StringName] = []
	for r: RecipeDefinition in DataRegistry.recipes():
		if _featured.has(r.id):
			out.append(r.id)
	return out


func capture() -> Dictionary:
	return {"announced": announced.keys()}


func restore(d: Dictionary) -> void:
	new_game()
	for k: Variant in d.get("announced", []):
		announced[str(k)] = true
