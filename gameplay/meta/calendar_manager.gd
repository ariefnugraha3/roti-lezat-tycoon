class_name CalendarManager
extends SimManager
## Kalender cap harian (GDD idle 21.3): satu cap per tanggal perangkat, mulai
## tanggal sesudah kalender pertama dilihat. Tujuh cap berputar
## (`calendar.rewards`); melewatkan hari tidak mereset apa pun, cap berikutnya
## hanya menunggu. Cap ketujuh memberi dekorasi kalender berikutnya yang belum
## dimiliki (`calendar.decor_rewards`), lalu KR saja setelah semuanya dimiliki.
##
## Simulasi tidak pernah membaca jam perangkat sendiri: GameRoot memberikan
## tanggalnya (BoostManager.today()), seperti Kopi Pak Lurah, jadi save tes tetap
## tanpa nilai jam dinding. Kalender bertahan lintas Waralaba.

## Tanggal perangkat kalender pertama dilihat (tanpa cap hari itu), tanggal cap
## terakhir, dan jumlah cap yang sudah diambil.
var first_date: String = ""
var last_date: String = ""
var stamps: int = 0


func new_game() -> void:
	first_date = ""
	last_date = ""
	stamps = 0


## Catat tanggal perangkat `date`; kunjungan pertama hanya memulai kalender.
func note_date(date: String) -> void:
	if first_date == "" and date != "":
		first_date = date


## Cap tersedia untuk tanggal `date`.
func available(date: String) -> bool:
	return date != "" and first_date != "" and date != first_date and date != last_date


## Nomor cap berikutnya dalam putaran tujuh hari (0..6).
func next_index() -> int:
	return stamps % rewards().size()


static func rewards() -> Array:
	return DataRegistry.idle("calendar.rewards")


## Hadiah cap ke-`i` bila diambil sekarang: {kr, boost_minutes, decor}.
func reward(i: int) -> Dictionary:
	var r: Dictionary = rewards()[i]
	var out: Dictionary = {"kr": 0.0, "boost_minutes": float(r.get("boost_minutes", 0.0)), "decor": &""}
	if r.has("kr_minutes"):
		out["kr"] = GoalManager.nice(maxf(DataRegistry.idlef("calendar.min_kr"), sim.idle_economy.rate(false) * 60.0 * float(r["kr_minutes"])))
	if bool(r.get("decor", false)):
		out["decor"] = next_decor()
	return out


## Dekorasi kalender berikutnya yang belum dimiliki (&"" bila semua dimiliki).
func next_decor() -> StringName:
	for id: Variant in DataRegistry.idle("calendar.decor_rewards"):
		var did: StringName = StringName(str(id))
		if not sim.decoration.owns(did):
			return did
	return &""


## Ambil cap untuk tanggal `date`. Mengembalikan hadiahnya ({} bila tidak ada cap).
func claim(date: String) -> Dictionary:
	if not available(date):
		return {}
	var r: Dictionary = reward(next_index())
	stamps += 1
	last_date = date
	sim.statistics.add(&"calendar_stamps", 1)
	if float(r["kr"]) > 0.0:
		sim.economy.credit(float(r["kr"]), &"REWARD", &"calendar", {"stamp": stamps})
	if float(r["boost_minutes"]) > 0.0:
		sim.boosts.add_income(DataRegistry.idlef("calendar.boost_mult"), float(r["boost_minutes"]) * 60.0)
	if StringName(r["decor"]) != &"":
		sim.decoration.grant(StringName(r["decor"]))
	EventBus.sfx.emit(&"achievement_unlock", &"")
	SaveManager.request_autosave("calendar")
	return r


func capture() -> Dictionary:
	return {"first_date": first_date, "last_date": last_date, "stamps": stamps}


func restore(d: Dictionary) -> void:
	new_game()
	first_date = str(d.get("first_date", ""))
	last_date = str(d.get("last_date", ""))
	stamps = maxi(0, int(d.get("stamps", 0)))
