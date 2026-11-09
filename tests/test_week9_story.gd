extends SceneTree

# Tuần 9: màn mở đầu, chuỗi nhiệm vụ Hệ thống, khám phá vùng, save/load, lời kết demo.
const TEST_SLOT := 93
const CHAIN: Array[StringName] = [&"sys_01_arrival", &"sys_02_build", &"sys_03_summon", &"sys_04_survey", &"sys_05_defend", &"sys_06_archive"]
const LOCKED := 0
const ACTIVE := 2
const READY := 3
const COMPLETED := 4

var _passed := 0
var _total := 0
var _quests: Node
var _world: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame
	_quests = root.get_node("QuestManager")
	_world = root.get_node("WorldState")
	var wallet := root.get_node("WalletManager")
	var gacha := root.get_node("GachaManager")
	var base_manager := root.get_node("BaseManager")
	var inventory := root.get_node("InventoryManager")
	var save_manager := root.get_node("SaveManager")
	var event_bus := root.get_node("EventBus")
	var player: Node2D = scene.get_node("Player")
	var narrative: Node = scene.get_node("NarrativeUI")
	for node in get_nodes_in_group("enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("NPCManager").set_process(false)
	scene.get_node("BaseRaid").set_process(false)

	# Màn mở đầu.
	_check(not narrative.visible and not paused, "Chạy headless không tự chiếu mở đầu")
	_check(bool(narrative.play_opening_if_needed()) and narrative.visible and paused, "Mở đầu hiện và tạm dừng game")
	_check(str(narrative.get("_text_label").text).contains("người Việt Nam"), "Trang đầu nói về người Việt Nam")
	for _i in narrative.OPENING_PAGES.size() - 1:
		narrative.advance()
	_check(str(narrative.get("_text_label").text).contains("[HỆ THỐNG]") and narrative.visible, "Trang cuối là lời Hệ thống")
	narrative.advance()
	_check(not narrative.visible and not paused, "Hết trang thì vào game")
	_check(not bool(narrative.play_opening_if_needed()), "Mở đầu chỉ chiếu một lần")
	_world.set_flag(narrative.FLAG_OPENING_SEEN, false)
	narrative.play_opening_if_needed()
	narrative.finish()
	_check(not narrative.visible and not paused and _world.get_flag(narrative.FLAG_OPENING_SEEN) == true, "Bỏ qua bằng Esc vẫn ghi đã xem")
	paused = true
	narrative.play(narrative.ENDING_PAGES)
	narrative.finish()
	_check(paused, "Đóng màn chữ không làm mất trạng thái tạm dừng của giao diện khác")
	paused = false

	# Chuỗi nhiệm vụ.
	_check(_status(CHAIN[0]) == ACTIVE and _status(CHAIN[1]) == LOCKED, "Nhiệm vụ Hệ thống đầu tự nhận, các nhiệm vụ sau còn khóa")
	var tinh_van := int(wallet.get_tinh_van())
	player.global_position = Vector2(900, 560)
	await _wait_until(func() -> bool: return _status(CHAIN[0]) == READY, 30)
	_check(_status(CHAIN[0]) == READY and _world.is_region_discovered(&"hope_valley_area"), "Đi vào căn cứ thì hoàn thành mục tiêu")
	_check(_quests.complete_quest(CHAIN[0]) and int(wallet.get_tinh_van()) == tinh_van + 30, "Trả nhiệm vụ nhận 30 Tinh Vẫn")
	_check(_status(CHAIN[1]) == ACTIVE and _status(CHAIN[2]) == LOCKED, "Hoàn thành thì mở đúng nhiệm vụ kế")
	_check(not _quests.complete_quest(CHAIN[0]) and int(wallet.get_tinh_van()) == tinh_van + 30, "Không nhận thưởng hai lần")

	base_manager.unlock_base_for_debug()
	inventory.add_item(&"wooden_plank", 8)
	inventory.add_item(&"processed_stone", 4)
	base_manager.set("is_build_mode", true)
	_check(base_manager.place_building(&"storage", Vector2i(52, 35)), "Xây kho chứa")
	base_manager.set("is_build_mode", false)
	_check(_status(CHAIN[1]) == READY, "Xây kho hoàn thành nhiệm vụ")

	# Việc làm trước khi nhiệm vụ mở vẫn được tính.
	wallet.add_tinh_van(10)
	gacha.pull(1)
	_check(_status(CHAIN[2]) == LOCKED, "Quay trước khi mở không đổi trạng thái nhiệm vụ khóa")
	_quests.complete_quest(CHAIN[1])
	_check(_status(CHAIN[2]) == READY, "Đã quay từ trước thì nhiệm vụ triệu hồi được tính ngay")
	_quests.complete_quest(CHAIN[2])
	_check(_status(CHAIN[3]) == ACTIVE, "Mở nhiệm vụ khảo sát")

	# Khám phá vùng bằng cách đi vào thật.
	tinh_van = int(wallet.get_tinh_van())
	player.global_position = Vector2(1500, 200)
	await _wait_until(func() -> bool: return _world.is_region_discovered(&"zone_forest"), 30)
	_check(_world.is_region_discovered(&"zone_forest") and int(wallet.get_tinh_van()) == tinh_van + 10, "Vào Khu Rừng được khám phá và thưởng theo giai đoạn")
	player.global_position = Vector2(1500, 210)
	await physics_frame
	_check(int(wallet.get_tinh_van()) == tinh_van + 10, "Đi lại khu cũ không thưởng thêm")
	_check(await _save(save_manager), "Lưu giữa chuỗi nhiệm vụ")
	var saved: Dictionary = _quests.to_dict()
	for position_hint in [Vector2(2200, 200), Vector2(1500, 500)]:
		player.global_position = position_hint
		await physics_frame
		await physics_frame
		await physics_frame
	_check(_world.is_region_discovered(&"zone_iron_mine"), "Khám phá thêm mỏ sắt")
	_check(await _load(save_manager) and _quests.to_dict() == saved, "F9 khôi phục đúng tiến độ nhiệm vụ")
	_check(not _world.is_region_discovered(&"zone_iron_mine") and _status(CHAIN[3]) == ACTIVE, "F9 trả lại vùng chưa khám phá")
	for region_id in [&"zone_stone_mine", &"zone_iron_mine", &"zone_gold_mine"]:
		_world.discover_region(region_id)
	_check(_status(CHAIN[3]) == READY, "Khám phá đủ 4 khu thì sẵn sàng trả")
	_quests.complete_quest(CHAIN[3])

	# Đợt quái thật kết thúc nhiệm vụ phòng thủ.
	_check(_status(CHAIN[4]) == ACTIVE, "Mở nhiệm vụ phòng thủ")
	event_bus.raid_repelled.emit(1)
	_check(_status(CHAIN[4]) == READY, "Đẩy lùi đợt quái hoàn thành nhiệm vụ")
	_quests.complete_quest(CHAIN[4])

	# Di tích và lời kết.
	_check(_status(CHAIN[5]) == ACTIVE, "Mở nhiệm vụ di tích cuối")
	var archive: Node = scene.get_node("AncientArchive")
	_check(archive.get("region_id") == &"ancient_archive", "Có di tích trong Mỏ Vàng")
	archive.call("_discover")
	_check(_status(CHAIN[5]) == READY, "Khám phá di tích hoàn thành mục tiêu")
	tinh_van = int(wallet.get_tinh_van())
	_check(_quests.complete_quest(CHAIN[5]) and int(wallet.get_tinh_van()) == tinh_van + 150 and _world.get_flag(&"demo_completed") == true, "Hoàn thành chuỗi thưởng 150 Tinh Vẫn và ghi cờ kết thúc")
	_check(narrative.visible and paused and str(narrative.get("_text_label").text).contains("chưa có dữ liệu"), "Hiện lời kết và không tự đặt ra nguyên nhân thảm họa")
	narrative.finish()
	_check(not paused, "Đóng lời kết thì chơi tiếp được")

	# Save cũ chưa có nhiệm vụ Hệ thống.
	_check(await _save(save_manager), "Lưu sau khi xong chuỗi")
	_check(_rewrite_slot(func(data: Dictionary) -> void:
		for quest_id in CHAIN:
			data["quest_manager"]["quest_status"].erase(str(quest_id))
			data["quest_manager"]["quest_progress"].erase(str(quest_id))), "Giả lập save cũ")
	_check(await _load(save_manager), "Save cũ vẫn tải được")
	_check(_status(CHAIN[0]) == ACTIVE and _status(CHAIN[5]) == LOCKED, "Save cũ bắt đầu chuỗi từ đầu")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))
	_finish()

func _status(quest_id: StringName) -> int:
	return int(_quests.get_quest_status(quest_id))

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
	print("Week 9 story checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
