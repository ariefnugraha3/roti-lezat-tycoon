extends Control
## Trailer promosi 60 detik, landscape 1920 x 1080 (permintaan maintainer
## 2026-11-03). Bukan bagian game: tools/ tidak ikut ekspor.
##
## Game sungguhan berjalan di SubViewport potret 720 x 1280 (layar ponsel di
## trailer), dan kamera sinematik kedua memotret dunia 3D yang sama dalam
## bingkai lebar. Teks promosi, logo, ketukan jari, dan musik trailer (digubah
## di sini dengan alat musik prosedural MusicBuild, 96 bpm, 24 bar = 60 detik)
## ditambahkan di atasnya. Setiap adegan berganti tepat di batas dua bar.
## Save memakai folder sendiri dan pengaturan pemain tidak disentuh.
##
## Rekam dengan Movie Maker (30 fps, PNG + WAV), lalu gabung dengan ffmpeg.
## Movie Maker memakai ukuran jendela proyek (540 x 960) dan mengabaikan
## --resolution, jadi selama merekam saja taruh override.cfg di akar proyek
## (hapus lagi sesudahnya):
##   [display] window/size/viewport_width=1920, viewport_height=1080,
##   window_width_override=1920, window_height_override=1080,
##   window/stretch/mode="viewport", window/stretch/aspect="keep"
##   godot --path . --write-movie <dir>/frame.png --fixed-fps 30 res://tools/trailer.tscn
## Baris "TRAILER_START <n>" menyebut bingkai pertama trailer; bingkai sebelumnya
## adalah boot game dan dibuang saat encode, begitu juga awal WAV-nya:
##   ffmpeg -framerate 30 -start_number <n> -i <dir>/frame%08d.png -ss <n/30> -i <dir>/frame.wav
##          -frames:v 1800 -af loudnorm=I=-14:TP=-1.5 -c:v libx264 -pix_fmt yuv420p -crf 16
##          -c:a aac -b:a 192k trailer.mp4
## QA cepat tanpa rekaman: `-- --stills` menyimpan satu PNG di tengah setiap
## adegan ke env LINEUP_OUT (atau user://lineup).

const OUT: Vector2 = Vector2(1920.0, 1080.0)
const PHONE_LOGICAL: Vector2 = Vector2(720.0, 1280.0)
const BPM: float = 96.0
const BEAT: float = 60.0 / BPM
const BAR: float = BEAT * 4.0
const LENGTH: float = BAR * 24.0
## Tier lokasi per adegan naik terus (lokasi tidak bisa turun).
const CTA_TITLE: String = "Bake your dream bakery"
const CTA_BUTTON: String = "Play now"
const CTA_PLATFORMS: String = "Web  ·  Android"

var game: GameRoot = null
var sim: SimulationRoot = null
var _stills: bool = false
var _out_dir: String = ""
var _phone_vp: SubViewport = null
var _cine_vp: SubViewport = null
var _cam: Camera3D = null
var _cine: TextureRect = null
var _fx: Control = null
var _veil: ColorRect = null
var _phone: Control = null
var _phone_screen: Control = null
var _layer: Control = null
var _flash: ColorRect = null
var _music: AudioStreamPlayer = null
var _t: float = -1.0
var _shot: int = -1
var _shots: Array[Dictionary] = []
## Pose kamera sinematik adegan sekarang: [dari, ke] masing-masing
## {focus, yaw, pitch, dist, fov}.
var _pose_from: Dictionary = {}
var _pose_to: Dictionary = {}
var _taps: Array[Dictionary] = []
var _shot_nodes: Array[Node] = []
var _phone_x: float = 0.0
var _oven_iid: int = -1
var _night_from: float = 0.0


func _ready() -> void:
	_stills = OS.get_cmdline_user_args().has("--stills")
	_out_dir = OS.get_environment("LINEUP_OUT")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://lineup")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Gambar akhir selalu 1920 x 1080, berapa pun ukuran jendelanya.
	var root: Window = get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(OUT)
	Engine.max_fps = 0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = OUT
	# Pengaturan bawaan di memori saja (tidak disimpan), musik game diam: trailer
	# punya musiknya sendiri. Save di folder sendiri.
	SettingsManager.values = SettingsManager.DEFAULTS.duplicate(true)
	SettingsManager.values["mute_when_unfocused"] = false
	SettingsManager.values["music_volume"] = 0
	# Ruang kepala 6 dB: campuran tidak terpotong di WAV; ffmpeg menormalkan
	# kerasnya saat encode.
	SettingsManager.values["master_volume"] = 50
	SettingsManager.values["sfx_volume"] = 45
	SettingsManager.values["ui_volume"] = 50
	SettingsManager.values["ambient_volume"] = 30
	ProceduralUIFactory.text_scale = 1.0
	SaveManager.dir = "user://trailer_saves"
	_build_stage()
	await _boot_game()
	_build_music()
	_build_shots()
	await _frames(4)
	_start()


# ===========================================================================
# PANGGUNG
# ===========================================================================

