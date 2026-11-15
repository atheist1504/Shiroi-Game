extends SceneTree

# Tuần 8: bản đồ mở rộng, thợ theo nghề, giao hàng, lính canh, đợt quái, save/load.
const TEST_SLOT := 94
const BLACKSMITH := &"gacha_char_01"
const ALCHEMIST := &"gacha_char_02"
const LUMBERJACK := &"gacha_char_03"
const MINER := &"gacha_char_04"
const GUARD := &"gacha_char_05"

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
	var npc_manager: Node = scene.get_node("NPCManager")
	var workers: Node = scene.get_node("WorkerManager")
	var raid: Node = scene.get_node("BaseRaid")
	var gacha := root.get_node("GachaManager")
	var party := root.get_node("PartyManager")
	var wallet := root.get_node("WalletManager")
	var base_manager := root.get_node("BaseManager")
	var inventory := root.get_node("InventoryManager")
	var clock := root.get_node("WorldClock")
	var save_manager := root.get_node("SaveManager")
	var player: Node2D = scene.get_node("Player")
	player.global_position = Vector2(300, 300)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for node in get_nodes_in_group("enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.global_position = Vector2(100, 100)
	npc_manager.set_process(false)
	workers.set_process(false)

	# Bản đồ và tài nguyên.
	await physics_frame
	npc_manager.call("refresh_navigation")
	var started := Time.get_ticks_usec()
	npc_manager.call("refresh_navigation")
	var refresh_ms := (Time.get_ticks_usec() - started) / 1000.0
	_check(refresh_ms < 100.0, "Cập nhật lưới đường đủ nhanh (%.1f ms)" % refresh_ms)
	_check(npc_manager.call("get_map_rect") == Rect2(-1280, -384, 5120, 2144), "Lưới đường đi phủ cả bản đồ nối ra lục địa")
	var counts := {}
	for node in get_nodes_in_group("resource_nodes"):
		if str(node.get("node_id")).begins_with("zone_"):
			counts[node.get("resource_id")] = int(counts.get(node.get("resource_id"), 0)) + 1
	_check(counts.get(&"wood") == 6 and counts.get(&"herb") == 3 and counts.get(&"stone") == 6, "Khu rừng và mỏ đá đủ điểm tài nguyên")
	_check(counts.get(&"iron_ore") == 6 and counts.get(&"gold_ore") == 5, "Mỏ sắt và mỏ vàng đủ điểm tài nguyên")
	_check(scene.get_node("Environment/Zones").get_child_count() == 6, "Có đủ các khu trên bản đồ (4 khu khai thác, Tàn Tích, Trại)")
	_check(inventory.get_item_def(&"iron_ore") != null and inventory.get_item_def(&"gold_ore") != null, "Có vật phẩm quặng sắt và quặng vàng")
	var far_path: PackedVector2Array = npc_manager.call("get_world_path", Vector2(704, 600), Vector2(2240, 500))
	_check(not far_path.is_empty() and far_path[far_path.size() - 1].distance_to(Vector2(2240, 500)) < 24.0, "Có đường từ căn cứ tới mỏ vàng")
	var villager: Node = npc_manager.call("get_npc")
	villager.call("set_idle")
	_check(not bool(npc_manager.call("request_destination", Vector2(2240, 500))), "NPC dân làng vẫn chỉ đi trong căn cứ")
	villager.call("set_idle")

	# Vàng do người chơi đào vào thẳng ví.
	var gold_node: Node = _find_resource(&"zone_gold_01")
	var gold_before := int(wallet.get_gold())
	gold_node.call("_try_gather")
	_check(int(wallet.get_gold()) == gold_before + 20 and int(inventory.get_item_count(&"gold_ore")) == 0, "Người chơi đào vàng nhận 20 vàng, không chiếm túi")
	gold_node.call("set_harvested", false, false)

	# Danh sách thợ theo nhân vật.
	_check(workers.get_worker_ids().is_empty(), "Chưa có nhân vật thì chưa có thợ")
	gacha.debug_unlock_all()
	party.add_member(GUARD)
	workers.sync_workers()
	_check(workers.get_worker_ids().size() == 4 and workers.get_worker_body(GUARD) == null, "Nhân vật trong đội không làm thợ")
	party.remove_member(GUARD)
	workers.sync_workers()
	_check(workers.get_worker_ids().size() == 5, "Rời đội thì quay lại làm thợ")
	var first_body: Node2D = workers.get_worker_body(MINER)
	workers.sync_workers()
	_check(workers.get_worker_body(MINER) == first_body, "Đồng bộ lại không tạo thợ trùng")

	# Thợ không còn tự đi khai thác: chưa có trạm hợp nghề thì đứng chờ.
	for character_id in [BLACKSMITH, ALCHEMIST, LUMBERJACK, MINER, GUARD]:
		_check(workers.call("_assign_station", workers.get("_workers")[character_id]) == false, "Chưa có trạm thì thợ %s không đi khai thác" % str(character_id))

	# Trạm khai thác: đặt trong khu đã khám phá, ngoài Trại.
	base_manager.unlock_base_for_debug()
	inventory.add_item(&"wooden_plank", 20)
	inventory.add_item(&"processed_stone", 10)
	var world_flags := root.get_node("WorldState")
	var iron_zone: Node2D = scene.get_node("Environment/Zones/IronMineZone")
	var iron_grid := _find_free_grid(base_manager, &"iron_mine", iron_zone)
	_check(base_manager._get_placement_block_reason(&"iron_mine", iron_grid).begins_with("Cần khám phá"), "Chưa khám phá Mỏ Sắt thì chưa xây được mỏ sắt")
	world_flags.discover_region(&"zone_iron_mine")
	iron_grid = _find_free_grid(base_manager, &"iron_mine", iron_zone)
	world_flags.discover_region(&"zone_forest")
	_check(base_manager._get_placement_block_reason(&"lumber_camp", iron_grid).contains("phải đặt trong"), "Trại gỗ không đặt được trong Mỏ Sắt")
	base_manager.set("is_build_mode", true)
	_check(base_manager.place_building(&"iron_mine", iron_grid), "Xây mỏ sắt ngoài Trại, trong Mỏ Sắt đã khám phá")
	var camp_area := Rect2(base_manager.CAMP_CENTER - Vector2(150, 150), Vector2(300, 300))
	_check(base_manager.place_building(&"storage", _find_free_grid_in(base_manager, &"storage", camp_area)), "Xây kho chứa")
	base_manager.set("is_build_mode", false)
	await physics_frame
	await physics_frame
	npc_manager.call("refresh_navigation")
	var mine: BaseBuilding = null
	var storage: Node2D = null
	for node in get_nodes_in_group("placed_buildings"):
		if node.building_type_id == &"iron_mine":
			mine = node
		elif node.building_type_id == &"storage":
			storage = node
	var storage_id := StringName(str(storage.get("instance_id")))
	mine.set_physics_process(false) # tính sản lượng bằng tay cho chắc

	# Thợ rèn tới mỏ sắt làm việc; người khác nghề không tới.
	var smith = workers.get("_workers")[BLACKSMITH]
	var smith_body: Node2D = smith.body
	smith_body.set("move_speed", 160.0)
	smith_body.global_position = mine.global_position + Vector2(0, 80)
	_check(workers.call("_assign_station", workers.get("_workers")[LUMBERJACK]) == false, "Tiều phu không tới mỏ sắt")
	for character_id in [ALCHEMIST, LUMBERJACK, MINER, GUARD]:
		workers.get_worker_body(character_id).set_physics_process(false)
		workers.get("_workers")[character_id].idle_retry = 9999.0
	smith.idle_retry = 0.0
	workers.set_process(true)
	await _wait_until(func() -> bool: return workers.count_station_workers(mine.instance_id) == 1, 900)
	_check(workers.count_station_workers(mine.instance_id) == 1, "Thợ rèn tới mỏ sắt và làm việc ở đó")
	workers.set_process(false)

	# Thuê NPC bằng vàng, tối đa 3.
	wallet.add_gold(200)
	var gold_start := int(wallet.get_gold())
	for i in 3:
		base_manager.hire_station_npc(mine)
	_check(mine.hired == 3 and int(wallet.get_gold()) == gold_start - 150, "Thuê 3 NPC, mỗi NPC 50 vàng")
	_check(not base_manager.hire_station_npc(mine) and int(wallet.get_gold()) == gold_start - 150, "Không thuê quá 3 NPC")

	# Tự sinh: (1 + 3 NPC + 2 x 1 thợ đúng nghề) / 30 giây = 6 đơn vị trong 30 giây, có xuất đặc biệt.
	_check(is_equal_approx(mine.get_production_rate(), 6.0 / 30.0), "Tốc độ sinh tính cả NPC thuê và thợ đúng nghề")
	mine._update_station(30.0)
	_check(int(mine.stock.get(&"iron_ore", 0)) == 6 and int(mine.stock.get(&"basic_building_kit", 0)) == 1, "Trạm sinh quặng sắt và xuất đặc biệt nhờ thợ rèn")

	# Đầy thì chở về kho Trại.
	mine.stock = {&"iron_ore": 30}
	mine._update_station(0.1)
	_check(mine.is_hauling(), "Kho trạm đầy thì NPC bắt đầu chở hàng")
	mine._update_station(BaseBuilding.STATION_HAUL_SECONDS + 0.1)
	_check(_storage_count(base_manager, storage_id, &"iron_ore") == 30 and mine.get_stock_total() == 0, "Chở về kho chứa đủ 30 quặng sắt")

	# Không có người làm thì đầy là dừng.
	mine.hired = 0
	smith.task_kind = ""
	mine.stock = {&"iron_ore": 30}
	mine._update_station(5.0)
	_check(not mine.is_hauling() and mine.get_stock_total() == 30, "Không có người làm thì trạm đầy là dừng")

	# Lưu và tải giữ kho trạm, số NPC.
	mine.hired = 2
	var base_save: Dictionary = base_manager.to_dict()
	_check(base_manager.load_from_dict(base_save), "Tải lại công trình có trạm")
	var loaded_mine: BaseBuilding = null
	for node in get_nodes_in_group("placed_buildings"):
		if node.building_type_id == &"iron_mine":
			loaded_mine = node
	_check(loaded_mine and loaded_mine.hired == 2 and int(loaded_mine.stock.get(&"iron_ore", 0)) == 30, "Save giữ kho trạm và số NPC")
	await physics_frame
	for node in get_nodes_in_group("placed_buildings"):
		if node.building_type_id == &"storage":
			storage = node

	# Vàng giao về thành tiền trong ví.
	var miner = workers.get("_workers")[MINER]
	miner.body.set_physics_process(true)
	miner.body.set("cargo", {&"gold_ore": 4, &"stone": 3})
	miner.body.global_position = storage.global_position + Vector2(0, 44)
	await physics_frame
	_check(workers.call("_assign_delivery", miner), "Thợ mỏ nhận việc giao hàng")
	miner.body.call("set_idle")
	miner.task_kind = "deliver"
	miner.task_building = storage
	gold_before = int(wallet.get_gold())
	workers.call("_deliver", miner)
	_check(int(wallet.get_gold()) == gold_before + 40 and _storage_count(base_manager, storage_id, &"stone") == 3 and int(miner.body.call("cargo_used")) == 0, "Quặng vàng thành 40 vàng, đá vào kho")

	# Vào đội khi đang mang hàng thì hàng không mất.
	miner.body.set("cargo", {&"stone": 3})
	party.add_member(MINER)
	workers.sync_workers()
	_check(_storage_count(base_manager, storage_id, &"stone") == 6 and workers.get_worker_body(MINER) == null, "Thợ vào đội: hàng đang mang được chuyển vào kho")
	party.remove_member(MINER)
	workers.sync_workers()

	# Đợt quái.
	var flags := root.get_node("WorldState")
	raid.call("_process", 0.0)
	var next_at := float(flags.get_flag(raid.FLAG_NEXT_AT, -1.0))
	_check(next_at > float(clock.get_time()) + 250.0 and next_at <= float(clock.get_time()) + 300.0, "Đặt lịch đợt đầu sau khi có công trình")
	raid.call("_process", 0.0)
	_check(not raid.is_raid_active(), "Chưa tới giờ thì chưa có quái")
	clock.advance(301.0)
	raid.call("_process", 0.0)
	_check(raid.is_raid_active() and raid.get_wave() == 1 and raid.get_alive_raider_count() == 2, "Tới giờ thì đợt 1 có 2 quái")
	_check(not raid.start_raid(), "Không tạo chồng hai đợt")
	var raiders := get_nodes_in_group("raiders")
	var attacker: Node2D = raiders[0]
	var other: Node2D = raiders[1]
	other.process_mode = Node.PROCESS_MODE_DISABLED
	other.global_position = Vector2(100, 150)
	attacker.global_position = storage.global_position + Vector2(-60, 0)
	attacker.set("attack_cooldown", 0.05)
	var health_before := float(storage.get("current_health"))
	await _wait_until(func() -> bool: return float(storage.get("current_health")) < health_before, 240)
	_check(float(storage.get("current_health")) < health_before, "Quái tự đi tới và cắn công trình")
	attacker.process_mode = Node.PROCESS_MODE_DISABLED

	# Save/Load giữa đợt.
	storage.set("current_health", 123.0)
	var guard_body: Node2D = workers.get_worker_body(GUARD)
	guard_body.global_position = Vector2(900, 600)
	workers.get_worker_body(LUMBERJACK).set("cargo", {&"wood": 6})
	_check(await _save(save_manager), "Lưu game giữa đợt quái")
	var saved_ids: Array = workers.get_worker_ids()
	storage.set("current_health", 400.0)
	attacker.global_position = Vector2(50, 50)
	workers.get_worker_body(LUMBERJACK).set("cargo", {})
	_check(await _load(save_manager), "F9 tải lại")
	storage = _first_storage()
	_check(is_equal_approx(storage.get("current_health"), 123.0), "Khôi phục máu công trình")
	_check(raid.is_raid_active() and raid.get_alive_raider_count() == 2, "Khôi phục đợt quái và số quái")
	_check(_count_sorted(workers.get_worker_ids()) == _count_sorted(saved_ids) and int(workers.get_worker_body(LUMBERJACK).get("cargo").get(&"wood", 0)) == 6, "Khôi phục thợ và hàng đang mang")
	_check(_count_npc_bodies() == 6, "Không nhân đôi thân NPC sau khi tải (1 dân làng + 5 thợ)")
	_check(await _load(save_manager) and _count_npc_bodies() == 6, "Tải liên tiếp vẫn đúng số NPC")
	_check(_rewrite_slot(func(data: Dictionary) -> void: data["worker_state"]["workers"][0]["character_id"] = "khong_ton_tai"), "Tạo file thợ lỗi")
	await create_timer(0.45).timeout
	_check(not bool(save_manager.call("load_game", TEST_SLOT)), "File thợ lỗi bị từ chối")
	_check(_rewrite_slot(func(data: Dictionary) -> void:
		data["worker_state"]["workers"][0]["character_id"] = "gacha_char_05"
		data.erase("worker_state")
		for entry in data["base_state"]["buildings"]:
			entry.erase("health")), "Giả lập save cũ")
	_check(await _load(save_manager), "Save cũ vẫn tải được")
	storage = _first_storage()
	_check(is_equal_approx(storage.get("current_health"), 400.0), "Save cũ: công trình đầy máu")
	workers.sync_workers()
	_check(workers.get_worker_ids().size() == 5, "Save cũ: tạo thợ theo danh sách nhân vật")

	# Lính canh và kết thúc đợt.
	for raider in get_nodes_in_group("raiders"):
		raider.process_mode = Node.PROCESS_MODE_DISABLED
		raider.set("current_health", 15.0)
	var guard = workers.get("_workers")[GUARD]
	guard.body.set_physics_process(true)
	guard.body.global_position = npc_manager.call("get_base_rect").get_center()
	var target: Node2D = get_nodes_in_group("raiders")[0]
	target.global_position = guard.body.global_position + Vector2(100, 0)
	var other_raider: Node2D = get_nodes_in_group("raiders")[1]
	other_raider.global_position = Vector2(100, 150)
	workers.set("_sync_pending", false)
	workers.set_process(true)
	for character_id in [BLACKSMITH, ALCHEMIST, LUMBERJACK, MINER]:
		workers.get("_workers")[character_id].idle_retry = 9999.0
	await _wait_until(func() -> bool: return bool(target.get("is_dead")) , 400)
	_check(bool(target.get("is_dead")), "Lính canh tự tới đánh chết quái đột kích")
	workers.set_process(false)
	storage.set("current_health", 200.0)
	var tinh_van_before := int(wallet.get_tinh_van())
	# Tween chết của quái chỉ chạy khi node không bị tắt xử lý.
	target.process_mode = Node.PROCESS_MODE_INHERIT
	other_raider.process_mode = Node.PROCESS_MODE_INHERIT
	other_raider.call("take_damage", 9999.0, Vector2.ZERO)
	raid.call("_process", 0.0)
	_check(not raid.is_raid_active() and int(wallet.get_tinh_van()) == tinh_van_before + 15, "Hết quái thì kết thúc đợt và thưởng 15 Tinh Vẫn")
	_check(is_equal_approx(storage.get("current_health"), 400.0), "Kết thúc đợt thì công trình được sửa")
	await create_timer(0.5).timeout
	_check(get_nodes_in_group("raiders").is_empty(), "Quái đột kích được dọn sau khi chết")

	# Đợt sau đông hơn và công trình có thể bị phá.
	clock.advance(241.0)
	raid.call("_process", 0.0)
	_check(raid.get_wave() == 2 and raid.get_alive_raider_count() == 3, "Đợt 2 có 3 quái")
	var storage_spot := storage.global_position
	storage.call("take_damage", 99999.0)
	await process_frame
	_check(_first_storage() == null and not base_manager.get("_storage_inventories").has(storage_id), "Kho hết máu thì bị phá và mất đồ bên trong")
	await physics_frame
	await physics_frame
	await physics_frame
	await process_frame
	var cleared_path: PackedVector2Array = npc_manager.call("get_world_path", Vector2(704, 600), storage_spot)
	_check(not cleared_path.is_empty() and cleared_path[cleared_path.size() - 1].distance_to(storage_spot) < 12.0, "Ô của công trình bị phá đi lại được")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))
	_finish()

