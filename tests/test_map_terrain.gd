extends SceneTree

# Bản đồ tile: dữ liệu nền, va chạm, lối đi nam bắc, cổng khóa theo nhiệm vụ, save/load.
const TEST_SLOT := 92

var _passed := 0
var _total := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame
	var terrain: Node = scene.get_node("Environment/Terrain")
	var navigation: Node = scene.get_node("NPCManager")
	var gate: Node = scene.get_node("Environment/RuinsGate")
	var world := root.get_node("WorldState")
	var save_manager := root.get_node("SaveManager")
	var player: CharacterBody2D = scene.get_node("Player")
	for node in get_nodes_in_group("enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	navigation.call("refresh_navigation")
	var layer: TileMapLayer = terrain.get_node("Ground")

	# Nền.
	_check(layer.get_used_cells().size() == 160 * 90, "Tile phủ kín bản đồ 160x90 ô")
	_check(terrain.get_ground_at(Vector2(900, 600)) == terrain.Ground.DIRT, "Căn cứ nền đất")
	_check(terrain.get_ground_at(Vector2(1500, 200)) == terrain.Ground.FOREST, "Khu Rừng nền rừng")
	_check(terrain.get_ground_at(Vector2(2200, 500)) == terrain.Ground.GOLD, "Mỏ Vàng nền vàng")
	_check(terrain.get_ground_at(Vector2(400, 900)) == terrain.Ground.MUD, "Đầm Lầy nền bùn")
	_check(terrain.get_ground_at(Vector2(1200, 900)) == terrain.Ground.SAND, "Đồi Cát nền cát")
	_check(terrain.get_ground_at(Vector2(2100, 900)) == terrain.Ground.RUIN, "Tàn Tích nền đá cổ")
	_check(terrain.get_ground_at(Vector2(-5, 10)) == -1, "Ngoài bản đồ không có nền")
	var first_variant := layer.get_cell_atlas_coords(Vector2i(10, 10))
	var other_terrain: Node = load("res://scripts/world_terrain.gd").new()
	root.add_child(other_terrain)
	_check(other_terrain.get_node("Ground").get_cell_atlas_coords(Vector2i(10, 10)) == first_variant, "Dựng lại ra đúng bản đồ cũ")
	other_terrain.free()

	# Tài nguyên không nằm trên ô chặn.
	var blocked_nodes := 0
	for node in get_nodes_in_group("resource_nodes"):
		if int(terrain.get_ground_at(node.global_position)) in terrain.SOLID_GROUNDS:
			blocked_nodes += 1
	_check(blocked_nodes == 0, "Không điểm tài nguyên nào nằm trên nước hay vách đá")
	var far_count := 0
	for node in get_nodes_in_group("resource_nodes"):
		if str(node.get("node_id")).begins_with("far_"):
			far_count += 1
	_check(far_count == 11, "Vùng phía nam có 11 điểm tài nguyên")

	# Va chạm và lối đi.
	player.global_position = Vector2(150, 700)
	player.velocity = Vector2.ZERO
	await physics_frame
	var blocked := player.test_move(player.global_transform, Vector2(0, 80))
	_check(blocked, "Vách đá chặn người chơi")
	var to_swamp: PackedVector2Array = navigation.call("get_world_path", Vector2(900, 600), Vector2(400, 900))
	_check(not to_swamp.is_empty() and _passes_through(to_swamp, 384.0, 480.0), "Tới Đầm Lầy đi qua đúng lối mở")
	var to_dunes: PackedVector2Array = navigation.call("get_world_path", Vector2(900, 600), Vector2(1200, 900))
	_check(not to_dunes.is_empty() and _passes_through(to_dunes, 1240.0, 1336.0), "Tới Đồi Cát đi qua đúng lối mở")
	var water_path: PackedVector2Array = navigation.call("get_world_path", Vector2(150, 1050), Vector2(420, 1050))
	var crosses_water := false
	for point in water_path:
		if int(terrain.get_ground_at(point)) == terrain.Ground.WATER:
			crosses_water = true
	_check(not water_path.is_empty() and not crosses_water, "Đường đi tránh nước")

	# Cổng Tàn Tích.
	_check(not gate.is_open and not bool(world.is_region_unlocked(&"ruins")), "Cổng Tàn Tích ban đầu đóng")
	_check((navigation.call("get_world_path", Vector2(2128, 650), Vector2(2100, 900)) as PackedVector2Array).is_empty(), "Cổng đóng thì không có đường vào Tàn Tích")
	var from_dunes: PackedVector2Array = navigation.call("get_world_path", Vector2(1500, 900), Vector2(2100, 900))
	_check(from_dunes.is_empty(), "Vách đá chặn lối từ Đồi Cát sang Tàn Tích")
	_check(await _save(save_manager), "Lưu khi cổng còn đóng")
	world.unlock_region(&"ruins")
	await _wait_frames(6)
	_check(gate.is_open and not gate.visible, "Mở khóa thì cổng mở")
	var through_gate: PackedVector2Array = navigation.call("get_world_path", Vector2(2128, 650), Vector2(2100, 900))
	_check(not through_gate.is_empty(), "Cổng mở thì có đường vào Tàn Tích")
	_check(await _load(save_manager), "F9 về lúc cổng đóng")
	await _wait_frames(6)
	_check(not gate.is_open and gate.visible, "F9 khóa lại cổng")
	_check((navigation.call("get_world_path", Vector2(2128, 650), Vector2(2100, 900)) as PackedVector2Array).is_empty(), "F9 cũng khóa lại đường đi")

	# Nhiệm vụ mở cổng.
	var quests := root.get_node("QuestManager")
	_check(quests.get_quest_definition(&"sys_05_defend")["rewards"]["unlock_regions"] == [&"ruins"], "Nhiệm vụ phòng thủ mở cổng Tàn Tích")
	var archive: Node2D = scene.get_node("AncientArchive")
	_check(int(terrain.get_ground_at(archive.global_position)) == terrain.Ground.RUIN, "Di tích cuối nằm trong Tàn Tích")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))
	_finish()

func _passes_through(path: PackedVector2Array, min_x: float, max_x: float) -> bool:
	for point in path:
		if point.y >= 720.0 and point.y <= 752.0:
			return point.x >= min_x and point.x <= max_x
	return false

func _wait_frames(count: int) -> void:
	for _i in count:
		await physics_frame
	await process_frame

func _slot_path() -> String:
	return "user://saves/slot_%02d.json" % TEST_SLOT

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

func _finish() -> void:
	print("Map terrain checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