func _build_stage() -> void:
	ProceduralUIFactory.apply_theme(self)
	var bg := ColorRect.new()
	bg.color = Palette.PANEL
	bg.size = OUT
	add_child(bg)
	_phone_vp = SubViewport.new()
	_phone_vp.name = "PhoneView"
	_phone_vp.size = Vector2i(PHONE_LOGICAL)
	_phone_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_phone_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_phone_vp)
	_cine_vp = SubViewport.new()
	_cine_vp.name = "CineView"
	_cine_vp.size = Vector2i(OUT)
	_cine_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_cine_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_cine_vp)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_cam.near = 0.1
	_cam.far = 300.0
	_cine_vp.add_child(_cam)
	_cam.current = true
	_cine = TextureRect.new()
	_cine.texture = _cine_vp.get_texture()
	_cine.size = OUT
	_cine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cine)
	# Koin melompat di atas gambar sinematik (ukuran UI ponsel x 1,5).
	_fx = Control.new()
	_fx.size = OUT / 1.5
	_fx.scale = Vector2(1.5, 1.5)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_veil = ColorRect.new()
	_veil.color = Color(Palette.PANEL, 0.0)
	_veil.size = OUT
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_build_phone()
	_layer = Control.new()
	_layer.size = OUT
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_flash = ColorRect.new()
	_flash.color = Color(Palette.FLOUR_WHITE, 1.0)
	_flash.size = OUT
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


## Ponsel: bingkai cokelat tua bersudut membulat dengan layar game potret di
## dalamnya (dipotong sudut layarnya), tanpa poni supaya HUD tidak tertutup.
func _build_phone() -> void:
	_phone = Control.new()
	_phone.name = "Phone"
	var body_size := Vector2(536.0, 936.0)
	_phone.size = body_size
	_phone.position = Vector2(OUT.x + 40.0, (OUT.y - body_size.y) * 0.5)
	add_child(_phone)
	var body := Panel.new()
	var bsb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.UI_WOOD_DEEP, 64, false)
	body.add_theme_stylebox_override("panel", bsb)
	body.size = body_size
	_phone.add_child(body)
	var screen := Panel.new()
	var ssb: StyleBoxFlat = ProceduralUIFactory.panel(Color.BLACK, 48, false)
	screen.add_theme_stylebox_override("panel", ssb)
	screen.position = Vector2(14.0, 14.0)
	screen.size = Vector2(508.0, 908.0)
	screen.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_phone.add_child(screen)
	_phone_screen = screen
	var tex := TextureRect.new()
	tex.texture = _phone_vp.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.size = screen.size
	screen.add_child(tex)


## Titik di layar game potret (koordinat logis 720 x 1280) -> titik di trailer.
func _phone_point(p: Vector2) -> Vector2:
	var sc: Vector2 = _phone_screen.size / PHONE_LOGICAL
	var k: float = maxf(sc.x, sc.y)
	var off: Vector2 = (_phone_screen.size - PHONE_LOGICAL * k) * 0.5
	return _phone.position + _phone_screen.position + off + p * k


# ===========================================================================
# GAME
# ===========================================================================

func _boot_game() -> void:
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	game = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	_phone_vp.add_child(game)
	await _frames(2)
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", Tx.t("ui_bakery_name_default"))
	sim = game.sim
	PauseManager.lifecycle_enabled = false
	PauseManager.clear_all()
	game.modals.close_all()
	sim.tutorial.skip()
	AudioManager.unlock()
	AudioManager.apply_volumes()
	EventBus.coin_popup.connect(_on_coin)
	# Tier 1, pagi: alat dibuka dan dinaikkan sedikit di bawah batas supaya
	# masih ada yang bisa di-upgrade di ponsel (evolusi oven di Lv 25).
	_equip(20)
	_oven_iid = sim.equipment.placed_list(&"oven")[0].iid
	sim.upgrades.set_station_level(_oven_iid, 21)
	sim.debug_set_time(7.0 * 3600.0)
	_promo()
	_warm(150.0)
	_set_balance(1840.0)
	_hush()
	sim.debug_set_time(7.2 * 3600.0)
	game.world.apply_daylight()
	await _frames(3)


## Semua slot alat dibuka dan dinaikkan, staf penuh, resep yang bisa dibuat
## dibuka (seperti TestSuite.equip_shop).
func _equip(level: int) -> void:
	sim.debug_add_kr(1.0e12)
	for cat: StringName in [&"display", &"oven", &"mixer"]:
		while sim.upgrades.open_station(cat) >= 0:
			pass
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			sim.upgrades.set_station_level(e.iid, mini(level, sim.upgrades.level_cap()) if level > 0 else sim.upgrades.level_cap())
	for role: StringName in [&"cashier", &"baker"]:
		for st: StaffDefinition in DataRegistry.staff_list():
			if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
				break
			if st.role_id == role and not sim.staff.is_employed(st.id):
				sim.staff.hire(st.id, true)
	for r: RecipeDefinition in DataRegistry.recipes():
		if sim.upgrades.unlock_block(r.id) == &"":
			sim.upgrades.unlock_recipe(r.id)


## Pindah ke tier `tier` lewat alur upgrade sungguhan, lalu toko dilengkapi.
func _jump(tier: int, level: int = -1) -> void:
	while sim.world.location.tier < tier:
		sim.debug_add_kr(SimulationRoot.location_cost(sim.world.location.tier + 1))
		if sim.upgrade_location() != "":
			break
	_equip(level)
	_promo()
	_hush()


## Bunyi naik level, evolusi, dan pencapaian yang dipicu persiapan toko di balik
## layar dihentikan sebelum sempat terdengar (bisa puluhan sekaligus).
func _hush() -> void:
	AudioManager.stop_all_sounds()


