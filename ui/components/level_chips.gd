class_name LevelChips
extends Control
## Chip level di atas setiap stasiun (GDD idle 12.1): "Lv 12" di atas mixer,
## oven, rak, dan meja kasir di lantai yang sedang dilihat, dengan panah naik
## yang berdenyut bila upgrade ×1 terjangkau. Chip adalah kontrol 2D yang
## diproyeksikan dari dunia, dan mengetuknya satu-satunya cara membuka kartu
## upgrade dari dunia; mengetuk perabotnya sendiri hanya memberi Semangat (GDD
## idle §20 no. 77, menggantikan no. 69).
##
## Chip dibuat besar supaya mudah diketuk: pil bulat bertulisan 20 px, dengan
## target sentuh `PAD` lebih luas di setiap sisi. Stasiun yang berjajar rapat
## (Tier 4-5) membuat chip bertabrakan, jadi setiap frame chip ditata dari yang
## paling depan (paling bawah di layar): chip yang menabrak chip lain didorong
## ke atas sampai berjarak `GAP_PX` (ke bawah bila ke atas ia keluar layar),
## lalu garis tipis menghubungkannya ke puncak stasiunnya. Panel HUD
## (`blockers`: KR, boost, jam, tombol pojok, bar tab) dihindari dengan cara yang
## sama, supaya chip tidak pernah tertutup panel yang menelan ketukannya. Chip
## juga digeser masuk ke layar bila stasiunnya di tepi.
##
## Chip disimpan per stasiun (pool, v3.1 §129) dan hanya dibuat/dibuang saat
## daftar stasiun berubah, jadi ketukan tidak pernah hilang karena tombolnya
## diganti di tengah tekan. Posisi diperbarui tiap frame; teks dan panah pada
## refresh HUD.

## Jarak bawah pil dari puncak model (px layar).
const LIFT_PX: float = 6.0
## Ukuran teks dan panah pil.
const FONT_PX: int = 20
const ARROW_PX: int = 22
## Target sentuh di luar pil, per sisi (px).
const PAD: Vector2 = Vector2(8.0, 8.0)
## Jarak paling kecil antarpil setelah ditata, dan dari tepi layar (px; selebar
## PAD supaya target sentuhnya juga tetap di dalam layar).
const GAP_PX: float = 6.0
const EDGE_PX: float = 8.0
## Chip yang tergeser lebih jauh dari ini dari tempatnya mendapat garis ke stasiunnya (px).
const LEADER_MIN_PX: float = 4.0
## Kategori perabot yang punya chip dan kartu upgrade stasiun.
const STATION_CATEGORIES: Array[StringName] = [&"mixer", &"oven", &"display"]

var game: GameRoot = null
var sim: SimulationRoot = null
## Kotak layar yang tidak boleh ditutupi chip (HUD.chip_blockers), -> Array[Rect2].
var blockers: Callable = Callable()
## key ("s<iid>" / "counter") -> {button, label, arrow, kind, id, pill, key,
## rect (kotak pil di layar), tip (puncak stasiun di layar)}
var _chips: Dictionary = {}
var _t: float = 0.0
## Tanda tata letak frame lalu (posisi puncak, ukuran pil, penghalang HUD,
## ukuran layar): sama = tata letak dan garis tidak dihitung ulang (GDD idle
## §20 no. 87).
var _last_sig: PackedFloat32Array = PackedFloat32Array()
var _sig_buf: PackedFloat32Array = PackedFloat32Array()
var _shown_buf: Array[Dictionary] = []
## Hambatan terlihat (GDD idle §20 no. 88): pembeli terakhir yang ditolak karena
## antrean penuh (statistik dan waktu nyata), dan giliran chip yang dinilai
## kenaikan KR/s-nya (satu chip per refresh, supaya tidak ada lonjakan kerja).
var _missed_seen: float = -1.0
var _missed_at_msec: int = -1000000
var _gain_turn: int = 0
var _gain_timer: float = 0.0
var _gain_cache: Dictionary = {}
var _counter_local_top: Vector3 = Vector3.INF
var _counter_ref: Node3D = null
## Pembeli yang ditolak dalam sekian detik nyata terakhir menyalakan "Queue full".
const QUEUE_FULL_SECONDS: float = 10.0
## Kenaikan KR/s di bawah bagian ini dari KR/s sekarang dianggap nol: panah abu-abu.
const NO_GAIN_RATIO: float = 0.001
const GAIN_CHECK_SECONDS: float = 1.0


