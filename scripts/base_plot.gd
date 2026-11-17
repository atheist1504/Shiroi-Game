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

# Đống lửa do công cụ AI vẽ (tools/ai_art.gd); quầng sáng lập lòe vẽ thêm bằng code.
const CAMPFIRE_ART: Texture2D = preload("res://assets/art_ai/campfire.png")

func _draw_campfire(c: Vector2) -> void:
	var glow := 0.07 + sin(_flicker * 9.0) * 0.02 + sin(_flicker * 13.0) * 0.01
	draw_circle(c, 18.0, Color(1.0, 0.7, 0.3, glow))
	draw_texture(CAMPFIRE_ART, (c - Vector2(CAMPFIRE_ART.get_width() * 0.5, CAMPFIRE_ART.get_height() - 6.0)).round())
