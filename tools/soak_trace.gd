extends Node
## Jejak determinisme jangka panjang (v3.1 102, 116): permainan TEST_LONGRUN_100
## (seed 100100, SimBot mengelola toko) dijalankan `--days=N` hari dan setiap hari
## dicetak sidik jarinya: tier, saldo, reputasi, dan hash state save logis. Dua
## versi kode yang seharusnya identik bisa dibandingkan baris demi baris.
## Jalankan sebagai scene (bukan --script):
##   godot --headless --path . res://tools/soak_trace.tscn -- --days=100


func _ready() -> void:
	var days: int = 100
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	PauseManager.clear_all()
	var s := SimulationRoot.new()
	add_child(s)
	s.start_new_game(&"profile_test", "Test Bakery", "male", 100100)
	var bot := SimBot.new(s)
	bot.manage = true
	for d in days:
		bot.play_day()
		var save: Dictionary = s.capture_save()
		save.erase("stats")
		save.erase("created_at")
		print("TRACE day %d tier %d balance %.6f reputation %.6f hash %d" % [s.time.day, s.world.location.tier,
			s.economy.balance, s.reputation.reputation, JSON.stringify(save, "", true).hash()])
	remove_child(s)
	s.free()
	get_tree().quit(0)
