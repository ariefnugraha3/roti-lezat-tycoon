class_name StaffScreen
extends Control
## Manajemen Karyawan (GDD 3.1-3.5 dan GDD 7 "Manajemen Karyawan").
##
## Pelamar ditampilkan sebagai kartu polaroid. Rekrutmen gratis (GDD 3.4) —
## bebannya murni gaji harian — dan kapasitas dibatasi tier lokasi (GDD 3.3).

var _content: VBoxContainer = null
var _role: String = "kasir"
var _mode: String = "aktif"  ## "aktif" = staf terpakai, "lamar" = bursa pelamar
var _main: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)
	_build_shell()
	_render()


func setup(_args: Dictionary) -> void:
	_main = _find_main()
	_render()


func _build_shell() -> void:
	var popup: Control = ProceduralUIFactory.popup("Manajemen Karyawan")
	add_child(popup)
	var head: HBoxContainer = popup.get_meta("head")
	var v: VBoxContainer = popup.get_meta("body")
	(popup.get_meta("scrim") as Control).gui_input.connect(_on_scrim_input)

	var tutup: Button = ProceduralUIFactory.icon_button("cross", "Tutup", "ghost", 22)
	tutup.pressed.connect(_on_close)
	head.add_child(tutup)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for t_v in [["kasir", "aktif", "Kasir Saya"], ["baker", "aktif", "Dapur Saya"],
			["kasir", "lamar", "Lamaran Kasir"], ["baker", "lamar", "Lamaran Baker"]]:
		var t: Array = t_v
		var b: Button = ProceduralUIFactory.button(String(t[2]), "secondary")
		b.pressed.connect(_on_tab.bind(String(t[0]), String(t[1])))
		tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


func _on_tab(role: String, mode: String) -> void:
	_role = role
	_mode = mode
	AudioBus.sfx("tap")
	_render()


func _on_close() -> void:
	AudioBus.sfx("tap")
	if not ScreenRouter.back():
		ScreenRouter.go("hud")


## Ketukan pada kaca gelap di luar kartu = tutup (GDD 12.4: satu ketukan).
func _on_scrim_input(event: InputEvent) -> void:
	var tekan: bool = (event is InputEventMouseButton
			and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tekan:
		_on_close()


func _render() -> void:
	if _content == null:
		return
	for c in _content.get_children():
		c.queue_free()

	var staff_sim: Object = _systems().get("staff")
	var terpakai: int = 0
	var kapasitas: int = 0
	if staff_sim != null and staff_sim.has_method("staff_count"):
		terpakai = int(staff_sim.call("staff_count", _role))
		kapasitas = int(staff_sim.call("capacity", _role))

	var label_peran: String = "Asisten Kasir" if _role == "kasir" else "Asisten Dapur"
	_content.add_child(ProceduralUIFactory.label(
		"%s — terpakai %d dari %d slot (Tier lokasi %d)"
		% [label_peran, terpakai, kapasitas, GameState.location_tier], 14, Palette.TEXT_MUTED))

	if GameState.solo_mode:
		_content.add_child(ProceduralUIFactory.label(
			"Mode Solo aktif: semua karyawan sedang diliburkan sampai kas pulih.",
			14, Palette.WARNING))

	if _mode == "aktif":
		_render_hired()
	else:
		_render_applicants(staff_sim)


func _render_hired() -> void:
	var ada: bool = false
	for s_v in GameState.staff:
		var s: Dictionary = s_v
		if String(s.get("role", "")) != _role:
			continue
		ada = true
		_content.add_child(_hired_card(s))
	if not ada:
		_content.add_child(ProceduralUIFactory.label(
			"Belum ada karyawan. Buka tab lamaran untuk merekrut (gratis).",
			14, Palette.TEXT_MUTED))


func _hired_card(s: Dictionary) -> Control:
	var id: String = String(s.get("staff_id", ""))
	var e: Dictionary = StaffDB.entry(id)
	var libur: bool = bool(s.get("on_leave", false))

	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.PANEL, 18, true))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	pc.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)

	var kartu: Control = ProceduralUIFactory.polaroid(id)
	kartu.modulate = Color(1, 1, 1, 0.45) if libur else Color.WHITE
	h.add_child(kartu)

	var kanan := VBoxContainer.new()
	kanan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kanan.add_theme_constant_override("separation", 4)
	h.add_child(kanan)

	kanan.add_child(ProceduralUIFactory.label(String(e.get("perk", "")), 13,
		Palette.TEXT_MUTED))
	if libur:
		kanan.add_child(ProceduralUIFactory.label(
			"Sedang diliburkan — tidak digaji hari ini.", 13, Palette.WARNING))

	# GDD 3.2: mode kerja khusus Asisten Dapur.
	if _role == "baker":
		kanan.add_child(_baker_mode_row(id))

	var aksi := HBoxContainer.new()
	aksi.add_theme_constant_override("separation", 8)
	kanan.add_child(aksi)

	var toggle: Button = ProceduralUIFactory.button(
		"Pekerjakan Lagi" if libur else "Liburkan", "secondary")
	toggle.pressed.connect(_on_leave.bind(id, not libur))
	aksi.add_child(toggle)

	var pecat: Button = ProceduralUIFactory.button("Berhentikan", "danger")
	pecat.pressed.connect(_on_fire.bind(id))
	aksi.add_child(pecat)
	return pc


