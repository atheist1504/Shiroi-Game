extends Node2D

signal npc_status_changed(status_text: String)

const NPC_SCENE: PackedScene = preload("res://scenes/autonomous_test_npc.tscn")
const CELL_SIZE: int = 16
const NPC_RADIUS: float = 6.0
const DEFAULT_NPC_ID: StringName = &"hope_valley_test_npc_001"
const DEFAULT_SPAWN_POSITION: Vector2 = Vector2(704, 560)
const MAX_STUCK_REPATHS: int = 3
const VALID_STATES: Array[String] = ["IDLE", "MOVING", "WORKING", "RESTING", "DELIVERING"]
const STATE_IDLE: int = 0
const STATE_MOVING: int = 1

var _npc: Node = null
var _astar: AStarGrid2D = null
var _grid_region: Rect2i = Rect2i()
var _base_rect: Rect2 = Rect2()
var _map_size: Vector2 = Vector2.ZERO
var _repath_attempts: int = 0
var _initializing: bool = false
var _task_kind: String = ""
var _task_node: Node2D = null
var _task_building_id: StringName = &""
var _work_remaining: float = 0.0
var _idle_retry: float = 0.0
const WORK_DURATION: float = 2.0
# 20px tới điểm tương tác + tối đa ~11px lệch do đường đi được làm tròn về tâm ô lưới.
const INTERACTION_RANGE: float = 32.0
const BUILDING_INTERACTION_GAP: float = 16.0
const RETRY_DELAY: float = 2.0

func _process(delta: float) -> void:
	if not is_instance_valid(_npc) or get_tree().paused:
		return
	var state := str(_npc.call("get_state_name"))
	if state == "MOVING" and _task_kind == "gather":
		if not is_instance_valid(_task_node) or bool(_task_node.get("is_harvested")) or not _task_node.call("is_available_for_npc", StringName(str(_npc.get("npc_id")))):
			_cancel_task("Điểm tài nguyên đã cạn; đang tìm điểm khác.")
			return
	if state == "MOVING" and _task_kind == "deliver" and not _find_building(_task_building_id):
		_cancel_task("Kho không còn khả dụng.")
		return
	if state == "WORKING":
		_work_remaining -= delta
		if _work_remaining <= 0.0:
			_complete_gather()
		return
	if state == "IDLE" and not _task_kind.is_empty():
		if _task_kind == "gather" and is_instance_valid(_task_node):
			if (_npc as Node2D).global_position.distance_to(_task_node.global_position) <= INTERACTION_RANGE:
				_work_remaining = WORK_DURATION
				_npc.call("set_working")
				return
			_cancel_task("Không thể tiếp cận điểm tài nguyên.")
		elif _task_kind == "deliver":
			var building := _find_building(_task_building_id)
			if building and _distance_to_building((_npc as Node2D).global_position, building) <= INTERACTION_RANGE:
				_npc.call("set_delivering")
				_deliver_cargo(building)
				return
			_cancel_task("Không thể tới kho chứa.")
	elif state == "IDLE":
		_idle_retry -= delta
		if _idle_retry <= 0.0:
			if int(_npc.call("cargo_used")) > 0:
				if not _assign_delivery():
					_idle_retry = RETRY_DELAY
			else:
				if not _assign_gather():
					_idle_retry = RETRY_DELAY

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("building_placed"):
		event_bus.building_placed.connect(_on_building_placed)
	call_deferred("_initialize_navigation")

func _initialize_navigation() -> void:
	if _initializing:
		return
	_initializing = true
	await get_tree().physics_frame
	refresh_navigation()
	spawn_test_npc()
	_initializing = false

