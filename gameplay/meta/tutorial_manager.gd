class_name TutorialManager
extends SimManager
## TutorialManager — timeline Hari 1-3 (GDD 27, 88, 127.5). Mengajar lewat aksi
## dunia. Skip tidak mengubah demand terjadwal (GDD 27.6).
##
## Hari 1 memakai urutan terpandu (keputusan maintainer 2026-10-07 dan
## 2026-10-08, GDD 88.1): Decoration Mode lebih dulu (pemain wajib mencoba
## memindahkan satu perabot), lalu Buku Resep dengan tur sorotan, mixer, oven,
## rak; sekali lagi Buku Resep, mixer, dan oven, dan kali kedua loyangnya
## ditaruh di Meja Tunggu. Sesudah itu Skip to Open, tur sorotan HUD tentang
## rating dan pesanan RotiFood begitu toko buka, lalu pembeli pertama: sorotan
## pada pembeli dan meja kasir, pemain ke kasir dan melayani, sampai penjualan
## pertama. Begitu toko tutup (Daily Summary Hari 1), tutorial mengajak ke
## Staff Management lalu Marketing, masing-masing dengan tur sorotan di
## layarnya, dan berakhir di tombol Continue to Next Day. Setiap langkah maju
## oleh peristiwa dunia (`FLOW`); langkah sorotan dan petunjuk penutup maju saat
## pemain menutupnya (`dismissed`). Hard-block
## hanya selama langkah dekorasi (semua ketukan dunia ditahan), langkah Storage
## pertama (hanya Storage), dan langkah Meja Tunggu (rak tidak bisa diketuk).
## Tip lain tetap muncul sekali saat kondisinya tercapai; tip non-modal menunggu
## sampai urutan terpandu selesai. Pengunjung lihat-lihat pertama yang pulang,
## kejutan pertama, dan pesanan RotiFood pertama mendapat sorotan sekali.

