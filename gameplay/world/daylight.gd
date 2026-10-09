class_name Daylight
extends RefCounted
## Cahaya dunia mengikuti jam in-game (keputusan maintainer 2026-10-09, GDD 32.6):
## fajar lembut pukul 05:00, pagi terang, siang hangat-netral, golden hour yang
## makin keemasan menjelang tutup, lalu senja pukul 18:00 dengan lampu jalan
## menyala (juga selama after-hours, karena jam berhenti di 18:00). Semua warna
## tetap hangat (GDD 130.3). Yang berubah hanya warna, kekuatan, dan sudut cahaya
## serta warna latar; materialnya tetap, jadi tidak ada kombinasi shader baru.
## Murni tampilan: hanya membaca jam dan cuaca simulasi.

## Titik kunci, urut jam. sun/amb = warna matahari/ambient, sun_e/amb_e =
## energinya, elev = sudut matahari di atas cakrawala (derajat), lamp_e = energi
## lampu ruangan, bg = warna latar, street = lampu jalan (>= 0,5 menyala).
const KEYS: Array[Dictionary] = [
	{"h": 5.0, "sun": Color("ffb98a"), "sun_e": 0.34, "elev": 24.0, "amb": Color("e8c3bd"), "amb_e": 0.46,
		"lamp_e": 0.95, "bg": Color("e3cdbb"), "street": 1.0},
	{"h": 5.75, "sun": Color("ffc896"), "sun_e": 0.55, "elev": 30.0, "amb": Color("f1d1c0"), "amb_e": 0.5,
		"lamp_e": 0.85, "bg": Color("ecd6c1"), "street": 1.0},
	{"h": 6.5, "sun": Color("ffdcb0"), "sun_e": 0.78, "elev": 38.0, "amb": Color("f8e0c9"), "amb_e": 0.53,
		"lamp_e": 0.7, "bg": Color("f2dfc7"), "street": 0.0},
	{"h": 8.0, "sun": Color("ffecd0"), "sun_e": 0.92, "elev": 48.0, "amb": Color("fcead2"), "amb_e": 0.56,
		"lamp_e": 0.55, "bg": Color("f6e8cf"), "street": 0.0},
	{"h": 12.0, "sun": Color("ffeed4"), "sun_e": 0.97, "elev": 58.0, "amb": Color("ffecd2"), "amb_e": 0.57,
		"lamp_e": 0.5, "bg": Color("f7e9d0"), "street": 0.0},
	{"h": 15.0, "sun": Palette.GOLDEN_HOUR, "sun_e": 0.95, "elev": 52.0, "amb": Palette.GOLDEN_HOUR, "amb_e": 0.55,
		"lamp_e": 0.55, "bg": Palette.BG, "street": 0.0},
	{"h": 16.75, "sun": Color("ffd08c"), "sun_e": 0.88, "elev": 40.0, "amb": Color("ffdcaa"), "amb_e": 0.52,
		"lamp_e": 0.62, "bg": Color("f2dcbd"), "street": 0.0},
	{"h": 17.6, "sun": Color("ffb276"), "sun_e": 0.64, "elev": 28.0, "amb": Color("f4c9a8"), "amb_e": 0.48,
		"lamp_e": 0.8, "bg": Color("e9cdb2"), "street": 1.0},
	{"h": 18.0, "sun": Color("f89c74"), "sun_e": 0.44, "elev": 20.0, "amb": Color("dcb6b3"), "amb_e": 0.45,
		"lamp_e": 0.95, "bg": Color("dcc0b0"), "street": 1.0},
]
## Arah matahari di bidang datar (derajat, sama dengan cahaya lama).
const SUN_YAW: float = -135.0
## Hujan: langit mendung, cahaya matahari redup dan lebih pucat, lampu lebih
## terang supaya toko terasa hangat.
const RAIN_SUN: float = 0.55
const RAIN_AMB: float = 1.12
const RAIN_LAMP: float = 1.2
const RAIN_TINT: Color = Color("e6ddd2")
const RAIN_TINT_WEIGHT: float = 0.5


## Cahaya pada jam `clock_seconds` (detik sejak 00:00).
static func sample(clock_seconds: float, rain: bool = false) -> Dictionary:
	var h: float = clock_seconds / 3600.0
	var a: Dictionary = KEYS[0]
	var b: Dictionary = KEYS[0]
	var t: float = 0.0
	if h <= float(KEYS[0]["h"]):
		a = KEYS[0]
		b = a
	elif h >= float(KEYS[KEYS.size() - 1]["h"]):
		a = KEYS[KEYS.size() - 1]
		b = a
	else:
		for i in KEYS.size() - 1:
			if h < float(KEYS[i + 1]["h"]):
				a = KEYS[i]
				b = KEYS[i + 1]
				t = (h - float(a["h"])) / (float(b["h"]) - float(a["h"]))
				break
	t = smoothstep(0.0, 1.0, t)
	var out: Dictionary = {
		"sun": (a["sun"] as Color).lerp(b["sun"], t),
		"sun_e": lerpf(a["sun_e"], b["sun_e"], t),
		"elev": lerpf(a["elev"], b["elev"], t),
		"amb": (a["amb"] as Color).lerp(b["amb"], t),
		"amb_e": lerpf(a["amb_e"], b["amb_e"], t),
		"lamp_e": lerpf(a["lamp_e"], b["lamp_e"], t),
		"bg": (a["bg"] as Color).lerp(b["bg"], t),
		"street": lerpf(a["street"], b["street"], t) >= 0.5,
	}
	if rain:
		out["sun"] = (out["sun"] as Color).lerp(RAIN_TINT, RAIN_TINT_WEIGHT)
		out["sun_e"] = float(out["sun_e"]) * RAIN_SUN
		out["amb"] = (out["amb"] as Color).lerp(RAIN_TINT, RAIN_TINT_WEIGHT)
		out["amb_e"] = float(out["amb_e"]) * RAIN_AMB
		out["lamp_e"] = float(out["lamp_e"]) * RAIN_LAMP
		out["bg"] = (out["bg"] as Color).lerp(RAIN_TINT, RAIN_TINT_WEIGHT)
	return out


## Pasang cahaya `s` (hasil `sample`) ke matahari, lampu ruangan, dan environment.
static func apply(s: Dictionary, suns: Array, lamps: Array, env: Environment) -> void:
	for n: Variant in suns:
		var sun: DirectionalLight3D = n
		if not is_instance_valid(sun):
			continue
		sun.light_color = s["sun"]
		sun.light_energy = s["sun_e"]
		sun.rotation_degrees = Vector3(-float(s["elev"]), SUN_YAW, 0.0)
	for n2: Variant in lamps:
		var lamp: OmniLight3D = n2
		if is_instance_valid(lamp):
			lamp.light_energy = s["lamp_e"]
	if env != null:
		env.ambient_light_color = s["amb"]
		env.ambient_light_energy = s["amb_e"]
		env.background_color = s["bg"]
