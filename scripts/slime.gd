extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died

enum State {
	IDLE,
	CHASE,
	WINDUP,    # Báo hiệu trước khi cắn (Telegraph)
	LUNGE,     # Phóng tới cắn
	RECOVERY   # Khựng lại sau khi cắn
}

@export_group("Thuộc tính quái vật")
@export var enemy_id: StringName = &"slime"
@export var region_id: StringName = &"forest_clearing"
@export var persistent_id: StringName = &""
@export var is_runtime_spawn: bool = false
@export var max_health: float = 60.0
@export var move_speed: float = 65.0
@export var aggro_range: float = 160.0
@export var attack_range: float = 38.0      # Khoảng cách bắt đầu chuẩn bị cắn
@export var stop_distance: float = 28.0     # Khoảng cách dừng để không đè vào người chơi
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.2
@export var windup_time: float = 0.32       # Thời gian cảnh báo để người chơi kịp né
@export var lunge_speed: float = 170.0      # Tốc độ chồm tới khi cắn
@export var hit_radius: float = 40.0        # Bán kính trúng đòn khi chồm cắn
@export var recovery_time: float = 0.3      # Thời gian khựng lại sau đòn
@export var knockback_decay: float = 600.0

@export_group("Chiến lợi phẩm (Loot)")
@export var gel_drop_chance: float = 0.70
@export var crystal_drop_chance: float = 0.10
@export var pickup_scene: PackedScene = preload("res://scenes/pickup_item.tscn")

var current_health: float = 60.0
var attack_timer: float = 0.0
var state_timer: float = 0.0
var current_state: State = State.IDLE

var knockback_velocity: Vector2 = Vector2.ZERO
var attack_target_dir: Vector2 = Vector2.ZERO
var is_dead: bool = false

const COLOR_NORMAL := Color(0.25, 0.85, 0.35, 1.0)
const COLOR_WINDUP := Color(1.0, 0.5, 0.15, 1.0)
const SCALE_NORMAL := Vector2(0.22, 0.18)

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var status_effect: StatusEffectComponent = get_node_or_null("StatusEffectComponent")

var player_ref: Node2D = null

func _ready() -> void:
	add_to_group("enemies")
	if persistent_id == StringName():
		persistent_id = StringName("%s:%s" % [str(region_id), str(get_path())])
	current_health = max_health

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false

	player_ref = get_tree().get_first_node_in_group("player")
	if not player_ref:
		player_ref = get_parent().get_node_or_null("Player")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Hồi chiêu đòn đánh
	if attack_timer > 0.0:
		attack_timer -= delta

	# Giảm dần lực đẩy lùi
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)

	# Kiểm tra hiệu ứng khống chế cứng (Bão Phong R)
	if status_effect and not status_effect.can_act():
		if current_state == State.WINDUP or current_state == State.LUNGE:
			current_state = State.CHASE
			if sprite_2d:
				sprite_2d.modulate = COLOR_NORMAL
				sprite_2d.scale = SCALE_NORMAL

		# Triệt tiêu lực đẩy lùi để lực hút lốc xoáy chiếm ưu thế hoàn toàn
		knockback_velocity = Vector2.ZERO

		# Khi bị khống chế cứng: Không thể tự di chuyển hoặc tấn công, bị hút dồn thẳng vào tâm lốc
		velocity = status_effect.get_pull_velocity()
		move_and_slide()
		return

	# Tìm người chơi nếu chưa có
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			player_ref = get_parent().get_node_or_null("Player")

	var target_vel: Vector2 = Vector2.ZERO

	match current_state:
		State.IDLE, State.CHASE:
			target_vel = _process_chase()

		State.WINDUP:
			# Đang gồng cảnh báo cắn: đứng yên tuyệt đối, không đẩy vào người chơi
			target_vel = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				_execute_lunge()

		State.LUNGE:
			# Đang trong tích tắc phóng tới cắn
			target_vel = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				_enter_recovery()

		State.RECOVERY:
			# Khựng lại sau đòn cắn
			target_vel = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.CHASE
				if sprite_2d:
					sprite_2d.modulate = COLOR_NORMAL
					sprite_2d.scale = SCALE_NORMAL

	var pull := status_effect.get_pull_velocity() if status_effect else Vector2.ZERO
	velocity = target_vel + knockback_velocity + pull
	move_and_slide()