## Langkah terpandu -> [kunci prompt, sasaran sorotan, sorotan layar (opsional)].
## Langkah dengan sorotan layar (`SPOTLIGHTS`) mem-pause game seperti tip modal.
## Kunci "" = tanpa petunjuk HUD, karena layarnya sendiri yang menjalankan tur
## (Staff Management, Marketing).
const GUIDED: Dictionary = {
	&"decor_open": ["tut_decor_open", &"decor_button"],
	&"decor_move": ["tut_decor_move", &"display"],
	&"decor_done": ["tut_decor_done", &"decor_done"],
	&"storage": ["tut_tap_storage", &"storage"],
	&"recipe": ["tut_choose_recipe", &""],
	&"mixer": ["tut_tap_mixer", &"mixer"],
	&"mixing": ["tut_equipment_works", &""],
	&"mixer_pickup": ["tut_mixer_done", &"mixer"],
	&"oven": ["tut_to_oven", &"oven"],
	&"baking": ["tut_baking", &"oven"],
	&"oven_pickup": ["tut_take_tray", &"oven"],
	&"display": ["tut_choose_slot", &"display"],
	&"storage2": ["tut_again_storage", &"storage"],
	&"recipe2": ["tut_choose_recipe_again", &""],
	&"mixer2": ["tut_mixer_again", &"mixer"],
	&"mixing2": ["tut_equipment_works", &""],
	&"mixer_pickup2": ["tut_mixer_done", &"mixer"],
	&"oven2": ["tut_to_oven", &"oven"],
	&"baking2": ["tut_baking", &"oven"],
	&"oven_pickup2": ["tut_take_tray", &"oven"],
	&"table": ["tut_to_table", &"table"],
	&"skip_open": ["tut_skip_open", &"skip_open"],
	&"open_tour": ["tut_tour_rating", &"", &"open_tour"],
	&"buyer_wait": ["tut_buyer_wait", &""],
	&"buyer": ["tut_buyer_enter", &"", &"buyer"],
	&"serve": ["tut_serve_counter", &"cashier"],
	&"serve_wait": ["tut_serve_wait", &""],
	&"serve_tap": ["tut_serve_tap", &"cashier"],
	&"serve_pack": ["tut_serve_pack", &""],
	&"sold": ["tut_first_sale", &""],
	&"close_staff": ["tut_staff_open", &"staff_button"],
	&"staff_tour": ["", &""],
	&"marketing": ["tut_marketing_open", &"marketing_button"],
	&"marketing_tour": ["", &""],
	&"close_done": ["tut_close_done", &"continue_button"],
}
## Langkah -> {peristiwa: langkah berikutnya}. &"" = urutan terpandu selesai.
## `dismissed` = pemain menutup sorotan atau petunjuk penutup langkah itu.
const FLOW: Dictionary = {
	&"decor_open": {&"decor_opened": &"decor_move", &"furniture_placed": &"decor_done"},
	&"decor_move": {&"furniture_placed": &"decor_done", &"decor_closed": &"decor_open"},
	&"decor_done": {&"decor_closed": &"storage"},
	&"storage": {&"storage_opened": &"recipe"},
	&"recipe": {&"recipe_ordered": &"mixer", &"storage_closed": &"storage"},
	&"mixer": {&"mixing_started": &"mixing"},
	&"mixing": {&"mixer_done": &"mixer_pickup"},
	&"mixer_pickup": {&"dough_picked": &"oven"},
	&"oven": {&"oven_inserted": &"baking"},
	&"baking": {&"oven_ready": &"oven_pickup"},
	&"oven_pickup": {&"tray_picked": &"display"},
	&"display": {&"bread_placed": &"storage2"},
	&"storage2": {&"storage_opened": &"recipe2"},
	&"recipe2": {&"recipe_ordered": &"mixer2", &"storage_closed": &"storage2"},
	&"mixer2": {&"mixing_started": &"mixing2"},
	&"mixing2": {&"mixer_done": &"mixer_pickup2"},
	&"mixer_pickup2": {&"dough_picked": &"oven2"},
	&"oven2": {&"oven_inserted": &"baking2"},
	&"baking2": {&"oven_ready": &"oven_pickup2"},
	&"oven_pickup2": {&"tray_picked": &"table"},
	&"table": {&"tray_on_table": &"skip_open"},
	&"skip_open": {&"store_open": &"open_tour"},
	&"open_tour": {&"dismissed": &"buyer_wait"},
	&"buyer_wait": {&"customer_entered": &"buyer"},
	&"buyer": {&"dismissed": &"serve"},
	&"serve": {&"player_at_cashier": &"serve_wait", &"manual_service_started": &"serve_pack", &"first_payment": &"sold"},
	&"serve_wait": {&"customer_at_counter": &"serve_tap", &"manual_service_started": &"serve_pack", &"first_payment": &"sold"},
	&"serve_tap": {&"manual_service_started": &"serve_pack", &"customer_abandoned": &"serve_wait", &"first_payment": &"sold"},
	&"serve_pack": {&"first_payment": &"sold"},
	&"sold": {&"dismissed": &""},
	&"close_staff": {&"staff_opened": &"staff_tour"},
	&"staff_tour": {&"staff_closed": &"marketing"},
	&"marketing": {&"marketing_opened": &"marketing_tour"},
	&"marketing_tour": {&"marketing_closed": &"close_done"},
	&"close_done": {&"dismissed": &""},
}
## Sorotan yang mem-pause game (GDD 27.5): [[kunci teks, sasaran], ...] per
## langkah. Sasaran HUD: store_rating, rotifood_rating, rotifood_panel,
## rotifood_order. Sasaran dunia: buyer, counter, window_shopper, surprise.
const SPOTLIGHTS: Dictionary = {
	&"open_tour": [["tut_tour_rating", &"store_rating"], ["tut_tour_rotifood_rating", &"rotifood_rating"],
		["tut_tour_rotifood_orders", &"rotifood_panel"], ["tut_rotifood", &"rotifood_panel"]],
	&"buyer": [["tut_buyer_enter", &"buyer"], ["tut_manual_cashier", &"counter"]],
	&"window_shopper": [["tut_window_shopper", &"window_shopper"]],
	&"surprise": [["tut_surprise", &"surprise"]],
	&"rotifood_order": [["tut_rotifood_first", &"rotifood_order"]],
}
## Tip lama yang isinya sudah diajarkan langkah terpandu ini, jadi tidak tampil lagi.
const COVERS: Dictionary = {
	&"serve_wait": ["tut_patience"],
	&"sold": ["tut_income"],
}
## Langkah dekorasi: semua ketukan dunia ditahan sampai pemain mencoba
## memindahkan perabot dan menutup Decoration Mode.
const DECOR_STEPS: Array[StringName] = [&"decor_open", &"decor_move", &"decor_done"]
## Sasaran sorotan yang berupa UI, bukan perabot.
const UI_TARGETS: Array[StringName] = [&"", &"cashier", &"tablet", &"decor_button", &"decor_done", &"skip_open",
	&"staff_button", &"marketing_button", &"continue_button"]