func refresh_navigation() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var floor := scene.get_node_or_null("Environment/FloorBackground") as ColorRect
	var base_plot := scene.get_node_or_null("Environment/HopeValleyBasePlot") as Node2D
	if not floor or not base_plot:
		push_warning("NPC pathfinding: thiếu FloorBackground hoặc HopeValleyBasePlot.")
		return
	_map_size = floor.size
	var plot_size: Vector2 = Vector2(base_plot.get("plot_size"))
	_base_rect = Rect2(base_plot.global_position, plot_size)
	_grid_region = Rect2i(Vector2i.ZERO, Vector2i(ceili(_map_size.x / CELL_SIZE), ceili(_map_size.y / CELL_SIZE)))
	var grid := AStarGrid2D.new()
	grid.region = _grid_region
	grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	grid.offset = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var physics := get_viewport().world_2d.direct_space_state
	var probe := CircleShape2D.new()
	probe.radius = NPC_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var safe_base := _base_rect.grow(-NPC_RADIUS - 1.0)
	for y in range(_grid_region.position.y, _grid_region.end.y):
		for x in range(_grid_region.position.x, _grid_region.end.x):
			var cell := Vector2i(x, y)
			var world_position := grid.get_point_position(cell)
			if not safe_base.has_point(world_position):
				grid.set_point_solid(cell, true)
				continue
			query.transform = Transform2D(0.0, world_position)
			if not physics.intersect_shape(query, 1).is_empty():
				grid.set_point_solid(cell, true)
	_astar = grid
	_repath_attempts = 0
	if is_instance_valid(_npc) and str(_npc.call("get_state_name")) == "MOVING" and bool(_npc.get("has_target")):
		request_destination(_npc.get("current_target"), true)

func spawn_test_npc() -> Node:
	if is_instance_valid(_npc):
		return _npc
	for candidate in get_tree().get_nodes_in_group("autonomous_test_npcs"):
		if is_instance_valid(candidate) and StringName(str(candidate.get("npc_id"))) == DEFAULT_NPC_ID:
			_npc = candidate as Node
			_connect_npc(_npc)
			return _npc
	if _astar == null:
		refresh_navigation()
	var scene := get_tree().current_scene
	if not scene:
		return null
	_npc = NPC_SCENE.instantiate() as Node
	if not _npc:
		return null
	_npc.set("npc_id", DEFAULT_NPC_ID)
	var spawn_cell := _find_nearest_walkable_cell(_world_to_cell(DEFAULT_SPAWN_POSITION))
	if spawn_cell == Vector2i(-1, -1):
		_npc.free()
		_npc = null
		return null
	(_npc as Node2D).global_position = _cell_to_world(spawn_cell)
	scene.add_child(_npc)
	_connect_npc(_npc)
	_emit_status()
	return _npc

func request_destination(destination: Vector2, is_repath: bool = false) -> bool:
	if not is_instance_valid(_npc):
		if not spawn_test_npc():
			return false
	if _astar == null:
		refresh_navigation()
	if _astar == null:
		return false
	var target_cell := _world_to_cell(destination)
	if not _astar.is_in_boundsv(target_cell) or _astar.is_point_solid(target_cell):
		_npc.call("stop_for_path_failure", destination, "Điểm đích bị chặn hoặc nằm ngoài căn cứ.")
		_notify_no_path()
		_emit_status()
		return false
	var npc_2d := _npc as Node2D
	var start_cell := _find_nearest_walkable_cell(_world_to_cell(npc_2d.global_position))
	if start_cell == Vector2i(-1, -1):
		_npc.call("stop_for_path_failure", destination, "NPC không có ô đứng an toàn.")
		_emit_status()
		return false
	var cells: Array[Vector2i] = _astar.get_id_path(start_cell, target_cell)
	if cells.is_empty():
		_npc.call("stop_for_path_failure", destination, "Không tìm thấy đường đến điểm đích.")
		_notify_no_path()
		_emit_status()
		return false
	var path := PackedVector2Array()
	for cell in cells:
		path.append(_cell_to_world(cell))
	_npc.call("set_path", path, _cell_to_world(target_cell))
	if not is_repath:
		_repath_attempts = 0
	_emit_status()
	return true

func _get_path_to(destination: Vector2, from_position: Vector2 = Vector2.INF) -> PackedVector2Array:
	if _astar == null:
		return PackedVector2Array()
	if not is_finite(destination.x) or not is_finite(destination.y):
		return PackedVector2Array()
	var target_cell := _world_to_cell(destination)
	if not _astar.is_in_boundsv(target_cell) or _astar.is_point_solid(target_cell):
		return PackedVector2Array()
	var origin := (_npc as Node2D).global_position if from_position == Vector2.INF else from_position
	var start_cell := _find_nearest_walkable_cell(_world_to_cell(origin))
	if start_cell == Vector2i(-1, -1):
		return PackedVector2Array()
	var cells := _astar.get_id_path(start_cell, target_cell)
	var result := PackedVector2Array()
	for cell in cells:
		result.append(_cell_to_world(cell))
	return result