# Ô lưới trống đầu tiên bên trong khu (trạm 3x2 ô) để bài thử không phụ thuộc chỗ cây, đá.
func _find_free_grid(base_manager: Node, type_id: StringName, zone: Node2D) -> Vector2i:
	return _find_free_grid_in(base_manager, type_id, Rect2(zone.global_position, zone.get("zone_size")).grow(-48.0))

func _find_free_grid_in(base_manager: Node, type_id: StringName, area: Rect2) -> Vector2i:
	var start := Vector2i((area.position / 16.0).ceil())
	var size := Vector2i((area.size / 16.0).floor())
	for y in range(0, size.y, 2):
		for x in range(0, size.x, 2):
			var grid := start + Vector2i(x, y)
			var reason: String = base_manager._get_placement_block_reason(type_id, grid)
			if reason.is_empty() or reason.begins_with("Cần khám phá"):
				return grid
	return start

func _find_resource(node_id: StringName) -> Node:
	for node in get_nodes_in_group("resource_nodes"):
		if StringName(str(node.get("node_id"))) == node_id:
			return node
	return null

func _storage_count(base_manager: Node, building_id: StringName, item_id: StringName) -> int:
	var total := 0
	for slot in base_manager.get_storage_contents(building_id):
		if slot["item_id"] == item_id:
			total += int(slot["amount"])
	return total

func _count_sorted(values: Array) -> Array:
	var copy := values.duplicate()
	copy.sort()
	return copy

func _count_npc_bodies() -> int:
	var total := 0
	for node in get_nodes_in_group("autonomous_test_npcs"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			total += 1
	return total

func _wait_until(condition: Callable, max_frames: int) -> void:
	for _i in max_frames:
		if condition.call():
			return
		await physics_frame

func _slot_path() -> String:
	return "user://saves/slot_%02d.json" % TEST_SLOT

func _rewrite_slot(change: Callable) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path()))
	if not data is Dictionary:
		return false
	change.call(data)
	var file := FileAccess.open(_slot_path(), FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

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
	print("Week 8 world checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)

func _first_storage() -> Node2D:
	for node in get_nodes_in_group("placed_buildings"):
		if node.get("building_type_id") == &"storage":
			return node
	return null
