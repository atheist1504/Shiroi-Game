extends StaticBody2D

# Cổng chặn lối vào một vùng cho tới khi WorldState mở khóa vùng đó.

@export var region_id: StringName = &"ruins"
@export var gate_size: Vector2 = Vector2(96, 32)

var is_open: bool = false
var _shape: CollisionShape2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = gate_size
	_shape.shape = rectangle
	add_child(_shape)
	_apply_state(_is_unlocked())

# Kiểm tra liên tục vì F9 có thể khóa lại vùng đã mở.
func _process(_delta: float) -> void:
	if _is_unlocked() != is_open:
		_apply_state(not is_open)
		_refresh_navigation()

func _is_unlocked() -> bool:
	return bool(get_node("/root/WorldState").is_region_unlocked(region_id))

func _apply_state(open: bool) -> void:
	is_open = open
	_shape.set_deferred("disabled", open)
	visible = not open

func _refresh_navigation() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var navigation := get_tree().current_scene.get_node_or_null("NPCManager")
	if navigation:
		navigation.refresh_navigation()

func _draw() -> void:
	var area := Rect2(-gate_size * 0.5, gate_size)
	draw_rect(area, Color(0.2, 0.17, 0.3), true)
	draw_rect(area, Color(0.55, 0.42, 0.85), false, 2.0)
	for x in range(int(area.position.x) + 8, int(area.end.x), 16):
		draw_line(Vector2(x, area.position.y + 4), Vector2(x, area.end.y - 4), Color(0.6, 0.9, 1.0, 0.8), 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(-110.0, -gate_size.y * 0.5 - 4.0), "Cần hoàn thành Giữ Vững Căn Cứ", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 8, Color(0.85, 0.8, 1.0))
