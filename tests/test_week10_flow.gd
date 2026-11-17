extends SceneTree

# Tuần 10: chết rồi chơi lại không mất căn cứ, F9 sau khi chết, đợt quái thật mở cổng Tàn Tích.
const TEST_SLOT := 91

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
	var base := root.get_node("BaseManager")
	var inventory := root.get_node("InventoryManager")
	var save_manager := root.get_node("SaveManager")
	var quests := root.get_node("QuestManager")
	var party := root.get_node("PartyManager")
	var gacha := root.get_node("GachaManager")
	var wallet := root.get_node("WalletManager")
	var player: CharacterBody2D = scene.get_node("Player")
	var hud: Node = scene.get_node("UI")
	var raid: Node = scene.get_node("BaseRaid")
	var gate: Node = scene.get_node("Environment/RuinsGate")
	var panel: Control = hud.get_node("GameOverPanel")
	var sprite: Sprite2D = player.get_node("Sprite2D")
	raid.set_process(false)
	for node in get_nodes_in_group("enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.global_position = Vector2(100, 100)
	scene.get_node("NPCManager").set_process(false)

	base.unlock_base_for_debug()
	inventory.add_item(&"wooden_plank", 4)
	inventory.add_item(&"processed_stone", 2)
	base.set("is_build_mode", true)
	_check(base.place_building(&"storage", Vector2i(52, 35)), "Xây kho chứa")
	base.set("is_build_mode", false)
	gacha.debug_unlock_all()
	party.add_member(&"gacha_char_01")
	var worker_manager: Node = scene.get_node("WorkerManager")
	worker_manager.sync_workers()
	var worker_count: int = worker_manager.get_worker_ids().size()

	# Lưu trước để thử F9 sau khi chết.
	player.global_position = Vector2(640, 360)
	_check(await _save(save_manager), "Lưu trước khi chết")

	# Cả đội gục.
	for _i in 2:
		player.take_damage(99999.0)
	await process_frame
	_check(bool(player.get("is_dead")) and panel.visible, "Cả đội gục thì hiện bảng thua")
	await create_timer(0.7).timeout

	# Chơi lại giữ nguyên thế giới.
	hud.call("_on_retry_button_pressed")
	await process_frame
	_check(not bool(player.get("is_dead")) and not panel.visible, "Chơi lại thì nhân vật sống và tắt bảng thua")
	_check(is_equal_approx(player.get("current_health"), player.get("max_health")), "Chơi lại đầy máu")
	_check(get_nodes_in_group("placed_buildings").size() == 1, "Chơi lại không mất công trình")
	_check(worker_manager.get_worker_ids().size() == worker_count, "Chơi lại không mất thợ")
	_check(party.get_party().size() == 2, "Chơi lại giữ đội hình")
	_check(is_equal_approx(sprite.modulate.a, 1.0), "Nhân vật hết mờ sau khi chơi lại")
	_check(not party.is_fallen(party.get_active_id()), "Không còn ai bị tính là gục")
	player.global_position = Vector2(640, 400)
	await physics_frame
	var before := player.global_position
	player.velocity = Vector2.ZERO
	player.call("heal", 1.0)
	_check(player.global_position.distance_to(before) < 1.0 and player.get("current_health") > 0.0, "Nhân vật hoạt động bình thường sau khi hồi sinh")

	# F9 sau khi chết.
	for _i in 2:
		player.take_damage(99999.0)
	await create_timer(0.7).timeout
	_check(bool(player.get("is_dead")) and sprite.modulate.a < 0.99, "Chết lần hai, nhân vật mờ đi")
	_check(await _load(save_manager), "F9 sau khi chết")
	await process_frame
	await process_frame
	_check(not bool(player.get("is_dead")) and not panel.visible, "F9 tắt bảng thua")
	_check(is_equal_approx(sprite.modulate.a, 1.0), "F9 làm nhân vật hết mờ")
	_check(not party.is_fallen(party.get_active_id()), "F9 khôi phục đội")
	sprite = player.get_node("Sprite2D")

	# Đợt quái thật dẫn tới mở cổng Tàn Tích.
	for quest_id in [&"sys_01_arrival", &"sys_02_build", &"sys_03_summon", &"sys_04_survey"]:
		quests.set("_quest_status", _with_status(quests.get("_quest_status"), quest_id, 4))
	quests.set("_quest_status", _with_status(quests.get("_quest_status"), &"sys_05_defend", 2))
	_check(raid.start_raid(), "Bắt đầu đợt quái")
	var tinh_van := int(wallet.get_tinh_van())
	var raiders := get_nodes_in_group("raiders")
	_check(raiders.size() >= 2, "Có quái đột kích")
	for raider in raiders:
		raider.call("take_damage", 99999.0, Vector2.ZERO)
	raid.call("_process", 0.0)
	_check(not raid.is_raid_active() and int(wallet.get_tinh_van()) == tinh_van + 15, "Đợt quái kết thúc và thưởng")
	_check(int(quests.get_quest_status(&"sys_05_defend")) == 3, "Đợt quái thật hoàn thành nhiệm vụ phòng thủ")
	_check(not gate.is_open, "Chưa trả nhiệm vụ thì cổng còn đóng")
	_check(bool(quests.complete_quest(&"sys_05_defend")), "Trả nhiệm vụ phòng thủ")
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	_check(gate.is_open, "Trả nhiệm vụ thì cổng Tàn Tích mở")
	_check(int(quests.get_quest_status(&"sys_06_archive")) == 2, "Mở nhiệm vụ bản ghi cuối")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))
	_finish()

func _with_status(statuses: Dictionary, quest_id: StringName, status: int) -> Dictionary:
	statuses[quest_id] = status
	return statuses

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
	print("Week 10 flow checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