## Saldo yang wajar untuk tahap ini (uang debug untuk melengkapi toko tidak
## ikut tampil di HUD).
func _set_balance(kr: float) -> void:
	sim.economy.balance = kr


func _promo() -> void:
	for pid: StringName in [&"promo_food_vlogger", &"promo_radio", &"promo_flyer"]:
		if sim.boosts.start_promo(pid):
			return


## Majukan simulasi tanpa menggambar (rak terisi, pembeli berdatangan).
func _warm(sim_seconds: float) -> void:
	var n: int = int(sim_seconds / sim.tick_seconds)
	for i in n:
		sim.step(sim.tick_seconds)
	# Bunyi penjualan selama majuan ini jatuh di satu bingkai: dibuang.
	_hush()


## Toko tier 5 dihias: kulit etalase, lalu setiap dekorasi dinding, meja, dan
## lantai di tempat yang boleh.
func _decorate() -> void:
	var dm: DecorationManager = sim.decoration
	var sf: StringName = dm.store_floor()
	for skin: StringName in [&"skin_storefront_striped_awning", &"skin_storefront_sign_carved_wood", &"skin_oven_decal_golden"]:
		if DataRegistry.decoration(skin) != null:
			dm.grant(skin)
			dm.equip(skin)
	var fg: FloorGrid = sim.world.grid(sf)
	var used: Array[Vector2i] = []
	for x: Variant in DataRegistry.decorations():
		var def: MiscDefinitions.DecorationDefinition = x
		if not def.placement_type in [&"wall", &"counter_prop", &"floor_prop", &"floor_overlay"]:
			continue
		var o: Dictionary = dm._add(def.id)
		var uid: int = int(o["uid"])
		if def.placement_type == &"wall" or def.placement_type == &"counter_prop":
			var free: Array[int] = dm.free_slots(def.placement_type, uid)
			if not free.is_empty():
				dm.place(uid, sf, Vector2i(-1, -1), free[0])
			continue
		# Lantai: sel yang boleh dan sejauh mungkin dari dekorasi lain.
		var best := Vector2i(-1, -1)
		var best_d: float = -1.0
		for z in fg.size.y:
			for xx in fg.size.x:
				var c := Vector2i(xx, z)
				if dm.check_place(uid, sf, c, -1, 0) != &"":
					continue
				var d: float = 99.0
				for u: Vector2i in used:
					d = minf(d, Vector2(c - u).length())
				if d > best_d:
					best_d = d
					best = c
		if best.x >= 0:
			dm.place(uid, sf, best, -1)
			used.append(best)
	game.world.rebuild_all()
	_hush()


func _clear_toasts() -> void:
	var t: Node = game.hud.find_child("Toasts", true, false)
	if t != null:
		for c: Node in t.get_children():
			c.queue_free()


func _on_coin(amount: float, cell: Vector2i, floor_id: StringName) -> void:
	if _veil.color.a > 0.3 or game.world == null or floor_id != game.world.camera_rig.active_floor:
		return
	var p3: Vector3 = GridMath.cell_center3(cell, 1.0)
	if _cam.is_position_behind(p3):
		return
	var p: Vector2 = _cam.unproject_position(p3)
	if Rect2(Vector2.ZERO, OUT).has_point(p):
		FX.coin_pop(_fx, p / 1.5, amount)


# ===========================================================================
# MUSIK TRAILER
# ===========================================================================

func _build_music() -> void:
	var m := TrailerMusic.new()
	m.setup_trailer(BPM, 24)
	var wav: AudioStreamWAV = m.finish_now()
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_music = AudioStreamPlayer.new()
	_music.stream = wav
	_music.bus = "Master"
	_music.volume_db = -6.0
	add_child(_music)


