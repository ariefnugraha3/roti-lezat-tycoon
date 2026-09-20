class_name RackScreen
extends Control
## Pemilih petak rak display (GDD 2: "roti ditaruh di slot etalase, posisi
## penempatan mempengaruhi penjualan").
##
## Muncul saat karakter pemain tiba di rak sambil membawa loyang. Petak digambar
## sebagai kisi tombol besar yang menyalin susunan rak sungguhan: kiri ke kanan
## persis seperti "Slot0".."Slot5" pada mesh rak, jadi apa yang ditekan pemain
## di sini adalah petak yang ia lihat di dunia 3D.
##
## Satu loyang bisa berisi lebih banyak roti daripada daya tampung satu petak.
## Karena itu layar ini TIDAK menutup sendiri setelah satu ketukan: ia menyegarkan
## diri dan membiarkan pemain menyebar sisanya ke petak lain.

## Sisi minimum satu tombol petak (GDD 7 / 12.4: hitbox minimal 48 dp).
const PETAK_PX: int = 108

var _main: Node = null
var _order_id: int = -1
var _rack: int = 0

var _judul: Label = null
var _info: Label = null
var _kisi: GridContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)
	_build()


func setup(args: Dictionary) -> void:
	_main = _find_main()
	_order_id = int(args.get("order_id", -1))
	_rack = maxi(0, int(args.get("rack", 0)))
	_render()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(Palette.BG.r, Palette.BG.g, Palette.BG.b, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe: Vector4 = ProceduralUIFactory.safe_area_margin()
	margin.add_theme_constant_override("margin_left", int(safe.x) + 24)
	margin.add_theme_constant_override("margin_top", int(safe.y) + 20)
	margin.add_theme_constant_override("margin_right", int(safe.z) + 24)
	margin.add_theme_constant_override("margin_bottom", int(safe.w) + 20)
	add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var kartu := PanelContainer.new()
	kartu.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.PANEL, 24, true))
	center.add_child(kartu)

	var m := MarginContainer.new()
	for sisi in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + sisi, 20)
	kartu.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	_judul = ProceduralUIFactory.title("Taruh di Petak Mana?", 26)
	_judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_judul)

	_info = ProceduralUIFactory.label("", 14, Palette.TEXT_MUTED)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(520, 0)
	v.add_child(_info)

	_kisi = GridContainer.new()
	_kisi.columns = GameConfig.SLOTS_PER_RACK
	_kisi.add_theme_constant_override("h_separation", 10)
	_kisi.add_theme_constant_override("v_separation", 10)
	v.add_child(_kisi)

	var tutup: Button = ProceduralUIFactory.button("Nanti Saja", "ghost")
	tutup.pressed.connect(_on_close)
	v.add_child(tutup)


# ===========================================================================
# ISI
# ===========================================================================

func _render() -> void:
	if _kisi == null:
		return
	for c in _kisi.get_children():
		c.queue_free()

	var pt: PlayerTaskSystem = _tasks()
	var pesanan: Dictionary = pt.order(_order_id) if pt != null else {}
	if pesanan.is_empty():
		_info.text = "Loyang ini sudah tidak ada."
		return

	var rid: String = String(pesanan.get("recipe_id", ""))
	var nama: String = String(RecipeDB.entry(rid).get("name", rid))
	var sisa: int = _sisa_loyang(pesanan)
	_judul.text = "Taruh %s di Petak Mana?" % nama
	_info.text = "Rak %d — sisa %d roti di loyang. Petak yang sudah berisi roti "  % [_rack + 1, sisa] \
		+ "lain tidak bisa dipakai."

	var quality: String = _kualitas(pesanan)
	for s: int in range(GameConfig.SLOTS_PER_RACK):
		_kisi.add_child(_tombol_petak(s, rid, quality))


func _tombol_petak(slot: int, rid: String, quality: String) -> Control:
	var gi: int = _rack * GameConfig.SLOTS_PER_RACK + slot
	var isi: Dictionary = GameState.display_entry_at(gi)
	var ruang: int = GameState.display_room_at(gi, rid, quality)

	var b: Button = ProceduralUIFactory.button("", "secondary" if ruang > 0 else "ghost")
	b.custom_minimum_size = Vector2(PETAK_PX, PETAK_PX)
	b.disabled = ruang <= 0
	b.pressed.connect(_on_petak.bind(gi))

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(v)

	var nomor: Label = ProceduralUIFactory.label("Petak %d" % (slot + 1), 13, Palette.TEXT_MUTED)
	nomor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nomor)

	var tengah := CenterContainer.new()
	tengah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tengah)
	if isi.is_empty():
		tengah.add_child(ProceduralUIFactory.icon("plus", 34, Palette.TEXT_MUTED))
	else:
		tengah.add_child(ProceduralUIFactory.icon("bread", 34,
			Palette.GOLDEN_CRUST if ruang > 0 else Palette.TEXT_MUTED))

	var ket: String = "kosong" if isi.is_empty() else "%d %s" % [
		int(isi.get("count", 0)),
		String(RecipeDB.entry(String(isi.get("recipe_id", ""))).get("name", "roti"))]
	if ruang <= 0 and not isi.is_empty():
		ket = "penuh / beda resep"
	var l: Label = ProceduralUIFactory.label(ket, 11, Palette.TEXT_MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return b


func _on_petak(global_slot: int) -> void:
	var pt: PlayerTaskSystem = _tasks()
	if pt == null:
		return
	var masuk: int = pt.place_bread(_order_id, global_slot)
	if masuk <= 0:
		EventBus.toast.emit("Petak itu tidak muat.", "warning")
		_render()
		return
	AudioBus.sfx("pop")
	# Pesanan yang sudah tuntas tidak ada lagi: layar menutup sendiri.
	if pt.order(_order_id).is_empty():
		_kembali()
		return
	_render()


func _on_close() -> void:
	AudioBus.sfx("tap")
	var pt: PlayerTaskSystem = _tasks()
	if pt != null:
		pt.cancel_rack(_order_id)
	_kembali()


func _kembali() -> void:
	if not ScreenRouter.back():
		ScreenRouter.go("hud")


# ===========================================================================
# Pembantu
# ===========================================================================

func _sisa_loyang(pesanan: Dictionary) -> int:
	var prod: ProductionSystem = _production()
	if prod == null:
		return 0
	var j: Dictionary = prod.job(int(pesanan.get("job_id", 0)))
	return int(j.get("remaining", 0))


func _kualitas(pesanan: Dictionary) -> String:
	var prod: ProductionSystem = _production()
	if prod == null:
		return ProductionSystem.QUALITY_PRIME
	var j: Dictionary = prod.job(int(pesanan.get("job_id", 0)))
	return String(j.get("quality", ProductionSystem.QUALITY_PRIME))


func _systems() -> Dictionary:
	if _main == null or not is_instance_valid(_main):
		_main = _find_main()
	if _main == null:
		return {}
	var raw: Variant = _main.get("systems")
	return raw if raw is Dictionary else {}


func _tasks() -> PlayerTaskSystem:
	return _systems().get("player") as PlayerTaskSystem


func _production() -> ProductionSystem:
	return _systems().get("prod") as ProductionSystem


func _find_main() -> Node:
	var t := get_tree()
	if t == null:
		return null
	var node: Node = t.current_scene
	if node is Main:
		return node
	if node != null:
		for c in node.get_children():
			if c is Main:
				return c
	return null