# Xử lý trạng thái đuổi theo người chơi
func _process_chase() -> Vector2:
	if not is_instance_valid(player_ref) or player_ref.get("is_dead"):
		current_state = State.IDLE
		return Vector2.ZERO

	var dist_to_player: float = global_position.distance_to(player_ref.global_position)
	var dir_to_player: Vector2 = (player_ref.global_position - global_position).normalized()

	if dist_to_player <= aggro_range:
		current_state = State.CHASE

		# Lật sprite theo hướng người chơi
		if sprite_2d and dir_to_player.x != 0.0:
			sprite_2d.flip_h = (dir_to_player.x < 0.0)

		# Nếu đủ điều kiện tấn công -> Bắt đầu giai đoạn báo hiệu (Wind-up)
		if dist_to_player <= attack_range and attack_timer <= 0.0:
			_start_windup(dir_to_player)
			return Vector2.ZERO

		# Di chuyển nếu chưa tới khoảng cách dừng (tránh đè dính người chơi)
		if dist_to_player > stop_distance:
			var effective_speed: float = move_speed
			if status_effect:
				effective_speed *= status_effect.get_speed_multiplier()
			return dir_to_player * effective_speed
		else:
			return Vector2.ZERO
	else:
		current_state = State.IDLE
		return Vector2.ZERO

# Giai đoạn 1: Báo hiệu trước đòn đánh (Wind-up / Telegraph)
func _start_windup(target_dir: Vector2) -> void:
	current_state = State.WINDUP
	state_timer = windup_time
	attack_target_dir = target_dir

	# Hiệu ứng báo hiệu rõ ràng: Slime co dẹp người xuống và chuyển sang màu cam đỏ
	if sprite_2d:
		sprite_2d.modulate = COLOR_WINDUP
		var tween := create_tween()
		tween.tween_property(sprite_2d, "scale", Vector2(0.28, 0.11), windup_time)

# Giai đoạn 2: Phóng tới chồm cắn (Lunge)
func _execute_lunge() -> void:
	current_state = State.LUNGE
	state_timer = 0.15 # Thời gian phóng

	# Tạo lực phóng chồm tới theo hướng đã nhắm
	knockback_velocity = attack_target_dir * lunge_speed

	# Kéo dãn cơ thể khi phóng
	if sprite_2d:
		var tween := create_tween()
		tween.tween_property(sprite_2d, "scale", Vector2(0.18, 0.24), 0.08)

	# Kiểm tra cự ly tại thời điểm cắn
	if is_instance_valid(player_ref):
		var current_dist: float = global_position.distance_to(player_ref.global_position)
		if current_dist <= hit_radius:
			# Nếu người chơi không né hoặc né trượt -> Nhận sát thương
			# Nếu người chơi đang trong thời gian né (Space) -> player.take_damage sẽ tự miễn sát thương (I-frame)
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(attack_damage)
		# Nếu current_dist > hit_radius -> Người chơi đã né ra xa -> Slime cắn trúng không khí!

# Giai đoạn 3: Khựng lại sau đòn cắn (Recovery)
func _enter_recovery() -> void:
	current_state = State.RECOVERY
	state_timer = recovery_time
	attack_timer = attack_cooldown

	if sprite_2d:
		var tween := create_tween()
		tween.tween_property(sprite_2d, "scale", SCALE_NORMAL, 0.15)
		tween.tween_property(sprite_2d, "modulate", COLOR_NORMAL, 0.15)