## Lagu trailer 24 bar: intro Rhodes (bar 1-2), hentakan judul dan alur bossa
## (bar 3), lapisan arpeggio dan shaker penuh (bar 7), isian menjelang akhir
## (bar 22), lalu akor penutup yang dibiarkan bergema (bar 23-24).
class TrailerMusic extends MusicBuild:

	func setup_trailer(bpm: float, bars: int) -> void:
		key = "trailer"
		_rng = RandomNumberGenerator.new()
		_rng.seed = 96024
		var beat: float = 60.0 / bpm
		_alloc(float(bars) * 4.0 * beat + 0.1)
		var root_hz: float = AudioGenerator.MUSIC_ROOT_HZ * pow(2.0, 2.0 / 12.0)
		var prog: Array = AudioGenerator.PROGRESSION
		for bar in bars:
			var t0: float = float(bar) * 4.0 * beat
			var is_final: bool = bar >= bars - 2
			var chord: Dictionary = prog[2] if is_final else prog[bar % prog.size()]
			var ivals: Array = chord["ivals"]
			var cr: float = root_hz * pow(2.0, float(chord["deg"]) / 12.0)
			if is_final:
				if bar == bars - 2:
					_add_note(KIND_BASS, cr * 0.5, beat * 7.5, 0.95, t0)
					for vi in range(1, ivals.size()):
						_add_note(KIND_RHODES, cr * 2.0 * pow(2.0, float(ivals[vi]) / 12.0), beat * 7.5, 0.45, t0 + 0.02 * float(vi))
					# Petikan gitar menyapu naik.
					for si in 6:
						var iv: int = int(ivals[si % ivals.size()]) + 12 * floori(float(si) / float(ivals.size()))
						_add_note(KIND_NYLON, cr * 2.0 * pow(2.0, float(iv) / 12.0), beat * 3.0, 0.45, t0 + 0.06 * float(si))
				continue
			var intro: bool = bar < 2
			var full: bool = bar >= 6
			# Rhodes: akor di ketuk 1 dan sinkopasi "dan" dari ketuk 2.
			var rh: float = 0.30 if intro else 0.40
			for vi2 in range(1, ivals.size()):
				var f: float = cr * 2.0 * pow(2.0, float(ivals[vi2]) / 12.0)
				_add_note(KIND_RHODES, f, beat * (4.0 if intro else 1.6), rh, t0 + 0.012 * float(vi2))
				if not intro:
					_add_note(KIND_RHODES, f, beat * 2.2, rh * 0.75, t0 + beat * 1.5 + 0.012 * float(vi2))
			if intro:
				_add_note(KIND_NYLON, cr * 2.0 * pow(2.0, float(ivals[2]) / 12.0), beat * 1.5, 0.30, t0 + beat * 2.0)
				_add_note(KIND_NYLON, cr * 4.0 * pow(2.0, float(ivals[1]) / 12.0), beat * 1.5, 0.22, t0 + beat * 3.0)
				continue
			# Bass bossa: akar di 1, kelima di 3 dengan antisipasi.
			_add_note(KIND_BASS, cr * 0.5, beat * 1.4, 0.90, t0)
			_add_note(KIND_BASS, cr * 0.5 * pow(2.0, 7.0 / 12.0), beat * 0.9, 0.70, t0 + beat * 1.5)
			_add_note(KIND_BASS, cr * 0.5, beat * 1.4, 0.85, t0 + beat * 2.0)
			_add_note(KIND_BASS, cr * 0.5 * pow(2.0, 7.0 / 12.0), beat * 0.9, 0.70, t0 + beat * 3.5)
			# Gitar nilon: pola petikan bossa.
			var pluck: Array = [0.0, 0.75, 1.5, 2.0, 2.75, 3.5]
			for pi in pluck.size():
				var ival: int = int(ivals[1 + (pi % 3)])
				var gf: float = cr * 2.0 * pow(2.0, float(ival) / 12.0)
				if pi % 2 == 1:
					gf *= 2.0
				_add_note(KIND_NYLON, gf, beat * 1.0, 0.42, t0 + float(pluck[pi]) * beat)
			# Shaker delapan-an, aksen di ketuk.
			for h in 8:
				_add_note(KIND_SHAKER, 0.0, 0.05, 0.26 if h % 2 == 0 else 0.16, t0 + float(h) * beat * 0.5)
			if full:
				# Arpeggio tinggi: nada akor naik-turun per seperdelapan.
				var order: Array = [0, 1, 2, 3, 2, 1, 2, 3]
				for a in 8:
					var iv2: int = int(ivals[order[a]])
					_add_note(KIND_NYLON, cr * 4.0 * pow(2.0, float(iv2) / 12.0), beat * 0.6, 0.22, t0 + float(a) * beat * 0.5 + beat * 0.25)
			if bar == bars - 3:
				# Isian: shaker enam-belasan di dua ketuk terakhir.
				for h2 in 8:
					_add_note(KIND_SHAKER, 0.0, 0.04, 0.20, t0 + beat * 2.0 + float(h2) * beat * 0.25)
		_tone = 5200.0
		_peak_target = 0.80
		_finish_setup()


# ===========================================================================
# ADEGAN
# ===========================================================================

func _build_shots() -> void:
	var b: float = BAR
	_shots = [
		{"at": 0.0, "enter": _s_open},
		{"at": b * 2.0, "enter": _s_title},
		{"at": b * 4.0, "enter": _s_bake},
		{"at": b * 6.0, "enter": _s_serve},
		{"at": b * 8.0, "enter": _s_upgrade},
		{"at": b * 10.0, "enter": _s_grow},
		{"at": b * 12.0, "enter": _s_crew},
		{"at": b * 14.0, "enter": _s_decor},
		{"at": b * 16.0, "enter": _s_night},
		{"at": b * 18.0, "enter": _s_offline},
		{"at": b * 20.0, "enter": _s_franchise},
		{"at": b * 22.0, "enter": _s_end},
	]
	for i in _shots.size():
		_shots[i]["len"] = (float(_shots[i + 1]["at"]) if i + 1 < _shots.size() else LENGTH) - float(_shots[i]["at"])


func _start() -> void:
	print("TRAILER_START ", Engine.get_frames_drawn())
	_t = 0.0
	_music.play()


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t >= LENGTH:
		_finish()
		return
	var idx: int = 0
	for i in _shots.size():
		if _t >= float(_shots[i]["at"]):
			idx = i
	if idx != _shot:
		_shot = idx
		_clear_shot()
		(_shots[idx]["enter"] as Callable).call()
		if _stills:
			_snap_later(idx)
	_update_camera()
	_update_taps()
	if _shot == 8:
		_tick_night()


func _finish() -> void:
	_t = -1.0
	print("TRAILER_END ", Engine.get_frames_drawn())
	set_process(false)
	game.modals.close_all()
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	get_tree().quit(0)


