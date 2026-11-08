class_name ShareCard
extends RefCounted
## Kartu "Share my bakery" dan foto (GDD idle 21.4, 21.5). Semua gambar dibuat di
## game: potret dunia tanpa HUD, lalu kartu 1080×1350 (4:5, ukuran unggahan
## media sosial) dirakit dari kit UI flat di SubViewport sementara. Tidak ada
## server: di Web gambarnya dibagikan lewat lembar bagi browser (Web Share) atau
## diunduh, di platform lain disimpan ke folder Pictures/Crumbtown.

const SIZE: Vector2i = Vector2i(1080, 1350)
## Bagian potret dunia yang dipakai kartu (lebar : tinggi).
const PHOTO_ASPECT: float = 2.0

## Tes: folder simpan pengganti ("" = Pictures/Crumbtown atau user://screenshots).
static var out_dir_override: String = ""


## Potret dunia apa adanya, tanpa HUD dan modal (satu frame tanpa keduanya).
static func capture_world(game: GameRoot) -> Image:
	var hud_on: bool = game.hud != null and game.hud.visible
	var modals_on: bool = game.modals.visible
	if game.hud != null:
		game.hud.visible = false
	game.modals.visible = false
	await after_draw(game)
	await after_draw(game)
	var img: Image = grab(game.get_viewport())
	if game.hud != null:
		game.hud.visible = hud_on
	game.modals.visible = modals_on
	return img


## Tunggu satu frame tergambar. Tanpa renderer (headless, tes) sinyal
## frame_post_draw tidak pernah datang, jadi cukup satu process frame.
static func after_draw(node: Node) -> void:
	if DisplayServer.get_name() == "headless":
		await node.get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


## Gambar isi viewport `vp` (RGB8). Tanpa renderer (headless) teksturnya kosong:
## hasilnya bidang krem seukuran viewport, supaya alurnya tetap berjalan.
static func grab(vp: Viewport) -> Image:
	var tex: ViewportTexture = vp.get_texture()
	var img: Image = tex.get_image() if tex != null and DisplayServer.get_name() != "headless" else null
	if img == null or img.is_empty():
		var sz: Vector2i = (vp as SubViewport).size if vp is SubViewport else Vector2i(vp.get_visible_rect().size)
		img = Image.create(maxi(1, sz.x), maxi(1, sz.y), false, Image.FORMAT_RGB8)
		img.fill(Palette.SHEET)
	img.convert(Image.FORMAT_RGB8)
	return img


## Potongan tengah potret dunia selebar `PHOTO_ASPECT`, sedikit di atas tengah
## (lantai toko berada di antara bar HUD atas dan bawah).
static func crop_photo(img: Image) -> Image:
	var w: int = img.get_width()
	var h: int = mini(img.get_height(), int(round(float(w) / PHOTO_ASPECT)))
	var cy: int = int(round(float(img.get_height()) * 0.47))
	var y: int = clampi(cy - h / 2, 0, img.get_height() - h)
	return img.get_region(Rect2i(0, y, w, h))


