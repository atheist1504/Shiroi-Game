extends CharacterBody2D

# Cọc gỗ tập đánh ở đêm đầu. Không mất máu, không đánh trả; trúng đòn thì
# rung và chớp sáng. Ở nhóm "enemies" để đòn chém, E và R nhận làm mục tiêu;
# nhóm "no_save" để không bị ghi vào save.

signal hit(amount: float)

const SIZE := Vector2(14, 30)

var is_dead: bool = false
var region_id: StringName = &"first_night"
var persistent_id: StringName = &"first_night_dummy"
# Tải save thì SaveManager xóa quái tạo lúc chạy, cọc cũng bị dọn như sói.
var is_runtime_spawn: bool = true
var _flash: float = 0.0
var _shake: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("no_save")
	add_to_group("first_night_wolves")
	add_to_group("training_targets") # tháp canh không bắn cọc tập
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(SIZE.x, 10)
	shape.shape = rectangle
	shape.position = Vector2(0, -5)
	add_child(shape)

func take_damage(amount: float, _hit_dir: Vector2 = Vector2.ZERO) -> void:
	_flash = 0.15
	_shake = 0.2
	hit.emit(amount)
	queue_redraw()

func _process(delta: float) -> void:
	if _flash <= 0.0 and _shake <= 0.0:
		return
	_flash = maxf(_flash - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	var wood := Color(0.55, 0.36, 0.2)
	var dark := Color(0.32, 0.2, 0.1)
	if _flash > 0.0:
		wood = wood.lerp(Color.WHITE, 0.7)
	var offset := Vector2(sin(_shake * 60.0) * 2.0 * signf(_shake), 0)
	# Bóng, thân cọc, xà ngang và dây buộc.
	draw_circle(Vector2(0, 0), 8.0, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(offset + Vector2(-SIZE.x * 0.5, -SIZE.y), SIZE), wood)
	draw_rect(Rect2(offset + Vector2(-SIZE.x * 0.5, -SIZE.y), SIZE), dark, false, 1.0)
	draw_rect(Rect2(offset + Vector2(-14, -SIZE.y + 6), Vector2(28, 5)), wood)
	draw_rect(Rect2(offset + Vector2(-14, -SIZE.y + 6), Vector2(28, 5)), dark, false, 1.0)
	draw_line(offset + Vector2(-SIZE.x * 0.5, -10), offset + Vector2(SIZE.x * 0.5, -10), Color(0.85, 0.75, 0.5), 2.0)
