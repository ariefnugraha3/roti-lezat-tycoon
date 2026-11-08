class_name DecorIcons
extends RefCounted
## Ikon lencana barang di katalog Decoration Mode (GDD idle §20 no. 72), seperti
## lencana peran di lembar Staff: [nama ikon IconCanvas, warna lencana]. Tiap
## dekorasi punya ikonnya sendiri; dekorasi baru tanpa entri memakai ikon
## lencananya (`badge_icon`) atau ikon jenisnya. Perabot memakai ikon
## kategorinya (sama dengan lembar Shop dan Upgrades).

const BY_ID: Dictionary = {
	&"decor_potted_plant": ["plant", Palette.MATCHA],
	&"decor_gingham_curtains": ["frame", Palette.STRAWBERRY],
	&"decor_wall_clock_pendulum": ["clock", Palette.CARAMEL],
	&"decor_chalk_menu_board": ["clipboard", Palette.MATCHA_DEEP],
	&"decor_bread_basket_stack": ["bread", Palette.HONEY],
	&"decor_cassette_radio": ["sound", Palette.SIGN_BLUE],
	&"decor_flower_window_box": ["plant", Palette.STRAWBERRY],
	&"decor_family_photo_wall": ["heart", Palette.SIGN_ORANGE],
	&"decor_hanging_lamp_warm": ["lamp", Palette.HONEY],
	&"decor_terracotta_rug": ["rug", Palette.TERRACOTTA],
	&"skin_storefront_striped_awning": ["shop", Palette.STRAWBERRY],
	&"skin_storefront_sign_carved_wood": ["flag", Palette.CARAMEL],
	&"decor_stamp_card": ["calendar", Palette.SIGN_PURPLE],
	&"decor_golden_croissant": ["bread", Palette.HONEY_DEEP],
	&"decor_bunting_garland": ["party", Palette.SIGN_ORANGE],
	&"decor_plaque_hundred_buns": ["trophy", Palette.CARAMEL],
	&"outfit_apron_neighborhood": ["apron", Palette.MATCHA],
	&"skin_oven_decal_golden": ["fire", Palette.HONEY_DEEP],
	&"outfit_chef_hat_perfect": ["chef", Palette.SIGN_BLUE],
	&"decor_floor_mat_smooth": ["rug", Palette.MATCHA],
	&"skin_rotifood_counter_five_star": ["scooter", Palette.OJOL_GREEN],
	&"badge_supporter": ["heart", Palette.STRAWBERRY],
	&"decor_gold_coin_jar": ["coin", Palette.HONEY],
	&"decor_trophy_millionaire": ["trophy", Palette.HONEY],
	&"decor_plaque_tier2": ["trophy", Palette.MATCHA],
	&"decor_plaque_tier3": ["trophy", Palette.SIGN_BLUE],
	&"decor_plaque_tier4": ["trophy", Palette.SIGN_PURPLE],
	&"decor_trophy_landmark": ["trophy", Palette.STRAWBERRY_DEEP],
	&"skin_recipe_book_encyclopedia": ["book", Palette.SIGN_BLUE],
	&"decor_retro_calculator": ["calculator", Palette.CARAMEL],
	&"decor_umbrella_stand": ["rain", Palette.SIGN_BLUE],
	&"decor_photo_pak_lurah": ["camera", Palette.CARAMEL],
	&"decor_brass_bell": ["bell", Palette.HONEY],
	&"decor_plaque_infinity": ["star", Palette.SIGN_PURPLE],
}
const BY_TYPE: Dictionary = {
	&"wall": ["frame", Palette.CARAMEL], &"counter_prop": ["box", Palette.HONEY], &"floor_prop": ["plant", Palette.MATCHA],
	&"floor_overlay": ["rug", Palette.TERRACOTTA], &"skin": ["shop", Palette.STRAWBERRY], &"outfit": ["apron", Palette.SIGN_BLUE],
}
const EQUIPMENT: Dictionary = {
	&"mixer": ["whisk", Palette.HONEY], &"oven": ["fire", Palette.STRAWBERRY], &"display": ["bread", Palette.CARAMEL],
	&"storage": ["box", Palette.SIGN_BLUE], &"table": ["kitchen", Palette.MATCHA], &"chair": ["kitchen", Palette.CARAMEL],
	&"counter": ["bag", Palette.MATCHA],
}
const FALLBACK: Array = ["frame", Palette.CARAMEL]


static func of_decor(def: MiscDefinitions.DecorationDefinition) -> Array:
	if def == null:
		return FALLBACK
	if BY_ID.has(def.id):
		return BY_ID[def.id]
	if def.badge_icon != &"" and IconCanvas.has_icon(String(def.badge_icon)):
		return [String(def.badge_icon), Palette.HONEY]
	return BY_TYPE.get(def.placement_type, FALLBACK)


static func of_equipment(category: StringName) -> Array:
	return EQUIPMENT.get(category, ["kitchen", Palette.CARAMEL])


## Lencana bulat berikon putih, sama dengan lencana baris di lembar Staff.
static func badge(icon: Array, size: int = 44) -> PanelContainer:
	return ProceduralUIFactory.badge(str(icon[0]), icon[1], Palette.FLOUR_WHITE, size)