## Prompt aktif: {key, modal, highlight_kind, highlight_iid, guided, dismissable,
## spotlight}
var prompt: Dictionary = {}
var done: Dictionary = {}
var skipped: bool = false
## Langkah terpandu Hari 1 yang sedang berjalan, atau &"" (GDD 88.1).
var guided_step: StringName = &""
var _queue: Array[Dictionary] = []


func new_game() -> void:
	prompt = {}
	done.clear()
	skipped = false
	guided_step = &""
	_queue.clear()


func active() -> bool:
	return not skipped and sim.time.day <= 3


func hints_enabled() -> bool:
	if skipped:
		return false
	if sim.time.day > 3:
		return SettingsManager.get_bool("tutorial_hints")
	return true


func skip() -> void:
	skipped = true
	prompt = {}
	guided_step = &""
	_queue.clear()
	EventBus.tutorial_step_changed.emit(&"")


## true selama urutan terpandu Hari 1 berjalan.
func guided() -> bool:
	return guided_step != &""


## true selama pemain diminta mencoba Decoration Mode (GDD 88.1 langkah 2).
func wants_furniture_move() -> bool:
	return guided_step in DECOR_STEPS


## Tur sorotan Buku Resep yang berlaku: &"full" pada resep pertama, &"short"
## pada resep kedua, &"" selain itu.
func recipe_tour() -> StringName:
	if guided_step == &"recipe":
		return &"full"
	if guided_step == &"recipe2":
		return &"short"
	return &""


## Popup pesanan pembeli menyorot tombol OK selama pemain belajar melayani
## pembeli pertamanya (GDD 88.1).
func order_tour() -> bool:
	return guided_step in [&"serve", &"serve_wait", &"serve_tap"]


## Daily Summary Hari 1 menyorot tombol Manage Staff (GDD 88.1).
func summary_tour() -> bool:
	return guided_step == &"close_staff"


## Staff Management dibuka pada langkahnya: tur sorotan pelamar (GDD 88.1).
func staff_tour() -> bool:
	return guided_step == &"staff_tour"


## Marketing dibuka pada langkahnya: tur sorotan kampanye (GDD 88.1).
func marketing_tour() -> bool:
	return guided_step == &"marketing_tour"


## Langkah sorotan `kind`: [[kunci teks, sasaran], ...].
static func spotlight_steps(kind: StringName) -> Array:
	return SPOTLIGHTS.get(kind, [])


## Ketukan dunia yang diizinkan (GDD 27.5, 88.1). Langkah dekorasi menahan
## semuanya, langkah Storage pertama hanya Storage, langkah Meja Tunggu
## menahan rak (loyangnya harus dicoba ditaruh di meja).
func allows_tap(kind: StringName) -> bool:
	if not active() or sim.time.day != 1:
		return true
	if guided_step in DECOR_STEPS:
		return false
	if guided_step == &"storage":
		return kind == &"storage"
	if guided_step == &"table":
		return kind != &"display"
	# Save lama tanpa urutan terpandu: hard-block Storage seperti dulu.
	if guided_step == &"" and not done.has("storage_opened"):
		return kind == &"storage"
	return true


func _show(key: String, modal: bool, highlight_kind: StringName = &"", once_key: String = "", spotlight: StringName = &"") -> void:
	var k: String = once_key if once_key != "" else key
	if done.has(k) or not hints_enabled():
		return
	# Selama urutan terpandu, tip non-modal menunggu kesempatan berikutnya
	# (belum dicatat tampil), supaya sorotan langkahnya tidak hilang.
	if guided_step != &"" and not modal:
		return
	done[k] = true
	var p: Dictionary = {"key": key, "modal": modal, "highlight_kind": String(highlight_kind), "highlight_iid": _iid_for(highlight_kind)}
	if spotlight != &"":
		p["spotlight"] = String(spotlight)
		_mark_spotlight(spotlight)
	if prompt.is_empty() or not bool(prompt.get("modal", false)):
		prompt = p
		EventBus.tutorial_step_changed.emit(StringName(key))
	else:
		_queue.append(p)


## Semua teks sebuah sorotan tercatat sudah tampil (arsip bantuan, GDD 27.6).
func _mark_spotlight(kind: StringName) -> void:
	for st: Array in spotlight_steps(kind):
		done[str(st[0])] = true


func _iid_for(kind: StringName) -> int:
	if kind in UI_TARGETS:
		return -1
	var l: Array[EquipmentInstance] = sim.equipment.placed_list(kind)
	return l[0].iid if not l.is_empty() else -1


