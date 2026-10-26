extends Node
## Probe akurasi model KR/s (GDD idle 9.1, ACC_IDLE_MODEL_MATCH): untuk toko
## contoh Tier 1-5, bandingkan rata-rata KR/s model dengan laba bersih nyata
## simulasi hidup (penjualan − bahan) per detik nyata.
##   godot --headless --path . res://tools/model_probe.tscn -- [--hours=8] [--warm=2] [--seed=7] [--bare]
## Tidak menulis save apa pun.

var _hours: float = 8.0
var _warm: float = 2.0
var _seed: int = 7
## --bare: hanya toko awal Tier 1 (tanpa staf, level 1), seperti permainan baru.
var _bare: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--hours="):
			_hours = float(a.substr(8))
		elif a.begins_with("--warm="):
			_warm = float(a.substr(7))
		elif a.begins_with("--seed="):
			_seed = int(a.substr(7))
		elif a == "--bare":
			_bare = true
	SaveManager.dir = "user://probe_saves"
	GameLogger.quiet = true
	await get_tree().process_frame
	for tier in ([1] if _bare else range(1, 6)):
		var sim := SimulationRoot.new()
		add_child(sim)
		sim.start_new_game(&"profile_probe", "Model Bakery", "male", _seed + tier)
		if _bare:
			sim.tutorial.skip()
			ModelSample.no_boosts(sim)
		else:
			ModelSample.build(sim, tier)
		var r: Dictionary = ModelSample.measure(sim, _warm, _hours)
		print("MODEL tier=%d model=%.2f live=%.2f ratio=%.3f units_model=%.1f units_live=%.1f demand=%.1f prod=%.1f" % [tier,
			r["model"], r["live"], float(r["model"]) / maxf(float(r["live"]), 0.0001), r["units_model"], r["units_live"], r["demand"], r["production"]])
		print("      per hour: entered=%.1f served=%.1f missed=%.1f lost=%.1f nostock=%.1f rf_done=%.1f rep=%.2f" % [r["entered"], r["served"],
			r["missed"], r["lost"], r["nostock"], r["rf_done"], r["rep"]])
		print("      live price/unit=%.1f model net/unit=%.1f auto=%s produced/h=%.1f jobs=%d table=%d" % [r["live_price"], r["model_net"], r["auto"], r["produced"], r["jobs"], r["table"]])
		remove_child(sim)
		sim.free()
	get_tree().quit(0)