func _assign_gather() -> bool:
	if _astar == null:
		refresh_navigation()
	var best: Node2D = null
	var best_path := PackedVector2Array()
	var best_length := INF
	for candidate in get_tree().get_nodes_in_group("resource_nodes"):
		var node := candidate as Node2D
		if not node or not _base_rect.has_point(node.global_position) or bool(node.get("is_harvested")):
			continue
		if not node.has_method("is_available_for_npc") or not node.call("is_available_for_npc", StringName(str(_npc.get("npc_id")))):
			continue
		var item_id := StringName(str(node.get("resource_id")))
		if not [&"wood", &"stone", &"herb"].has(item_id):
			continue
		var yield_count := int(node.get("yield_amount"))
		if int(_npc.call("cargo_used")) + yield_count > int(_npc.get("cargo_capacity")):
			continue
		var destination := _nearest_interaction_point(node.global_position)
		var path := _get_path_to(destination)
		if path.is_empty():
			continue
		var length := _path_length(path, (_npc as Node2D).global_position)
		if length < best_length:
			best = node
			best_path = path
			best_length = length
	if not best or not best.call("reserve_for_npc", StringName(str(_npc.get("npc_id")))):
		return false
	_task_node = best
	_task_kind = "gather"
	var target := best_path[best_path.size() - 1]
	_npc.call("set_path", best_path, target)
	_emit_status()
	return true

func _complete_gather() -> void:
	if not is_instance_valid(_task_node):
		_cancel_task("Điểm tài nguyên không còn tồn tại.")
		return
	var item_id := StringName(str(_task_node.get("resource_id")))
	var amount := int(_task_node.call("harvest_for_npc", StringName(str(_npc.get("npc_id"))))) if _task_node.has_method("harvest_for_npc") else 0
	if amount > 0 and bool(_npc.call("add_cargo", item_id, amount)):
		_task_node = null
		_task_kind = ""
		_npc.call("set_idle")
		if int(_npc.call("cargo_used")) >= int(_npc.get("cargo_capacity")):
			_assign_delivery()
	else:
		if is_instance_valid(_task_node) and _task_node.has_method("release_npc_reservation"):
			_task_node.call("release_npc_reservation", StringName(str(_npc.get("npc_id"))))
		_task_node = null
		_task_kind = ""
		_npc.call("set_idle")
	_idle_retry = 0.4
	_emit_status()

func _assign_delivery() -> bool:
	var base_manager := get_node_or_null("/root/BaseManager")
	if not base_manager:
		return false
	var best_building: Node2D = null
	var best_path := PackedVector2Array()
	var best_length := INF
	for candidate in get_tree().get_nodes_in_group("placed_buildings"):
		var building := candidate as Node2D
		if not building or StringName(str(building.get("building_type_id"))) != &"storage":
			continue
		var building_id := StringName(str(building.get("instance_id")))
		var interaction_point := _nearest_building_interaction_point(building)
		if not is_finite(interaction_point.x):
			continue
		var path := _get_path_to(interaction_point)
		if path.is_empty():
			continue
		if not bool(base_manager.call("can_deposit_npc_cargo", building_id, _npc.get("cargo"))):
			continue
		var length := _path_length(path, (_npc as Node2D).global_position)
		if length < best_length:
			best_building = building
			best_path = path
			best_length = length
	if not best_building:
		return false
	_task_building_id = StringName(str(best_building.get("instance_id")))
	_task_kind = "deliver"
	_npc.call("set_path", best_path, best_path[best_path.size() - 1])
	return true

func _deliver_cargo(building: Node2D) -> void:
	var base_manager := get_node_or_null("/root/BaseManager")
	if not base_manager:
		_npc.call("set_idle")
		_task_kind = ""
		return
	var cargo: Dictionary = (_npc.get("cargo") as Dictionary).duplicate(true)
	if bool(base_manager.call("deposit_npc_cargo", _task_building_id, cargo)):
		for raw_item_id in cargo:
			_npc.call("remove_cargo", StringName(str(raw_item_id)), int(cargo[raw_item_id]))
	_task_kind = ""
	_task_building_id = &""
	_npc.call("set_idle")
	_idle_retry = RETRY_DELAY if int(_npc.call("cargo_used")) > 0 else 0.5
	_emit_status()

