#!/usr/bin/env bash
# Render trailer video (tools/trailer.tscn) menjadi build/trailer/roti-lezat-tycoon-trailer.mp4.
#
# 1. Godot Movie Maker memainkan trailer dengan timestep tetap. Frame 1920x1080
#    ditangkap tools/trailer.gd sebagai PNG; suaranya ada di audio.avi.
# 2. Suara dipotong mulai frame tempat rekaman dimulai (baris TRAILER_REC).
# 3. ffmpeg menggabungkan keduanya menjadi H.264 + AAC, suara memudar di akhir.
#
# Perlu jendela (renderer) dan ffmpeg di PATH. Jalankan dari akar proyek:
#   tools/render_trailer.sh
# Variabel: GODOT (path ke Godot console), FPS (bawaan 30), OUT (bawaan build/trailer),
# SKIP_RENDER=1 (encode ulang dari frame dan suara yang sudah ada).
set -euo pipefail

GODOT="${GODOT:-D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
FPS="${FPS:-30}"
OUT="${OUT:-build/trailer}"
WORK="$OUT/work"
abs() { if command -v cygpath > /dev/null; then cygpath -m "$1"; else realpath "$1"; fi; }

if [ "${SKIP_RENDER:-0}" != "1" ]; then
	rm -rf "$WORK"
	mkdir -p "$WORK/frames"
	TRAILER_OUT="$(abs "$WORK/frames")" "$GODOT" --path . --write-movie "$(abs "$WORK")/audio.avi" \
		--fixed-fps "$FPS" res://tools/trailer.tscn > "$WORK/render.log" 2>&1
fi
grep -E "TRAILER_|frames at" "$WORK/render.log" || true

start=$(grep -o 'start_process_frame=[0-9]*' "$WORK/render.log" | head -1 | cut -d= -f2)
frames=$(find "$WORK/frames" -name 'f*.png' | wc -l)
offset=$(awk "BEGIN { printf \"%.4f\", $start / $FPS }")
duration=$(awk "BEGIN { printf \"%.4f\", $frames / $FPS }")
fade_at=$(awk "BEGIN { printf \"%.4f\", $frames / $FPS - 1.6 }")
echo "frames=$frames duration=${duration}s audio_offset=${offset}s"

ffmpeg -y -loglevel error \
	-framerate "$FPS" -i "$WORK/frames/f%05d.png" \
	-ss "$offset" -i "$WORK/audio.avi" \
	-map 0:v -map 1:a -t "$duration" \
	-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r "$FPS" \
	-af "loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:d=0.3,afade=t=out:st=$fade_at:d=1.6" \
	-ar 48000 -c:a aac -b:a 192k \
	-movflags +faststart "$OUT/roti-lezat-tycoon-trailer.mp4"
echo "wrote $OUT/roti-lezat-tycoon-trailer.mp4"
