class_name StringLint
extends RefCounted
## Kelengkapan kunci string & lint bahasa Inggris (GDD 43, 127, 133.1). Dipakai
## TEST_UI_001 dan tools/release_validator.gd.

## Literal "ui_*"/"tut_*"/"dlg_*"/"npc_*" di skrip yang bukan kunci teks.
const NON_TEXT_LITERALS: Array[String] = ["ui_restore", "ui_scale", "ui_volume"]
## Kata Indonesia umum yang tidak boleh muncul di teks pemain (GDD 43, 127).
const INDONESIAN_WORDS: Array[String] = [
	"yang", "tidak", "dengan", "untuk", "sudah", "belum", "pelanggan", "bahan", "harga", "hari",
	"toko", "uang", "beli", "jual", "silakan", "terima", "kasih", "selamat", "gudang", "kasir",
	"antrean", "adonan", "panggang", "dapur", "rak", "karyawan", "gaji", "pesanan", "dan", "atau",
]


## Hasil: {files, missing: {key: sumber}, empty: [key], bad: {key: alasan}}.
## include_runtime: sertakan kunci hilang yang tercatat DataRegistry saat runtime.
static func run(include_runtime: bool) -> Dictionary:
	var table: Dictionary = DataRegistry.strings_table()
	var missing: Dictionary = {}
	# 1. Kunci literal di skrip.
	var call_re := RegEx.create_from_string("(?:Tx\\.t|DataRegistry\\.text|notify\\.emit\\(\\s*\\d+\\s*,)\\(?\\s*\"([a-z0-9_]+)\"")
	var lit_re := RegEx.create_from_string("\"((?:ui|tut|dlg|npc)_[a-z0-9_]+)\"")
	var audio: Dictionary = {}
	for x: Variant in DataRegistry.audio_events():
		audio[String((x as MiscDefinitions.AudioEventDefinition).id)] = true
	var files: Array[String] = []
	for root: String in ["res://ui", "res://scenes", "res://gameplay", "res://core", "res://autoload", "res://procedural", "res://audio"]:
		collect_gd(root, files)
	for f: String in files:
		var text: String = FileAccess.get_file_as_string(f)
		for m: RegExMatch in call_re.search_all(text):
			var k: String = m.get_string(1)
			if not k.ends_with("_") and not table.has(k):
				missing[k] = f
		for m2: RegExMatch in lit_re.search_all(text):
			var k2: String = m2.get_string(1)
			if not k2.ends_with("_") and not table.has(k2) and not audio.has(k2) and not NON_TEXT_LITERALS.has(k2):
				missing[k2] = f
	# 2. Kunci turunan katalog & konstanta.
	var derived: Array[String] = []
	for r: RecipeDefinition in DataRegistry.recipes():
		derived.append(String(r.localization_key))
		for t: StringName in r.customer_tags:
			derived.append("tag_" + String(t))
	for ing: IngredientDefinition in DataRegistry.ingredients():
		derived.append(String(ing.localization_key))
		derived.append("ingredient_category_" + String(ing.category_id))
		derived.append(String(ing.unit_label_key))
	for e: EquipmentDefinition in DataRegistry.equipment_list():
		derived.append(String(e.localization_key))
		if e.for_sale:
			derived.append("equipment_category_" + String(e.category_id))
	for a: CustomerArchetypeDefinition in DataRegistry.archetypes():
		derived.append(String(a.id))
	for st: StaffDefinition in DataRegistry.staff_list():
		derived.append(String(st.id))
	for loc: LocationDefinition in DataRegistry.locations():
		derived.append(String(loc.localization_key))
	for c: Variant in DataRegistry.campaigns():
		derived.append(String((c as MiscDefinitions.MarketingCampaignDefinition).localization_key))
		derived.append(String((c as MiscDefinitions.MarketingCampaignDefinition).id))
	for d: Variant in DataRegistry.decorations():
		var dd: MiscDefinitions.DecorationDefinition = d
		derived.append(String(dd.localization_key))
		derived.append("decor_type_" + String(dd.placement_type))
	for ach: Variant in DataRegistry.achievements():
		var ad: MiscDefinitions.AchievementDefinition = ach
		derived.append(String(ad.localization_key))
		derived.append(String(ad.id) + "_desc")
		derived.append(String(ad.reward_id))
	for w: Variant in DataRegistry.weather_list():
		derived.append(String((w as MiscDefinitions.WeatherDefinition).localization_key))
	for k3: String in StatisticsManager.STAT_KEYS:
		derived.append("ui_stat_" + k3)
	for sc: Script in [HUD, DecorationScreen, RecipeBookScreen, StatsScreen]:
		for cv: Variant in sc.get_script_constant_map().values():
			if cv is Dictionary:
				for v: Variant in (cv as Dictionary).values():
					# Nilai tanpa "_" adalah nama ikon, bukan kunci teks.
					if v is String and (v as String).contains("_"):
						derived.append(v)
					elif v is Array and not (v as Array).is_empty() and (v as Array)[0] is String:
						derived.append((v as Array)[0])
	for k4: String in derived:
		if k4 != "" and not table.has(k4):
			missing[k4] = "catalog/constant"
	# 3. Kunci yang diminta saat runtime.
	if include_runtime:
		for k5: Variant in DataRegistry.missing_keys.keys():
			missing[str(k5)] = "runtime"
	# 4. Lint bahasa Inggris & placeholder.
	var word_re := RegEx.create_from_string("[A-Za-z]+")
	var brace_re := RegEx.create_from_string("\\{([^}]*)\\}")
	var bad_words: Dictionary = {}
	var empty: Array = []
	for key: Variant in table.keys():
		var val: String = str(table[key])
		if val.strip_edges() == "":
			empty.append(key)
		for m3: RegExMatch in word_re.search_all(val):
			var wlow: String = m3.get_string().to_lower()
			if INDONESIAN_WORDS.has(wlow):
				bad_words[key] = wlow
		for m4: RegExMatch in brace_re.search_all(val):
			if not RegEx.create_from_string("^[a-z_0-9]+$").search(m4.get_string(1)):
				bad_words[key] = "bad placeholder {%s}" % m4.get_string(1)
		if val.count("{") != val.count("}"):
			bad_words[key] = "unbalanced braces"
	return {"files": files.size(), "missing": missing, "empty": empty, "bad": bad_words}


static func collect_gd(path: String, out: Array[String]) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(path.path_join(f))
	for sub: String in d.get_directories():
		collect_gd(path.path_join(sub), out)