func _cancel_task(reason: String) -> void:
	if is_instance_valid(_task_node) and _task_node.has_method("release_npc_reservation"):
		_task_node.call("release_npc_reservation", StringName(str(_npc.get("npc_id"))))
	_task_node = null
	_task_kind = ""
	_task_building_id = &""
	_npc.call("set_idle")
	_npc.set("status_message", reason)
	_idle_retry = 0.5
	_emit_status()

func _nearest_interaction_point(center: Vector2) -> Vector2:
	return _closest_reachable_point([center + Vector2(20, 0), center + Vector2(-20, 0), center + Vector2(0, 20), center + Vector2(0, -20)])

# Công trình có va chạm theo footprint, nên điểm đứng phải nằm ngoài cả bốn cạnh.
func _nearest_building_interaction_point(building: Node2D) -> Vector2:
	var center := building.global_position
	var offset: Vector2 = (building.call("get_footprint") as Vector2) * 0.5 + Vector2(BUILDING_INTERACTION_GAP, BUILDING_INTERACTION_GAP)
	return _closest_reachable_point([center + Vector2(offset.x, 0), center - Vector2(offset.x, 0), center + Vector2(0, offset.y), center - Vector2(0, offset.y)])

func _closest_reachable_point(candidates: Array[Vector2]) -> Vector2:
	var best := Vector2.INF
	var best_distance := INF
	for candidate in candidates:
		var path := _get_path_to(candidate)
		if path.is_empty():
			continue
		var length := _path_length(path, (_npc as Node2D).global_position)
		if length < best_distance:
			best = candidate
			best_distance = length
	return best

func _path_length(path: PackedVector2Array, origin: Vector2) -> float:
	var total := 0.0
	var previous := origin
	for point in path:
		total += previous.distance_to(point)
		previous = point
	return total

func _find_building(building_id: StringName) -> Node2D:
	for candidate in get_tree().get_nodes_in_group("placed_buildings"):
		if StringName(str(candidate.get("instance_id"))) == building_id:
			return candidate as Node2D
	return null

func _distance_to_building(position: Vector2, building: Node2D) -> float:
	var half: Vector2 = (building.call("get_footprint") as Vector2) * 0.5
	var closest := position.clamp(building.global_position - half, building.global_position + half)
	return position.distance_to(closest)

func get_debug_status() -> String:
	if not is_instance_valid(_npc):
		return "NPC: chưa được tạo."
	var has_target := bool(_npc.get("has_target"))
	var target: Vector2 = _npc.get("current_target")
	var target_text := "không có" if not has_target else "%.0f, %.0f" % [target.x, target.y]
	return "ID: %s | Trạng thái: %s | Đích: %s\n%s" % [str(_npc.get("npc_id")), str(_npc.call("get_state_name")), target_text, str(_npc.get("status_message"))]

func get_npc() -> Node:
	return _npc

func to_dict() -> Dictionary:
	var npcs: Array[Dictionary] = []
	if is_instance_valid(_npc):
		npcs.append(_npc.call("to_save_dict"))
	return {"schema_version": 1, "npcs": npcs}

func validate_save_data(data: Variant) -> bool:
	if _base_rect.size == Vector2.ZERO:
		refresh_navigation()
	if not data is Dictionary or int(data.get("schema_version", 0)) > 1:
		return false
	var entries: Variant = data.get("npcs", [])
	if not entries is Array or entries.size() > 1:
		return false
	var seen_ids: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary:
			return false
		var id := str(entry.get("npc_id", ""))
		if id.is_empty() or seen_ids.has(id) or not VALID_STATES.has(str(entry.get("state", ""))):
			return false
		seen_ids[id] = true
		for key in ["x", "y", "target_x", "target_y", "direction_x", "direction_y"]:
			if not is_finite(float(entry.get(key, 0.0))):
				return false
		var cargo: Variant = entry.get("cargo", {})
		if not cargo is Dictionary:
			return false
		var cargo_total := 0
		var inventory := get_node_or_null("/root/InventoryManager")
		for item_key in cargo:
			var amount := int(cargo[item_key])
			if amount <= 0 or not inventory or not inventory.call("get_item_def", StringName(str(item_key))):
				return false
			cargo_total += amount
		if cargo_total > maxi(1, int(entry.get("cargo_capacity", 10))):
			return false
		var position := Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
		if not _base_rect.has_point(position):
			return false
	return true

