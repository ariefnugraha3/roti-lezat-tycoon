class_name ShareScreen
extends UIScreen
## Popup "Share my bakery" (GDD idle 21.4): memotret toko tanpa HUD, merakit
## kartu 1080×1350 (nama toko, lokasi, KR/s, roti terjual, bintang atau pembeli,
## hari), menampilkan pratinjaunya, lalu Share (Web: lembar bagi browser atau
## unduhan) atau Save image (folder Pictures/Crumbtown). Dibuka dari menu Pause.

## Kartu yang sudah jadi (null selama dirakit).
var card: Image = null
var _preview: TextureRect = null
var _status: Label = null
var _go: Button = null


func build() -> void:
	var extra: float = 160.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)
	var body: VBoxContainer = make_popup(Tx.t("ui_share_title"), Vector2(640, 1000.0 + extra), true)
	_preview = TextureRect.new()
	_preview.name = "Preview"
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(0.0, 600.0)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_preview)
	_status = lbl(body, Tx.t("ui_share_preparing"), 16, Palette.TEXT_MUTED, true)
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nav := CenterContainer.new()
	body.add_child(nav)
	var web: bool = WebPlatform.is_web()
	_go = ProceduralUIFactory.icon_text_button("share" if web else "frame", Tx.t("ui_share_share" if web else "ui_share_save"), "primary", 24, 20)
	_go.name = "Share"
	_go.custom_minimum_size = Vector2(280, 64)
	_go.disabled = true
	_go.pressed.connect(_export)
	nav.add_child(_go)
	_make.call_deferred()


func _make() -> void:
	if game == null or sim == null:
		return
	var shot: Image = await ShareCard.capture_world(game)
	if not is_inside_tree():
		return
	card = await ShareCard.build(game, ShareCard.crop_photo(shot))
	if not is_inside_tree():
		return
	_preview.texture = ImageTexture.create_from_image(card)
	_status.text = Tx.t("ui_share_ready")
	_go.disabled = false


func _export() -> void:
	if card == null:
		return
	var r: Dictionary = ShareCard.export_png(card, ShareCard.file_base(sim, "bakery"))
	match str(r.get("kind", "")):
		"share":
			_status.text = Tx.t("ui_share_ready")
		"download":
			EventBus.notify.emit(2, "ui_share_downloaded", {}, &"heart")
			_status.text = Tx.t("ui_share_downloaded")
		"saved":
			EventBus.notify.emit(2, "ui_share_saved", {"path": str(r["path"])}, &"heart")
			_status.text = Tx.t("ui_share_saved", {"path": str(r["path"])})
		_:
			_status.text = Tx.t("ui_share_failed")
	EventBus.sfx.emit(&"ui_confirm", &"")
