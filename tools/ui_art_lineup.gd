extends Control
## QA gambar UI 2D (v3.1 12.3.3, 130.6): potret Pak Lurah, potret karakter New
## Game, polaroid staf, dan gambar toko di kartu profil, berjajar dalam ukuran
## yang dipakai layar sungguhan, lalu disimpan ke PNG. Jalankan dengan jendela
## (perlu renderer):
##   godot --path . --resolution 720x1280 res://tools/ui_art_lineup.tscn
## Folder keluaran: env LINEUP_OUT, atau user://lineup bila tidak diisi.
## `-- --zoom=2` menggambar potret dan toko dua kali lebih besar untuk QA detail.


func _ready() -> void:
	var out: String = OS.get_environment("LINEUP_OUT")
	if out == "":
		out = ProjectSettings.globalize_path("user://lineup")
	DirAccess.make_dir_recursive_absolute(out)
	var z: float = 1.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--zoom="):
			z = maxf(1.0, float(a.substr(7)))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	ProceduralUIFactory.apply_theme(self)
	var bg := ColorRect.new()
	bg.color = Palette.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_top = 16
	v.add_theme_constant_override("separation", 18)
	add_child(v)
	# Pak Lurah: popup tutorial, Welcome Back, cutscene Waralaba.
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 18)
	v.add_child(r1)
	for px: float in ([104.0, 140.0, 220.0] if z <= 1.0 else [220.0 * z]):
		var l := LurahPortrait.new()
		l.custom_minimum_size = Vector2(px, px)
		l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r1.add_child(l)
	# Potret New Game (pria, wanita) dan dua polaroid staf.
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 14)
	v.add_child(r2)
	for g: String in ["male", "female"]:
		var p := ProceduralUIFactory.ChibiPortrait.new()
		p.custom_minimum_size = Vector2(220, 200) * minf(z, 1.5)
		p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		p.configure(NewGameScreen.portrait_visual(g), "baker", 1)
		r2.add_child(p)
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 14)
	v.add_child(r3)
	for sid: String in ["staff_cashier_budi", "staff_baker_ani", "staff_baker_joko"]:
		var pol: Control = ProceduralUIFactory.polaroid(sid)
		pol.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		r3.add_child(pol)
	# Gambar toko di kartu profil: tier 1-5 dan profil kosong.
	var r4 := HBoxContainer.new()
	r4.add_theme_constant_override("separation", 12)
	v.add_child(r4)
	for tier: int in [0, 1, 2, 3, 4, 5]:
		var shop := ShopFrontArt.new()
		shop.tier = tier
		shop.custom_minimum_size = Vector2(104, 104) * minf(z, 1.1)
		r4.add_child(shop)
	# Kartu profil sungguhan: save tier 3 dan profil kosong.
	var r5 := VBoxContainer.new()
	r5.custom_minimum_size = Vector2(600, 0)
	r5.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(r5)
	var ps := ProfileScreen.new()
	ps.params = {"mode": "load"}
	r5.add_child(ps._card(1, {"profile_id": &"profile_1", "exists": true, "bakery_name": "Sweet Crumbs", "day": 12,
		"location_id": "location_t3_independent_bakery", "balance_kr": 12345.0, "badges": [], "last_played_at": "2026-11-03T10:00:00Z"}))
	r5.add_child(ps._card(2, {"profile_id": &"profile_2", "exists": false}))
	ps.free()
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join("ui_art_lineup.png"))
	print("UI ART saved to ", out.path_join("ui_art_lineup.png"))
	get_tree().quit(0)
