extends Node2D

# Trại: đống lửa ở giữa, vùng xây là vòng tròn quanh đó, nở rộng theo số công
# trình (BaseManager.get_camp_radius). Vòng chỉ hiện khi đang ở chế độ xây (G).
# plot_size là khung vuông bao vòng Trại lớn nhất; NPC dân làng dùng khung này
# làm vùng đi lại (npc_manager.gd), nên node đặt ở góc trên trái của khung.

@export var plot_size: Vector2 = Vector2(640, 640)

var _flicker: float = 0.0

func _ready() -> void:
	var base_manager := get_node_or_null("/root/BaseManager")
	if base_manager:
		base_manager.build_mode_changed.connect(func(_active: bool) -> void: queue_redraw())

func get_camp_center_local() -> Vector2:
	return plot_size * 0.5

func _process(delta: float) -> void:
	_flicker += delta
	queue_redraw()

func _draw() -> void:
	var center := get_camp_center_local()
	var base_manager := get_node_or_null("/root/BaseManager")
	if base_manager and bool(base_manager.get("is_build_mode")):
		var radius: float = base_manager.get_camp_radius()
		draw_circle(center, radius, Color(0.35, 0.8, 0.55, 0.08))
		# Vòng nét đứt.
		var steps := 72
		for i in steps:
			if i % 2 == 1:
				continue
			var a0 := TAU * i / steps
			var a1 := TAU * (i + 1) / steps
			draw_line(center + Vector2.from_angle(a0) * radius, center + Vector2.from_angle(a1) * radius, Color(0.55, 0.95, 0.7, 0.85), 1.5)
		draw_arc(center, base_manager.CAMP_FIRE_CLEAR, 0.0, TAU, 32, Color(1.0, 0.85, 0.5, 0.5), 1.0)
	_draw_campfire(center)

func _draw_campfire(c: Vector2) -> void:
	# Vòng đá.
	for i in 8:
		var p := c + Vector2.from_angle(TAU * i / 8.0) * Vector2(9, 6)
		draw_circle(p, 2.6, Color(0.42, 0.41, 0.40))
		draw_circle(p - Vector2(0.6, 0.6), 1.4, Color(0.62, 0.61, 0.58))
	# Củi.
	draw_line(c + Vector2(-6, 2), c + Vector2(6, -1), Color(0.42, 0.27, 0.15), 3.0)
	draw_line(c + Vector2(-6, -1), c + Vector2(6, 2), Color(0.36, 0.22, 0.12), 3.0)
	# Lửa lập lòe.
	var h := 7.0 + sin(_flicker * 9.0) * 1.5 + sin(_flicker * 13.0) * 0.8
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 1), c + Vector2(0, -h), c + Vector2(4, 1)]), Color(1.0, 0.55, 0.15, 0.95))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 1), c + Vector2(0, -h * 0.6), c + Vector2(2, 1)]), Color(1.0, 0.88, 0.45))
	draw_circle(c, 18.0, Color(1.0, 0.7, 0.3, 0.06))
