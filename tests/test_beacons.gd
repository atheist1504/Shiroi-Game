extends SceneTree

# Cột mốc (beacon.gd), mở bản đồ M, dịch chuyển nhanh và % khám phá (exploration.gd).
# Gọi hàm trực tiếp, không mô phỏng chuột.

const Exploration = preload("res://scripts/exploration.gd")

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
	var world_state: Node = root.get_node("WorldState")
	var minimap: Node = scene.get_node("Minimap") if scene.has_node("Minimap") else _find_minimap(scene)
	var player: Node2D = scene.get_node("Player")
	var terrain: Node = scene.get_node("Environment/Terrain")
	var npc_manager: Node = scene.get_node("NPCManager")
	npc_manager.refresh_navigation()
	# Không để đêm đầu chặn dịch chuyển trong bài thử.
	var night := scene.get_node_or_null("FirstNight")
	if night:
		night.set_process(false)

	# Bố trí: 7 cột mốc, mã không trùng, đứng trên đất đi được, tới được từ Trại (trừ Tàn Tích có cổng).
	var beacons := get_nodes_in_group("beacons")
	_check(beacons.size() == 7, "Có 7 cột mốc")
	var ids := {}
	var all_ok := true
	for beacon in beacons:
		ids[beacon.beacon_id] = true
		var ground: int = terrain.get_ground_at(beacon.global_position)
		if ground < 0 or ground in [9, 10, 11] or not terrain.is_in_play_area(beacon.global_position):
			all_ok = false
		if beacon.beacon_id != &"ruins" and npc_manager.get_world_path(Vector2(944, 640), beacon.global_position + Vector2(0, 28)).is_empty():
			all_ok = false
	_check(ids.size() == 7, "Mã cột mốc không trùng")
	_check(all_ok, "Cột mốc đứng trên đất đi được và tới được từ Trại")

	# Ban đầu chỉ quanh Trại được mở trên bản đồ M.
	var iron_beacon: Node2D = scene.get_node("Beacons/BeaconIronMine")
	_check(not iron_beacon.is_active(), "Cột mốc chưa kích hoạt lúc đầu")
	_check(minimap.is_revealed(Vector2(944, 640)) and not minimap.is_revealed(iron_beacon.global_position), "Bản đồ M chỉ mở quanh Trại lúc đầu")

	# % khám phá khu Mỏ Sắt trước khi làm gì.
	var iron_zone: Node2D = scene.get_node("Environment/Zones/IronMineZone")
	var before: Vector2i = Exploration.zone_progress(self, iron_zone)
	_check(before.x == 0 and before.y > 2, "Mỏ Sắt chưa khám phá: 0%")

	# Kích hoạt bằng F khi đứng gần.
	player.global_position = iron_beacon.global_position + Vector2(0, 20)
	await physics_frame
	await physics_frame
	iron_beacon._unhandled_input(_key(KEY_F))
	_check(iron_beacon.is_active() and world_state.get_flag(&"beacon_iron_mine", false) == true, "Bấm F kích hoạt cột mốc, lưu cờ trong WorldState")
	_check(minimap.is_revealed(iron_beacon.global_position + Vector2(300, 0)), "Kích hoạt thì bản đồ M mở quanh cột mốc")
	_check(not iron_beacon.activate(), "Kích hoạt lại không làm gì")

	# % tăng khi tới khu, kích hoạt cột mốc, tự tay thu thập điểm tài nguyên trong khu.
	world_state.discover_region(&"zone_iron_mine")
	var iron_node: Node = null
	for node in get_nodes_in_group("resource_nodes"):
		if Rect2(iron_zone.global_position, iron_zone.zone_size).has_point(node.global_position):
			iron_node = node
			break
	iron_node.set_harvested(true, true)
	var after: Vector2i = Exploration.zone_progress(self, iron_zone)
	_check(after.x == 3 and after.y == before.y, "Mỏ Sắt tính: đã tới khu, cột mốc, 1 điểm thu thập")
	_check(Exploration.percent(Vector2i(1, 3)) == 33 and Exploration.percent(Vector2i(0, 0)) == 0, "Làm tròn % xuống, khu trống là 0%")
	var npc_harvest := Exploration.zone_progress(self, iron_zone)
	for node in get_nodes_in_group("resource_nodes"):
		if node != iron_node and Rect2(iron_zone.global_position, iron_zone.zone_size).has_point(node.global_position):
			node.set_harvested(true, false) # NPC hay save khôi phục: không tính
			break
	_check(Exploration.zone_progress(self, iron_zone) == npc_harvest, "Chỉ người chơi tự tay thu thập mới tính %")

	# Dịch chuyển: mở bản đồ, bấm cột mốc Trại.
	player.global_position = iron_beacon.global_position + Vector2(0, 40)
	minimap.set_world_map_open(true)
	var marker := _find_marker(minimap, iron_beacon.global_position)
	_check(marker != null and not marker.disabled, "Cột mốc đã kích hoạt là nút trên bản đồ M")
	_check(minimap.teleport_to(minimap.CAMP_BEACON_POSITION) and player.global_position.distance_to(minimap.CAMP_BEACON_POSITION) < 40.0, "Dịch chuyển về Trại")
	_check(not minimap.is_world_map_open() and not paused, "Dịch chuyển xong thì đóng bản đồ, chạy tiếp")
	var forest_beacon: Node2D = scene.get_node("Beacons/BeaconForest")
	minimap.set_world_map_open(true)
	_check(not minimap.teleport_to(forest_beacon.global_position) and player.global_position.distance_to(minimap.CAMP_BEACON_POSITION) < 40.0, "Không dịch chuyển tới chỗ chưa mở")
	_check(minimap.teleport_to(iron_beacon.global_position) and player.global_position.distance_to(iron_beacon.global_position) < 40.0, "Dịch chuyển tới cột mốc đã kích hoạt")

	# Không xây đè lên cột mốc.
	player.global_position = minimap.CAMP_BEACON_POSITION
	await physics_frame
	var base: Node = root.get_node("BaseManager")
	base.unlock_base_for_debug()
	for enemy in get_nodes_in_group("enemies"):
		if (enemy as Node2D).global_position.distance_to(iron_beacon.global_position) < 200.0:
			enemy.free() # quái đi lang thang chắn chỗ thì lý do chặn là quái
	var reason: String = base._get_placement_block_reason(&"iron_mine", Vector2i((iron_beacon.global_position / 16.0).round()))
	_check(reason.contains("cột mốc"), "Không xây trạm đè lên cột mốc")

	# Cờ cột mốc nằm trong dữ liệu lưu của thế giới.
	_check(str(world_state.to_dict()).contains("beacon_iron_mine"), "Save giữ cột mốc đã kích hoạt")
	_finish()

func _find_minimap(scene: Node) -> Node:
	for child in scene.get_children():
		if child.has_method("teleport_to"):
			return child
	return null

func _find_marker(minimap: Node, world_pos: Vector2) -> Button:
	for child in minimap.get("_world_labels").get_children():
		if child is Button and child.name == "Beacon_%d_%d" % [int(world_pos.x), int(world_pos.y)]:
			return child
	return null

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = keycode
	return event

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _finish() -> void:
	print("Beacon checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
