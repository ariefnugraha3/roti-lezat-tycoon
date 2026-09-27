class_name SimManager
extends Node
## Basis setiap manajer gameplay per-profil (GDD 35.2, 98). Semua manajer adalah
## anak SimulationRoot dan dihancurkan saat kembali ke Main Menu, sehingga state
## antar-profil tidak pernah bocor (TEST_PROFILE_001).
##
## Kontrak:
##   setup(sim)        dipanggil sekali setelah semua manajer dibuat
##   new_game()        state awal profil baru
##   step(dt)          satu tick simulasi (detik-simulasi), dipanggil berurutan
##   capture()/restore(d)  serialisasi milik manajer ini saja

var sim: SimulationRoot = null


func setup(s: SimulationRoot) -> void:
	sim = s


func new_game() -> void:
	pass


func step(_dt: float) -> void:
	pass


func capture() -> Dictionary:
	return {}


func restore(_d: Dictionary) -> void:
	pass


## Vector2i <-> Array agar JSON-safe (GDD 106: tidak ada tipe engine di save).
static func cell_to_arr(c: Vector2i) -> Array:
	return [c.x, c.y]


static func arr_to_cell(v: Variant) -> Vector2i:
	if v is Array and (v as Array).size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(-1, -1)


static func vec_to_arr(v: Vector2) -> Array:
	return [v.x, v.y]


static func arr_to_vec(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


## Dictionary dengan kunci StringName -> kunci String untuk JSON.
static func sn_dict_to_json(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d.keys():
		out[String(k)] = d[k]
	return out


static func json_to_sn_dict(d: Variant) -> Dictionary:
	var out: Dictionary = {}
	if d is Dictionary:
		for k: Variant in (d as Dictionary).keys():
			out[StringName(str(k))] = (d as Dictionary)[k]
	return out