func _local() -> float:
	return _t - float(_shots[_shot]["at"])


func _snap_later(idx: int) -> void:
	var at: float = float(_shots[idx]["len"]) * (0.5 if idx == 9 else 0.6)
	await get_tree().create_timer(at).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_out_dir.path_join("trailer_%02d.png" % idx))
	print("TRAILER still ", idx)


func _clear_shot() -> void:
	for n: Node in _shot_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_shot_nodes.clear()
	_taps.clear()


# --- kamera sinematik ----------------------------------------------------------

func _pose(focus: Vector3, yaw: float, pitch: float, dist: float, fov: float = 32.0) -> Dictionary:
	return {"focus": focus, "yaw": yaw, "pitch": pitch, "dist": dist, "fov": fov}


func _move(from: Dictionary, to: Dictionary) -> void:
	_pose_from = from
	_pose_to = to


func _update_camera() -> void:
	if _pose_from.is_empty():
		return
	var k: float = clampf(_local() / float(_shots[_shot]["len"]), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var focus: Vector3 = (_pose_from["focus"] as Vector3).lerp(_pose_to["focus"], k)
	var yaw: float = deg_to_rad(lerpf(_pose_from["yaw"], _pose_to["yaw"], k))
	var pitch: float = deg_to_rad(lerpf(_pose_from["pitch"], _pose_to["pitch"], k))
	var dist: float = lerpf(_pose_from["dist"], _pose_to["dist"], k)
	var off := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * dist
	_cam.global_position = focus + off
	_cam.look_at(focus, Vector3.UP)
	_cam.fov = lerpf(_pose_from["fov"], _pose_to["fov"], k)


func _floor_center() -> Vector3:
	var sz: Vector2 = Vector2(sim.world.grid(sim.world.location.store_floor()).size) * GridMath.WORLD_METERS_PER_TILE
	return Vector3(sz.x * 0.5, 0.0, sz.y * 0.5)


func _floor_span() -> float:
	var sz: Vector2 = Vector2(sim.world.grid(sim.world.location.store_floor()).size) * GridMath.WORLD_METERS_PER_TILE
	return sz.length()


## Titik tengah puncak alat kategori `cat` di lantai toko.
func _centroid(cat: StringName) -> Vector3:
	var sum := Vector3.ZERO
	var n: int = 0
	for e: EquipmentInstance in sim.equipment.placed_list(cat):
		var p: Vector3 = game.world.top_of_iid(e.iid)
		if p != Vector3.INF and e.floor_id == game.world.camera_rig.active_floor:
			sum += p
			n += 1
	return sum / float(n) if n > 0 else _floor_center()


func _lanes_center() -> Vector3:
	var sum := Vector3.ZERO
	var n: int = 0
	for lane: QueueLane in sim.queue.lanes:
		if lane.kind == QueueLane.KIND_PHYSICAL:
			sum += GridMath.cell_center3(lane.service_point, 0.6)
			n += 1
	return sum / float(n) if n > 0 else _floor_center()


# --- teks ------------------------------------------------------------------------

## Kartu judul adegan di kiri bawah: lencana ikon madu, judul besar, keterangan.
func _caption(title: String, sub: String, icon: String) -> void:
	var card := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.96), 40, false)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	card.add_child(h)
	var badge: PanelContainer = ProceduralUIFactory.badge(icon, Palette.HONEY, Palette.FLOUR_WHITE, 96)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(ProceduralUIFactory.title(title, 62))
	(v.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if sub != "":
		v.add_child(ProceduralUIFactory.label(sub, 30, Palette.UI_WOOD))
	_layer.add_child(card)
	_shot_nodes.append(card)
	card.reset_size()
	var end: Vector2 = Vector2(72.0, OUT.y - 72.0 - card.size.y)
	card.position = end + Vector2(-90.0, 0.0)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(card, "position", end, 0.45).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.15)
	var out := card.create_tween()
	out.tween_interval(maxf(0.5, float(_shots[_shot]["len"]) - 0.45))
	out.tween_property(card, "modulate:a", 0.0, 0.3)


## Teks besar di kiri untuk adegan ponsel: pita kecil, judul, keterangan.
func _side_text(kicker: String, title: String, sub: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.size = Vector2(980.0, 0.0)
	var pill := PanelContainer.new()
	var psb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.HONEY, 26, false)
	psb.content_margin_left = 26.0
	psb.content_margin_right = 26.0
	psb.content_margin_top = 6.0
	psb.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", psb)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var kl: Label = ProceduralUIFactory.label(kicker, 30, Palette.FLOUR_WHITE)
	kl.add_theme_font_override("font", ProceduralUIFactory.section_font())
	kl.uppercase = true
	pill.add_child(kl)
	v.add_child(pill)
	var tl: Label = ProceduralUIFactory.title(title, 92)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(980.0, 0.0)
	v.add_child(tl)
	var sl: Label = ProceduralUIFactory.label(sub, 38, Palette.UI_WOOD)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(900.0, 0.0)
	v.add_child(sl)
	_layer.add_child(v)
	_shot_nodes.append(v)
	v.reset_size()
	var end := Vector2(110.0, (OUT.y - v.size.y) * 0.5)
	v.position = end + Vector2(0.0, 40.0)
	v.modulate.a = 0.0
	var tw := v.create_tween().set_parallel(true)
	tw.tween_property(v, "position", end, 0.5).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "modulate:a", 1.0, 0.35).set_delay(0.2)
	var out := v.create_tween()
	out.tween_interval(maxf(0.5, float(_shots[_shot]["len"]) - 0.4))
	out.tween_property(v, "modulate:a", 0.0, 0.3)


