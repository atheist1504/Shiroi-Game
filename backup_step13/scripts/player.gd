extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal player_died

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

# Cơ chế Chiến đấu (Combat & HP)
@export_group("Chiến đấu")
@export var max_health: float = 100.0
@export var attack_range: float = 48.0
@export var attack_arc_deg: float = 90.0
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 0.45

var current_health: float = 100.0
var stamina: float = 100.0
var stamina_regen_timer: float = 0.0

var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.DOWN
var last_move_direction: Vector2 = Vector2.DOWN

var attack_cooldown_timer: float = 0.0
var is_dead: bool = false

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var slash_effect: Node2D = get_node_or_null("SlashEffect")
@onready var anim_ctrl: Node = get_node_or_null("AnimationController")

var attack_anim_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_setup_fallback_input_actions()

	if sprite_2d:
		sprite_2d.flip_h = false

	current_health = max_health
	stamina = max_stamina

	health_changed.emit(current_health, max_health)
	stamina_changed.emit(stamina, max_stamina)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Cập nhật thời gian hồi chiêu né và tấn công
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	if attack_anim_timer > 0.0:
		attack_anim_timer -= delta
		if attack_anim_timer <= 0.0 and anim_ctrl:
			anim_ctrl.end_attack()

	var input_direction := _get_input_direction()
	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction

	# Kiểm tra tấn công bằng kiếm (Chuột trái)
	if _is_attack_triggered() and attack_cooldown_timer <= 0.0 and not is_dodging:
		_perform_attack()

	# Kiểm tra kích hoạt né tránh (Phím Space)
	if _is_dodge_triggered():
		_start_dodge(input_direction)

	var stamina_consumed := false

	if is_dodging:
		# Đang thực hiện hành động né: di chuyển nhanh và miễn sát thương
		dodge_timer -= delta
		velocity = dodge_direction * dodge_speed

		# move_and_slide giữ đúng va chạm vật lý, không xuyên tường/vật cản
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
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

		move_and_slide()

		# Cập nhật animation di chuyển (Idle / Walk / Run) 4 hướng
		if anim_ctrl:
			anim_ctrl.update_movement_animation(velocity, can_sprint, input_direction)

	# Xử lý hồi phục thể lực nếu không tiêu hao
	if not stamina_consumed and not is_dodging:
		if stamina_regen_timer > 0.0:
			stamina_regen_timer -= delta
		elif stamina < max_stamina:
			stamina = minf(max_stamina, stamina + stamina_regen_rate * delta)
			stamina_changed.emit(stamina, max_stamina)

# Thực hiện đòn chém theo hướng con trỏ chuột
func _perform_attack() -> void:
	attack_cooldown_timer = attack_cooldown

	var mouse_pos := get_global_mouse_position()
	var attack_dir := (mouse_pos - global_position).normalized()
	if attack_dir == Vector2.ZERO:
		attack_dir = last_move_direction

	var attack_angle := attack_dir.angle()

	# Kích hoạt hiệu ứng quét kiếm
	if slash_effect and slash_effect.has_method("play"):
		slash_effect.play(attack_angle)

	# Kích hoạt animation tấn công 4 hướng
	attack_anim_timer = 0.2
	if anim_ctrl:
		anim_ctrl.play_attack(attack_dir)

	# Kiểm tra hình học hitbox: góc quét 90 độ, phạm vi 48px
	var half_arc_rad: float = deg_to_rad(attack_arc_deg / 2.0)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

	# Danh sách bảo đảm mỗi mục tiêu chỉ nhận sát thương đúng 1 lần trong mỗi đòn
	var damaged_targets: Array[Node2D] = []

	for node in enemies:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var enemy: Node2D = node as Node2D
		if enemy in damaged_targets or enemy.get("is_dead"):
			continue

		var dist: float = global_position.distance_to(enemy.global_position)
		# Bổ sung dung sai kích thước hitbox của quái (~14px)
		if dist <= (attack_range + 14.0):
			var to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
			var angle_diff: float = absf(attack_dir.angle_to(to_enemy))

			if angle_diff <= half_arc_rad:
				damaged_targets.append(enemy)
				if enemy.has_method("take_damage"):
					enemy.take_damage(attack_damage, attack_dir)

# Nhận sát thương từ quái vật
func take_damage(amount: float) -> void:
	# Yêu cầu 4: Trong thời gian né, người chơi miễn sát thương hoàn toàn
	if is_dead or is_dodging:
		return

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)

	# Hiệu ứng chớp đỏ khi bị đánh trúng
	if anim_ctrl:
		anim_ctrl.play_hurt()
	elif sprite_2d:
		sprite_2d.modulate = Color(1.0, 0.35, 0.35, 1.0)
		var tween := create_tween()
		tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.12)

	if current_health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	player_died.emit()
	if anim_ctrl:
		anim_ctrl.play_die()
	elif sprite_2d:
		var tween := create_tween()
		tween.tween_property(sprite_2d, "modulate:a", 0.4, 0.3)

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

	# Kích hoạt animation né 4 hướng
	if anim_ctrl:
		anim_ctrl.play_dodge(dodge_direction)
	elif sprite_2d:
		sprite_2d.modulate.a = 0.55

# Kết thúc trạng thái né tránh
func _end_dodge() -> void:
	is_dodging = false
	if anim_ctrl:
		anim_ctrl.end_dodge()
	elif sprite_2d and not is_dead:
		sprite_2d.modulate.a = 1.0

# Kiểm tra người chơi có bấm nút né không
func _is_dodge_triggered() -> bool:
	return Input.is_action_just_pressed("dodge")

# Kiểm tra người chơi có bấm tấn công không (Chuột trái)
func _is_attack_triggered() -> bool:
	return Input.is_action_just_pressed("attack")

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
	_ensure_action_with_mouse_button("attack", MOUSE_BUTTON_LEFT)

func _ensure_action_with_key(action_name: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		for keycode in keycodes:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)

func _ensure_action_with_mouse_button(action_name: StringName, button_idx: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var event := InputEventMouseButton.new()
		event.button_index = button_idx
		InputMap.action_add_event(action_name, event)