func load_from_dict(data: Dictionary) -> bool:
	if not validate_save_data(data):
		return false
	_remove_current_npc()
	# BaseManager restores its buildings immediately before this call.
	# Re-query the physics world so old obstacle data cannot leak across loads.
	refresh_navigation()
	var entries: Array = data.get("npcs", [])
	if entries.is_empty():
		_emit_status()
		return true
	if entries.size() > 1:
		return false
	if _astar == null:
		refresh_navigation()
	var scene := get_tree().current_scene
	if not scene:
		return false
	_npc = NPC_SCENE.instantiate() as Node
	if not _npc:
		return false
	_npc.call("restore_saved_state", entries[0])
	scene.add_child(_npc)
	_connect_npc(_npc)
	var restored_state := int(_npc.get("current_state"))
	var has_target := bool(_npc.get("has_target"))
	if restored_state == STATE_MOVING and has_target:
		var destination: Vector2 = _npc.get("current_target")
		if not request_destination(destination, true):
			_npc.call("stop_for_path_failure", destination, "Không tìm thấy đường sau khi tải; NPC đã dừng an toàn.")
	elif restored_state != STATE_IDLE:
		_npc.set("velocity", Vector2.ZERO)
	_emit_status()
	return true

func clear_npcs() -> void:
	_remove_current_npc()
	_emit_status()

func _find_nearest_walkable_cell(origin: Vector2i) -> Vector2i:
	if _astar == null:
		return Vector2i(-1, -1)
	for radius in range(0, 6):
		var best := Vector2i(-1, -1)
		var best_distance := 2147483647
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var cell := Vector2i(x, y)
				if not _astar.is_in_boundsv(cell) or _astar.is_point_solid(cell):
					continue
				var distance := origin.distance_squared_to(cell)
				if distance < best_distance:
					best = cell
					best_distance = distance
		if best != Vector2i(-1, -1):
			return best
	return Vector2i(-1, -1)

func _world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL_SIZE) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)

func _on_building_placed(_instance_id: StringName, _building_type_id: StringName, _base_id: StringName) -> void:
	refresh_navigation()

func _on_npc_repath_requested(npc_id: StringName, destination: Vector2) -> void:
	if not is_instance_valid(_npc) or npc_id != StringName(str(_npc.get("npc_id"))):
		return
	_repath_attempts += 1
	if _repath_attempts > MAX_STUCK_REPATHS:
		_npc.call("stop_for_path_failure", destination, "Bị kẹt; NPC đã dừng an toàn.")
		_emit_status()
		return
	request_destination(destination, true)

func _connect_npc(npc: Node) -> void:
	if not npc:
		return
	var repath_callback := Callable(self, "_on_npc_repath_requested")
	var state_callback := Callable(self, "_on_npc_state_changed")
	if not npc.is_connected("repath_requested", repath_callback):
		npc.connect("repath_requested", repath_callback)
	if not npc.is_connected("state_changed", state_callback):
		npc.connect("state_changed", state_callback)

func _on_npc_state_changed(_npc_id: StringName, _state_name: String, _target: Vector2, _status: String) -> void:
	_emit_status()

func _emit_status() -> void:
	npc_status_changed.emit(get_debug_status())

func _notify_no_path() -> void:
	var notifications := get_node_or_null("/root/NotificationManager")
	if notifications and notifications.has_method("show_warning"):
		notifications.call("show_warning", "NPC thử nghiệm không tìm thấy đường và đã dừng.")

func _remove_current_npc() -> void:
	if is_instance_valid(_npc):
		if _npc.is_inside_tree() and _npc.get_parent():
			_npc.get_parent().remove_child(_npc)
		_npc.free()
	_npc = null
	_repath_attempts = 0