# Nhận sát thương từ người chơi
func take_damage(amount: float, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)

	# Cập nhật thanh máu trên đầu
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_health

	# Đẩy lùi khi trúng kiếm
	if hit_dir != Vector2.ZERO:
		knockback_velocity = hit_dir * 130.0

	# Bị ngắt đòn nếu đang gồng (stagger)
	if current_state == State.WINDUP:
		current_state = State.RECOVERY
		state_timer = 0.2
		attack_timer = 0.6
		if sprite_2d:
			sprite_2d.scale = SCALE_NORMAL
			sprite_2d.modulate = COLOR_NORMAL

	# Hiệu ứng chớp đỏ khi trúng đòn
	if sprite_2d:
		sprite_2d.modulate = Color(1.0, 0.35, 0.35, 1.0)
		var tween := create_tween()
		tween.tween_property(sprite_2d, "modulate", COLOR_NORMAL, 0.12)

	if current_health <= 0.0:
		_die()

func assign_persistent_spawn_id(id: StringName) -> bool:
	if id == StringName():
		push_warning("Slime cần persistent_id hợp lệ trước khi được thêm vào world.")
		return false
	persistent_id = id
	is_runtime_spawn = true
	return true

func get_persistence_data(scene_root: Node) -> Dictionary:
	return {
		"persistent_id": str(persistent_id),
		"region_id": str(region_id),
		"enemy_type_id": str(enemy_id),
		"scene_path": scene_file_path,
		"parent_path": str(scene_root.get_path_to(get_parent())),
		"node_name": str(name),
		"runtime_spawn": is_runtime_spawn,
		"position_x": global_position.x,
		"position_y": global_position.y,
		"current_hp": current_health,
		"is_alive": not is_dead
	}

func restore_persistence_data(data: Dictionary) -> void:
	current_health = clampf(float(data.get("current_hp", max_health)), 0.0, max_health)
	is_dead = not bool(data.get("is_alive", true)) or current_health <= 0.0
	global_position = Vector2(float(data.get("position_x", global_position.x)), float(data.get("position_y", global_position.y)))
	current_state = State.IDLE
	state_timer = 0.0
	attack_timer = 0.0
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = not is_dead and current_health < max_health
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", is_dead)
	visible = not is_dead
	if sprite_2d and not is_dead:
		sprite_2d.modulate = COLOR_NORMAL
		sprite_2d.scale = SCALE_NORMAL

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()

	# Phát sự kiện hạ gục quái qua EventBus (đúng 1 lần)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("enemy_defeated"):
		event_bus.enemy_defeated.emit(enemy_id, region_id)

	# Rơi chiến lợi phẩm thử nghiệm xuống mặt đất (thủ công nhặt bằng phím F)
	_spawn_loot()

	if status_effect:
		status_effect.remove_hard_cc()
		status_effect.remove_slow()
	if health_bar:
		health_bar.visible = false

	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

	if sprite_2d:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite_2d, "scale", Vector2(0.28, 0.02), 0.2)
		tween.tween_property(sprite_2d, "modulate:a", 0.0, 0.22)
		tween.finished.connect(func(): visible = false)
	else:
		visible = false

func _spawn_loot() -> void:
	if not pickup_scene:
		return

	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		scene_root = get_parent()
	if not scene_root:
		return

	# Tỷ lệ rơi Gel Slime (70%)
	if randf() < gel_drop_chance:
		var p1: Node2D = pickup_scene.instantiate() as Node2D
		if p1:
			p1.set("item_id", &"slime_gel")
			p1.set("amount", 1 if randf() < 0.65 else 2)
			var offset := Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
			p1.global_position = global_position + offset
			scene_root.call_deferred("add_child", p1)

	# Tỷ lệ rơi Tinh thể Phong (10%)
	if randf() < crystal_drop_chance:
		var p2: Node2D = pickup_scene.instantiate() as Node2D
		if p2:
			p2.set("item_id", &"wind_crystal")
			p2.set("amount", 1)
			var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
			p2.global_position = global_position + offset
			scene_root.call_deferred("add_child", p2)

