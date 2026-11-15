extends Node2D

# Mũi tên của tháp canh: bay thẳng tới quái, chạm thì gây sát thương rồi biến mất.
const SPEED: float = 360.0
const HIT_DISTANCE: float = 8.0

var target: Node2D = null
var damage: float = 0.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or target.get("is_dead") == true:
		queue_free()
		return
	var to_target := target.global_position - global_position
	if to_target.length() <= HIT_DISTANCE:
		if target.has_method("take_damage"):
			target.call("take_damage", damage, to_target.normalized())
		queue_free()
		return
	global_position += to_target.normalized() * minf(SPEED * delta, to_target.length())
	rotation = to_target.angle()
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-6, 0), Vector2(4, 0), Color(0.55, 0.38, 0.2, 1), 2.0)
	draw_line(Vector2(4, 0), Vector2(0, -2), Color(0.85, 0.85, 0.9, 1), 1.0)
	draw_line(Vector2(4, 0), Vector2(0, 2), Color(0.85, 0.85, 0.9, 1), 1.0)