## Prompt langkah terpandu saat ini, atau {} bila tidak ada.
func _guided_prompt() -> Dictionary:
	if not GUIDED.has(guided_step):
		return {}
	var g: Array = GUIDED[guided_step]
	var kind: StringName = g[1]
	var spot: StringName = g[2] if g.size() > 2 else &""
	var p: Dictionary = {"key": String(g[0]), "modal": spot != &"", "highlight_kind": String(kind), "highlight_iid": _iid_for(kind),
		"guided": true, "dismissable": (FLOW.get(guided_step, {}) as Dictionary).has(&"dismissed")}
	if spot != &"":
		p["spotlight"] = String(spot)
	return p


## Pindah langkah terpandu. Tip modal biasa yang sedang tampil tetap di depan,
## dan tip yang mengantre tampil lebih dulu; prompt langkahnya muncul begitu
## tip itu ditutup.
func _set_step(s: StringName) -> void:
	guided_step = _resolve(s)
	# Dicatat sebagai sudah tampil, supaya ikut arsip bantuan (GDD 27.6).
	if GUIDED.has(guided_step):
		var g: Array = GUIDED[guided_step]
		if String(g[0]) != "":
			done[String(g[0])] = true
		if g.size() > 2:
			_mark_spotlight(g[2])
		for k: Variant in COVERS.get(guided_step, []):
			done[str(k)] = true
	if bool(prompt.get("modal", false)) and not bool(prompt.get("guided", false)):
		return
	prompt = _queue.pop_front() if not _queue.is_empty() else _guided_prompt()
	EventBus.tutorial_step_changed.emit(StringName(str(prompt.get("key", ""))))


## Langkah yang keadaannya sudah tercapai langsung dilewati (GDD 88, "recovery
## condition"): toko sudah buka saat Skip to Open diminta, pembeli sudah di
## dalam saat menunggu pembeli, pemain sudah berdiri di kasir saat diminta ke
## kasir, pembeli sudah menunggu di depan kasir saat pemain baru tiba.
func _resolve(s: StringName) -> StringName:
	for i in GUIDED.size():
		var nxt: StringName = s
		match s:
			&"skip_open":
				if sim.time.phase != TimeManager.PREPARATION:
					nxt = &"open_tour"
			&"buyer_wait":
				if sim.customers.first_buyer() != null:
					nxt = &"buyer"
			&"serve":
				var lane: QueueLane = sim.queue.main_lane()
				if lane != null and sim.player.is_manning_lane(lane.id):
					nxt = &"serve_wait"
			&"serve_wait":
				if _customer_at_counter():
					nxt = &"serve_tap"
		if nxt == s:
			break
		s = nxt
	return s


## Pembeli sudah berdiri di depan meja kasir jalur pemain dan menunggu diketuk
## (GDD 21.4).
func _customer_at_counter() -> bool:
	var lane: QueueLane = sim.queue.main_lane()
	if lane == null or lane.service_occupant == &"":
		return false
	var c: Customer = sim.customers.customer(lane.service_occupant)
	return c != null and c.awaiting_tap and c.state == Customer.FRONT_OF_QUEUE and not c.actor.has_route()


## Pemain menutup prompt (tombol "Got it", sorotan selesai, atau langkah
## berikut tercapai). Prompt terpandu hanya bisa ditutup bila langkahnya maju
## lewat `dismissed` (sorotan dan petunjuk penutup).
func dismiss() -> void:
	if bool(prompt.get("guided", false)):
		if not bool(prompt.get("dismissable", false)):
			return
		prompt = {}
		_set_step(StringName(str((FLOW.get(guided_step, {}) as Dictionary).get(&"dismissed", &""))))
		return
	prompt = {}
	if not _queue.is_empty():
		prompt = _queue.pop_front()
	elif guided_step != &"":
		prompt = _guided_prompt()
	EventBus.tutorial_step_changed.emit(StringName(str(prompt.get("key", ""))))


## Tutup prompt `key` bila masih yang tampil (layar tutorial yang menutup
## dirinya sendiri tidak pernah menutup prompt lain).
func dismiss_key(key: String) -> void:
	if str(prompt.get("key", "")) == key:
		dismiss()


func _hint_done(key: String) -> void:
	if str(prompt.get("key", "")) == key and not bool(prompt.get("modal", false)) and not bool(prompt.get("guided", false)):
		dismiss()


func begin_day() -> void:
	if not active():
		return
	match sim.time.day:
		1:
			_show("tut_welcome", true)
			_set_step(&"decor_open")
		2:
			_set_step(&"")
			_show("tut_day2_prep", false)
		3:
			_set_step(&"")
			_show("tut_day3_balance", true)


