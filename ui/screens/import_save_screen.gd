class_name ImportSaveScreen
extends UIScreen
## Import Save (GDD idle 15.3, 20 no. 57), dari layar Profiles: kode save dari
## perangkat lain ditempel (tombol Paste, atau langsung ke kolomnya) atau, di Web,
## dibaca dari berkas .txt hasil Download File. Kode yang sah menampilkan
## ringkasan tokonya dan satu tombol per profil; profil yang berisi minta
## konfirmasi dulu. Kode yang salah dijelaskan dengan kalimat biasa.

## Lama menunggu jawaban clipboard browser sebelum menyerah (detik nyata).
const PASTE_TIMEOUT: float = 10.0

## Kode yang sedang dipratinjau dan save hasil decode-nya.
var code: String = ""
var data: Dictionary = {}
var _edit: LineEdit = null
var _status: Label = null
var _preview: VBoxContainer = null
## &"paste" atau &"file" selama menunggu browser.
var _waiting: StringName = &""
var _wait_left: float = 0.0


func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_import_save"), Vector2(640, 900), true, Palette.SHEET)
	body.add_theme_constant_override("separation", 14)
	lbl(body, Tx.t("ui_import_body"), 17, Palette.TEXT, true)
	_edit = LineEdit.new()
	_edit.name = "CodeField"
	_edit.placeholder_text = Tx.t("ui_import_placeholder")
	_edit.custom_minimum_size = Vector2(0, 60)
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.add_theme_font_size_override("font_size", ProceduralUIFactory.scaled(18))
	_edit.text_changed.connect(func(t: String) -> void: show_code(t))
	body.add_child(_edit)
	# Paste (dan Open File di Web) berdampingan di bawah kolomnya.
	var row: HBoxContainer = hbox(body, 12)
	var paste: Button = ProceduralUIFactory.icon_text_button("clipboard", Tx.t("ui_import_paste"), "primary", 22, 18)
	paste.name = "Paste"
	paste.custom_minimum_size = Vector2(0, 60)
	paste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paste.pressed.connect(_paste)
	row.add_child(paste)
	if WebPlatform.is_web():
		var open: Button = ProceduralUIFactory.icon_text_button("box", Tx.t("ui_import_open_file"), "secondary", 22, 18)
		open.name = "OpenFile"
		open.custom_minimum_size = Vector2(0, 60)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open.pressed.connect(_open_file)
		row.add_child(open)
	_status = lbl(body, "", 16, Palette.TEXT_MUTED, true)
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview = scroll_box(body)
	_preview.add_theme_constant_override("separation", 12)


func _process(delta: float) -> void:
	if _waiting == &"":
		return
	var got: Variant = WebPlatform.poll_paste() if _waiting == &"paste" else WebPlatform.poll_file()
	if got == null:
		_wait_left -= delta
		if _waiting == &"paste" and _wait_left <= 0.0:
			_waiting = &""
			_say(Tx.t("ui_import_empty"), true)
		return
	_waiting = &""
	var text: String = str(got)
	if text.strip_edges() == "":
		_say(Tx.t("ui_import_empty"), true)
		return
	show_code(text)


func _paste() -> void:
	_say(Tx.t("ui_import_reading"))
	_waiting = &"paste"
	_wait_left = PASTE_TIMEOUT
	WebPlatform.request_paste()


func _open_file() -> void:
	_waiting = &"file"
	WebPlatform.request_file()


## Pratinjau kode: ringkasan toko dan tombol profil tujuan, atau penjelasan
## kenapa kode itu tidak bisa dipakai.
func show_code(text: String) -> void:
	clear(_preview)
	code = text
	data = {}
	if text.strip_edges() == "":
		_say("")
		return
	var r: Dictionary = SaveManager.decode_code(text)
	if not bool(r.get("ok", false)):
		_say(Tx.t("ui_import_err_" + str(r.get("error", "format"))), true)
		return
	data = r["data"]
	_say("")
	var card := PanelContainer.new()
	card.name = "Preview"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 24, true)
	sb.set_content_margin_all(16.0)
	card.add_theme_stylebox_override("panel", sb)
	card.add_child(ProfileScreen.summary_row(SaveManager.header_of(data), 96.0))
	_preview.add_child(card)
	_preview.add_child(ProceduralUIFactory.section_label(Tx.t("ui_import_pick")))
	var headers: Array[Dictionary] = SaveManager.scan_headers()
	for i in headers.size():
		var h: Dictionary = headers[i]
		var pid: StringName = h["profile_id"]
		var exists: bool = bool(h.get("exists", false))
		var what: String = Tx.t("ui_profile_empty")
		if bool(h.get("classic", false)):
			what = Tx.t("ui_classic_save")
		elif bool(h.get("corrupt", false)):
			what = Tx.t("ui_save_error")
		elif exists:
			what = str(h.get("bakery_name", ""))
		var b: Button = ProceduralUIFactory.button("%s · %s" % [Tx.t("ui_profile_slot", {"n": i + 1}), what], "secondary" if exists else "primary")
		b.name = "ImportTo%d" % (i + 1)
		b.custom_minimum_size = Vector2(0, 60)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		b.pressed.connect(_pick.bind(pid, i + 1, exists, what))
		_preview.add_child(b)


func _pick(pid: StringName, n: int, exists: bool, what: String) -> void:
	if exists:
		host.confirm(Tx.t("ui_import_overwrite", {"name": what, "n": n}), _import.bind(pid, n), true)
	else:
		_import(pid, n)


func _import(pid: StringName, n: int) -> void:
	var err: String = SaveManager.import_code(code, pid)
	if err != "":
		_say(Tx.t("ui_import_err_" + err), true)
		EventBus.sfx.emit(&"ui_error", &"")
		return
	EventBus.sfx.emit(&"coin_shower", &"")
	# Main Menu tidak punya HUD untuk toast: daftar profil yang dibangun ulang
	# menampilkan kabarnya.
	var done: Variant = params.get("on_done")
	if done is Callable and (done as Callable).is_valid():
		(done as Callable).call(Tx.t("ui_import_done", {"name": str(data.get("bakery_name", "")), "n": n}))
	close()


func _say(text: String, problem: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Palette.DANGER if problem else Palette.TEXT_MUTED)