func _baker_mode_row(id: String) -> Control:
	var staff_sim: Object = _systems().get("staff")
	var mode: Dictionary = {}
	if staff_sim != null and staff_sim.has_method("baker_mode_of"):
		mode = staff_sim.call("baker_mode_of", id)
	var sekarang: String = String(mode.get("mode", "auto_replenish"))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(ProceduralUIFactory.label("Mode:", 13, Palette.TEXT_MUTED))

	var auto_b: Button = ProceduralUIFactory.button("Auto-Replenish",
		"primary" if sekarang == "auto_replenish" else "ghost")
	auto_b.pressed.connect(_on_baker_mode.bind(id, "auto_replenish", ""))
	h.add_child(auto_b)

	var target_b: Button = ProceduralUIFactory.button("Target Resep",
		"primary" if sekarang == "target" else "ghost")
	# Target memakai resep pertama yang terbuka; pemain bisa menggantinya di Buku Resep.
	var pilihan: String = String(mode.get("recipe_id", ""))
	if pilihan == "" and not GameState.unlocked_recipes.is_empty():
		pilihan = String(GameState.unlocked_recipes[0])
	target_b.pressed.connect(_on_baker_mode.bind(id, "target", pilihan))
	h.add_child(target_b)
	return h


func _render_applicants(staff_sim: Object) -> void:
	var ids: Array = []
	if staff_sim != null and staff_sim.has_method("roster"):
		ids = staff_sim.call("roster", _role)
	else:
		ids = StaffDB.by_role(_role)

	var bisa: bool = true
	if staff_sim != null and staff_sim.has_method("can_hire"):
		bisa = bool(staff_sim.call("can_hire", _role))
	if not bisa:
		_content.add_child(ProceduralUIFactory.label(
			"Slot penuh. Upgrade tier toko untuk menambah kapasitas (GDD 3.3).",
			14, Palette.WARNING))

	var sudah: Dictionary = {}
	for s_v in GameState.staff:
		sudah[String((s_v as Dictionary).get("staff_id", ""))] = true

	for id_v in ids:
		var id: String = String(id_v)
		if sudah.has(id):
			continue
		_content.add_child(_applicant_card(id, bisa))


func _applicant_card(id: String, bisa: bool) -> Control:
	var e: Dictionary = StaffDB.entry(id)

	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.PANEL_ALT, 18, true))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	pc.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	h.add_child(ProceduralUIFactory.polaroid(id))

	var kanan := VBoxContainer.new()
	kanan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kanan.add_theme_constant_override("separation", 4)
	h.add_child(kanan)

	var profil: Label = ProceduralUIFactory.label(String(e.get("profile", "")), 13,
		Palette.TEXT_MUTED)
	profil.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kanan.add_child(profil)
	kanan.add_child(ProceduralUIFactory.label(String(e.get("perk", "")), 13))

	var rekrut: Button = ProceduralUIFactory.button("Rekrut (Gratis)", "primary")
	rekrut.disabled = not bisa
	rekrut.pressed.connect(_on_hire.bind(id))
	kanan.add_child(rekrut)
	return pc


# ===========================================================================
# AKSI
# ===========================================================================

func _on_hire(id: String) -> void:
	var staff_sim: Object = _systems().get("staff")
	if staff_sim == null or not staff_sim.has_method("hire"):
		return
	if bool(staff_sim.call("hire", id)):
		AudioBus.sfx("pop")
		EventBus.toast.emit("%s bergabung!" % String(StaffDB.entry(id).get("name", id)), "people")
	else:
		EventBus.toast.emit("Slot karyawan sudah penuh.", "warning")
	_render()


func _on_fire(id: String) -> void:
	var staff_sim: Object = _systems().get("staff")
	if staff_sim != null and staff_sim.has_method("fire"):
		staff_sim.call("fire", id)
		AudioBus.sfx("tap")
	_render()


func _on_leave(id: String, libur: bool) -> void:
	var staff_sim: Object = _systems().get("staff")
	if staff_sim != null and staff_sim.has_method("set_leave"):
		staff_sim.call("set_leave", id, libur)
		AudioBus.sfx("tap")
	_render()


func _on_baker_mode(id: String, mode: String, recipe_id: String) -> void:
	var staff_sim: Object = _systems().get("staff")
	if staff_sim != null and staff_sim.has_method("set_baker_mode"):
		staff_sim.call("set_baker_mode", id, mode, recipe_id)
		AudioBus.sfx("tap")
	_render()


func _systems() -> Dictionary:
	if _main == null or not is_instance_valid(_main):
		_main = _find_main()
	if _main == null:
		return {}
	var raw: Variant = _main.get("systems")
	return raw if raw is Dictionary else {}


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