## Logo besar di tengah (judul dan kartu akhir).
func _logo(y_center: float, scale_to: float = 1.0) -> Control:
	var lock: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"), 132, 176, 1600.0)
	_layer.add_child(lock)
	_shot_nodes.append(lock)
	lock.reset_size()
	lock.position = Vector2((OUT.x - lock.size.x) * 0.5, y_center - lock.size.y * 0.5)
	lock.pivot_offset = lock.size * 0.5
	lock.scale = Vector2(0.55, 0.55) * scale_to
	lock.modulate.a = 0.0
	var tw := lock.create_tween().set_parallel(true)
	tw.tween_property(lock, "scale", Vector2.ONE * scale_to, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lock, "modulate:a", 1.0, 0.2)
	ProceduralAnimationSystem.idle_wobble(lock.get_meta("bread"))
	return lock


func _center_label(text: String, size_px: int, y: float, color: Color, delay: float) -> Label:
	var l: Label = ProceduralUIFactory.label(text, size_px, color)
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(OUT.x, 0.0)
	_layer.add_child(l)
	_shot_nodes.append(l)
	l.reset_size()
	l.size.x = OUT.x
	l.position = Vector2(0.0, y)
	l.modulate.a = 0.0
	l.create_tween().tween_property(l, "modulate:a", 1.0, 0.4).set_delay(delay)
	return l


# --- transisi --------------------------------------------------------------------

func _flash_in(from_alpha: float = 0.85, seconds: float = 0.35) -> void:
	_flash.color.a = from_alpha
	_flash.create_tween().tween_property(_flash, "color:a", 0.0, seconds)


func _veil_to(a: float, seconds: float = 0.4) -> void:
	_veil.create_tween().tween_property(_veil, "color:a", a, seconds)


func _phone_in() -> void:
	var to: float = OUT.x - _phone.size.x - 190.0
	if _phone.position.x < OUT.x:
		return
	_phone.create_tween().tween_property(_phone, "position:x", to, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _phone_out() -> void:
	_phone.create_tween().tween_property(_phone, "position:x", OUT.x + 40.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


# --- ketukan jari di ponsel ----------------------------------------------------------

## Ketuk `button` di layar ponsel pada detik lokal `at`: lingkaran jari muncul,
## tombolnya memantul, dan aksinya dijalankan.
func _tap_at(at: float, target: Callable, action: Callable) -> void:
	_taps.append({"at": at, "target": target, "action": action, "done": false})


func _update_taps() -> void:
	var lt: float = _local()
	for tp: Dictionary in _taps:
		if bool(tp["done"]) or lt < float(tp["at"]):
			continue
		tp["done"] = true
		var b: Control = (tp["target"] as Callable).call()
		if b == null or not is_instance_valid(b):
			continue
		var r: Rect2 = b.get_global_rect()
		_ripple(_phone_point(r.get_center()))
		ProceduralAnimationSystem.press_bounce(b)
		AudioManager.play(&"ui_tap_soft")
		(tp["action"] as Callable).call(b)


func _ripple(p: Vector2) -> void:
	var r := TapRipple.new()
	r.position = p
	_layer.add_child(r)


class TapRipple extends Control:

	var _k: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			_k = v
			queue_redraw(), 0.0, 1.0, 0.45)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var a: float = 1.0 - _k
		draw_circle(Vector2.ZERO, 34.0 * (0.6 + 0.4 * _k), Color(1.0, 1.0, 1.0, 0.55 * a), true, -1.0, true)
		draw_arc(Vector2.ZERO, 34.0 + 30.0 * _k, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.9 * a), 5.0, true)


# ===========================================================================
# ADEGAN SATU PER SATU (2 bar = 5 detik)
# ===========================================================================

## 1. Pembuka: toko garasi mungil di pagi hari, kamera turun mendekat.
func _s_open() -> void:
	_flash.color = Color(Palette.PANEL, 1.0)
	_flash.create_tween().tween_property(_flash, "color:a", 0.0, 1.2)
	var c: Vector3 = _floor_center()
	_move(_pose(c, 18.0, 40.0, 30.0), _pose(c + Vector3(0.0, 0.3, 0.0), 36.0, 27.0, 17.0))
	var l: Label = _center_label("Every great bakery starts small...", 58, OUT.y - 190.0, Palette.UI_WOOD_DEEP, 1.0)
	var pill := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.92), 36, false)
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	pill.add_theme_stylebox_override("panel", sb)
	l.get_parent().remove_child(l)
	pill.add_child(l)
	l.modulate.a = 1.0
	_layer.add_child(pill)
	pill.reset_size()
	pill.position = Vector2((OUT.x - pill.size.x) * 0.5, OUT.y - 200.0)
	pill.modulate.a = 0.0
	var tw := pill.create_tween()
	tw.tween_property(pill, "modulate:a", 1.0, 0.5).set_delay(1.0)
	tw.tween_interval(2.6)
	tw.tween_property(pill, "modulate:a", 0.0, 0.4)
	_shot_nodes.append(pill)


