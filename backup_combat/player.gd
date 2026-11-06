extends CharacterBody2D

signal stamina_changed(current: float, maximum: float)

# Tốc độ di chuyển cơ bản và chạy nhanh
@export_group("Di chuyển")
@export var walk_speed: float = 130.0
@export var run_speed: float = 230.0
@export var acceleration: float = 1200.0
@export var friction: float = 1200.0

# Cơ chế Né tránh (Dodge / Dash)
@export_group("Né tránh")
@export var dodge_speed: float = 320.0
@export var dodge_duration: float = 0.22
@export var dodge_cooldown: float = 0.7
@export var dodge_stamina_cost: float = 25.0

# Cơ chế Thể lực (Stamina)
@export_group("Thể lực")
@export var max_stamina: float = 100.0
@export var sprint_stamina_cost: float = 12.0 # 12 điểm / giây
@export var stamina_regen_rate: float = 18.0    # 18 điểm / giây
@export var stamina_regen_delay: float = 0.8   # 0.8 giây trễ trước khi hồi phục

var stamina: float = 100.0
var stamina_regen_timer: float = 0.0

var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.DOWN
var last_move_direction: Vector2 = Vector2.DOWN

@onready var sprite_2d: Sprite2D = $Sprite2D

func _ready() -> void:
	_setup_fallback_input_actions()
	stamina = max_stamina
	stamina_changed.emit(stamina, max_stamina)

func _physics_process(delta: float) -> void:
	# Cập nhật thời gian hồi chiêu né
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta

	var input_direction := _get_input_direction()
	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction

	# Kiểm tra kích hoạt né tránh
	if _is_dodge_triggered():
		_start_dodge(input_direction)

	var stamina_consumed := false

	if is_dodging:
		# Đang thực hiện hành động né
		dodge_timer -= delta
		velocity = dodge_direction * dodge_speed

		if sprite_2d and dodge_direction.x != 0.0:
			sprite_2d.flip_h = (dodge_direction.x < 0.0)

		# move_and_slide giữ đúng va chạm vật lý, ngăn né xuyên tường
		move_and_slide()

		if dodge_timer <= 0.0:
			_end_dodge()
	else:
		# Di chuyển thông thường (Đi bộ / Chạy)
		var wants_to_sprint := _is_sprint_active() and input_direction != Vector2.ZERO
		var can_sprint := wants_to_sprint and stamina > 0.0

		var target_speed := walk_speed
		if can_sprint:
			target_speed = run_speed
			stamina = maxf(0.0, stamina - sprint_stamina_cost * delta)
			stamina_regen_timer = stamina_regen_delay
			stamina_consumed = true
			stamina_changed.emit(stamina, max_stamina)

		if input_direction != Vector2.ZERO:
			var target_velocity := input_direction * target_speed
			velocity = velocity.move_toward(target_velocity, acceleration * delta)

			if sprite_2d and input_direction.x != 0.0:
				sprite_2d.flip_h = (input_direction.x < 0.0)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

		move_and_slide()

	# Xử lý hồi phục thể lực nếu không tiêu hao
	if not stamina_consumed and not is_dodging:
		if stamina_regen_timer > 0.0:
			stamina_regen_timer -= delta
		elif stamina < max_stamina:
			stamina = minf(max_stamina, stamina + stamina_regen_rate * delta)
			stamina_changed.emit(stamina, max_stamina)

# Bắt đầu trạng thái né tránh
func _start_dodge(input_direction: Vector2) -> void:
	if is_dodging or dodge_cooldown_timer > 0.0:
		return
	if stamina < dodge_stamina_cost:
		return

	# Tiêu hao thể lực
	stamina = maxf(0.0, stamina - dodge_stamina_cost)
	stamina_regen_timer = stamina_regen_delay
	stamina_changed.emit(stamina, max_stamina)

	# Xác định hướng né: ưu tiên hướng đang nhấn, nếu đứng yên dùng hướng cuối
	if input_direction != Vector2.ZERO:
		dodge_direction = input_direction
	else:
		dodge_direction = last_move_direction

	if dodge_direction == Vector2.ZERO:
		dodge_direction = Vector2.DOWN

	dodge_direction = dodge_direction.normalized()

	is_dodging = true
	dodge_timer = dodge_duration
	dodge_cooldown_timer = dodge_cooldown

	# Hiệu ứng thị giác khi lướt né
	if sprite_2d:
		sprite_2d.modulate.a = 0.55

# Kết thúc trạng thái né tránh
func _end_dodge() -> void:
	is_dodging = false
	if sprite_2d:
		sprite_2d.modulate.a = 1.0

# Kiểm tra người chơi có bấm nút né không
func _is_dodge_triggered() -> bool:
	return Input.is_action_just_pressed("dodge")

# Lấy hướng di chuyển chuẩn hóa 8 hướng từ WASD hoặc phím mũi tên
func _get_input_direction() -> Vector2:
	var dir := Vector2.ZERO

	if Input.is_action_pressed("move_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_action_pressed("move_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_action_pressed("move_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0

	return dir.normalized()

# Kiểm tra trạng thái nhấn Shift để chạy
func _is_sprint_active() -> bool:
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)

# Tự động khởi tạo Action nếu trong Project Settings chưa có
func _setup_fallback_input_actions() -> void:
	_ensure_action_with_key("move_left", [KEY_A, KEY_LEFT])
	_ensure_action_with_key("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action_with_key("move_up", [KEY_W, KEY_UP])
	_ensure_action_with_key("move_down", [KEY_S, KEY_DOWN])
	_ensure_action_with_key("sprint", [KEY_SHIFT])
	_ensure_action_with_key("dodge", [KEY_SPACE])

func _ensure_action_with_key(action_name: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		for keycode in keycodes:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)
