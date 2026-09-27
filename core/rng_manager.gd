class_name RNGManager
extends SimManager
## RNGManager — delapan stream deterministik terpisah (GDD 91.3, 116).
##
## Kedatangan dan pilihan memakai stream berbeda, jadi menata ulang display tidak
## pernah mengubah siapa yang datang berikutnya. cosmetic_rng/audio_rng tidak
## boleh dipakai untuk hasil gameplay. Semua state stream ikut disimpan sehingga
## save/load tidak me-reroll cuaca atau kedatangan berikutnya (GDD 77.4).

const STREAMS: Array[StringName] = [
	&"weather_rng", &"customer_arrival_rng", &"customer_choice_rng", &"rotifood_rng",
	&"staff_rng", &"marketing_rng", &"cosmetic_rng", &"audio_rng",
]

var master_seed: int = 1
var day_seed: int = 0
var _streams: Dictionary = {}


func new_game() -> void:
	init_seed(master_seed)


## Membuat semua stream dari master seed (New Game, GDD 89.4).
func init_seed(seed_value: int) -> void:
	master_seed = seed_value
	_streams.clear()
	for name: StringName in STREAMS:
		var r := RandomNumberGenerator.new()
		r.seed = _derive(seed_value, String(name))
		_streams[name] = r


func stream(name: StringName) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = _streams.get(name)
	if r == null:
		push_error("[TEST] unknown RNG stream %s" % name)
		r = RandomNumberGenerator.new()
		_streams[name] = r
	return r


## Seed per hari untuk reproduksi bug (GDD 25.5, 39.2). Tidak mengubah stream.
func begin_day(day: int) -> void:
	day_seed = _derive(master_seed, "day_%d" % day)


static func _derive(seed_value: int, salt: String) -> int:
	var h: int = hash("%d:%s" % [seed_value, salt])
	return absi(h) + 1


## Pilihan berbobot dari Dictionary key -> bobot. Mengembalikan key atau null.
static func weighted_pick(r: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var total: float = 0.0
	var keys: Array = weights.keys()
	keys.sort()
	for k: Variant in keys:
		total += maxf(0.0, float(weights[k]))
	if total <= 0.0:
		return null
	var roll: float = r.randf() * total
	for k2: Variant in keys:
		roll -= maxf(0.0, float(weights[k2]))
		if roll < 0.0:
			return k2
	return keys[keys.size() - 1]


func capture() -> Dictionary:
	var states: Dictionary = {}
	for name: StringName in STREAMS:
		var r: RandomNumberGenerator = stream(name)
		states[String(name)] = {"seed": str(r.seed), "state": str(r.state)}
	return {"master_seed": str(master_seed), "day_seed": str(day_seed), "streams": states}


func restore(d: Dictionary) -> void:
	master_seed = int(str(d.get("master_seed", "1")))
	day_seed = int(str(d.get("day_seed", "0")))
	init_seed(master_seed)
	var states: Dictionary = d.get("streams", {})
	for name: StringName in STREAMS:
		var sd: Variant = states.get(String(name))
		if sd is Dictionary:
			var r: RandomNumberGenerator = stream(name)
			r.seed = int(str((sd as Dictionary).get("seed", r.seed)))
			r.state = int(str((sd as Dictionary).get("state", r.state)))
