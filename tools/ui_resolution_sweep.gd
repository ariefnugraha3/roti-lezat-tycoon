extends Node
## Sapuan resolusi dan skala teks (GDD idle 12.0.7, menggantikan v3.1 110):
## membuka layar-layar utama (menu dan dalam game) di setiap ukuran matriks
## potret, tablet, dan laptop/PC, pada skala teks 100/125/150%, memotretnya, dan
## mencetak "SWEEP OFF" untuk setiap Control yang tampak tetapi keluar dari layar
## (di luar ScrollContainer). Save memakai folder uji sendiri. Jalankan dengan
## jendela (perlu renderer), lalu baca baris "SWEEP done, N issues":
##   godot --path . --resolution 540x960 res://tools/ui_resolution_sweep.tscn
## Folder potret: env LINEUP_OUT, atau user://lineup bila tidak diisi.
## Filter opsional: -- --res=720x1280,1920x1080 --scales=100,150
## --screens=welcome_back,franchise (menu utama dilewati bila --screens diisi)
## --full (potret ukuran penuh, bukan setengah), --date=YYYY-MM-DD (tanggal
## perangkat palsu, mis. untuk event musiman), --golden (Roti Emas terbang), --regular (pelanggan
## langganan berkunjung; juga memotret ketiga minigame pesanannya), --menus (hanya splash dan
## layar di luar permainan: popup toko baru kedua langkahnya, lalu dengan save
## Export Save dan Import Save), --ads
## (penyedia iklan dan toko palsu: tombol Ad dan kartu Supporter Pack, GDD idle 22),
## --tips (kartu tip, sorotan, dan panduan berkedip ke tab dan stasiun, GDD idle 13),
## --skin=id (skin atau pakaian dipakai dulu, boleh berulang), --floor=2 (lantai atas), --tier=N (lokasi permainan, bawaan 3), --name=teks (nama toko, papan nama), --hour=N (jam perangkat palsu untuk halaman start: 0-23), --lang=id (bahasa teks), --equip (semua slot stasiun dibuka: chip level
## di toko yang penuh).

const RES: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1080, 2400),
	Vector2i(1536, 2048), Vector2i(2048, 1536), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(2560, 1080)]
const SCALES: Array[int] = [100, 125, 150]
const MENU_SCREENS: Array[StringName] = [&"new_game", &"settings", &"credits", &"help"]
const OPEN_SCREENS: Array[StringName] = [&"upgrades", &"menu", &"staff", &"shop", &"franchise", &"stats", &"pause", &"settings",
	&"welcome_back", &"franchise_cutscene", &"tutorial", &"upgrade_card", &"decoration", &"goals", &"calendar", &"share", &"photo_mode", &"town_map", &"regular_order",
	&"store", &"reward_reveal"]

