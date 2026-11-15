extends SceneTree

# Bản đồ Rừng Nguyệt Ảnh: nền, sông và cầu, hồ, vòng vách Tàn Tích, cổng khóa theo nhiệm vụ, save/load.
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

	# Nền: Rừng Nguyệt Ảnh là rừng, không còn đầm lầy hay đồi cát.
	_check(layer.get_used_cells().size() == terrain.MAP_CELLS.x * terrain.MAP_CELLS.y and terrain.MAP_CELLS == Vector2i(320, 134), "Tile phủ kín bản đồ nối ra lục địa 320x134 ô")
	_check(terrain.is_in_play_area(Vector2(-600, 1100)) and terrain.is_in_play_area(Vector2(3300, 1100)) and not terrain.is_in_play_area(Vector2(1000, -300)), "Vùng chơi kéo sang tây, sang đông; phía bắc đường ranh là mây")
	_check(terrain.get_ground_at(Vector2(944, 640)) == terrain.Ground.DIRT, "Trại là khoảng trống đất")
	_check(terrain.get_ground_at(Vector2(1500, 200)) == terrain.Ground.FOREST, "Khu Rừng nền rừng")
	_check(terrain.get_ground_at(Vector2(2200, 520)) == terrain.Ground.GOLD, "Mỏ Vàng là bãi đá lộ quặng vàng")
	_check(terrain.get_ground_at(Vector2(2100, 900)) == terrain.Ground.RUIN, "Tàn Tích nền đá cổ")
	_check(terrain.get_ground_at(Vector2(-2000, 10)) == -1 and terrain.get_ground_at(Vector2(1000, 2000)) == -1, "Ngoài bản đồ không có nền")
	_check(terrain.get_ground_at(Vector2(24, 24)) == terrain.Ground.VOID and not terrain.is_in_play_area(Vector2(24, 24)), "Góc khung bản đồ nằm ngoài vùng chơi bầu dục, bị chặn")
	_check(terrain.is_in_play_area(Vector2(1280, 720)) and terrain.is_in_play_area(Vector2(944, 600)), "Trại nằm trong vùng chơi")
	var outside_nodes := 0
	for node in get_nodes_in_group("resource_nodes") + get_nodes_in_group("enemies"):
		if terrain.play_shape_value((node as Node2D).global_position) > 0.85:
			outside_nodes += 1
	_check(outside_nodes == 0, "Không tài nguyên hay quái nào nằm sát hoặc ngoài mép mây")
	var kinds := {}
	# Chỉ xét trong hình bầu dục của Rừng Nguyệt Ảnh cũ (phần nối ra lục địa có bãi cát bờ biển).
	var in_old_oval := func(c: Vector2i) -> bool:
		var rel := (Vector2(c) * 16.0 + Vector2(8, 8) - Vector2(1280, 720)) / Vector2(76 * 16, 42 * 16)
		return pow(absf(rel.x), 4.0) + pow(absf(rel.y), 4.0) <= 1.0
	for cell in layer.get_used_cells().filter(in_old_oval):
		kinds[int(layer.get_cell_tile_data(cell).get_custom_data("ground"))] = true
	_check(not kinds.has(terrain.Ground.MUD) and not kinds.has(terrain.Ground.SAND), "Rừng Nguyệt Ảnh không còn đầm lầy và đồi cát (bãi cát chỉ ở bờ biển phần nối ra lục địa)")
	var forest_cells := 0
	for cell in layer.get_used_cells().filter(in_old_oval):
		if int(layer.get_cell_tile_data(cell).get_custom_data("ground")) == terrain.Ground.FOREST:
			forest_cells += 1
	_check(forest_cells > 160 * 90 / 4, "Rừng phủ phần lớn bản đồ")
	# Bản đồ nằm trong scene riêng, tileset lưu thành file để sửa trong editor.
	_check(terrain.scene_file_path == "res://scenes/world_map.tscn", "Bản đồ nạp từ scene world_map.tscn")
	_check(layer.tile_set.resource_path == "res://assets/tiles/terrain_tileset.tres", "Tileset là file riêng, sửa được trong editor")
	var obstacles: TileMapLayer = terrain.get_node("Obstacles")
	_check(terrain.has_node("Decoration") and obstacles.get_used_cells().size() > 0, "Có lớp Vật cản và lớp Trang trí")
	_check(terrain.get_ground_at(Vector2(380, 1080)) == terrain.Ground.WATER, "Hồ nước nằm ở lớp Vật cản")
	_check(layer.get_cell_tile_data(Vector2i(40, 21)).get_custom_data("ground") == terrain.Ground.GRASS, "Tile mang loại nền trong custom data")
	# Không còn bức vách thẳng chia đôi bản đồ.
	var long_wall := false
	for y in 90:
		var run := 0
		for x in 160:
			run = run + 1 if int(terrain.get_ground_at(Vector2(x, y) * 16.0 + Vector2(8, 8))) == terrain.Ground.CLIFF else 0
			if run >= 60:
				long_wall = true
	_check(not long_wall, "Không có bức vách thẳng dài chia cắt rừng")

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

	# Sông chặn đường, chỉ qua được ở cầu.
	player.global_position = Vector2(1240, 400)
	player.velocity = Vector2.ZERO
	await physics_frame
	_check(player.test_move(player.global_transform, Vector2(120, 0)), "Sông chặn người chơi")
	var to_iron: PackedVector2Array = navigation.call("get_world_path", Vector2(944, 640), Vector2(1600, 560))
	_check(not to_iron.is_empty() and not _crosses_water(terrain, to_iron), "Từ Trại tới Mỏ Sắt đi qua cầu, không lội nước")
	var to_south: PackedVector2Array = navigation.call("get_world_path", Vector2(944, 640), Vector2(700, 1180))
	_check(not to_south.is_empty() and not _crosses_water(terrain, to_south), "Từ Trại xuống rừng phía nam qua cầu")
	var water_path: PackedVector2Array = navigation.call("get_world_path", Vector2(200, 1200), Vector2(560, 1200))
	_check(not water_path.is_empty() and not _crosses_water(terrain, water_path), "Đường đi vòng tránh hồ")

	# Cổng Tàn Tích.
	_check(not gate.is_open and not bool(world.is_region_unlocked(&"ruins")), "Cổng Tàn Tích ban đầu đóng")
	_check((navigation.call("get_world_path", Vector2(2128, 650), Vector2(2100, 900)) as PackedVector2Array).is_empty(), "Cổng đóng thì không có đường vào Tàn Tích")
	var from_outside: PackedVector2Array = navigation.call("get_world_path", Vector2(1500, 900), Vector2(2100, 900))
	_check(from_outside.is_empty(), "Vòng vách đá quanh Tàn Tích chặn mọi lối trừ cổng")
	_check(await _save(save_manager), "Lưu khi cổng còn đóng")
	world.unlock_region(&"ruins")
	await _wait_frames(12)
	_check(gate.is_open and not gate.visible, "Mở khóa thì cổng mở")
	var through_gate: PackedVector2Array = navigation.call("get_world_path", Vector2(2128, 650), Vector2(2100, 900))
	_check(not through_gate.is_empty(), "Cổng mở thì có đường vào Tàn Tích")
	_check(await _load(save_manager), "F9 về lúc cổng đóng")
	await _wait_frames(12)
	_check(not gate.is_open and gate.visible, "F9 khóa lại cổng")
	_check((navigation.call("get_world_path", Vector2(2128, 650), Vector2(2100, 900)) as PackedVector2Array).is_empty(), "F9 cũng khóa lại đường đi")

	# Nhiệm vụ mở cổng.
	var quests := root.get_node("QuestManager")
	_check(quests.get_quest_definition(&"sys_05_defend")["rewards"]["unlock_regions"] == [&"ruins"], "Nhiệm vụ phòng thủ mở cổng Tàn Tích")
	var archive: Node2D = scene.get_node("AncientArchive")
	_check(int(terrain.get_ground_at(archive.global_position)) == terrain.Ground.RUIN, "Di tích cuối nằm trong Tàn Tích")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))
	_finish()

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

func _crosses_water(terrain: Node, path: PackedVector2Array) -> bool:
	for point in path:
		if int(terrain.get_ground_at(point)) == terrain.Ground.WATER:
			return true
	return false
