extends Node

class_name SkillComponent

signal skill_used(skill_name: String)
signal skill_hit(skill_name: String, target: Node2D, damage: float)
signal energy_changed(current: float, maximum: float)
signal cooldown_changed(skill_name: String, remaining: float, total: float)
signal skill_feedback(message: String)

@export_group("Năng lượng nguyên tố")
@export var max_energy: float = 100.0
@export var current_energy: float = 0.0
@export var sword_energy_gain: float = 5.0
@export var e_energy_gain: float = 10.0

@export_group("Kỹ năng E - Phong Nhận")
@export var e_damage: float = 30.0
@export var e_cooldown: float = 5.0
@export var e_range: float = 240.0
@export var e_speed: float = 320.0
@export var wind_blade_scene: PackedScene = preload("res://scenes/wind_blade.tscn")

@export_group("Kỹ năng R - Bão Phong")
@export var r_damage_per_tick: float = 15.0
@export var r_ticks: int = 4
@export var r_duration: float = 2.0
@export var r_pull_radius: float = 96.0
@export var r_damage_radius: float = 64.0
@export var r_energy_cost: float = 100.0
@export var r_cooldown: float = 15.0
@export var r_max_cast_range: float = 180.0
@export var cyclone_scene: PackedScene = preload("res://scenes/cyclone.tscn")

var e_cooldown_timer: float = 0.0
var r_cooldown_timer: float = 0.0

var player_body: CharacterBody2D = null

func _ready() -> void:
	if get_parent() is CharacterBody2D:
		player_body = get_parent() as CharacterBody2D

	_setup_fallback_input_actions()

	# Phát tín hiệu ban đầu
	energy_changed.emit(current_energy, max_energy)
	cooldown_changed.emit("E", 0.0, e_cooldown)
	cooldown_changed.emit("R", 0.0, r_cooldown)

func _process(delta: float) -> void:
	var e_prev := e_cooldown_timer
	var r_prev := r_cooldown_timer

	if e_cooldown_timer > 0.0:
		e_cooldown_timer = maxf(0.0, e_cooldown_timer - delta)
		if e_prev > 0.0 and e_cooldown_timer <= 0.0:
			cooldown_changed.emit("E", 0.0, e_cooldown)

	if r_cooldown_timer > 0.0:
		r_cooldown_timer = maxf(0.0, r_cooldown_timer - delta)
		if r_prev > 0.0 and r_cooldown_timer <= 0.0:
			cooldown_changed.emit("R", 0.0, r_cooldown)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if player_body and player_body.get("is_dead") == true:
		return

	# Không thi triển kỹ năng khi đang mở bảng Nhật ký, Debug hoặc Pause Menu
	var root := get_tree().current_scene
	if root:
		var journal = root.get_node_or_null("QuestJournal")
		if journal and journal.visible:
			return
		var debug_p = root.get_node_or_null("DebugPanel")
		if debug_p and debug_p.visible:
			return
		var pause_m = root.get_node_or_null("PauseMenu")
		if pause_m and pause_m.visible:
			return

	if event.is_action_pressed("skill_e") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E):
		try_cast_e()
	elif event.is_action_pressed("skill_r") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R):
		try_cast_r()

# Thi triển kỹ năng E - Phong Nhận
func try_cast_e() -> bool:
	if e_cooldown_timer > 0.0:
		skill_feedback.emit("Phong Nhận đang hồi chiêu (%.1fs)!" % e_cooldown_timer)
		return false

	var spawn_pos: Vector2 = player_body.global_position if player_body else Vector2.ZERO
	var mouse_pos: Vector2 = player_body.get_global_mouse_position() if player_body else Vector2.ZERO
	var cast_dir := (mouse_pos - spawn_pos).normalized()
	if cast_dir == Vector2.ZERO:
		cast_dir = Vector2.RIGHT

	if not wind_blade_scene:
		return false

	var blade := wind_blade_scene.instantiate() as WindBlade
	blade.speed = e_speed
	blade.max_range = e_range
	blade.damage = e_damage
	blade.hit_enemy.connect(_on_e_hit_enemy)

	# Thêm vào Scene Tree trước khi setup vị trí
	var root := get_tree().current_scene
	if root:
		root.add_child(blade)
	else:
		get_parent().add_child(blade)

	blade.setup(spawn_pos, cast_dir)

	e_cooldown_timer = e_cooldown
	cooldown_changed.emit("E", e_cooldown, e_cooldown)
	skill_used.emit("E")
	return true

# Phản hồi khi E trúng đích: +10 năng lượng nguyên tố
func _on_e_hit_enemy(enemy: Node2D, dmg: float) -> void:
	add_energy(e_energy_gain)
	skill_hit.emit("E", enemy, dmg)

# Thi triển kỹ năng R - Bão Phong
func try_cast_r() -> bool:
	if r_cooldown_timer > 0.0:
		skill_feedback.emit("Bão Phong đang hồi chiêu (%.1fs)!" % r_cooldown_timer)
		return false

	if current_energy < r_energy_cost:
		skill_feedback.emit("Chưa đủ Năng lượng nguyên tố (%d / %d)!" % [roundi(current_energy), roundi(r_energy_cost)])
		return false

	var player_pos: Vector2 = player_body.global_position if player_body else Vector2.ZERO
	var mouse_pos: Vector2 = player_body.get_global_mouse_position() if player_body else Vector2.ZERO

	# Giới hạn phạm vi thi triển tối đa 180 px từ vị trí người chơi
	var target_offset := mouse_pos - player_pos
	if target_offset.length() > r_max_cast_range:
		target_offset = target_offset.normalized() * r_max_cast_range
	var spawn_pos := player_pos + target_offset

	if not cyclone_scene:
		return false

	var cyclone := cyclone_scene.instantiate() as Cyclone
	cyclone.duration = r_duration
	cyclone.pull_radius = r_pull_radius
	cyclone.damage_radius = r_damage_radius
	cyclone.damage_per_tick = r_damage_per_tick
	cyclone.total_ticks = r_ticks

	cyclone.tick_hit.connect(_on_r_tick_hit)

	var root := get_tree().current_scene
	if root:
		root.add_child(cyclone)
	else:
		get_parent().add_child(cyclone)

	cyclone.global_position = spawn_pos

	# Tiêu hao năng lượng và bắt đầu hồi chiêu chỉ khi thi triển thành công
	current_energy -= r_energy_cost
	energy_changed.emit(current_energy, max_energy)

	r_cooldown_timer = r_cooldown
	cooldown_changed.emit("R", r_cooldown, r_cooldown)
	skill_used.emit("R")
	return true

func _on_r_tick_hit(enemy: Node2D, dmg: float) -> void:
	skill_hit.emit("R", enemy, dmg)

# Thêm năng lượng nguyên tố khi đánh trúng mục tiêu (kiếm hoặc kỹ năng)
func add_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	var old_val := current_energy
	current_energy = clampf(current_energy + amount, 0.0, max_energy)
	if current_energy != old_val:
		energy_changed.emit(current_energy, max_energy)

# Đòn chém kiếm trúng đích: +5 năng lượng mỗi mục tiêu
func on_sword_hit(enemy: Node2D) -> void:
	add_energy(sword_energy_gain)
	skill_hit.emit("Sword", enemy, 20.0)

# Cấu hình dự phòng nếu Project Settings chưa có Action
func _setup_fallback_input_actions() -> void:
	if not InputMap.has_action("skill_e"):
		InputMap.add_action("skill_e")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("skill_e", ev)

	if not InputMap.has_action("skill_r"):
		InputMap.add_action("skill_r")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_R
		InputMap.action_add_event("skill_r", ev)
