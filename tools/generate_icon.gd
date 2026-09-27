extends SceneTree
## Menghasilkan res://icon.svg (ikon aplikasi & tab browser) dari kode, supaya
## tidak ada aset visual eksternal (GDD 4, 111.3). Jalankan:
##   godot --headless --path . --script res://tools/generate_icon.gd
## Warna diambil dari palet game (core/palette.gd) sebagai heks agar skrip ini
## tidak bergantung pada autoload.

const OUT: String = "res://icon.svg"
const SIZE: int = 256

const CREAM: String = "#FFF8EA"
const CRUST_DARK: String = "#A0612B"
const CRUST: String = "#D9914A"
const CRUST_LIGHT: String = "#F1B96B"
const CRUMB: String = "#FBE3B5"
const CHOCOLATE: String = "#5A3825"
const ROSY: String = "#F08A80"


func _init() -> void:
	var f: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		printerr("cannot write ", OUT)
		quit(1)
		return
	f.store_string(build())
	f.close()
	print("wrote ", OUT)
	quit(0)


## Roti tawar chibi: latar krem membulat, kubah kerak dengan tiga guratan,
## irisan remah, wajah kecil (selaras karakter chibi GDD 12.3.3).
static func build() -> String:
	var s: PackedStringArray = PackedStringArray()
	s.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 256 256">' % [SIZE, SIZE])
	s.append('<rect x="8" y="8" width="240" height="240" rx="56" fill="%s"/>' % CREAM)
	# Bayangan lembut.
	s.append('<ellipse cx="128" cy="206" rx="86" ry="14" fill="%s" opacity="0.18"/>' % CHOCOLATE)
	# Badan roti: kubah atas + badan persegi membulat.
	s.append('<path d="M44 120 C44 70 84 48 128 48 C172 48 212 70 212 120 L212 180 Q212 200 192 200 L64 200 Q44 200 44 180 Z" fill="%s"/>' % CRUST_DARK)
	s.append('<path d="M52 122 C52 78 88 58 128 58 C168 58 204 78 204 122 L204 176 Q204 192 188 192 L68 192 Q52 192 52 176 Z" fill="%s"/>' % CRUST)
	# Sorotan kerak.
	s.append('<path d="M72 92 C84 72 108 64 128 64" stroke="%s" stroke-width="10" stroke-linecap="round" fill="none" opacity="0.8"/>' % CRUST_LIGHT)
	# Guratan di atas kerak.
	for i in 3:
		var x: int = 92 + i * 36
		s.append('<path d="M%d 84 q10 -10 20 0" stroke="%s" stroke-width="6" stroke-linecap="round" fill="none"/>' % [x, CRUST_DARK])
	# Irisan remah (wajah).
	s.append('<rect x="72" y="112" width="112" height="70" rx="22" fill="%s"/>' % CRUMB)
	s.append('<circle cx="106" cy="142" r="7" fill="%s"/>' % CHOCOLATE)
	s.append('<circle cx="150" cy="142" r="7" fill="%s"/>' % CHOCOLATE)
	s.append('<circle cx="94" cy="158" r="7" fill="%s" opacity="0.55"/>' % ROSY)
	s.append('<circle cx="162" cy="158" r="7" fill="%s" opacity="0.55"/>' % ROSY)
	s.append('<path d="M118 156 q10 10 20 0" stroke="%s" stroke-width="5" stroke-linecap="round" fill="none"/>' % CHOCOLATE)
	s.append('</svg>')
	return "\n".join(s) + "\n"
