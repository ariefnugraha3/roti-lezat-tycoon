class_name TableclothSides
extends Control
## Taplak di luar bingkai potret (GDD idle 12.0.3): gingham yang sama dengan
## tepi bawah layar pembuka, renda krem di sisi yang bersentuhan dengan
## bingkai, dan ikon samar CozyBackdrop yang melayang pelan. Murni gambar: tidak
## menangkap ketukan dan tidak menampilkan informasi game. Bidang taplak hanya
## digambar ulang saat ukuran jendela berubah; yang beranimasi hanya ikonnya.

## Ikon samar per sisi: [nama, posisi relatif (0..1) dalam area taplak, ukuran].
const FLOATERS: Array = [
	["bread", Vector2(0.50, 0.14), 54.0], ["star", Vector2(0.38, 0.40), 34.0], ["coin", Vector2(0.62, 0.66), 44.0],
	["heart", Vector2(0.45, 0.88), 36.0],
]
const FLOATER_ALPHA: float = 0.18

var frame: Rect2 = Rect2()
var _t: float = 0.0
## [{icon, region, at}] untuk setiap ikon yang tampil.
var _floaters: Array[Dictionary] = []


func _init() -> void:
	name = "TableclothSides"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Kotak bingkai potret dalam koordinat kontrol ini.
func set_frame(r: Rect2) -> void:
	frame = r
	_build_floaters()
	queue_redraw()


## Area taplak yang tampil: kiri, kanan, atas, dan bawah bingkai (yang lebarnya
## nol tidak ikut). Masing-masing {rect, lace} dengan `lace` sisi renda.
func regions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var full: Rect2 = Rect2(Vector2.ZERO, size)
	var parts: Array = [
		[Rect2(0.0, 0.0, frame.position.x, full.size.y), SIDE_RIGHT],
		[Rect2(frame.end.x, 0.0, full.size.x - frame.end.x, full.size.y), SIDE_LEFT],
		[Rect2(frame.position.x, 0.0, frame.size.x, frame.position.y), SIDE_BOTTOM],
		[Rect2(frame.position.x, frame.end.y, frame.size.x, full.size.y - frame.end.y), SIDE_TOP],
	]
	for p: Array in parts:
		var r: Rect2 = p[0]
		if r.size.x >= 0.5 and r.size.y >= 0.5:
			out.append({"rect": r, "lace": int(p[1])})
	return out


func _draw() -> void:
	for reg: Dictionary in regions():
		ProceduralUIFactory.draw_gingham(self, reg["rect"], int(reg["lace"]))


func _build_floaters() -> void:
	for f: Dictionary in _floaters:
		(f["icon"] as Node).queue_free()
	_floaters.clear()
	for reg: Dictionary in regions():
		var r: Rect2 = reg["rect"]
		# Hanya area yang cukup lebar untuk ikon; pita tipis tetap polos.
		if minf(r.size.x, r.size.y) < 64.0:
			continue
		for fl: Array in FLOATERS:
			var ic: IconCanvas = ProceduralUIFactory.icon(str(fl[0]), int(fl[2]), Palette.GOLDEN_CRUST if str(fl[0]) != "heart" else Palette.PASTEL_STRAWBERRY)
			ic.outlined = false
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.modulate = Color(1.0, 1.0, 1.0, FLOATER_ALPHA)
			add_child(ic)
			var at: Vector2 = r.position + r.size * (fl[1] as Vector2) - ic.custom_minimum_size * 0.5
			ic.position = at
			_floaters.append({"icon": ic, "at": at})


func _process(delta: float) -> void:
	if _floaters.is_empty() or SettingsManager.reduced_motion() or not is_visible_in_tree():
		return
	_t += delta
	for i in _floaters.size():
		var f: Dictionary = _floaters[i]
		(f["icon"] as Control).position = (f["at"] as Vector2) + Vector2(0.0, sin(_t * 0.8 + float(i) * 1.7) * 6.0)


## Ikon samar yang tampil (tes).
func floater_count() -> int:
	return _floaters.size()