func on_event(ev: StringName) -> void:
	if skipped:
		return
	done["ev_" + String(ev)] = true
	if ev == &"storage_opened":
		done["storage_opened"] = true
	# Urutan terpandu Hari 1 (GDD 88.1).
	if guided_step != &"":
		var nxt: Variant = (FLOW.get(guided_step, {}) as Dictionary).get(ev)
		if nxt != null:
			if ev == &"oven_ready" and guided_step == &"baking":
				_show("tut_burn_risk", true, &"oven")
			_set_step(nxt)
	match ev:
		&"near_burn":
			if sim.time.day >= 2:
				_show("tut_smart_speed", false)
		&"customer_queued":
			if sim.queue.main_lane() != null and sim.queue.main_lane().reservations.size() >= 2 and sim.time.day >= 2:
				_show("tut_queue_capacity", false)
		&"player_at_cashier", &"manual_service_started":
			_hint_done("tut_manual_cashier")
		&"first_payment":
			_show("tut_income", false)
		&"rotifood_order":
			# Pesanannya menunggu di panel sampai dikemas, jadi sorotannya boleh
			# mengantre di belakang tip modal lain.
			_show("tut_rotifood_first", true, &"", "", &"rotifood_order")
		&"summary":
			# Hari 1: setelah tutup, kenalkan Staff Management dan Marketing
			# (GDD 88.1). Langkah terpandu lain yang belum selesai berakhir di sini.
			_set_step(&"close_staff" if sim.time.day == 1 else &"")
			_show("tut_summary", true)
			if sim.time.day == 3:
				_show("tut_market_unlock", true)
				_show("tut_market_teaser", false)
		&"pricing_opened":
			if sim.time.day >= 2:
				_show("tut_pricing", false)
		&"store_open":
			if sim.time.day == 2 and sim.inventory.is_empty():
				_show("tut_fried_bread_stale", false)


func on_customer_entered(c: Customer) -> void:
	if skipped:
		return
	on_event(&"customer_entered")
	# Hari 1 terpandu mengenalkan pembeli pertama dengan sorotan (GDD 88.1).
	if guided_step == &"":
		_show("tut_patience", true)
	if c.archetype == &"customer_office_worker":
		_show("tut_office_worker", false)


## Pengunjung lihat-lihat pertama yang pulang tanpa membeli (GDD 20.12, 88.1):
## sorotan sekali padanya yang mem-pause game. Bila tip modal lain sedang
## tampil, tip ini menunggu pengunjung lihat-lihat berikutnya.
func on_window_shopper_left() -> void:
	if skipped or bool(prompt.get("modal", false)):
		return
	_show("tut_window_shopper", true, &"", "", &"window_shopper")


## Kejutan pertama di toko (GDD 31.9, 88.1): sorotan sekali pada pemerannya
## yang menjelaskan bahwa kejutan hanya tontonan. Dipanggil SurpriseDirector
## sesaat setelah pemeran masuk; bila tip modal lain sedang tampil, tip ini
## menunggu kejutan berikutnya.
func on_surprise() -> void:
	if skipped or bool(prompt.get("modal", false)):
		return
	_show("tut_surprise", true, &"", "", &"surprise")


func on_customer_front(_c: Customer) -> void:
	if sim.staff.any_cashier_working():
		return
	_show("tut_manual_cashier", false, &"cashier")


func on_freshness_changed(state: StringName) -> void:
	if state == &"GOOD" and sim.time.day <= 3:
		_show("tut_freshness", true)


## Arsip bantuan: kunci prompt yang sudah pernah tampil (GDD 27.6 replay).
func archive() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in done.keys():
		var s: String = str(k)
		if s.begins_with("tut_"):
			out.append(s)
	return out


func capture() -> Dictionary:
	return {"done": done.keys(), "skipped": skipped, "prompt": prompt.duplicate(), "step": String(guided_step)}


func restore(d: Dictionary) -> void:
	new_game()
	for k: Variant in d.get("done", []):
		done[str(k)] = true
	skipped = bool(d.get("skipped", false))
	prompt = (d.get("prompt", {}) as Dictionary).duplicate()
	guided_step = StringName(str(d.get("step", "")))
	# Langkah yang tidak dikenal lagi (save dari versi lain): urutan terpandu selesai.
	if guided_step != &"" and not GUIDED.has(guided_step):
		guided_step = &""
		if bool(prompt.get("guided", false)):
			prompt = {}