## 2. Judul: logo memantul di ketuk pertama bar 3, tagline menyusul.
func _s_title() -> void:
	_flash_in(0.9, 0.4)
	_veil_to(0.62, 0.3)
	var c: Vector3 = _floor_center()
	_move(_pose(c + Vector3(0.0, 0.3, 0.0), 36.0, 27.0, 17.0), _pose(c + Vector3(0.0, 0.3, 0.0), 50.0, 26.0, 15.5))
	_logo(OUT.y * 0.42)
	_center_label("From a single crumb to a whole town", 52, OUT.y * 0.42 + 268.0, Palette.UI_WOOD, 0.8)


## 3. Memanggang: oven dan mixer bekerja sendiri; dua kali Semangat.
func _s_bake() -> void:
	_flash_in()
	_veil_to(0.0, 0.25)
	var ov: Vector3 = _centroid(&"oven")
	var mx: Vector3 = _centroid(&"mixer")
	var f: Vector3 = ov.lerp(mx, 0.35)
	_move(_pose(f, 26.0, 30.0, 7.5, 30.0), _pose(f, 52.0, 24.0, 6.2, 30.0))
	_caption("Bake fresh bread", "Mixers and ovens work all by themselves", "bread")
	for k in 2:
		var at: float = BEAT * (3.0 + 3.0 * float(k))
		get_tree().create_timer(at).timeout.connect(func() -> void:
			if sim != null and _oven_iid >= 0:
				sim.player.tap_station(sim.equipment.placed_list(&"oven")[k % sim.equipment.placed_list(&"oven").size()].iid))


## 4. Melayani: antrean di kasir, koin melompat.
func _s_serve() -> void:
	_flash_in()
	var l: Vector3 = _lanes_center()
	_move(_pose(l, 62.0, 30.0, 8.0, 30.0), _pose(l, 38.0, 26.0, 6.6, 30.0))
	_caption("Serve hungry customers", "Every sale rings in Koin Roti", "coin")


## 5. Upgrade: ponsel, kartu upgrade oven, empat ketukan x1 sampai oven
## berevolusi di Lv 25.
func _s_upgrade() -> void:
	_flash_in(0.6, 0.3)
	_veil_to(0.72, 0.35)
	var c: Vector3 = _floor_center()
	_move(_pose(c, 30.0, 34.0, 22.0), _pose(c, 44.0, 32.0, 20.0))
	_clear_toasts()
	game.modals.close_all()
	_set_balance(maxf(sim.economy.balance, 1840.0))
	game.modals.open(&"upgrade_card", {"kind": &"station", "id": _oven_iid})
	_phone_in()
	_side_text("Upgrade", "Upgrade everything", "Level up ovens, recipes and staff, and watch them evolve!")
	for i in 4:
		_tap_at(0.9 + BEAT * 1.5 * float(i), _x1_button, func(b: Control) -> void: (b as Button).pressed.emit())


func _x1_button() -> Control:
	var card: UpgradeCard = game.modals.screen(&"upgrade_card") as UpgradeCard
	return card.buttons().button(&"x1") if card != null and card.buttons() != null else null


## 6. Tumbuh: garasi -> ruko -> toko roti -> flagship, potongan cepat.
func _s_grow() -> void:
	_phone_out()
	game.modals.close_all()
	_veil_to(0.0, 0.2)
	var steps: Array = [[2, "...to a cozy shophouse"], [3, "...to a corner bakery"], [4, "...to a busy flagship store!"]]
	_cut_tier(steps[0])
	_caption("From a tiny garage...", "", "shop")
	for i in range(1, steps.size()):
		var st: Array = steps[i]
		get_tree().create_timer(BAR * 2.0 / 3.0 * float(i)).timeout.connect(func() -> void: _cut_tier(st))


func _cut_tier(st: Array) -> void:
	_flash_in(0.9, 0.3)
	_jump(int(st[0]), -1)
	sim.debug_set_time(11.0 * 3600.0)
	_warm(90.0)
	_set_balance([0.0, 0.0, 86400.0, 1.38e6, 2.21e7, 3.6e8][int(st[0])])
	game.world.apply_daylight()
	var c: Vector3 = _floor_center()
	var span: float = _floor_span()
	_move(_pose(c, 30.0, 33.0, span * 2.2), _pose(c, 44.0, 30.0, span * 1.9))
	var lbl: Label = _center_label(String(st[1]), 56, 70.0, Palette.UI_WOOD_DEEP, 0.1)
	var pill := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.94), 36, false)
	sb.content_margin_left = 36.0
	sb.content_margin_right = 36.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	pill.add_theme_stylebox_override("panel", sb)
	lbl.get_parent().remove_child(lbl)
	pill.add_child(lbl)
	lbl.modulate.a = 1.0
	_layer.add_child(pill)
	pill.reset_size()
	pill.position = Vector2((OUT.x - pill.size.x) * 0.5, 64.0)
	_shot_nodes.append(pill)
	get_tree().create_timer(BAR * 2.0 / 3.0 - 0.05).timeout.connect(func() -> void:
		if is_instance_valid(pill):
			pill.queue_free())


