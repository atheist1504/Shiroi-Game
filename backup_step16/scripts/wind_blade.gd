extends Area2D

# class_name WindBlade

signal hit_enemy(enemy: Node2D, damage: float)

@export var speed: float = 320.0
@export var max_range: float = 240.0
@export var damage: float = 30.0

var direction: Vector2 = Vector2.RIGHT
var distance_traveled: float = 0.0
var damaged_targets: Array[Node2D] = []
var is_active: bool = true

# Lưu vị trí trước đó để vẽ vệt gió (wind trail)
var trail_positions: Array[Vector2] = []
const MAX_TRAIL_COUNT := 4

func _ready() -> void:
	# Thiết lập va chạm: theo dõi Layer 1 (Tường) và Layer 4 (Quái)
	collision_layer = 0
	collision_mask = 1 | 4
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(spawn_pos: Vector2, target_dir: Vector2) -> void:
	global_position = spawn_pos
	direction = target_dir.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	var move_step := speed * delta
	global_position += direction * move_step
	distance_traveled += move_step

	# Lưu điểm đuôi vệt gió
	trail_positions.push_front(global_position)
	if trail_positions.size() > MAX_TRAIL_COUNT:
		trail_positions.pop_back()

	queue_redraw()

	# Đạt giới hạn tầm bắn 240px -> tan biến
	if distance_traveled >= max_range:
		_dissipate()

func _on_body_entered(body: Node2D) -> void:
	if not is_active or body == self:
		return

	# Va chạm tường / vật cản (Layer 1): Dừng lại ngay lập tức, không xuyên tường!
	if body is StaticBody2D or (body.get("collision_layer") != null and (body.collision_layer & 1) != 0):
		_dissipate()
		return

	# Va chạm quái vật (nhóm enemies hoặc Layer 4)
	if body.is_in_group("enemies") or (body.get("collision_layer") != null and (body.collision_layer & 4) != 0):
		_damage_target(body)

func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	var parent := area.get_parent()
	if parent and parent.is_in_group("enemies"):
		_damage_target(parent as Node2D)

func _damage_target(target: Node2D) -> void:
	if target in damaged_targets or target.get("is_dead") == true:
		return # Mỗi quái chỉ nhận sát thương một lần duy nhất trong một lần phóng

	damaged_targets.append(target)

	if target.has_method("take_damage"):
		target.take_damage(damage, direction)
		hit_enemy.emit(target, damage)

func _dissipate() -> void:
	if not is_active:
		return
	is_active = false
	set_physics_process(false)

	# Hiệu ứng tan biến nhỏ dạng hạt gió
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.finished.connect(queue_free)

func _draw() -> void:
	# Vẽ lưỡi kiếm gió hình bán nguyệt sắc nét phong cách Pixel Art
	# Màu chủ đạo: Xanh ngọc (Turquoise) và Lõi trắng (White Core)
	var color_outer := Color(0.25, 0.95, 0.82, 0.9)
	var color_inner := Color(0.9, 1.0, 0.98, 1.0)
	var color_wind := Color(0.5, 0.95, 0.88, 0.45)

	# Vẽ vệt đuôi gió phía sau
	for i in range(trail_positions.size()):
		var local_trail_pos := to_local(trail_positions[i])
		var alpha := 1.0 - (float(i) / float(MAX_TRAIL_COUNT))
		draw_circle(local_trail_pos, 3.5 * alpha, Color(color_wind.r, color_wind.g, color_wind.b, alpha * 0.3))

	# Điểm tọa độ lưỡi liềm gió (hướng về phía +X theo góc quay rotation)
	var points_outer := PackedVector2Array([
		Vector2(14, 0),
		Vector2(10, -8),
		Vector2(2, -14),
		Vector2(-4, -16),
		Vector2(0, -9),
		Vector2(4, 0),
		Vector2(0, 9),
		Vector2(-4, 16),
		Vector2(2, 14),
		Vector2(10, 8)
	])
	draw_colored_polygon(points_outer, color_outer)

	# Lõi sáng trắng ở giữa lưỡi dao
	var points_inner := PackedVector2Array([
		Vector2(13, 0),
		Vector2(8, -5),
		Vector2(1, -9),
		Vector2(2, 0),
		Vector2(1, 9),
		Vector2(8, 5)
	])
	draw_colored_polygon(points_inner, color_inner)

	# Viền mũi gió phát sáng
	draw_line(Vector2(-2, -15), Vector2(14, 0), color_inner, 1.2)
	draw_line(Vector2(14, 0), Vector2(-2, 15), color_inner, 1.2)
