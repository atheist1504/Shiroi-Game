extends Node2D

# Vùng đất có tên trên bản đồ, chỉ dùng để hiển thị.

@export var zone_title: String = ""
@export var zone_size: Vector2 = Vector2(560, 280)
@export var zone_color: Color = Color(0.3, 0.3, 0.3)

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, zone_size)
	draw_rect(area, Color(zone_color.r, zone_color.g, zone_color.b, 0.2), true)
	draw_rect(area, Color(zone_color.r, zone_color.g, zone_color.b, 0.75), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(10, 16), zone_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, zone_color.lerp(Color.WHITE, 0.5))
