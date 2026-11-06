extends Node2D

# class_name StatusEffectComponent

signal cc_state_changed(is_cc: bool)
signal slow_state_changed(is_slowed: bool, multiplier: float)

@export var is_boss: bool = false

# Trạng thái khống chế cứng (Stun / Vortex CC)
var is_hard_cc: bool = false
var cc_timer: float = 0.0

# Vận tốc hút từ lốc xoáy
var pull_velocity: Vector2 = Vector2.ZERO
var pull_decay_rate: float = 600.0

# Trạng thái làm chậm
var is_slowed: bool = false
var slow_timer: float = 0.0
var slow_percent: float = 0.0 # Giá trị từ 0.0 đến 1.0 (ví dụ 0.35 = chậm 35%)

# Tham chiếu tới chủ thể
var owner_body: CharacterBody2D = null

func _ready() -> void:
	if get_parent() is CharacterBody2D:
		owner_body = get_parent() as CharacterBody2D

func _physics_process(delta: float) -> void:
	# Cập nhật thời gian khống chế cứng
	if is_hard_cc:
		cc_timer -= delta
		if cc_timer <= 0.0:
			remove_hard_cc()

	# Cập nhật thời gian làm chậm
	if is_slowed:
		slow_timer -= delta
		if slow_timer <= 0.0:
			remove_slow()

	# Giảm dần vận tốc hút khi rời khỏi vùng gió
	if pull_velocity != Vector2.ZERO:
		pull_velocity = pull_velocity.move_toward(Vector2.ZERO, pull_decay_rate * delta)

	queue_redraw()

# Kiểm tra xem chủ thể có được phép hành động (di chuyển, tấn công, dùng chiêu) không
func can_act() -> bool:
	if is_boss:
		return true # Boss luôn được phép hành động và tấn công
	return not is_hard_cc

# Áp dụng khống chế cứng
func apply_hard_cc(duration: float) -> void:
	if is_boss:
		return # Boss miễn nhiễm hoàn toàn với khống chế cứng

	var was_cc := is_hard_cc
	is_hard_cc = true
	cc_timer = maxf(cc_timer, duration)

	if not was_cc:
		cc_state_changed.emit(true)

# Hủy khống chế cứng
func remove_hard_cc() -> void:
	if not is_hard_cc:
		return
	is_hard_cc = false
	cc_timer = 0.0
	cc_state_changed.emit(false)

# Áp dụng lực hút từ lốc xoáy (bảo đảm di chuyển bằng va chạm vật lý, không kéo xuyên tường)
func apply_pull(pull_vec: Vector2) -> void:
	if is_boss:
		return # Boss miễn nhiễm với lực hút
	pull_velocity = pull_vec

# Lấy vận tốc hút hiện tại để CharacterBody2D cộng vào velocity
func get_pull_velocity() -> Vector2:
	if is_boss:
		return Vector2.ZERO
	return pull_velocity

# Áp dụng làm chậm (không cộng dồn vô hạn)
func apply_slow(percent: float, duration: float) -> void:
	# percent tối đa 0.9 (giảm 90%), mặc định boss là 0.35 (35%)
	slow_percent = clampf(maxf(slow_percent, percent), 0.0, 0.9)
	slow_timer = maxf(slow_timer, duration)

	if not is_slowed:
		is_slowed = true
		slow_state_changed.emit(true, get_speed_multiplier())

# Hủy làm chậm và khôi phục tốc độ chính xác
func remove_slow() -> void:
	if not is_slowed:
		return
	is_slowed = false
	slow_timer = 0.0
	slow_percent = 0.0
	slow_state_changed.emit(false, 1.0)

# Hệ số tốc độ di chuyển hiện tại
func get_speed_multiplier() -> float:
	if is_slowed:
		return maxf(0.1, 1.0 - slow_percent)
	return 1.0

# Hiển thị hiệu ứng đồ họa nhẹ dạng pixel art quanh đầu quái
func _draw() -> void:
	if is_hard_cc:
		# Vòng xoáy gió nhỏ trên đầu khi bị khống chế
		var center := Vector2(0, -22)
		var t := Time.get_ticks_msec() / 150.0
		var r := 7.0
		var p1 := center + Vector2(cos(t), sin(t) * 0.4) * r
		var p2 := center + Vector2(cos(t + PI), sin(t + PI) * 0.4) * r
		draw_circle(p1, 2.0, Color(0.4, 0.95, 0.85, 0.85))
		draw_circle(p2, 1.8, Color(0.85, 1.0, 0.95, 0.85))
	elif is_slowed:
		# Hiệu ứng làm chậm: vệt gió cyan dưới chân
		var foot_y := 6.0
		var t := Time.get_ticks_msec() / 200.0
		var offset_x := sin(t) * 4.0
		draw_line(Vector2(-8 + offset_x, foot_y), Vector2(8 + offset_x, foot_y), Color(0.3, 0.9, 0.8, 0.6), 1.5)