## 7. Kru: kasir dan koki bekerja di flagship store.
func _s_crew() -> void:
	_flash_in()
	sim.debug_set_time(12.0 * 3600.0)
	game.world.apply_daylight()
	var l: Vector3 = _lanes_center()
	var k: Vector3 = _centroid(&"oven")
	var f: Vector3 = l.lerp(k, 0.4)
	_move(_pose(f, 28.0, 32.0, 13.0, 32.0), _pose(f, 54.0, 28.0, 11.0, 32.0))
	_caption("Hire a cheerful crew", "Cashiers and bakers keep the shop humming", "people")


## 8. Dekorasi: landmark tier 5 yang dihias penuh.
func _s_decor() -> void:
	_flash_in(1.0, 0.45)
	_jump(5, -1)
	_decorate()
	sim.debug_set_time(14.5 * 3600.0)
	_warm(90.0)
	_set_balance(4.12e8)
	game.world.apply_daylight()
	var c: Vector3 = _floor_center()
	var span: float = _floor_span()
	_move(_pose(c, 22.0, 42.0, span * 1.25), _pose(c, 56.0, 34.0, span * 1.05))
	_caption("Decorate it your way", "Plants, clocks, rugs and a grand storefront", "frame")


## 9. Siang ke malam: jam berputar cepat, lampu-lampu menyala.
func _s_night() -> void:
	_flash_in(0.5, 0.3)
	_night_from = 16.8 * 3600.0
	var c: Vector3 = _floor_center()
	var span: float = _floor_span()
	_move(_pose(c, 40.0, 30.0, span * 2.0), _pose(c, 48.0, 27.0, span * 1.7))
	_caption("Open day and night", "Your bakery never stops baking", "moon")


func _tick_night() -> void:
	var k: float = clampf(_local() / float(_shots[_shot]["len"]), 0.0, 1.0)
	sim.debug_set_time(_night_from + k * 4.6 * 3600.0)
	game.world.apply_daylight()


## 10. Offline: ponsel menyapa dengan Welcome Back, Collect, hujan koin.
func _s_offline() -> void:
	_veil_to(0.72, 0.35)
	var c: Vector3 = _floor_center()
	_move(_pose(c, 44.0, 30.0, _floor_span() * 1.6), _pose(c, 52.0, 28.0, _floor_span() * 1.5))
	_clear_toasts()
	game.modals.close_all()
	sim.offline.pending = {"amount": 1.86e8, "seconds": 7200.0, "away": 3.0 * 3600.0 + 25.0 * 60.0}
	game.modals.open(&"welcome_back")
	_phone_in()
	_side_text("While you're away", "Earn while you rest", "Your bakery keeps selling. Come back to a pile of Koin Roti!")
	_tap_at(BAR * 1.0 + BEAT * 2.0, func() -> Control:
		var s: UIScreen = game.modals.screen(&"welcome_back")
		return s.find_child("Collect", true, false) as Control if s != null else null,
		func(b: Control) -> void: (b as Button).pressed.emit())


## 11. Waralaba: Pak Lurah membawa kabar dan bintang, lalu papan cabang baru.
func _s_franchise() -> void:
	_clear_toasts()
	game.modals.close_all()
	game.modals.open(&"franchise_cutscene", {"stars": 12, "number": 2})
	_side_text("Franchise", "Grow a bakery empire", "Sell your shop for Franchise Stars and every new branch earns more.")
	get_tree().create_timer(BAR * 1.0 + BEAT * 1.0).timeout.connect(func() -> void:
		var s: FranchiseCutscene = game.modals.screen(&"franchise_cutscene") as FranchiseCutscene
		if s != null:
			s._advance())


## 12. Penutup: logo, ajakan, dan platform di atas toko senja.
func _s_end() -> void:
	_phone_out()
	_flash_in(1.0, 0.5)
	game.modals.close_all()
	sim.debug_set_time(17.6 * 3600.0)
	game.world.apply_daylight()
	_veil_to(0.55, 0.4)
	var c: Vector3 = _floor_center()
	var span: float = _floor_span()
	_move(_pose(c, 36.0, 30.0, span * 2.1), _pose(c, 46.0, 28.0, span * 1.8))
	_logo(OUT.y * 0.36, 0.92)
	_center_label(CTA_TITLE, 60, OUT.y * 0.36 + 215.0, Palette.UI_WOOD_DEEP, 0.6)
	var cta: Button = ProceduralUIFactory.icon_text_button("play", CTA_BUTTON, "primary", 40, 44)
	cta.custom_minimum_size = Vector2(420.0, 96.0)
	_layer.add_child(cta)
	_shot_nodes.append(cta)
	cta.size = cta.custom_minimum_size
	cta.position = Vector2((OUT.x - cta.size.x) * 0.5, OUT.y * 0.36 + 320.0)
	cta.pivot_offset = cta.size * 0.5
	cta.scale = Vector2.ZERO
	cta.create_tween().tween_property(cta, "scale", Vector2.ONE, 0.45).set_delay(1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_center_label(CTA_PLATFORMS, 40, OUT.y * 0.36 + 440.0, Palette.UI_WOOD, 1.5)
	# Pudar ke krem di detik terakhir.
	var tw := _flash.create_tween()
	tw.tween_interval(float(_shots[_shot]["len"]) - 0.9)
	tw.tween_property(_flash, "color", Color(Palette.PANEL, 1.0), 0.8)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
