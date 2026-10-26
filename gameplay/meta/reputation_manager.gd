class_name ReputationManager
extends SimManager
## ReputationManager — satu Reputasi ★ 1,0–5,0, ID `reputation` (GDD idle 6.6).
## Menggantikan dua rating v3.1 (toko dan RotiFood Stars).
##
## Setiap pembeli atau pesanan yang terlayani menambah `reputation.served_delta`;
## setiap yang pergi tanpa terlayani mengurangi `reputation.lost_delta`.
## Pengali kedatangan = mult_base + mult_per_star × reputasi.

var reputation: float = 3.0


func new_game() -> void:
	reputation = DataRegistry.idlef("reputation.start")


func _clamp(v: float) -> float:
	return clampf(v, DataRegistry.idlef("reputation.min"), DataRegistry.idlef("reputation.max"))


func add(delta: float) -> void:
	if is_nan(delta) or delta == 0.0:
		return
	var before: float = reputation
	reputation = _clamp(reputation + delta)
	if reputation != before:
		sim.statistics.note_reputation(reputation)
		EventBus.reputation_changed.emit(reputation)


func on_served() -> void:
	add(DataRegistry.idlef("reputation.served_delta"))


func on_lost() -> void:
	add(-DataRegistry.idlef("reputation.lost_delta"))


## Pengali kedatangan (GDD idle 6.6): ★1 = ×0,8; ★5 = ×1,6.
func mult() -> float:
	return mult_for(reputation)


static func mult_for(rep: float) -> float:
	return DataRegistry.idlef("reputation.mult_base") + DataRegistry.idlef("reputation.mult_per_star") * rep


func capture() -> Dictionary:
	return {"reputation": reputation}


func restore(d: Dictionary) -> void:
	reputation = _clamp(float(d.get("reputation", DataRegistry.idlef("reputation.start"))))
