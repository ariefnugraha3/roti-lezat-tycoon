class_name LurahPortrait
extends Control
## Potret chibi Pak Lurah digambar dengan _draw() (v3.1 12.3.3 potret 2D). Dipakai
## popup Selamat Datang dan cutscene Waralaba (GDD idle 9.5, 10.6).

## Seluruh figur (peci sampai badan) muat di dalam kotaknya.
func _draw() -> void:
	var c: Vector2 = size * Vector2(0.5, 0.3)
	var r: float = minf(size.x, size.y) * 0.2
	draw_circle(c + Vector2(0, r * 1.9), r * 1.35, Color(0.827, 0.780, 0.596))
	draw_circle(c, r, CharacterFactory.SKIN_TAN)
	draw_rect(Rect2(c.x - r * 0.8, c.y - r * 1.25, r * 1.6, r * 0.5), Color(0.15, 0.15, 0.18))
	for s: float in [-1.0, 1.0]:
		draw_circle(c + Vector2(s * r * 0.38, -r * 0.05), r * 0.11, CharacterFactory.EYE_COLOR)
		draw_circle(c + Vector2(s * r * 0.55, r * 0.28), r * 0.14, Color(Palette.ROSY_CHEEK, 0.6))
	draw_arc(c + Vector2(0, r * 0.25), r * 0.3, 0.2, PI - 0.2, 12, CharacterFactory.MOUTH_COLOR, 3.0)
	draw_rect(Rect2(c.x - r * 0.35, c.y + r * 0.12, r * 0.7, r * 0.1), CharacterFactory.HAIR_GREY)
	draw_rect(Rect2(c.x + r * 0.9, c.y + r * 1.6, r * 0.9, r * 0.6), Palette.CARAMEL)
