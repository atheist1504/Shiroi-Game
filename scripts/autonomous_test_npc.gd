extends CharacterBody2D

signal state_changed(npc_id: StringName, state_name: String, target: Vector2, status: String)
signal repath_requested(npc_id: StringName, target: Vector2)

enum State { IDLE, MOVING, WORKING, RESTING, DELIVERING }

const STATE_LABELS: Dictionary = {
	State.IDLE: "IDLE",
	State.MOVING: "MOVING",
	State.WORKING: "WORKING",
	State.RESTING: "RESTING",
	State.DELIVERING: "DELIVERING"
}

@export var npc_id: StringName = &"hope_valley_test_npc_001"
@export var move_speed: float = 48.0

var current_state: State = State.IDLE
var current_target: Vector2 = Vector2.ZERO
var has_target: bool = false
var movement_direction: Vector2 = Vector2.DOWN
var status_message: String = "Đang chờ lệnh."
@export var cargo_capacity: int = 10
var cargo: Dictionary = {}
var tunic_color: Color = Color("4b8d79")
var display_name: String = ""

var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _stuck_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("autonomous_test_npcs")
	collision_layer = 8
	collision_mask = 1

func set_path(path_points: PackedVector2Array, destination: Vector2) -> void:
	current_target = destination
	has_target = true
	status_message = "Đang tìm đường."
	_path = path_points
	_path_index = 0
	_stuck_time = 0.0
	if _path.is_empty():
		stop_for_path_failure(destination, "Không tìm thấy đường.")
		return
	if global_position.distance_to(_path[0]) <= 8.0:
		_path_index = 1
	if _path_index >= _path.size():
		_arrive()
		return
	_set_state(State.MOVING, "Đang di chuyển đến điểm đích.")

func stop_for_path_failure(destination: Vector2, reason: String = "Không tìm thấy đường.") -> void:
	current_target = destination
	has_target = true
	_path = PackedVector2Array()
	_path_index = 0
	velocity = Vector2.ZERO
	_set_state(State.IDLE, reason)

func set_idle() -> void:
	has_target = false
	_path = PackedVector2Array()
	_path_index = 0
	velocity = Vector2.ZERO
	_set_state(State.IDLE, "Đang chờ lệnh.")

func set_working() -> void:
	velocity = Vector2.ZERO
	_set_state(State.WORKING, "Đang thu thập tài nguyên.")

func set_delivering() -> void:
	velocity = Vector2.ZERO
	_set_state(State.DELIVERING, "Đang giao tài nguyên vào kho.")

func cargo_used() -> int:
	var total := 0
	for amount in cargo.values():
		total += int(amount)
	return total

func add_cargo(item_id: StringName, amount: int) -> bool:
	if item_id == StringName() or amount <= 0 or cargo_used() + amount > maxi(1, cargo_capacity):
		return false
	cargo[item_id] = int(cargo.get(item_id, 0)) + amount
	return true

func remove_cargo(item_id: StringName, amount: int) -> bool:
	var held := int(cargo.get(item_id, 0))
	if amount <= 0 or held < amount:
		return false
	if held == amount:
		cargo.erase(item_id)
	else:
		cargo[item_id] = held - amount
	return true

func set_resting() -> void:
	velocity = Vector2.ZERO
	_set_state(State.RESTING, "Trạng thái dự phòng.")

func get_state_name() -> String:
	return str(STATE_LABELS.get(current_state, "IDLE"))

func get_path_points() -> PackedVector2Array:
	return _path.duplicate()

func to_save_dict() -> Dictionary:
	return {
		"npc_id": str(npc_id),
		"x": global_position.x,
		"y": global_position.y,
		"state": get_state_name(),
		"has_target": has_target,
		"target_x": current_target.x,
		"target_y": current_target.y,
		"direction_x": movement_direction.x,
		"direction_y": movement_direction.y,
		"cargo": cargo.duplicate(true),
		"cargo_capacity": cargo_capacity
	}

func restore_saved_state(data: Dictionary) -> void:
	npc_id = StringName(str(data.get("npc_id", npc_id)))
	cargo_capacity = maxi(1, int(data.get("cargo_capacity", cargo_capacity)))
	cargo = data.get("cargo", {}).duplicate(true) if data.get("cargo", {}) is Dictionary else {}
	global_position = Vector2(float(data.get("x", global_position.x)), float(data.get("y", global_position.y)))
	current_target = Vector2(float(data.get("target_x", global_position.x)), float(data.get("target_y", global_position.y)))
	has_target = bool(data.get("has_target", false))
	var restored_direction := Vector2(float(data.get("direction_x", 0.0)), float(data.get("direction_y", 1.0)))
	if restored_direction.length_squared() > 0.001:
		movement_direction = restored_direction.normalized()
	velocity = Vector2.ZERO
	_path = PackedVector2Array()
	_path_index = 0
	_stuck_time = 0.0
	var saved_state := str(data.get("state", "IDLE"))
	match saved_state:
		"MOVING": current_state = State.MOVING
		"WORKING": current_state = State.WORKING
		"RESTING": current_state = State.RESTING
		"DELIVERING": current_state = State.IDLE
		_: current_state = State.IDLE
	status_message = "Đang chờ lệnh." if current_state == State.IDLE else "Đã khôi phục trạng thái."
	state_changed.emit(npc_id, get_state_name(), current_target, status_message)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if current_state != State.MOVING:
		velocity = Vector2.ZERO
		return
	if _path_index >= _path.size():
		_arrive()
		return
	var waypoint := _path[_path_index]
	if global_position.distance_to(waypoint) <= 2.5:
		_path_index += 1
		if _path_index >= _path.size():
			_arrive()
			return
		waypoint = _path[_path_index]
	var previous_position := global_position
	var direction := (waypoint - global_position).normalized()
	if direction.length_squared() > 0.001:
		movement_direction = direction
	velocity = direction * move_speed
	move_and_slide()
	if previous_position.distance_to(global_position) < 0.15:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time >= 0.4:
		_stuck_time = 0.0
		repath_requested.emit(npc_id, current_target)
	queue_redraw()

func _arrive() -> void:
	global_position = _path[_path.size() - 1] if not _path.is_empty() else global_position
	_path = PackedVector2Array()
	_path_index = 0
	velocity = Vector2.ZERO
	has_target = false
	_set_state(State.IDLE, "Đã đến nơi.")

func _set_state(next_state: State, message: String) -> void:
	var changed := current_state != next_state or status_message != message
	current_state = next_state
	status_message = message
	if changed:
		state_changed.emit(npc_id, get_state_name(), current_target, status_message)
	queue_redraw()

func _draw() -> void:
	# Placeholder pixel-art silhouette, kept independent of the player's assets.
	draw_rect(Rect2(-5, -8, 10, 5), Color("e9c49b"), true)
	draw_rect(Rect2(-6, -3, 12, 8), tunic_color, true)
	if not display_name.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-24, -12), display_name, HORIZONTAL_ALIGNMENT_CENTER, 48, 7, Color(1.0, 1.0, 1.0, 0.85))
	draw_rect(Rect2(-5, 5, 4, 4), Color("514a68"), true)
	draw_rect(Rect2(1, 5, 4, 4), Color("514a68"), true)
	draw_rect(Rect2(-3, -6, 2, 1), Color("252b38"), true)
	if current_state == State.MOVING:
		draw_line(Vector2.ZERO, movement_direction * 10.0, Color("f3d66f"), 1.0)