func _init() -> void:
	name = "LevelChips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	EventBus.level_up.connect(_on_level_up)


## Kunci chip untuk penawaran.
static func key_of(kind: StringName, id: Variant) -> String:
	return "counter" if kind == &"counter" else "s%d" % int(id)


func chip(kind: StringName, id: Variant) -> Button:
	var c: Variant = _chips.get(key_of(kind, id))
	return (c as Dictionary)["button"] if c is Dictionary else null


## Perbarui daftar chip, teks levelnya, dan panah "terjangkau".
func refresh() -> void:
	if sim == null or game == null or game.world == null:
		return
	var want: Dictionary = {}
	for cat: StringName in STATION_CATEGORIES:
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			want[key_of(&"station", e.iid)] = [&"station", e.iid]
	want["counter"] = [&"counter", &"counter"]
	for k: Variant in _chips.keys():
		if not want.has(k):
			((_chips[k] as Dictionary)["button"] as Node).queue_free()
			_chips.erase(k)
			_last_sig = PackedFloat32Array()
	for k2: Variant in want.keys():
		if not _chips.has(k2):
			_chips[k2] = _make(want[k2][0], want[k2][1])
			_last_sig = PackedFloat32Array()
		var c: Dictionary = _chips[k2]
		var lvl: int = sim.upgrades.station_level(int(c["id"])) if c["kind"] == &"station" else sim.upgrades.counter_level
		var tier_now: int = sim.world.location.tier
		var o: Dictionary = c.get("offer_cache", {}) as Dictionary
		if o.is_empty() or int(c.get("offer_lvl", -1)) != lvl or int(c.get("offer_tier", -1)) != tier_now or int(c.get("offer_cnt", -1)) != _chips.size():
			o = sim.upgrades.offer(c["kind"], c["id"])
			c["offer_cache"] = o
			c["offer_lvl"] = lvl
			c["offer_tier"] = tier_now
			c["offer_cnt"] = _chips.size()
			var room: int = int(o.get("cap", 0)) - int(o.get("level", 0)) if not o.is_empty() else 0
			c["next_room"] = room
			c["next_cost"] = Money.round_cents(UpgradeManager.series_cost(float(o["base"]), float(o["growth"]), int(o["steps"]), 1)) if room >= 1 else 0.0
		if int(c.get("last_lvl", -1)) != lvl:
			c["last_lvl"] = lvl
			(c["label"] as Label).text = Tx.t("ui_level_chip", {"level": lvl})
			c["sz_dirty"] = true
		var show_arrow: bool = int(c.get("next_room", 0)) >= 1 and sim.economy.can_afford(float(c.get("next_cost", 0.0)))
		var arrow: Control = c["arrow"] as Control
		if arrow.visible != show_arrow:
			arrow.visible = show_arrow
			c["sz_dirty"] = true
	_refresh_queue_full()
	_refresh_gain_turn()


## "Queue full" di chip meja kasir selama ada pembeli yang baru saja ditolak
## karena antrean penuh DAN antrean kasir saat ini memang masih penuh terisi
## (tidak menyala saat kasir kosong atau slot baru saja terbuka).
func _refresh_queue_full() -> void:
	var missed: float = sim.statistics.get_stat("total_customers_missed")
	var currently_full: bool = _queue_currently_full()
	if _missed_seen >= 0.0 and missed > _missed_seen and currently_full:
		_missed_at_msec = Time.get_ticks_msec()
	_missed_seen = missed
	var full: bool = currently_full and float(Time.get_ticks_msec() - _missed_at_msec) / 1000.0 <= QUEUE_FULL_SECONDS
	var c: Variant = _chips.get("counter")
	if c is Dictionary and (c as Dictionary).has("full"):
		var tag: Control = (c as Dictionary)["full"]
		if tag.visible != full:
			tag.visible = full
			(c as Dictionary)["sz_dirty"] = true
			_last_sig = PackedFloat32Array()


