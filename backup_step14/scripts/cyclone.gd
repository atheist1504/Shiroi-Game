extends Node2D

# class_name Cyclone

signal tick_hit(enemy: Node2D, damage: float)
signal cyclone_finished

@export var duration: float = 2.0
@export var pull_radius: float = 96.0
@export var damage_radius: float = 64.0
@export var damage_per_tick: float = 15.0
@export var total_ticks: int = 4
@export var pull_speed: float = 115.0

var elapsed_time: float = 0.0
var tick_interval: float = 0.5 # 2.0 / 4 = 0.5s
var next_tick_time: float = 0.25
var current_tick_count: int = 0

var current_rotation: float = 0.0
var is_active: bool = true

# Lưu trữ danh sách quái vật đang chịu ảnh hưởng để dọn dẹp trạng thái khi lốc kết thúc
var affected_enemies: Array[Node2D] = []

func _ready() -> void:
	tick_interval = duration / float(total_ticks)
	next_tick_time = tick_interval * 0.5

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	elapsed_time += delta
	current_rotation += delta * 8.0 # Góc quay xoáy nhanh phong cách bão gió

	# 1. Xử lý lực hút và hiệu ứng khống chế / làm chậm liên tục
	_process_pull_and_effects(delta)

	# 2. Xử lý các đợt gây sát thương theo tick (4 đợt)
	if current_tick_count < total_ticks and elapsed_time >= next_tick_time:
		_process_damage_tick()
		current_tick_count += 1
		next_tick_time += tick_interval

	queue_redraw()

	# 3. Kết thúc vòng đời lốc xoáy sau 2 giây
	if elapsed_time >= duration:
		_finish_cyclone()

# Xử lý hút quái thường và làm chậm boss
func _process_pull_and_effects(_delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var space_state := get_world_2d().direct_space_state

	for node in enemies:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var enemy: Node2D = node as Node2D
		if enemy.get("is_dead") == true:
			continue

		var dist := global_position.distance_to(enemy.global_position)
		if dist <= pull_radius:
			# Kiểm tra xem có bị tường ngăn cản không (Không tác động xuyên tường)
			if _is_blocked_by_wall(space_state, enemy.global_position):
				continue

			if not (enemy in affected_enemies):
				affected_enemies.append(enemy)

			# Tìm StatusEffectComponent trên quái
			var status_comp: StatusEffectComponent = enemy.get_node_or_null("StatusEffectComponent")
			if not status_comp:
				# Quái chưa có component thì tìm theo kiểu thuộc tính
				continue

			var is_boss: bool = status_comp.is_boss or enemy.is_in_group("boss")

			if is_boss:
				# Hiệu ứng với Boss:
				# - Miễn nhiễm hút và khống chế cứng
				# - Giảm 35% tốc độ di chuyển
				# - Boss vẫn di chuyển và tấn công bình thường
				status_comp.apply_slow(0.35, 0.25)
			else:
				# Hiệu ứng với Quái thường:
				# - Bị khống chế cứng (không thể tự di chuyển, tấn công hoặc dùng chiêu)
				status_comp.apply_hard_cc(0.2)

				# - Bị hút dần vào tâm lốc xoáy bằng va chạm vật lý (không dịch chuyển, không kéo xuyên tường)
				var to_center := (global_position - enemy.global_position).normalized()
				# Tốc độ hút giảm dần khi càng gần tâm để quái tụ lại đẹp mắt
				var current_pull := to_center * (pull_speed * clampf(dist / pull_radius + 0.3, 0.4, 1.2))
				status_comp.apply_pull(current_pull)

# Gây sát thương mỗi đợt (4 đợt, mỗi đợt 15 dmg)
func _process_damage_tick() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var space_state := get_world_2d().direct_space_state

	# Danh sách bảo đảm mỗi mục tiêu chỉ nhận tối đa một hit mỗi đợt
	var hit_this_tick: Array[Node2D] = []

	for node in enemies:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var enemy: Node2D = node as Node2D
		if enemy in hit_this_tick or enemy.get("is_dead") == true:
			continue

		var dist := global_position.distance_to(enemy.global_position)
		if dist <= damage_radius:
			# Kiểm tra tường ngăn cách
			if _is_blocked_by_wall(space_state, enemy.global_position):
				continue

			hit_this_tick.append(enemy)

			if enemy.has_method("take_damage"):
				# Sát thương lốc xoáy gây lực rung nhẹ hướng vào tâm
				var inward_dir := (global_position - enemy.global_position).normalized()
				enemy.take_damage(damage_per_tick, inward_dir * 30.0)
				tick_hit.emit(enemy, damage_per_tick)

# Kiểm tra đường ngắm tia Raycast xem có chạm vào tường (Layer 1) không
func _is_blocked_by_wall(space_state: PhysicsDirectSpaceState2D, target_pos: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target_pos)
	query.collision_mask = 1 # Layer 1 là tường và vật cản
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	return not result.is_empty()

# Kết thúc lốc xoáy an toàn
func _finish_cyclone() -> void:
	if not is_active:
		return
	is_active = false
	set_physics_process(false)

	# Giải phóng và khôi phục trạng thái cho tất cả quái vật bị ảnh hưởng
	for enemy in affected_enemies:
		if is_instance_valid(enemy):
			var status_comp: StatusEffectComponent = enemy.get_node_or_null("StatusEffectComponent")
			if status_comp:
				status_comp.remove_hard_cc()
				status_comp.remove_slow()

	cyclone_finished.emit()

	# Hiệu ứng nổ gió tan biến mượt mà
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.finished.connect(queue_free)

func _draw() -> void:
	# Vẽ vùng lốc xoáy Bão Phong phong cách Pixel Art
	var color_outer := Color(0.25, 0.9, 0.8, 0.25)       # Vùng ảnh hưởng hút (96px)
	var color_damage := Color(0.3, 0.95, 0.85, 0.35)     # Vùng sát thương (64px)
	var color_blade := Color(0.85, 1.0, 0.95, 0.8)       # Các nhánh gió cuộn xoáy
	var color_core := Color(0.95, 1.0, 1.0, 0.95)        # Mắt bão trung tâm

	# 1. Vòng tròn bán kính hút 96px (nét đứt hoặc viền mờ)
	draw_arc(Vector2.ZERO, pull_radius, 0, TAU, 32, color_outer, 1.0)

	# 2. Vòng tròn bán kính sát thương 64px
	draw_arc(Vector2.ZERO, damage_radius, 0, TAU, 28, color_damage, 1.5)
	draw_circle(Vector2.ZERO, damage_radius, Color(0.2, 0.85, 0.75, 0.08))

	# 3. Các cánh xoáy cuộn gió phong cách Pixel Art quay tròn
	var arm_count := 4
	var arm_len := 72.0
	for i in range(arm_count):
		var base_angle := current_rotation + (float(i) * TAU / float(arm_count))
		var prev_pt := Vector2.ZERO
		var step_count := 8
		for s in range(1, step_count + 1):
			var t := float(s) / float(step_count)
			var angle := base_angle + t * 1.5
			var r := t * arm_len
			var pt := Vector2(cos(angle), sin(angle)) * r
			var line_alpha := (1.0 - t * 0.4) * 0.8
			var arm_col := Color(color_blade.r, color_blade.g, color_blade.b, line_alpha)
			draw_line(prev_pt, pt, arm_col, 2.0 - t * 0.8)
			prev_pt = pt

	# 4. Mắt bão trung tâm
	draw_circle(Vector2.ZERO, 6.0, color_core)
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
