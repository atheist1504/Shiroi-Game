extends SceneTree

# Tuần 6: ví, gacha 5 sao, bảo hiểm, chặn F5/F9, thưởng quest, save/load và UI.
const TEST_SLOT := 96

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
	var wallet := root.get_node("WalletManager")
	var gacha := root.get_node("GachaManager")
	var inventory := root.get_node("InventoryManager")
	var save_manager := root.get_node("SaveManager")
	var quests := root.get_node("QuestManager")
	var event_bus := root.get_node("EventBus")

	_check(not gacha.pull(1)["ok"] and int(wallet.get_tinh_van()) == 0, "Không đủ Tinh Vẫn thì không quay được")
	_check(not gacha.pull(3)["ok"], "Chỉ cho quay 1 hoặc 10 lượt")

	wallet.add_tinh_van(9)
	_check(not gacha.pull(1)["ok"] and int(wallet.get_tinh_van()) == 9, "Thiếu 1 Tinh Vẫn thì không bị trừ")
	wallet.add_tinh_van(101)
	_check(gacha.pull(1)["ok"] and int(wallet.get_tinh_van()) == 100, "Một lượt tốn đúng 10 Tinh Vẫn")
	_check(gacha.pull(10)["results"].size() == 10 and int(wallet.get_tinh_van()) == 0, "Mười lượt tốn đúng 100 Tinh Vẫn")

	# F5/F9 không đổi được kết quả.
	wallet.add_tinh_van(200)
	var wallet_state: Dictionary = wallet.to_dict()
	var gacha_state: Dictionary = gacha.to_dict()
	var inventory_state: Dictionary = JSON.parse_string(JSON.stringify(inventory.to_dict()))
	var first: Array = gacha.pull(10)["results"]
	wallet.load_from_dict(wallet_state)
	gacha.load_from_dict(gacha_state)
	inventory.load_from_dict(inventory_state)
	var second: Array = gacha.pull(10)["results"]
	_check(first == second, "Tải lại rồi quay vẫn ra đúng kết quả cũ")
	var third: Array = gacha.pull(10)["results"]
	_check(third != second, "Các lượt quay sau vẫn ra kết quả khác")

	# Bảo toàn vật phẩm và vàng.
	wallet.add_tinh_van(100)
	var gold_before := int(wallet.get_gold())
	var wood_before := int(inventory.get_item_count(&"wood"))
	var results: Array = gacha.pull(10)["results"]
	var expected_gold := 0
	var expected_wood := 0
	for entry in results:
		if entry["type"] == "gold":
			expected_gold += int(entry["amount"])
		elif entry["type"] == "item":
			expected_gold += int(entry["converted_gold"])
			if entry["item_id"] == &"wood":
				expected_wood += int(entry["amount"])
	_check(int(wallet.get_gold()) - gold_before == expected_gold, "Vàng nhận khớp đúng kết quả quay")
	_check(int(inventory.get_item_count(&"wood")) - wood_before == expected_wood, "Vật phẩm nhận khớp đúng kết quả quay")

	# Tỉ lệ và bảo hiểm trên mẫu lớn.
	wallet.add_tinh_van(30000)
	var since_last := 0
	var max_gap := 0
	var five_stars := 0
	var loot_kinds := {}
	for _i in 3000:
		var entry: Dictionary = gacha.pull(1)["results"][0]
		since_last += 1
		if entry["type"] == "character":
			five_stars += 1
			max_gap = maxi(max_gap, since_last)
			since_last = 0
		else:
			loot_kinds[entry.get("item_id", &"gold")] = true
	var rate := float(five_stars) / 3000.0
	_check(max_gap <= 40, "Không lượt nào vượt quá bảo hiểm 40 (dài nhất %d)" % max_gap)
	_check(rate > 0.025 and rate < 0.05, "Tỉ lệ 5 sao đúng khoảng mong đợi (%.3f)" % rate)
	_check(loot_kinds.size() == 6, "Ra đủ vàng và 5 loại nguyên liệu")
	var owned := 0
	for character in gacha.get_characters():
		if gacha.is_owned(character["id"]):
			owned += 1
	_check(owned == 5, "Mẫu lớn sở hữu đủ 5 nhân vật")

	# Trùng nhân vật cho Tinh Hồn, Tinh Hồn tăng bậc.
	var character_id: StringName = gacha.get_characters()[0]["id"]
	var souls := int(gacha.get_souls(character_id))
	_check(souls > 0, "Quay trùng nhận Tinh Hồn")
	var speed_before := float(gacha.get_work_speed(character_id))
	_check(gacha.rank_up(character_id) and int(gacha.get_souls(character_id)) == souls - 1 and int(gacha.get_rank(character_id)) == 1, "Tăng bậc tiêu 1 Tinh Hồn")
	_check(float(gacha.get_work_speed(character_id)) > speed_before, "Tăng bậc làm tăng tốc độ làm việc")
	_check(not gacha.rank_up(&"khong_ton_tai"), "Không tăng bậc nhân vật không tồn tại")

	# Túi đầy thì đổi thành vàng.
	inventory.call("_init_empty_slots")
	while int(inventory.add_item(&"wood", 99)) == 0:
		pass
	for item_id in [&"stone", &"herb", &"slime_gel", &"wind_crystal"]:
		_check(not bool(inventory.can_add_item(item_id, 1)), "Túi đã đầy trước khi quay: " + str(item_id))
	wallet.add_tinh_van(100)
	var lost := false
	for entry in gacha.pull(10)["results"]:
		if entry["type"] == "item" and int(entry["amount"]) != 0 and int(entry["converted_gold"]) == 0:
			lost = true
		if entry["type"] == "item" and int(entry["converted_gold"]) <= 0:
			lost = true
	_check(not lost, "Túi đầy: nguyên liệu được đổi hết thành vàng")
	inventory.call("_init_empty_slots")

	# Thưởng nhiệm vụ: theo giai đoạn và khi hoàn thành, chỉ một lần.
	var quest_wallet_before := int(wallet.get_tinh_van())
	_check(bool(quests.activate_quest(&"main_clear_slimes")), "Nhận nhiệm vụ Thanh Trừng Slime")
	event_bus.enemy_defeated.emit(&"slime", &"forest_clearing")
	_check(int(wallet.get_tinh_van()) == quest_wallet_before + 10, "Giết slime 1 thưởng 10 Tinh Vẫn theo giai đoạn")
	event_bus.enemy_defeated.emit(&"slime", &"forest_clearing")
	_check(int(wallet.get_tinh_van()) == quest_wallet_before + 20, "Giết slime 2 thưởng thêm 10 Tinh Vẫn")
	event_bus.enemy_defeated.emit(&"slime", &"forest_clearing")
	_check(int(wallet.get_tinh_van()) == quest_wallet_before + 20, "Slime 3 không có thưởng giai đoạn")
	_check(bool(quests.complete_quest(&"main_clear_slimes")) and int(wallet.get_tinh_van()) == quest_wallet_before + 120, "Hoàn thành thưởng 100 Tinh Vẫn")
	_check(not bool(quests.complete_quest(&"main_clear_slimes")) and int(wallet.get_tinh_van()) == quest_wallet_before + 120, "Không nhận thưởng hoàn thành hai lần")

	# Save/Load thật.
	wallet.add_tinh_van(100)
	_check(await _save(save_manager), "Lưu game có ví và gacha")
	var saved_wallet: Dictionary = wallet.to_dict()
	var saved_gacha: Dictionary = gacha.to_dict()
	var after_save: Array = gacha.pull(10)["results"]
	_check(await _load(save_manager), "F9 tải lại")
	_check(wallet.to_dict() == saved_wallet and gacha.to_dict() == saved_gacha, "F9 khôi phục đúng ví, bảo hiểm và danh sách nhân vật")
	_check(gacha.pull(10)["results"] == after_save, "Sau F9 kết quả quay vẫn như cũ")
	_check(await _load(save_manager), "Tải lại lần hai")
	_check(wallet.to_dict() == saved_wallet and gacha.to_dict() == saved_gacha, "Tải liên tiếp không nhân đôi dữ liệu")

	# File lỗi bị từ chối, không làm hỏng trạng thái.
	_check(_rewrite_slot(func(data: Dictionary) -> void: data["wallet"]["tinh_van"] = -5), "Tạo file có ví không hợp lệ")
	var before_bad: Dictionary = wallet.to_dict()
	await create_timer(0.45).timeout
	_check(not bool(save_manager.call("load_game", TEST_SLOT)) and wallet.to_dict() == before_bad, "File có ví âm bị từ chối và giữ nguyên ví")

	# Save cũ chưa có ví và gacha.
	_check(_rewrite_slot(func(data: Dictionary) -> void:
		data.erase("wallet")
		data.erase("gacha")), "Giả lập save cũ")
	_check(await _load(save_manager), "Save cũ vẫn tải được")
	_check(int(wallet.get_tinh_van()) == 0 and int(wallet.get_gold()) == 0 and int(gacha.get_pity()) == 0 and not gacha.is_owned(character_id), "Save cũ bắt đầu với ví rỗng và chưa có nhân vật")

	# UI.
	var ui: Node = scene.get_node("GachaUI")
	_check(InputMap.has_action("open_gacha"), "Có phím mở gacha")
	wallet.add_tinh_van(100)
	ui.set_gacha_visible(true)
	await process_frame
	_check(ui.visible and paused, "Mở UI gacha và tạm dừng game")
	var count_before := int(wallet.get_tinh_van())
	ui.pull_and_show(10)
	_check(int(wallet.get_tinh_van()) == count_before - 100 and ui.get("_results_list").get_child_count() == 10, "UI quay 10 lượt hiện đủ 10 kết quả")
	ui.pull_and_show(1)
	_check(str(ui.get("_status_label").text).contains("Không đủ"), "UI báo khi không đủ Tinh Vẫn")
	ui.set_gacha_visible(false)
	await process_frame
	_check(not ui.visible and not paused, "Đóng UI thì game chạy lại")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))
	_finish()

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
	print("Week 6 gacha checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
