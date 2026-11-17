extends Node2D

# Vòng sáng ngắn khi kích hoạt phối hợp nguyên tố.

var radius: float = 96.0
var color: Color = Color.WHITE

func _ready() -> void:
	z_index = 10
	scale = Vector2(0.25, 0.25)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	tween.finished.connect(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.22))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color, 2.0)
