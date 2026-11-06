extends Node2D

@export var plot_size: Vector2 = Vector2(544, 160)

func _draw() -> void:
	var plot := Rect2(Vector2.ZERO, plot_size)
	draw_rect(plot, Color(0.16, 0.27, 0.2, 0.22), true)
	draw_rect(plot, Color(0.35, 0.8, 0.55, 0.8), false, 2.0)
	var lane_y := plot_size.y * 0.5
	for x in range(12, int(plot_size.x) - 8, 24):
		draw_line(Vector2(x, lane_y), Vector2(minf(x + 12, plot_size.x), lane_y), Color(0.9, 0.82, 0.47, 0.75), 1.0)
	var label := "THUNG LUNG HY VONG"
	draw_string(ThemeDB.fallback_font, Vector2(10, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.84, 1.0, 0.86, 0.9))
