extends SceneTree

const TEST_SLOT: int = 96
const NPC_ID: StringName = &"hope_valley_test_npc_001"

var _passed: int = 0
var _total: int = 0
var _slot_path: String = ""
var _backup_path: String = ""
var _backed_up_slot: bool = false
var _load_gameplay_event_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_prepare_test_slot()
	var packed := load("res://main.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var npc_manager := scene.get_node("NPCManager")
	var npc: Node = npc_manager.call("get_npc")
	_check(npc != null, "Hope Valley creates the test NPC on startup")
	if not npc:
		_finish()
		return
	_check(StringName(str(npc.get("npc_id"))) == NPC_ID and _count_npcs() == 1, "NPC has a stable unique ID and exists only once")
	_check(str(npc.call("get_state_name")) == "IDLE", "New NPC starts in IDLE")
	_check(int(npc.get("collision_mask")) == 1 and int(npc.get("collision_layer")) == 8, "NPC collision uses building/wall layer without changing Player collision")
	_check(scene.has_node("DebugPanel/PanelContainer/Margin/VBox/TabContainer/NPC thử nghiệm"), "F3 includes the NPC test tab")

	# A direct route demonstrates IDLE -> MOVING -> IDLE.
	npc.set("move_speed", 100.0)
	var first_destination := Vector2(1168, 560)
	_check(bool(npc_manager.call("request_destination", first_destination)), "A* accepts a valid destination inside the base")
	_check(str(npc.call("get_state_name")) == "MOVING", "Requesting a route changes IDLE to MOVING")
	await _wait_for_arrival(npc, 360)
	_check(str(npc.call("get_state_name")) == "IDLE" and not bool(npc.get("has_target")), "NPC returns to IDLE at its destination")
	_check((npc as Node2D).global_position.distance_to(first_destination) <= 12.0, "NPC reaches the selected point")

	# A newly loaded House blocks the direct route. BaseManager load does not emit
	# gameplay placement events, so refresh is explicitly invoked just as save load does.
	(npc as Node2D).global_position = Vector2(720, 560)
	npc.call("set_idle")
	_check(bool(npc_manager.call("request_destination", first_destination)), "NPC begins a second route before a building is added")
	var base_manager := root.get_node("BaseManager")
	var house_data := {
		"schema_version": 2,
		"buildings": [{"instance_id": "npc_path_house", "building_type_id": "house", "base_id": "hope_valley_base", "grid_x": 59, "grid_y": 35}],
		"next_instance_number": 2
	}
	_check(bool(base_manager.call("load_from_dict", house_data)), "A House fixture loads successfully")
	await physics_frame
	npc_manager.call("refresh_navigation")
	await process_frame
	var detour: PackedVector2Array = npc.call("get_path_points")
	var expanded_house := Rect2(Vector2(912, 536), Vector2(64, 48)).grow(7.0)
	var path_avoids_house := not detour.is_empty()
	for point in detour:
		if expanded_house.has_point(point):
			path_avoids_house = false
	_check(path_avoids_house, "A* replans after construction and routes around the House")
	await _wait_for_arrival(npc, 420)
	_check(str(npc.call("get_state_name")) == "IDLE", "Replanned route finishes without remaining stuck")

	# A solid wall across the plot makes the east side unreachable.
	base_manager.call("load_from_dict", {"schema_version": 2, "buildings": [], "next_instance_number": 1})
	(npc as Node2D).global_position = Vector2(720, 560)
	npc.call("set_idle")
	var wall := StaticBody2D.new()
	wall.name = "NPCPathTestWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape2D.new()
	var wall_rectangle := RectangleShape2D.new()
	wall_rectangle.size = Vector2(16, 176)
	wall_shape.shape = wall_rectangle
	wall.add_child(wall_shape)
	wall.position = Vector2(944, 600)
	scene.get_node("Environment").add_child(wall)
	await physics_frame
	npc_manager.call("refresh_navigation")
	_check(not bool(npc_manager.call("request_destination", first_destination)), "A* rejects a target when no path exists")
	_check(str(npc.call("get_state_name")) == "IDLE" and str(npc.get("status_message")).contains("Không tìm thấy đường"), "No-path case stops safely and reports the reason")
	wall.queue_free()
	await physics_frame
	npc_manager.call("refresh_navigation")

	# Save/Load includes NPC state and does not duplicate it. Calls the same public
	# SaveManager operations used by F5/F9, without injecting gameplay rewards/events.
	(npc as Node2D).global_position = Vector2(720, 560)
	npc.call("set_idle")
	_check(bool(npc_manager.call("request_destination", first_destination)), "NPC is moving before save")
	var saved_position: Vector2 = (npc as Node2D).global_position
	var save_manager := root.get_node("SaveManager")
	var event_bus := root.get_node("EventBus")
	event_bus.building_placed.connect(_on_building_placed)
	event_bus.quest_completed.connect(_on_quest_completed)
	_check(await _save(save_manager), "SaveManager saves the moving NPC")
	(npc as Node2D).global_position = Vector2(720, 648)
	npc.call("set_idle")
	_load_gameplay_event_count = 0
	_check(await _load(save_manager), "SaveManager restores the NPC snapshot")
	npc = npc_manager.call("get_npc")
	_check(npc != null and StringName(str(npc.get("npc_id"))) == NPC_ID and _count_npcs() == 1, "Load restores the same NPC ID exactly once")
	var loaded_target: Vector2 = npc.get("current_target")
	_check(str(npc.call("get_state_name")) == "MOVING" and loaded_target.distance_to(first_destination) <= 12.0, "Load replans the saved MOVING target")
	_check((npc as Node2D).global_position.distance_to(saved_position) <= 0.1, "Load restores the saved NPC position before it advances")
	_check(int(base_manager.call("get_building_count")) == 0, "NPC save/load leaves saved building state consistent")
	_check(_load_gameplay_event_count == 0, "NPC restoration emits no building or quest reward event")
	await process_frame
	_check(await _load(save_manager), "Repeated load remains valid")
	await process_frame
	_check(_count_npcs() == 1, "Repeated load does not duplicate NPCs")

	# Simulate a legacy file by removing only the optional NPC field.
	var save_dict: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path))
	var legacy_ok := save_dict is Dictionary
	if legacy_ok:
		save_dict.erase("npc_state")
		var file := FileAccess.open(_slot_path, FileAccess.WRITE)
		legacy_ok = file != null
		if file:
			file.store_string(JSON.stringify(save_dict))
			file.close()
	_check(legacy_ok, "Create a legacy-compatible snapshot without npc_state")
	if legacy_ok:
		_check(await _load(save_manager), "A legacy save without NPC data still loads")
		await process_frame
		_check(_count_npcs() == 0, "Legacy load does not keep or duplicate an unsaved NPC")
		npc = npc_manager.call("spawn_test_npc")
		_check(npc != null and _count_npcs() == 1, "Debug spawn recreates one NPC after legacy load")

	_finish()

