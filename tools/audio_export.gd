extends Node
## Ekspor semua bunyi hasil generator ke berkas WAV untuk didengarkan, dengan
## lama perakitan, ukuran, kekerasan (RMS), dan puncak tiap bunyi (Seksi 20 no.
## 108). Tidak memakai atau mengisi cache disk.
##   godot --headless --path . res://tools/audio_export.tscn [-- --out=C:/folder] [--only=tap_soft,music_day]
## Bawaan --out: user://audio_export.

func _ready() -> void:
	var out: String = "user://audio_export"
	var only: PackedStringArray = PackedStringArray()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
	AudioCache.enabled = false
	DirAccess.make_dir_recursive_absolute(out)
	var total_ms: float = 0.0
	var total_kb: int = 0
	var rows: Array = []
	for g: String in AudioGenerator.RECIPES:
		if not only.is_empty() and not only.has(g):
			continue
		var t0: int = Time.get_ticks_usec()
		var s: AudioStreamWAV = AudioGenerator.build(g)
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		var d: PackedByteArray = s.data
		var n: int = d.size() / 2 - AudioGenerator.TAIL_PAD
		var sq: float = 0.0
		var pk: float = 0.0
		for i in n:
			var v: float = float(d.decode_s16(i * 2)) / 32767.0
			sq += v * v
			pk = maxf(pk, absf(v))
		total_ms += ms
		total_kb += d.size() / 1024
		rows.append([g, ms, d.size() / 1024, s.get_length(), sqrt(sq / maxf(n, 1)), pk, s.mix_rate])
		s.save_to_wav(out.path_join(g + ".wav"))
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	for r: Array in rows:
		print("AUDIO %-22s %7.1f ms %6d KB %6.2f s rms %.3f peak %.3f %d Hz" % r)
	print("AUDIO total %.0f ms, %d KB -> %s" % [total_ms, total_kb, ProjectSettings.globalize_path(out)])
	get_tree().quit()