func _queue_currently_full() -> bool:
	if sim == null or sim.queue == null:
		return false
	var lanes: Array[QueueLane] = sim.queue.open_physical_lanes()
	if lanes.is_empty():
		return false
	var any_in_line: bool = false
	for l: QueueLane in lanes:
		if l.free_capacity() > 0:
			return false
		if not l.line.is_empty():
			any_in_line = true
	return any_in_line


## Satu chip per refresh: panah hijau bila satu level menaikkan KR/s, abu-abu bila
## tidak (stasiun itu bukan hambatannya sekarang; GDD idle §20 no. 88).
func _refresh_gain_turn() -> void:
	if _chips.is_empty():
		return
	var keys: Array = _chips.keys()
	_gain_turn = (_gain_turn + 1) % keys.size()
	var c: Dictionary = _chips[keys[_gain_turn]]
	var arrow: IconCanvas = c["arrow"]
	if not arrow.visible:
		return
	var o: Dictionary = c.get("offer_cache", {}) as Dictionary
	if o.is_empty():
		o = sim.upgrades.offer(c["kind"], c["id"])
	var rate: float = sim.idle_economy.rate(false)
	var gsig: String = "%d|%.4f|%d" % [int(o.get("level", 1)), rate, _chips.size()]
	var ck: String = str(c["key"])
	var useful: bool
	if _gain_cache.has(ck) and str((_gain_cache[ck] as Array)[0]) == gsig:
		useful = bool((_gain_cache[ck] as Array)[1])
	else:
		var gain: float = sim.idle_economy.delta_rate(o, 1)
		useful = gain > maxf(rate, 0.000001) * NO_GAIN_RATIO
		_gain_cache[ck] = [gsig, useful]
	if bool(c.get("useful_set", false)) and bool(c.get("useful", true)) == useful:
		return
	c["useful_set"] = true
	c["useful"] = useful
	arrow.configure("up", ARROW_PX, Palette.MATCHA if useful else Palette.TEXT_MUTED)


## Panah chip `key` sedang hijau (naik level menaikkan KR/s) atau abu-abu (tes).
func arrow_useful(key: String) -> bool:
	var c: Variant = _chips.get(key)
	return c is Dictionary and bool((c as Dictionary).get("useful", true))


## Tanda "Queue full" chip meja kasir tampil (tes).
func queue_full_shown() -> bool:
	var c: Variant = _chips.get("counter")
	return c is Dictionary and (c as Dictionary).has("full") and ((c as Dictionary)["full"] as Control).visible