var game: GameRoot = null
var shell: PortraitShell = null
var _out: String = ""
var _golden: bool = false
var _regular: bool = false
var _issues: int = 0
var _res: Array[Vector2i] = RES.duplicate()
var _scales: Array[int] = SCALES.duplicate()
var _screens: Array[StringName] = []
## Potret ukuran penuh (--full); bawaannya diperkecil setengah.
var _full: bool = false
## Hanya splash dan layar menu (--menus).
var _menus: bool = false
## Potret tip onboarding sesudah HUD (--tips).
var _tips: bool = false
## Lokasi permainan (--tier=N) dan semua slot stasiun dibuka (--equip).
var _tier: int = 3
var _equip: bool = false
## Skin atau pakaian yang dipakai sebelum dipotret (--skin=id, boleh berulang).
var _skins: Array[StringName] = []
## Lantai yang dilihat kamera (--floor=2: lantai atas lokasi bertingkat).
var _floor: int = 1
## Nama toko (--name=teks), mis. nama panjang untuk papan nama.
var _name: String = "Sweep Bakery"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--res="):
			_res.clear()
			for t: String in a.substr(6).split(","):
				var wh: PackedStringArray = t.split("x")
				_res.append(Vector2i(int(wh[0]), int(wh[1])))
		elif a.begins_with("--scales="):
			_scales.clear()
			for t2: String in a.substr(9).split(","):
				_scales.append(int(t2))
		elif a == "--full":
			_full = true
		elif a == "--menus":
			_menus = true
		elif a.begins_with("--screens="):
			for t3: String in a.substr(10).split(","):
				_screens.append(StringName(t3))
		elif a == "--regular":
			# Pelanggan langganan berkunjung, dan album berisi beberapa teman (GDD idle 21.10).
			_regular = true
		elif a == "--ads":
			# Iklan berhadiah dan toko palsu (GDD idle 22): tombol Ad, kartu Supporter.
			Monetization.path = "user://sweep_monetization.json"
			Monetization.reset_for_tests()
			Monetization.use_provider(TestMonetizationProvider.new())
		elif a == "--tips":
			# Tip onboarding: kartu di atas bar tab, sorotan, dan panduan berkedip (GDD idle 13).
			_tips = true
		elif a == "--golden":
			# Roti Emas di tengah terbang dan hadiah boost-nya di HUD (GDD idle 21.9).
			_golden = true
		elif a.begins_with("--tier="):
			_tier = clampi(int(a.substr(7)), 1, 5)
		elif a == "--equip":
			_equip = true
		elif a.begins_with("--skin="):
			_skins.append(StringName(a.substr(7)))
		elif a.begins_with("--floor="):
			_floor = clampi(int(a.substr(8)), 1, 2)
		elif a.begins_with("--name="):
			_name = a.substr(7)
		elif a.begins_with("--lang="):
			# Bahasa teks (GDD idle 20 no. 109), tanpa menyimpan pilihan pemain.
			SettingsManager.values["language"] = a.substr(7)
			DataRegistry.set_language(a.substr(7))
		elif a.begins_with("--hour="):
			# Halaman start siang/malam (GDD idle 20 no. 106).
			StartScene.hour_override = clampi(int(a.substr(7)), 0, 23)
		elif a.begins_with("--date="):
			# Tanggal perangkat palsu, mis. untuk event musiman (GDD idle 21.6).
			BoostManager.date_override = a.substr(7)
	_out = OS.get_environment("LINEUP_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("user://lineup")
	DirAccess.make_dir_recursive_absolute(_out)
	PauseManager.lifecycle_enabled = false
	# Folder save uji sendiri: jangan pernah menyentuh save pemain.
	SaveManager.dir = "user://test_saves_sweep"
	Monetization.use_test_file("ui_resolution_sweep")
	# Popup penawaran tidak menutupi foto HUD.
	for op: Dictionary in Monetization.products("offer"):
		Monetization.mark_offer_shown(StringName(str(op["id"])))
	# Scene utama sungguhan: bingkai potret dengan taplak di sisinya (GDD idle 12.0).
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(shell)
	game = shell.game
	await _frames(2)
	if _menus:
		await _menu_pass()
		return
	game.skip_splash_for_tests()
	await _frames(4)
	var was_scale: int = SettingsManager.get_int("text_scale")
	for r: Vector2i in _res:
		if not _screens.is_empty():
			break
		await _resize(r)
		for sc: int in _scales:
			SettingsManager.set_value("text_scale", sc)
			await _frames(3)
			for id: StringName in MENU_SCREENS:
				await _visit(id, {}, r, sc)
	await game.start_new_game(&"profile_3", "female", _name)
	await _frames(20)
	PauseManager.lifecycle_enabled = false
	PauseManager.clear_all()
	var sim: SimulationRoot = game.sim
	sim.tutorial.skip()
	while sim.world.location.tier < _tier:
		sim.debug_add_kr(sim.location_price(sim.world.location.tier + 1))
		if sim.upgrade_location() != "":
			break
	if _equip:
		sim.debug_add_kr(1.0e15)
		for cat: StringName in [&"display", &"oven", &"mixer"]:
			while sim.upgrades.open_station(cat) >= 0:
				pass
		await _frames(4)
	sim.debug_set_time(10.0 * 3600.0)
	# Beberapa dekorasi milik (belum dipasang) supaya tab katalog Decoration Mode
	# punya baris "Your Decorations".
	for did: StringName in [&"decor_gingham_curtains", &"decor_cassette_radio", &"decor_potted_plant", &"decor_terracotta_rug",
			&"outfit_apron_neighborhood"]:
		if not sim.decoration.owns(did):
			sim.decoration._add(did)
	for sk: StringName in _skins:
		sim.decoration.grant(sk)
		sim.decoration.equip(sk)
	if not _skins.is_empty():
		game.world.rebuild_all()
	if _floor == 2 and sim.world.location.is_multi_floor():
		game.world.toggle_view_floor()
		await _frames(30)
	game.playing = true
	for r2: Vector2i in _res:
		await _resize(r2)
		for sc2: int in _scales:
			SettingsManager.set_value("text_scale", sc2)
			game.modals.close_all()
			if _regular and sim.regulars.visit.is_empty():
				sim.regulars.friends = {"regular_mila": {"orders": 4, "level": 2}, "regular_rosa": {"orders": 11, "level": 4}}
				sim.regulars.next_in = 0.0
				for i in int(20.0 / sim.tick_seconds):
					sim.step(sim.tick_seconds)
			if _golden:
				sim.golden.next_in = 0.0
				sim.golden.step(sim.tick_seconds)
				sim.golden.visible_left = DataRegistry.idlef("golden.visible_seconds") * 0.5
				sim.boosts.add_frenzy(3.0, 30.0)
				sim.boosts.add_rush(2.0, 60.0)
			await _frames(4)
			_check(game.hud, "hud", r2, sc2)
			await _shot("hud", r2, sc2)
			if _tips:
				await _tip_shots(r2, sc2)
			for id2: StringName in OPEN_SCREENS:
				if game.modals.has_screen(id2) and (_screens.is_empty() or _screens.has(id2)):
					await _visit(id2, _params_for(id2), r2, sc2)
	SettingsManager.set_value("text_scale", was_scale)
	print("SWEEP done, %d issues" % _issues)
	game.modals.close_all()
	game.playing = true
	game.end_session()
	await _frames(2)
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	get_tree().quit(0)


## Splash dan layar menu saja (--menus): tanpa save, lalu dengan satu save Tier 3.
func _menu_pass() -> void:
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var was_scale: int = SettingsManager.get_int("text_scale")
	for r: Vector2i in _res:
		await _resize(r)
		for sc: int in _scales:
			SettingsManager.set_value("text_scale", sc)
			await _frames(3)
			if r == _res[0] and sc == _scales[0]:
				await _shot("splash", r, sc)
				game.skip_splash_for_tests()
				await _frames(2)
			await _menu_screens(r, sc, "")
	SettingsManager.set_value("text_scale", was_scale)
	await game.start_new_game(SaveManager.SAVE_ID, "female", _name)
	await _frames(10)
	var sim: SimulationRoot = game.sim
	sim.tutorial.skip()
	while sim.world.location.tier < 3:
		sim.debug_add_kr(SimulationRoot.location_cost(sim.world.location.tier + 1))
		if sim.upgrade_location() != "":
			break
	sim.debug_add_kr(123456.0)
	game.playing = true
	game.end_session()
	await _frames(4)
	for r2: Vector2i in _res:
		await _resize(r2)
		for sc2: int in _scales:
			SettingsManager.set_value("text_scale", sc2)
			await _frames(3)
			await _menu_screens(r2, sc2, "_saved")
	SettingsManager.set_value("text_scale", was_scale)
	print("SWEEP done, %d issues" % _issues)
	game.modals.close_all()
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	get_tree().quit(0)


func _menu_screens(r: Vector2i, sc: int, suffix: String) -> void:
	game.modals.close_all()
	if suffix != "":
		# Kode save (GDD idle 20 no. 57): Export Save, lalu Import Save dengan
		# pratinjau kode save itu.
		var latest: StringName = SaveManager.SAVE_ID
		var sc_code: UIScreen = game.modals.open(&"save_code", {"profile_id": latest})
		await _frames(4)
		_check(sc_code, "save_code" + suffix, r, sc)
		await _shot("save_code" + suffix, r, sc)
		game.modals.close_screen(sc_code)
		var imp: ImportSaveScreen = game.modals.open(&"import_save") as ImportSaveScreen
		await _frames(2)
		_check(imp, "import_save_empty" + suffix, r, sc)
		await _shot("import_save_empty" + suffix, r, sc)
		imp.show_code(SaveManager.export_code(latest))
		await _frames(4)
		_check(imp, "import_save" + suffix, r, sc)
		await _shot("import_save" + suffix, r, sc)
		game.modals.close_screen(imp)
		return
	game.open_new_game()
	var ng: NewGameScreen = game.modals.screen(&"new_game") as NewGameScreen
	for step in NewGameScreen.STEPS:
		ng._step = step
		ng._render()
		await _frames(4)
		_check(ng, "new_game_%d" % step, r, sc)
		await _shot("new_game_%d" % step, r, sc)
	game.modals.close_screen(ng)


func _resize(r: Vector2i) -> void:
	get_window().size = r
	await _frames(6)
	print("SWEEP window %s -> frame %s, logical %s" % [r, shell.frame, shell.viewport.size_2d_override])


func _visit(id: StringName, params: Dictionary, r: Vector2i, sc: int) -> void:
	game.modals.close_all()
	await _frames(1)
	var s: UIScreen = game.modals.open(id, params)
	await _frames(4)
	# Kartu Share dirakit beberapa frame; simpan juga kartunya utuh.
	if s is ShareScreen:
		var wait: int = 0
		while (s as ShareScreen).card == null and wait < 300:
			await _frames(1)
			wait += 1
		if (s as ShareScreen).card != null:
			(s as ShareScreen).card.save_png(_out.path_join("%dx%d_%d_share_card.png" % [r.x, r.y, sc]))
		await _frames(2)
	if s is PhotoModeScreen:
		(s as PhotoModeScreen)._set_filter(1)
		(s as PhotoModeScreen)._toggle_frame()
		await _frames(2)
	var label: String = String(id) + (("_tab%d" % int(params["tab"])) if params.has("tab") else "")
	if s != null:
		_check(s, label, r, sc)
	await _shot(label, r, sc)
	# Minigame pesanan regular (GDD idle 20 no. 110): ketiganya, Ingat Pesanan juga
	# sesudah pesanannya ditutup, Panggang Pas dengan jarum di zona emas.
	if s is RegularOrderScreen and not game.sim.regulars.visit.is_empty():
		for g: String in RegularManager.GAMES:
			game.modals.close_all()
			await _frames(1)
			game.sim.regulars.visit["game"] = g
			var ro: RegularOrderScreen = game.modals.open(&"regular_order", params) as RegularOrderScreen
			await _frames(4)
			if g == "bake":
				var z: Vector2 = ro.bake_zone(0)
				ro.doneness = (z.x + z.y) * 0.5
				await _frames(2)
			_check(ro, "regular_order_" + g, r, sc)
			await _shot("regular_order_" + g, r, sc)
			if g == "memory":
				ro.end_memory_show()
				await _frames(2)
				_check(ro, "regular_order_memory_go", r, sc)
				await _shot("regular_order_memory_go", r, sc)
		game.sim.regulars.visit["game"] = "pack"
		game.modals.close_all()
		return
	# Perayaan Store (GDD idle 22.11): beberapa barang sesudah animasinya tenang,
	# dan satu foto di tengah ledakan confetti.
	if s is RewardReveal:
		await get_tree().create_timer(1.8).timeout
		await _shot("reward_reveal_settled", r, sc)
		for rp: Dictionary in [{"deco": &"decor_golden_loaf_statue"}, {"deco": &"skin_awning_gold"}, {"deco": &"decor_neon_bread_sign"},
				{"deco": &"decor_marble_rug"}, {"deco": &"skin_door_galaxy"}, {"deco": &"skin_door_kitty"},
				{"product": &"bakers_club"}, {"product": &"starter_pack"}]:
			game.modals.close_all()
			await _frames(2)
			var rv: UIScreen = game.modals.open(&"reward_reveal", rp)
			var tag: String = str(rp.get("deco", rp.get("product", "")))
			await get_tree().create_timer(0.55).timeout
			if tag == "decor_golden_loaf_statue":
				await _shot("reward_reveal_burst_" + tag, r, sc)
			await get_tree().create_timer(1.3).timeout
			_check(rv, "reward_reveal_" + tag, r, sc)
			await _shot("reward_reveal_" + tag, r, sc)
		game.modals.close_all()
		return
	# Store (GDD idle 22.5): setiap tab.
	if s is StoreScreen:
		var store: StoreScreen = s
		store.sim.premium.ensure_season(BoostManager.today())
		store.sim.premium.add_xp(450)
		for t in range(1, StoreScreen.TAB_KEYS.size()):
			store.show_tab(t)
			await _frames(4)
			_check(s, "store_tab%d" % t, r, sc)
			await _shot("store_tab%d" % t, r, sc)
	# Katalog Decoration Mode (GDD idle §20 no. 72): setiap tab jenis barang.
	if s is DecorationScreen:
		var deco: DecorationScreen = s
		for t in range(1, DecorationScreen.TAB_KEYS.size()):
			deco._set_tab(t)
			await _frames(3)
			_check(s, "decoration_tab%d" % t, r, sc)
			await _shot("decoration_tab%d" % t, r, sc)
		# Mixer dipegang, empat putaran: panah sisi depannya (GDD idle §20 no. 76).
		var mixers: Array[EquipmentInstance] = game.sim.equipment.placed_list(&"mixer")
		if not mixers.is_empty():
			deco._hold_equipment(mixers[0].iid)
			for q in 4:
				await _frames(3)
				_check(s, "decoration_hold_r%d" % deco._rot, r, sc)
				await _shot("decoration_hold_r%d" % deco._rot, r, sc)
				deco._rotate()
			deco._cancel()
	# Cerita cabang lain (tabungan, Visit) dan cabang yang sedang dimainkan (GDD
	# idle 21.7, §20 no. 78).
	if s is TownMapScreen:
		var map: TownMapScreen = s
		for n: int in [1, game.sim.prestige.branch_no]:
			var lot: Button = map.content().find_child("Branch%d" % n, true, false) as Button
			if lot == null:
				continue
			lot.pressed.emit()
			await _frames(3)
			_check(s, "town_map_branch%d" % n, r, sc)
			await _shot("town_map_branch%d" % n, r, sc)
			map.pop_page()
			await _frames(2)
	# Tab Gameplay Settings: bagian save (Export, Import, Reset Game) saat bermain.
	if s is SettingsScreen and game.sim != null:
		for b: Node in s.find_children("*", "Button", true, false):
			if (b as Button).text == Tx.t("ui_settings_gameplay"):
				(b as Button).pressed.emit()
				break
		await _frames(3)
		_check(s, label + "_gameplay", r, sc)
		await _shot(label + "_gameplay", r, sc)
	# Halaman kedua cutscene: papan nama cabang baru.
	if s is FranchiseCutscene:
		(s as FranchiseCutscene)._advance()
		await _frames(3)
		_check(s, label + "_p2", r, sc)
		await _shot(label + "_p2", r, sc)
	game.modals.close_all()
	if game.sim != null:
		game.sim.offline.pending = {}
	await _frames(1)


## Isi contoh untuk layar yang butuh data: penghasilan offline yang menunggu
## Collect, dan bintang cutscene Waralaba.
func _params_for(id: StringName) -> Dictionary:
	match id:
		&"reward_reveal":
			return {"deco": &"outfit_night_owl"}
		&"welcome_back":
			game.sim.offline.pending = {"amount": 123456.0, "seconds": 7200.0, "away": 3.0 * 3600.0 + 25.0 * 60.0}
		&"franchise_cutscene":
			return {"stars": 12, "number": 3}
		&"tutorial":
			return {"key": "onb_welcome"}
		&"upgrade_card":
			return {"kind": &"station", "id": game.sim.equipment.placed_list(&"oven")[0].iid}
		&"goals":
			# Satu tujuan selesai, satu setengah jalan, dan cap hari ini tersedia.
			var g: GoalManager = game.sim.goals
			if g.goals.is_empty():
				# Tujuan mulai hari 2: lewati tengah malam dulu.
				game.sim.debug_set_time(86400.0 - 1.0)
				for i in 8:
					game.sim.step(game.sim.tick_seconds)
			if not g.goals.is_empty() and g.progress(g.goals[0]) <= 0.0:
				game.sim.statistics.add(StringName(str(g.goals[0]["stat"])), float(g.goals[0]["target"]))
				game.sim.statistics.add(StringName(str(g.goals[1]["stat"])), float(g.goals[1]["target"]) * 0.5)
			_stamp_card(3)
		&"calendar":
			_stamp_card(3)
			return {"date": BoostManager.today()}
		&"town_map":
			# Empat cabang lain yang menabung (GDD idle §20 no. 78), lalu cabang ke-5
			# yang sedang dimainkan.
			var pm: PrestigeManager = game.sim.prestige
			if pm.branches.is_empty():
				var now: float = game.sim.offline.now_unix()
				for t: int in [3, 4, 5, 4]:
					pm.branches.append({"number": pm.branches.size() + 1, "tier": t, "stars": 5 * t, "earned": 1.0e6 * t,
						"rate": 400.0 * t, "opened_day": 1, "left_unix": now - 1800.0 * t, "cap": 3.0 * 3600.0, "eff": 0.5,
						"state": {"location_id": String(DataRegistry.location_by_tier(t).id)}})
				pm.run_index = 5
				pm.branch_no = 5
	return {}


## Kartu cap contoh: `n` cap sudah diambil, cap hari ini tersedia.
func _stamp_card(n: int) -> void:
	game.sim.calendar.first_date = "2000-01-01"
	game.sim.calendar.last_date = ""
	game.sim.calendar.stamps = n


func _inside_clip(c: Control) -> bool:
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		if p is Control and (p as Control).clip_contents:
			return true
		p = p.get_parent()
	return false


## Setiap kontrol yang tampak harus berada di dalam bingkai potret (isi
## SubViewport); tidak ada yang boleh keluar ke area taplak (GDD idle 12.0.7).
func _check(root: Node, label: String, r: Vector2i, sc: int) -> void:
	var vis: Rect2 = game.get_viewport().get_visible_rect()
	var found: int = 0
	for n: Node in root.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or _inside_clip(c):
			continue
		var g: Rect2 = c.get_global_rect()
		if g.size.x < 1.0 or g.size.y < 1.0:
			continue
		if g.position.x < vis.position.x - 1.0 or g.position.y < vis.position.y - 1.0 or g.end.x > vis.end.x + 1.0 or g.end.y > vis.end.y + 1.0:
			found += 1
			_issues += 1
			if found <= 4:
				print("SWEEP OFF %dx%d @%d%% %s: %s %s %s" % [r.x, r.y, sc, label, c.get_class(), root.get_path_to(c), g])
	if found > 4:
		print("SWEEP OFF %dx%d @%d%% %s: ... %d more" % [r.x, r.y, sc, label, found - 4])


func _shot(label: String, r: Vector2i, sc: int) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if not _full:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out.path_join("%dx%d_%d_%s.png" % [r.x, r.y, sc, label]))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Tip onboarding (GDD idle 13): kartu tanpa sasaran di atas bar tab, sorotan
## yang mem-pause (KR), dan panduan berkedip ke tab dan ke stasiun di dunia.
func _tip_shots(r: Vector2i, sc: int) -> void:
	var sim: SimulationRoot = game.sim
	# Rak di lantai toko (dapur Tier 3 ada di lantai atas, di luar pandangan).
	var oven: int = sim.equipment.placed_list(&"display")[0].iid
	for t: Array in [["tip_card", "onb_offline", &"", "hint"], ["tip_spotlight", "onb_first_sale", &"cash", "spotlight"],
			["tip_guide_tab", "onb_hire", &"tab_staff", "hint"], ["tip_guide_station", "onb_tap_boost", StringName("station_%d" % oven), "hint"]]:
		game.modals.close_all()
		sim.tutorial.skipped = false
		sim.tutorial.done.erase(str(t[1]))
		sim.tutorial.prompt = {}
		sim.tutorial.show_step(str(t[1]), t[2], str(t[3]))
		await _frames(8)
		await _shot(str(t[0]), r, sc)
		sim.tutorial.dismiss()
		game.modals.close_all()
		await _frames(2)
	sim.tutorial.skip()

