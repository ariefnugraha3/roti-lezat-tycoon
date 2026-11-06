class_name ErrorScreen
extends UIScreen
## Galat yang dapat dipulihkan (GDD 89.5, 114, 132). Save rusak tidak pernah
## ditimpa otomatis: memulai toko baru memerlukan konfirmasi. Tanpa Main Menu
## (GDD idle 19 no. 21) save yang tidak terbaca menawarkan Try Again (`retry`)
## dan Start a New Bakery; `backdrop` menaruh latar layar pembuka di belakangnya
## karena belum ada dunia yang digambar.


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	if bool(params.get("backdrop", false)):
		add_child(ProceduralUIFactory.backdrop())
	var retry: Variant = params.get("retry")
	var can_retry: bool = retry is Callable and (retry as Callable).is_valid()
	var body: VBoxContainer = make_popup(Tx.t("ui_confirm") if DataRegistry.is_valid() else "Error", Vector2(600, 340), not can_retry)
	lbl(body, str(params.get("text", "")), 20, Palette.TEXT, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	if not DataRegistry.is_valid():
		return
	var row: HBoxContainer = hbox(body, 16)
	row.alignment = BoxContainer.ALIGNMENT_END
	if can_retry:
		var again: Button = btn(row, Tx.t("ui_try_again"), "primary", func() -> void:
			close()
			(retry as Callable).call())
		again.name = "TryAgain"
	else:
		btn(row, Tx.t("ui_back"), "secondary", close)
	if bool(params.get("offer_new", false)):
		var fresh: Button = btn(row, Tx.t("ui_start_new_bakery"), "danger", _ask_new)
		fresh.name = "StartNew"


func _ask_new() -> void:
	host.confirm(Tx.t("ui_start_new_confirm"), _start_new, true)


func _start_new() -> void:
	var g: GameRoot = game
	close()
	g.open_new_game()


## Tanpa Main Menu, Back tidak boleh meninggalkan layar kosong.
func on_back() -> bool:
	if params.get("retry") is Callable:
		return true
	return super.on_back()