## Rakit kartu dari potret `photo` (sudah dipotong) dan state simulasi.
static func build(game: GameRoot, photo: Image) -> Image:
	var sim: SimulationRoot = game.sim
	var keep_scale: float = ProceduralUIFactory.text_scale
	ProceduralUIFactory.text_scale = 1.0
	var vp := SubViewport.new()
	vp.name = "ShareCardViewport"
	vp.size = SIZE
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game.add_child(vp)
	var root := Control.new()
	root.size = Vector2(SIZE)
	vp.add_child(root)
	ProceduralUIFactory.apply_theme(root)
	var bg := ColorRect.new()
	bg.color = Palette.SHEET
	bg.size = Vector2(SIZE)
	root.add_child(bg)
	var band := Gingham.new()
	band.position = Vector2.ZERO
	band.size = Vector2(float(SIZE.x), 64.0)
	root.add_child(band)
	var foot_band := Gingham.new()
	foot_band.position = Vector2(0.0, float(SIZE.y) - 40.0)
	foot_band.size = Vector2(float(SIZE.x), 40.0)
	root.add_child(foot_band)
	var col := VBoxContainer.new()
	col.position = Vector2(60.0, 80.0)
	col.size = Vector2(float(SIZE.x) - 120.0, float(SIZE.y) - 136.0)
	col.add_theme_constant_override("separation", 16)
	root.add_child(col)
	var logo: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"), 58, 64, 860.0)
	col.add_child(logo)
	# Potret toko dalam bingkai kartu.
	var frame := PanelContainer.new()
	var fsb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 30, false)
	fsb.set_content_margin_all(14.0)
	frame.add_theme_stylebox_override("panel", fsb)
	col.add_child(frame)
	var pic := TextureRect.new()
	pic.name = "Photo"
	pic.texture = ImageTexture.create_from_image(photo)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(float(SIZE.x) - 148.0, (float(SIZE.x) - 148.0) / PHOTO_ASPECT)
	pic.clip_contents = true
	frame.add_child(pic)
	var name_l: Label = _fixed(ProceduralUIFactory.title(sim.bakery_name, 54), 54)
	name_l.name = "BakeryName"
	name_l.clip_text = true
	col.add_child(name_l)
	var where: String = Tx.t(String(sim.world.location.localization_key))
	if sim.prestige.run_index > 1:
		where = Tx.t("ui_share_branch_line", {"location": where, "number": sim.prestige.branch_no})
	var sub: Label = _fixed(ProceduralUIFactory.label(where, 28, Palette.TEXT_MUTED), 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var grid := GridContainer.new()
	grid.name = "Stats"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	col.add_child(grid)
	for st: Array in stats(sim):
		grid.add_child(_stat_tile(str(st[0]), str(st[1]), str(st[2])))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var tag := CenterContainer.new()
	col.add_child(tag)
	var rb: PanelContainer = ProceduralUIFactory.ribbon_plate(Tx.t("ui_share_tagline"), 34, 900.0)
	tag.add_child(rb)
	ProceduralUIFactory.text_scale = keep_scale
	for i in 3:
		await after_draw(game)
	var img: Image = grab(vp)
	vp.queue_free()
	return img


## Empat angka kartu: [ikon, nilai, keterangan].
static func stats(sim: SimulationRoot) -> Array:
	var out: Array = [
		["coin", Tx.t("ui_kr_per_second", {"amount": Tx.rate(sim.income_rate())}), Tx.t("ui_share_stat_rate")],
		["bread", Tx.big(sim.statistics.get_stat("total_bread_sold")), Tx.t("ui_share_stat_sold")],
	]
	if sim.prestige.stars > 0:
		out.append(["star", Tx.big(float(sim.prestige.stars)), Tx.t("ui_share_stat_stars")])
	else:
		out.append(["people", Tx.big(sim.statistics.get_stat("total_customers_served")), Tx.t("ui_share_stat_served")])
	out.append(["sun", Tx.big(float(sim.time.day)), Tx.t("ui_share_stat_days")])
	return out


static func _stat_tile(icon_name: String, value: String, caption: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 24, false)
	sb.set_content_margin_all(12.0)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(471.0, 0.0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	pc.add_child(h)
	h.add_child(ProceduralUIFactory.badge(icon_name, Palette.HONEY_SOFT, Palette.HONEY_DEEP, 64))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var val: Label = _fixed(ProceduralUIFactory.label(value, 36, Palette.UI_WOOD_DEEP), 36)
	val.add_theme_font_override("font", ProceduralUIFactory.display_font())
	v.add_child(val)
	v.add_child(_fixed(ProceduralUIFactory.label(caption, 22, Palette.TEXT_MUTED), 22))
	return pc


## Ukuran huruf tetap (kartu tidak ikut pengaturan ukuran teks).
static func _fixed(l: Label, size: int) -> Label:
	l.add_theme_font_size_override("font_size", size)
	return l


## Nama berkas aman: "crumbtown-<toko>-<YYYYmmdd-HHMMSS>".
static func file_base(sim: SimulationRoot, kind: String) -> String:
	var shop: String = ""
	for ch: String in sim.bakery_name.to_lower():
		shop += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	while shop.contains("--"):
		shop = shop.replace("--", "-")
	shop = shop.strip_edges().trim_prefix("-").trim_suffix("-")
	var stamp: String = Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "-")
	return "crumbtown-%s-%s%s" % [kind, (shop + "-") if shop != "" else "", stamp]


## Simpan atau bagikan PNG. Hasil: {kind: "share"|"download"|"saved"|"error", path}.
static func export_png(img: Image, base: String) -> Dictionary:
	var buf: PackedByteArray = img.save_png_to_buffer()
	if WebPlatform.is_web():
		return {"kind": WebPlatform.share_or_download_png(buf, base + ".png", Tx.t("ui_share_tagline")), "path": ""}
	var dir: String = out_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join(base + ".png")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"kind": "error", "path": path}
	f.store_buffer(buf)
	f.close()
	return {"kind": "saved", "path": path}


## Folder simpan di luar Web: Pictures/Crumbtown di desktop, folder data game di
## tempat lain.
static func out_dir() -> String:
	if out_dir_override != "":
		return out_dir_override
	var pic: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pic != "" and not OS.has_feature("android") and not OS.has_feature("ios"):
		return pic.path_join("Crumbtown")
	return ProjectSettings.globalize_path("user://screenshots")


## Pita gingham (taplak) di tepi kartu.
class Gingham:
	extends Control

	func _draw() -> void:
		ProceduralUIFactory.draw_gingham(self, Rect2(Vector2.ZERO, size))
