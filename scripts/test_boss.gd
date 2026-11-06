extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died

@export_group("Thuộc tính Boss Thử Nghiệm")
@export var enemy_id: StringName = &"slime_boss"
@export var region_id: StringName = &"forest_clearing"
@export var unique_boss_id: StringName = &"slime_king_boss"
@export var persistent_id: StringName = &""
@export var is_runtime_spawn: bool = false
@export var max_health: float = 200.0
@export var base_move_speed: float = 42.0
@export var aggro_range: float = 220.0
@export var attack_range: float = 52.0
@export var attack_damage: float = 16.0
@export var attack_cooldown: float = 2.0

var current_health: float = 200.0
var attack_timer: float = 0.0
var is_dead: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $BossUI/HealthBar
@onready var title_label: Label = $BossUI/TitleLabel
@onready var status_effect: StatusEffectComponent = $StatusEffectComponent

var player_ref: Node2D = null

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	if persistent_id == StringName():
		persistent_id = StringName("%s:%s" % [str(region_id), str(get_path())])

	current_health = max_health

	if status_effect:
		status_effect.is_boss = true

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	player_ref = get_tree().get_first_node_in_group("player")
	if not player_ref:
		player_ref = get_parent().get_node_or_null("Player")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)

	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")

	var target_vel := Vector2.ZERO

	if is_instance_valid(player_ref) and not player_ref.get("is_dead"):
		var dist := global_position.distance_to(player_ref.global_position)
		var dir := (player_ref.global_position - global_position).normalized()

		if dist <= aggro_range:
			if sprite_2d and dir.x != 0.0:
				sprite_2d.flip_h = (dir.x < 0.0)

			# Tốc độ di chuyển có tính đến hiệu ứng làm chậm (35% từ Bão Phong R)
			var cur_speed := base_move_speed
			if status_effect:
				cur_speed *= status_effect.get_speed_multiplier()

			if dist > attack_range:
				target_vel = dir * cur_speed
			elif attack_timer <= 0.0:
				_perform_boss_attack()

	# Boss miễn nhiễm lực hút: chỉ nhận target_vel và knockback nhẹ
	velocity = target_vel + knockback_velocity
	move_and_slide()

# Đòn tấn công của Boss: Đập đất gây chấn động
func _perform_boss_attack() -> void:
	attack_timer = attack_cooldown
	if sprite_2d:
		# Gồng đập đất
		var tween := create_tween()
		tween.tween_property(sprite_2d, "scale", Vector2(0.55, 0.28), 0.2)
		tween.tween_property(sprite_2d, "scale", Vector2(0.45, 0.45), 0.15)
		tween.tween_callback(func():
			if is_instance_valid(player_ref) and not is_dead:
				var dist := global_position.distance_to(player_ref.global_position)
				if dist <= (attack_range + 10.0):
					if player_ref.has_method("take_damage"):
						player_ref.take_damage(attack_damage)
		)

func take_damage(amount: float, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if health_bar:
		health_bar.value = current_health

	# Boss có trọng lượng lớn -> lực đẩy lùi chỉ bằng 25% quái thường
	if hit_dir != Vector2.ZERO:
		knockback_velocity = hit_dir * 30.0

	# Hiệu ứng chớp đỏ
	if sprite_2d:
		sprite_2d.modulate = Color(1.0, 0.35, 0.35, 1.0)
		var tween := create_tween()
		var normal_color := Color(0.85, 0.35, 0.85, 1.0)
		tween.tween_property(sprite_2d, "modulate", normal_color, 0.12)

	if current_health <= 0.0:
		_die()

func assign_persistent_spawn_id(id: StringName) -> bool:
	if id == StringName():
		push_warning("Boss cần persistent_id hợp lệ trước khi được thêm vào world.")
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
		"unique_boss_id": str(unique_boss_id),
		"position_x": global_position.x,
		"position_y": global_position.y,
		"current_hp": current_health,
		"is_alive": not is_dead
	}

func restore_persistence_data(data: Dictionary) -> void:
	current_health = clampf(float(data.get("current_hp", max_health)), 0.0, max_health)
	is_dead = not bool(data.get("is_alive", true)) or current_health <= 0.0
	global_position = Vector2(float(data.get("position_x", global_position.x)), float(data.get("position_y", global_position.y)))
	attack_timer = 0.0
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", is_dead)
	visible = not is_dead
	if sprite_2d and not is_dead:
		sprite_2d.modulate = Color(0.85, 0.35, 0.85, 1.0)
		sprite_2d.scale = Vector2(0.45, 0.45)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()

	# Phát sự kiện hạ gục quái qua EventBus
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("enemy_defeated"):
		event_bus.enemy_defeated.emit(enemy_id, region_id)

	# Ghi nhận boss duy nhất bị tiêu diệt vào trạng thái thế giới (WorldState)
	if unique_boss_id != StringName():
		var world_state = get_node_or_null("/root/WorldState")
		if world_state and world_state.has_method("mark_unique_boss_defeated"):
			world_state.mark_unique_boss_defeated(unique_boss_id)

	if status_effect:
		status_effect.remove_slow()
		status_effect.remove_hard_cc()

	# Rơi chiến lợi phẩm Boss
	_spawn_boss_loot()

	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

	if sprite_2d:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite_2d, "scale", Vector2(0.6, 0.05), 0.35)
		tween.tween_property(sprite_2d, "modulate:a", 0.0, 0.35)
		tween.finished.connect(func(): visible = false)
	else:
		visible = false

func _spawn_boss_loot() -> void:
	var pickup_scene: PackedScene = load("res://scenes/pickup_item.tscn") as PackedScene
	if not pickup_scene:
		return

	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		scene_root = get_parent()
	if not scene_root:
		return

	# Rơi Gel Slime lớn (x4)
	var p1: Node2D = pickup_scene.instantiate() as Node2D
	if p1:
		p1.set("item_id", &"slime_gel")
		p1.set("amount", 4)
		p1.global_position = global_position + Vector2(-16.0, 10.0)
		scene_root.call_deferred("add_child", p1)

	# Rơi Tinh thể Phong (x2)
	var p2: Node2D = pickup_scene.instantiate() as Node2D
	if p2:
		p2.set("item_id", &"wind_crystal")
		p2.set("amount", 2)
		p2.global_position = global_position + Vector2(16.0, -10.0)
		scene_root.call_deferred("add_child", p2)

