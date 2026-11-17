extends SceneTree

# Màn đêm đầu: tập phím trên cọc gỗ lúc chạng vạng, Enter vào đêm, bầy sói, nhặt răng nanh, trời sáng.
# Đòn đánh được gọi theo đúng thứ tự như trong game (take_damage rồi skill_hit),
# không mô phỏng chuột và phím thật.
const TEST_SLOT := 92
const QUEST := &"sys_00_first_night"
const ACTIVE := 2
const LOCKED := 0
const COMPLETED := 4

var _passed := 0
var _total := 0
var _quests: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	_quests = root.get_node("QuestManager")
	var wallet := root.get_node("WalletManager")
	var inventory := root.get_node("InventoryManager")
	var save_manager := root.get_node("SaveManager")
	var player: CharacterBody2D = scene.get_node("Player")
	var skill: Node = player.get_node("SkillComponent")
	var narrative: Node = scene.get_node("NarrativeUI")
	var night: Node = scene.get_node("FirstNight")
	var slime: Node = scene.get_node("Slime1")
	var boss: Node = scene.get_node("TestBoss")
	scene.get_node("NPCManager").set_process(false)
	scene.get_node("BaseRaid").set_process(false)
	player.set("max_health", 99999.0)
	player.set("current_health", 99999.0)

	_check(narrative.OPENING_PAGES[-1]["text"].contains("Sống sót đến sáng"), "Mở đầu kết bằng một dòng Hệ thống: sống sót đến sáng")
	_check(_status(QUEST) == ACTIVE and _status(&"sys_01_arrival") == LOCKED, "Nhiệm vụ đầu là Sống sót đến sáng")
	_check(night.stage == night.Stage.IDLE, "Headless không tự bắt đầu đêm")

	# Bắt đầu: trời chạng vạng, tập phím trước khi tối.
	_check(bool(night.start_if_needed()) and not night.is_dark(), "Bắt đầu thì chưa tối, vào chặng tập trước")
	await physics_frame
	_check(night.is_dusk() and scene.get_node_or_null("NightModulate") != null and player.get_node_or_null("NightLight") == null, "Lúc tập trời chạng vạng, chưa cần đèn")
	_check(not slime.is_in_group("enemies") and not slime.visible and not boss.visible, "Slime và Thủ Lĩnh Slime chưa xuất hiện")
	_check(night.stage == night.Stage.MOVE and get_nodes_in_group("first_night_wolves").is_empty(), "Tập di chuyển chưa có sói hay cọc")
	_check(str(night.get("_title_label").text).contains("Bước 1/7") and (night.get("_ui").get_child(0) as Control).custom_minimum_size.x <= 220.0, "Hướng dẫn ghi số bước, khung gọn")
	var hint: Label = night.get("_hint_label")
	_check(hint.text.contains("Space") and hint.text.contains("chuột phải"), "Hướng dẫn lướt và chạy")

	# Tập di chuyển: lướt và chạy thật bằng hàm của nhân vật.
	player.call("_start_dodge", Vector2.RIGHT)
	await physics_frame
	player.set("is_dodging", false)
	for _i in 30:
		player.velocity = Vector2(220, 0)
		night.call("_physics_process", 1.0 / 60.0)
		if night.stage != night.Stage.MOVE:
			break
	_check(night.stage == night.Stage.SWORD, "Lướt và chạy xong thì sang tập chém")
	_check(scene.position == Vector2.ZERO, "Scene chính nằm ở gốc tọa độ (không bị kéo lệch trong editor)")
	await process_frame
	var dummy: Node2D = night.get_dummy()
	_check(dummy != null and dummy.is_inside_tree() and dummy.global_position.distance_to(player.global_position) < 100.0, "Cọc gỗ dựng ngay trước mặt")
	_check(dummy != null and dummy.is_in_group("enemies") and dummy.is_in_group("no_save"), "Chiêu nhận cọc làm mục tiêu, cọc không vào save")

	# Đánh sai chiêu thì báo, không tính.
	await _hit_dummy(night, skill, "E", 1)
	_check(night.get_hit_count() == 0 and hint.text.contains("bước này cần chuột trái"), "Đánh cọc sai chiêu thì báo chiêu đúng")
	await _hit_dummy(night, skill, "Sword", 2)
	_check(night.stage == night.Stage.SWORD and hint.text.contains("2/3"), "Chém đếm từng lần trúng")
	await _hit_dummy(night, skill, "Sword", 1)
	_check(night.stage == night.Stage.SKILL_E and night.get_dummy() == dummy, "Chém trúng 3 lần thì sang E, vẫn cọc cũ")
	_check(not bool(dummy.get("is_dead")), "Cọc không gãy")
	# Bắn lưỡi gió thật (va chạm vật lý) vào cọc, nối như try_cast_e().
	var blade: Node2D = (skill.get("wind_blade_scene") as PackedScene).instantiate()
	blade.hit_enemy.connect(Callable(skill, "_on_e_hit_enemy"))
	scene.add_child(blade)
	blade.setup(dummy.global_position - Vector2(50, 0), Vector2.RIGHT)
	for _i in 30:
		await physics_frame
		if night.stage != night.Stage.SKILL_E:
			break
	_check(night.stage == night.Stage.SKILL_R, "Lưỡi gió E bắn thật trúng cọc, không bị coi là tường")
	if night.stage == night.Stage.SKILL_E:
		await _hit_dummy(night, skill, "E", 1)
	_check(night.stage == night.Stage.SKILL_R and float(skill.get("current_energy")) >= float(skill.get("r_energy_cost")), "E trúng thì sang R, được nạp năng lượng")

	# Lưu giữa lúc tập: cọc không vào save, tải lại thì tập lại từ đầu.
	_check(await _save(save_manager), "Lưu giữa lúc tập")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_slot_path()))
	_check(not data.get("enemy_states", {}).has("first_night"), "Cọc và sói đêm đầu không được lưu")
	_check(await _load(save_manager), "Tải lại giữa lúc tập")
	await process_frame
	_check(night.stage == night.Stage.MOVE and night.is_dusk(), "Tải lại thì tập lại từ đầu")
	_check(get_nodes_in_group("first_night_wolves").is_empty(), "Không còn cọc thừa sau khi tải")
	_check(not slime.is_in_group("enemies"), "Slime vẫn ẩn sau khi tải giữa lúc tập")
	night.set("_dodged", true)
	night.set("_sprint_time", 1.0)
	night.call("_physics_process", 0.0)
	await process_frame
	await _hit_dummy(night, skill, "Sword", 3)
	await _hit_dummy(night, skill, "E", 1)
	await _hit_dummy(night, skill, "R", 1)
	_check(night.stage == night.Stage.READY and not night.is_dark() and night.get_dummy() != null, "Tập xong thì chờ sẵn sàng, chưa tối, cọc còn để tập thêm")
	_check(hint.text.contains("Enter"), "Hướng dẫn nhấn Enter khi sẵn sàng")
	await _hit_dummy(night, skill, "Sword", 1)
	_check(night.stage == night.Stage.READY, "Đánh cọc thêm không làm tối trời")

	# Enter: màn đêm buông, bầy sói tới trong vùng sáng.
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	night._unhandled_input(enter)
	await physics_frame
	_check(night.stage == night.Stage.PACK and night.get_pack().size() == 4, "Nhấn Enter thì bầy 3 sói và Sói Đầu Đàn kéo đến")
	_check(night.is_dark() and player.get_node_or_null("NightLight") != null, "Trời tối hẳn, chỉ sáng quanh nhân vật")
	_check(str(night.get("_title_label").text).contains("Bước 6/7 · Bầy sói"), "Hướng dẫn chuyển sang sống sót")
	await process_frame
	_check(night.get_dummy() == null and get_nodes_in_group("first_night_wolves").size() == 4, "Cọc gỗ được dọn khi vào đêm")
	var all_in_light := true
	for wolf in night.get_pack():
		if wolf.global_position.distance_to(player.global_position) >= night.LIGHT_RADIUS:
			all_in_light = false
	_check(all_in_light, "Cả bầy sói xuất hiện trong vùng sáng, thấy được ngay")
	var alpha: Node2D = null
	for wolf in night.get_pack():
		if wolf.get("enemy_id") == &"wolf_alpha":
			alpha = wolf
	_check(alpha != null and float(alpha.get("max_health")) > 100.0, "Sói Đầu Đàn máu dày như boss")
	_check(float(night.get_pack()[0].get("max_health")) > 1.0, "Bầy sói máu bình thường, không chết một đòn")
	var alpha_position := alpha.global_position
	for wolf in night.get_pack():
		wolf.call("take_damage", 99999.0, Vector2.ZERO)
	await process_frame
	for _i in 10:
		if night.stage != night.Stage.PACK:
			break
		await physics_frame
	var fang: Node = null
	for pickup in get_nodes_in_group("pickup_items"):
		if pickup.get("item_id") == &"wolf_fang":
			fang = pickup
	_check(fang != null, "Sói rớt răng nanh")
	_check(fang != null and (fang as Node2D).global_position.distance_to(alpha_position) < 200.0, "Răng nanh rơi ngay cạnh bầy sói, không văng ra xa")
	_check(night.stage == night.Stage.LOOT and hint.text.contains("F"), "Lần đầu có đồ rơi thì hướng dẫn nhấn F")

	# Nhặt răng nanh thì trời sáng.
	var tinh_van := int(wallet.get_tinh_van())
	fang.call("_try_pickup")
	for _i in 3:
		if night.stage != night.Stage.LOOT:
			break
		await physics_frame
	_check(inventory.get_item_count(&"wolf_fang") > 0, "Răng nanh vào túi")
	_check(narrative.visible and paused and str(narrative.get("_text_label").text).contains("đêm đầu tiên đã qua"), "Màn tối và lời độc thoại")
	_check(_status(QUEST) == COMPLETED and int(wallet.get_tinh_van()) == tinh_van + 10, "Hoàn thành nhiệm vụ nhận 10 Tinh Vẫn")
	_check(not night.is_dark(), "Trời sáng, tầm nhìn mở rộng")
	_check(slime.is_in_group("enemies") and slime.visible and boss.visible, "Slime và Thủ Lĩnh Slime xuất hiện sau khi trời sáng")
	_check(_status(&"sys_01_arrival") == ACTIVE, "Nhiệm vụ kế mở")
	narrative.finish()
	_check(not paused and night.stage == night.Stage.DONE, "Đóng màn chữ thì chơi tiếp")
	_check(str(night.get("_title_label").text).contains("Nhận 10 Tinh Vẫn"), "Hệ thống báo hoàn thành, không giải thích")
	_check(not bool(night.start_if_needed()), "Đêm đầu chỉ diễn ra một lần")

	# Save có trước màn đêm đầu được coi là đã qua đêm.
	_check(await _save(save_manager), "Lưu sau đêm đầu")
	_check(_rewrite_slot(func(d: Dictionary) -> void:
		d["quest_manager"]["quest_status"].erase(str(QUEST))
		d["quest_manager"]["quest_progress"].erase(str(QUEST))), "Giả lập save cũ chưa có đêm đầu")
	_check(await _load(save_manager), "Tải save cũ")
	_check(_status(QUEST) == COMPLETED and _status(&"sys_01_arrival") == ACTIVE and not night.is_dark(), "Save cũ không phải chơi lại đêm đầu")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))
	_finish()


# Đánh cọc theo đúng thứ tự trong game: take_damage trước, skill_hit sau.
func _hit_dummy(night: Node, skill: Node, method: String, count: int) -> void:
	for i in count:
		var dummy: Node2D = night.get_dummy()
		if not dummy:
			return
		dummy.call("take_damage", 30.0, Vector2.ZERO)
		skill.skill_hit.emit(method, dummy, 30.0)
		await process_frame

func _status(quest_id: StringName) -> int:
	return int(_quests.get_quest_status(quest_id))

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
	print("First night checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
