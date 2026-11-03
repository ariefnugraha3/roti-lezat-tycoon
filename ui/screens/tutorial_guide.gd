class_name TutorialGuide
extends UIScreen
## Panduan onboarding yang menunggu ketukan pemain (GDD idle 13; keputusan
## maintainer 2026-11-02): layar diredupkan kecuali yang harus diketuk, dan
## sasaran itu berkedip. Sasarannya maju bersama langkahnya: tab dulu, lalu
## tombol di lembar yang terbuka (Hire, Unlock, Move, Sell & Franchise); chip
## level oven, lalu tombol ×1 di kartunya; atau stasiun di dunia, yang modelnya
## ikut berkedip (`WorldView.highlight`). Ketukan di lubang sorotan sampai ke
## tombol di bawahnya, bagian lain tertutup lapisan redup. Not now dan Back
## menutup prompt; langkah yang dikerjakan pemain menutup sendiri
## (`TutorialManager._auto_close`). Panduan tidak mem-pause toko, dan
## bersembunyi selama lapisan sistem lain (konfirmasi, menu Pause, Welcome Back)
## terbuka di atasnya atau modal pemblokir terbuka di bawahnya: selama itu toko
## di-pause dan scrim modal itu menelan ketukan di lubang sorotan.
##
## Params: {key, target}; target `chip_<iid>`, `tab_<id>`, `station_<iid>`, atau
## `hud_<name>` (tombol HUD: craving, goals, event, pause; GDD idle 21.8).

## Teks balon setelah pemain membuka lembar atau kartu yang benar.
const SECOND_TEXT: Dictionary = {
	"onb_first_upgrade": "onb_first_upgrade_step2",
	"onb_hire": "onb_hire_step2",
	"onb_recipe": "onb_recipe_step2",
	"onb_location": "onb_location_step2",
	"onb_franchise": "onb_franchise_step2",
	"onb_map": "onb_map_step2",
}
## Tip yang selesai sendiri begitu layarnya terbuka (tombol HUD tanpa langkah
## kedua, dan Peta Crumbtown dari lembar Franchise).
const DONE_SCREENS: Dictionary = {
	"hud_craving": &"menu",
	"hud_goals": &"goals",
	"hud_event": &"menu",
	"hud_pause": &"pause",
}
const DONE_KEYS: Dictionary = {
	"onb_map": &"town_map",
}

var key: String = ""
var target: String = ""
var _marks: CoachMarks = null
## Stasiun dunia yang harus diketuk, atau -1.
var _world_iid: int = -1
## Yang harus diketuk sekarang: kotak kanvasnya dan kontrolnya (null untuk
## stasiun dunia).
var _rect: Rect2 = Rect2()
var _control: Control = null


func _init() -> void:
	super._init()
	overlay = true
	blocking = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	key = str(params.get("key", ""))
	target = str(params.get("target", ""))
	if target.begins_with("station_"):
		_world_iid = int(target.substr(8))
		# Modelnya harus terlihat: lembar yang menutupi dunia ditutup.
		if host != null:
			host.close_sheets.call_deferred()
		if game != null and game.world != null and sim != null:
			var e: EquipmentInstance = sim.equipment.get_inst(_world_iid)
			game.world.highlight(e.category() if e != null else &"", _world_iid)
	_marks = CoachMarks.new()
	_marks.finished.connect(_not_now)
	add_child(_marks)
	_resolve()
	_marks.setup([{"targets": _targets, "key": key, "next": false, "skip_key": "ui_tutorial_not_now", "flash": _world_iid < 0}])


## Sorotannya (untuk tes), atau null.
func marks() -> CoachMarks:
	return _marks if _marks != null and is_instance_valid(_marks) else null


## Kontrol yang harus diketuk sekarang (untuk tes), atau null.
func target_control() -> Control:
	return _control if _control != null and is_instance_valid(_control) else null


func on_back() -> bool:
	_not_now()
	return true


func on_closed() -> void:
	if _world_iid >= 0 and game != null and game.world != null:
		game.world.highlight(&"", -1)


func _not_now() -> void:
	if is_queued_for_deletion():
		return
	close()
	if sim != null:
		sim.tutorial.dismiss_key(key)


func _process(_delta: float) -> void:
	var done_screen: StringName = DONE_KEYS.get(key, DONE_SCREENS.get(target, &""))
	if done_screen != &"" and host != null and host.is_open(done_screen):
		_not_now()
		return
	visible = host == null or (host.top() == self and not host.has_blocking())
	_resolve()


func _targets() -> Array:
	return [_rect] if _rect.has_area() else []


## Cari yang harus diketuk sekarang: tombol di lembar yang sudah terbuka, selain
## itu pintu masuknya (tab atau chip), atau stasiun di dunia.
func _resolve() -> void:
	_control = null
	_rect = Rect2()
	var second: bool = false
	var hud: HUD = game.hud if game != null else null
	if target.begins_with("chip_"):
		var iid: int = int(target.substr(5))
		var card: UpgradeCard = host.screen(&"upgrade_card") as UpgradeCard if host != null else null
		if card != null and card.kind == &"station" and int(card.id) == iid and card.buttons() != null:
			_control = card.buttons().button(&"x1")
			second = _control != null and not _control.disabled
		if not second and hud != null:
			_control = hud.level_chips.chip(&"station", iid)
	elif target.begins_with("tab_"):
		var tab: StringName = StringName(target.substr(4))
		var sheet: UIScreen = host.screen(HUD.screen_for_tab(tab)) if host != null else null
		_control = _inner_button(tab, sheet, key)
		second = _control != null
		if not second and hud != null:
			_control = hud.tab_button(tab)
	elif target.begins_with("hud_") and hud != null:
		_control = hud.tutorial_target(target.substr(4))
	elif _world_iid >= 0 and game != null and game.world != null:
		var node: Variant = game.world.furniture.get(_world_iid)
		if node != null:
			_rect = game.world.screen_rect_of([node], TutorialSpotlight.MIN_WORLD_HOLE)
	if _control != null:
		_rect = _visible_rect(_control)
	if _marks != null and _marks.step_count() > 0:
		_marks.set_text(str(SECOND_TEXT.get(key, key)) if second else key)


## Tombol yang harus diketuk di lembar tab yang terbuka, atau null.
static func _inner_button(tab: StringName, sheet: UIScreen, step_key: String = "") -> Button:
	if sheet == null:
		return null
	match tab:
		&"staff":
			return (sheet as StaffScreen).hire_button(&"baker") if sheet is StaffScreen else null
		&"menu":
			return (sheet as MenuScreen).unlock_button() if sheet is MenuScreen else null
		&"shop":
			return (sheet as ShopScreen).move_button() if sheet is ShopScreen else null
		&"franchise":
			if step_key == "onb_map":
				return sheet.find_child("TownMap", true, false) as Button
			return (sheet as FranchiseScreen).sell_button() if sheet is FranchiseScreen else null
	return null


## Kotak kanvas kontrol yang benar-benar terlihat. Tombol di daftar bergulir
## digulir ke dalam pandangan dulu, lalu dipotong tepi daftarnya.
static func _visible_rect(c: Control) -> Rect2:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Rect2()
	var r: Rect2 = c.get_global_rect()
	var n: Node = c.get_parent()
	while n != null:
		if n is ScrollContainer:
			var sc: ScrollContainer = n
			var clip: Rect2 = sc.get_global_rect()
			if not clip.encloses(r):
				sc.ensure_control_visible(c)
			r = r.intersection(clip)
			break
		n = n.get_parent()
	return r