func _make(kind: StringName, id: Variant) -> Dictionary:
	var b := Button.new()
	b.name = "Chip_" + key_of(kind, id)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var pill := PanelContainer.new()
	pill.name = "Pill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PANEL, 24, true)
	sb.border_color = Color(Palette.UI_WOOD, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	pill.add_theme_stylebox_override("panel", sb)
	pill.position = PAD
	b.add_child(pill)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	pill.add_child(row)
	var l: Label = ProceduralUIFactory.label("", FONT_PX, Palette.UI_WOOD_DEEP)
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	row.add_child(l)
	var arrow: IconCanvas = ProceduralUIFactory.icon("up", ARROW_PX, Palette.MATCHA)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.name = "Arrow"
	arrow.visible = false
	row.add_child(arrow)
	var k: StringName = kind
	var i: Variant = id
	b.pressed.connect(func() -> void: open_card(k, i))
	add_child(b)
	var out: Dictionary = {"button": b, "label": l, "arrow": arrow, "kind": kind, "id": id, "pill": pill, "key": String(b.name),
		"rect": Rect2(), "tip": Vector2.ZERO}
	if kind == &"counter":
		var full: Label = ProceduralUIFactory.label(Tx.t("ui_chip_queue_full"), 15, Palette.DANGER)
		full.name = "QueueFull"
		full.add_theme_font_override("font", ProceduralUIFactory.display_font())
		full.visible = false
		row.add_child(full)
		out["full"] = full
	return out


## Buka kartu upgrade stasiun itu. Kartu yang sudah terbuka untuk stasiun yang
## sama dibiarkan (ketukan beruntun tidak membangunnya ulang).
func open_card(kind: StringName, id: Variant) -> void:
	if game == null:
		return
	var open: UpgradeCard = game.modals.screen(&"upgrade_card") as UpgradeCard
	if open != null and open.kind == kind and str(open.id) == str(id):
		return
	game.modals.close_id(&"upgrade_card")
	game.modals.open(&"upgrade_card", {"kind": kind, "id": id})


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if game == null or game.world == null or sim == null:
		return
	var rig: CameraRig = game.world.camera_rig
	var view: Vector2 = get_viewport_rect().size
	var pulse: float = 1.0 if SettingsManager.reduced_motion() else 1.0 + 0.12 * sin(_t * TAU * 1.2)
	_shown_buf.clear()
	var n_floats: int = 2
	if _sig_buf.size() < 2:
		_sig_buf.resize(2)
	_sig_buf[0] = roundf(view.x * 2.0)
	_sig_buf[1] = roundf(view.y * 2.0)
	for k: Variant in _chips.keys():
		var c: Dictionary = _chips[k]
		var b: Button = c["button"]
		var at: Vector3 = _anchor(c)
		var s: Vector2 = rig.world_to_screen(at) if at != Vector3.INF else Vector2(-1.0e6, -1.0e6)
		b.visible = s.x > 0.0 and s.x < view.x and s.y > 0.0 and s.y < view.y
		if not b.visible:
			continue
		c["tip"] = s
		_shown_buf.append(c)
		var sz: Vector2
		if bool(c.get("sz_dirty", true)):
			sz = (c["pill"] as Control).get_combined_minimum_size()
			c["sz"] = sz
			c["sz_dirty"] = false
		else:
			sz = c["sz"]
		if _sig_buf.size() < n_floats + 4:
			_sig_buf.resize(n_floats + 4)
		_sig_buf[n_floats] = roundf(s.x * 2.0)
		_sig_buf[n_floats + 1] = roundf(s.y * 2.0)
		_sig_buf[n_floats + 2] = sz.x
		_sig_buf[n_floats + 3] = sz.y
		n_floats += 4
		var arrow: Control = c["arrow"]
		if arrow.visible:
			arrow.pivot_offset = arrow.size * 0.5
			arrow.scale = Vector2(pulse, pulse)
	if blockers.is_valid():
		for r: Rect2 in blockers.call():
			if _sig_buf.size() < n_floats + 4:
				_sig_buf.resize(n_floats + 4)
			_sig_buf[n_floats] = r.position.x
			_sig_buf[n_floats + 1] = r.position.y
			_sig_buf[n_floats + 2] = r.size.x
			_sig_buf[n_floats + 3] = r.size.y
			n_floats += 4
	if _sig_buf.size() != n_floats:
		_sig_buf.resize(n_floats)
	if _sig_buf == _last_sig:
		return
	_last_sig = _sig_buf.duplicate()
	_layout(_shown_buf, view)
	queue_redraw()


static func _cmp_chip(a: Dictionary, b: Dictionary) -> bool:
	var ya: float = (a["tip"] as Vector2).y
	var yb: float = (b["tip"] as Vector2).y
	if ya != yb:
		return ya > yb
	return str(a["key"]) < str(b["key"])


## Tata chip yang tampak: mulai dari yang paling depan (puncak stasiunnya paling
## bawah di layar), setiap pil yang menabrak pil yang sudah ditata didorong ke
## atas sampai berjarak GAP_PX; bila itu membuatnya keluar dari atas layar, ia
## didorong ke bawah saja. Pil juga digeser masuk ke layar di kiri-kanan.
func _layout(shown: Array[Dictionary], view: Vector2) -> void:
	shown.sort_custom(_cmp_chip)
	var placed: Array[Rect2] = []
	if blockers.is_valid():
		placed.assign(blockers.call())
	for c: Dictionary in shown:
		var pill: Control = c["pill"]
		var sz: Vector2 = c["sz"]
		var tip: Vector2 = c["tip"]
		var r := Rect2(Vector2(tip.x - sz.x * 0.5, tip.y - LIFT_PX - sz.y), sz)
		r.position.x = clampf(r.position.x, EDGE_PX, maxf(EDGE_PX, view.x - sz.x - EDGE_PX))
		r.position.y = clampf(r.position.y, EDGE_PX, maxf(EDGE_PX, view.y - sz.y - EDGE_PX))
		var up: Rect2 = _settle(r, placed, true)
		var down: Rect2 = _settle(r, placed, false)
		if up.position.y >= EDGE_PX:
			r = up
		elif down.end.y <= view.y - EDGE_PX:
			r = down
		else:
			r.position.y = EDGE_PX
		placed.append(r)
		c["rect"] = r
		pill.size = sz
		var b: Button = c["button"]
		b.position = r.position - PAD
		b.size = sz + PAD * 2.0


## Geser kotak `r` ke atas (`up`) atau ke bawah sampai tidak menabrak kotak
## `placed` mana pun, dengan jarak GAP_PX.
static func _settle(r: Rect2, placed: Array[Rect2], up: bool) -> Rect2:
	for guard in 64:
		var hit: bool = false
		for q: Rect2 in placed:
			if r.grow(GAP_PX * 0.5).intersects(q.grow(GAP_PX * 0.5)):
				r.position.y = q.position.y - GAP_PX - r.size.y if up else q.end.y + GAP_PX
				hit = true
		if not hit:
			break
	return r


## Garis tipis dari chip yang tergeser ke puncak stasiunnya.
func _draw() -> void:
	var col := Color(Palette.UI_WOOD, 0.55)
	for c: Dictionary in _chips.values():
		if not (c["button"] as Button).visible:
			continue
		var r: Rect2 = c["rect"]
		var tip: Vector2 = c["tip"]
		var foot := Vector2(r.get_center().x, r.end.y if r.get_center().y < tip.y else r.position.y)
		if foot.distance_to(tip - Vector2(0.0, LIFT_PX)) <= LEADER_MIN_PX:
			continue
		draw_line(foot, tip, col, 2.0, false)
		ProceduralUIFactory.circle_aa(self, tip, 3.5, col)


## Kotak pil chip di layar setelah ditata (kosong bila tidak tampak).
func chip_rect(kind: StringName, id: Variant) -> Rect2:
	var c: Variant = _chips.get(key_of(kind, id))
	if not (c is Dictionary) or not ((c as Dictionary)["button"] as Button).visible:
		return Rect2()
	return (c as Dictionary)["rect"]


func _anchor(c: Dictionary) -> Vector3:
	var rig: CameraRig = game.world.camera_rig
	if c["kind"] == &"counter":
		var lane: QueueLane = sim.queue.main_lane()
		if lane == null or lane.floor_id != rig.active_floor:
			return Vector3.INF
		var n: Node3D = game.world.main_counter()
		if n == null:
			return Vector3.INF
		if n != _counter_ref or _counter_local_top == Vector3.INF:
			_counter_ref = n
			var b: AABB = EquipmentFactory._mesh_bounds(n)
			_counter_local_top = Vector3(b.get_center().x, b.end.y, b.get_center().z)
		return n.global_transform * _counter_local_top
	var e: EquipmentInstance = sim.equipment.get_inst(int(c["id"]))
	if e == null or not e.placed or e.floor_id != rig.active_floor:
		return Vector3.INF
	return game.world.top_of_iid(e.iid)


## Naik level: chip-nya memantul sebentar (Reduced Motion: tidak).
func _on_level_up(kind: StringName, id: Variant, _level: int, _milestone: bool) -> void:
	if kind != &"station" and kind != &"counter":
		return
	refresh()
	var c: Variant = _chips.get(key_of(kind, id))
	if c is Dictionary and not SettingsManager.reduced_motion():
		ProceduralAnimationSystem.squash_pop((c as Dictionary)["pill"], 1.25, 0.25)