func _wait_for_arrival(npc: Node, max_frames: int) -> void:
	for _frame in max_frames:
		if str(npc.call("get_state_name")) == "IDLE":
			return
		await physics_frame

func _count_npcs() -> int:
	return get_nodes_in_group("autonomous_test_npcs").size()

func _save(save_manager: Node) -> bool:
	await create_timer(0.45).timeout
	return bool(save_manager.call("save_game", TEST_SLOT))

func _load(save_manager: Node) -> bool:
	await create_timer(0.45).timeout
	return bool(save_manager.call("load_game", TEST_SLOT))

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _on_building_placed(_instance_id: StringName, _type_id: StringName, _base_id: StringName) -> void:
	_load_gameplay_event_count += 1

func _on_quest_completed(_quest_id: StringName) -> void:
	_load_gameplay_event_count += 1

func _prepare_test_slot() -> void:
	var path := "user://saves/slot_%02d.json" % TEST_SLOT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	_slot_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(_slot_path):
		_backup_path = _slot_path + ".step21_test_%d.bak" % Time.get_ticks_usec()
		if DirAccess.rename_absolute(_slot_path, _backup_path) == OK:
			_backed_up_slot = true

func _finish() -> void:
	print("Step 21.1+21.2 checks: %d / %d passed" % [_passed, _total])
	_restore_test_slot()
	quit(0 if _passed == _total else 1)

func _restore_test_slot() -> void:
	if not _slot_path.is_empty() and FileAccess.file_exists(_slot_path):
		DirAccess.remove_absolute(_slot_path)
	if _backed_up_slot and FileAccess.file_exists(_backup_path):
		DirAccess.rename_absolute(_backup_path, _slot_path)
