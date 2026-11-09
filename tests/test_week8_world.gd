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
	_check(npc_manager.call("get_map_rect").size == Vector2(2560, 720), "Bản đồ mở rộng 2560x720")
	var counts := {}
	for node in get_nodes_in_group("resource_nodes"):
		if str(node.get("node_id")).begins_with("zone_"):
			counts[node.get("resource_id")] = int(counts.get(node.get("resource_id"), 0)) + 1
	_check(counts.get(&"wood") == 6 and counts.get(&"herb") == 3 and counts.get(&"stone") == 6, "Khu rừng và mỏ đá đủ điểm tài nguyên")
	_check(counts.get(&"iron_ore") == 6 and counts.get(&"gold_ore") == 5, "Mỏ sắt và mỏ vàng đủ điểm tài nguyên")
	_check(scene.get_node("Environment/Zones").get_child_count() == 5, "Có đủ 4 khu khai thác và vùng căn cứ trên bản đồ")
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

	# Chọn việc đúng nghề.
	var expected := {BLACKSMITH: [&"iron_ore"], ALCHEMIST: [&"herb"], LUMBERJACK: [&"wood"], MINER: [&"stone", &"gold_ore"]}
	for character_id in expected:
		var worker = workers.get("_workers")[character_id]
		_check(workers.call("_assign_gather", worker) and worker.task_node.get("resource_id") in expected[character_id], "Thợ %s chọn đúng tài nguyên" % str(character_id))
		workers.call("_cancel_task", worker, "test")
	_check(workers.call("_assign_gather", workers.get("_workers")[GUARD]) == false, "Lính canh không đi khai thác")

	# Khai thác và giao hàng thật qua _process.
	base_manager.unlock_base_for_debug()
	inventory.add_item(&"wooden_plank", 4)
	inventory.add_item(&"processed_stone", 2)
	base_manager.set("is_build_mode", true)
	_check(base_manager.place_building(&"storage", Vector2i(52, 35)), "Xây kho chứa")
	base_manager.set("is_build_mode", false)
	await physics_frame
	await physics_frame
	npc_manager.call("refresh_navigation")
	var storage: Node2D = get_nodes_in_group("placed_buildings")[0]
	var storage_id := StringName(str(storage.get("instance_id")))
	var smith = workers.get("_workers")[BLACKSMITH]
	var smith_body: Node2D = smith.body
	smith_body.set("move_speed", 130.0)
	smith_body.global_position = Vector2(1400, 450)
	for character_id in [ALCHEMIST, LUMBERJACK, MINER, GUARD]:
		workers.get_worker_body(character_id).set_physics_process(false)
		workers.get("_workers")[character_id].idle_retry = 9999.0
	workers.set_process(true)
	await _wait_until(func() -> bool: return smith_body.call("cargo_used") >= 3, 900)
	_check(int(smith_body.get("cargo").get(&"iron_ore", 0)) >= 3, "Thợ rèn đào được quặng sắt ở mỏ ngoài căn cứ")
	var harvested_duration: float = workers.WORK_DURATION / float(gacha.get_work_speed(BLACKSMITH))
	_check(is_equal_approx(harvested_duration, 2.0), "Tốc độ làm việc rút ngắn thời gian đào")
	smith_body.set("cargo", {&"iron_ore": 9})
	smith.idle_retry = 0.0
	await _wait_until(func() -> bool: return _storage_count(base_manager, storage_id, &"iron_ore") >= 9, 1200)
	_check(_storage_count(base_manager, storage_id, &"iron_ore") == 9 and int(smith_body.call("cargo_used")) == 0, "Thợ giao quặng vào kho, hàng không mất và không nhân đôi")
	workers.set_process(false)

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
	storage = get_nodes_in_group("placed_buildings")[0]
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
	storage = get_nodes_in_group("placed_buildings")[0]
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
	storage.call("take_damage", 99999.0)
	await process_frame
	_check(get_nodes_in_group("placed_buildings").is_empty() and not base_manager.get("_storage_inventories").has(storage_id), "Kho hết máu thì bị phá và mất đồ bên trong")
	await physics_frame
	await physics_frame
	await physics_frame
	await process_frame
	var cleared_path: PackedVector2Array = npc_manager.call("get_world_path", Vector2(704, 600), Vector2(832, 560))
	_check(not cleared_path.is_empty() and cleared_path[cleared_path.size() - 1].distance_to(Vector2(832, 560)) < 12.0, "Ô của công trình bị phá đi lại được")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))
	_finish()

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
