extends SceneTree

# Tuần 7: đội hình, đổi người, chỉ số riêng, phối hợp nguyên tố, gục, save/load và UI.
const TEST_SLOT := 95
const HERO := &"protagonist"
const FIRE := &"gacha_char_01"
const WATER := &"gacha_char_02"
const WIND := &"gacha_char_03"

var _passed := 0
var _total := 0
var _party: Node
var _player: Node2D
var _skill: Node
var _deaths := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	_party = root.get_node("PartyManager")
	var gacha := root.get_node("GachaManager")
	var save_manager := root.get_node("SaveManager")
	_player = scene.get_node("Player")
	_skill = _player.get_node("SkillComponent")
	_player.player_died.connect(func(): _deaths += 1)

	# Giữ một slime đứng yên làm mục tiêu, đưa các kẻ địch khác ra xa.
	var slime: Node2D = scene.get_node("Slime1")
	for node in get_nodes_in_group("enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node != slime:
			node.global_position = Vector2(-5000, -5000)
	slime.set("max_health", 100000.0)
	slime.set("current_health", 100000.0)
	slime.global_position = _player.global_position + Vector2(30, 0)

	# Đội hình.
	_check(_party.get_party() == [HERO] and _party.get_active_id() == HERO, "Đội mặc định chỉ có nhân vật chính")
	_check(not _party.try_switch(1)["ok"], "Không đổi được sang ô trống")
	_check(not _party.add_member(FIRE), "Không thêm được nhân vật chưa sở hữu")
	gacha.debug_unlock_all()
	_check(_party.add_member(FIRE) and _party.add_member(WATER), "Thêm được hai nhân vật đã sở hữu")
	_check(not _party.add_member(WIND) and _party.get_party().size() == 3, "Đội tối đa 3 người")
	_check(not _party.add_member(FIRE), "Không thêm trùng nhân vật")
	_check(not _party.remove_member(HERO), "Không bỏ được nhân vật chính")

	# Đổi người và chỉ số riêng.
	var result: Dictionary = _party.try_switch(1)
	_check(result["ok"] and _party.get_active_id() == FIRE, "Đổi sang ô 2")
	_check(is_equal_approx(_player.get("attack_damage"), 26.0) and is_equal_approx(_player.get("max_health"), 110.0), "Nhận chỉ số của nhân vật mới")
	_check(is_equal_approx(_player.get("current_health"), 110.0), "Nhân vật mới có đầy máu của mình")
	_check(is_equal_approx(_skill.get("e_damage"), 39.0) and str(_skill.get("e_skill_name")) == "Hỏa Nhận", "Kỹ năng theo nguyên tố và sức tấn công")
	_check(_player.get_node("Sprite2D").self_modulate != Color.WHITE, "Màu nhân vật thay đổi")
	_check(not _party.try_switch(0)["ok"] and _party.get_active_id() == FIRE, "Đang hồi đổi người thì không đổi được")
	_ready_switch()
	_check(not _party.try_switch(1)["ok"], "Không đổi sang người đang trên sân")

	# Trạng thái riêng từng người.
	_player.take_damage(30.0)
	_skill.add_energy(40.0)
	_skill.set("e_cooldown_timer", 5.0)
	_switch(0)
	_check(is_equal_approx(_player.get("current_health"), 100.0) and is_equal_approx(_skill.get("current_energy"), 0.0), "Nhân vật chính giữ máu và năng lượng riêng")
	_check(is_equal_approx(_skill.get("e_cooldown_timer"), 0.0), "Hồi chiêu là riêng từng người")
	_party.call("_process", 2.0)
	_switch(1)
	_check(is_equal_approx(_player.get("current_health"), 80.0) and is_equal_approx(_skill.get("current_energy"), 40.0), "Quay lại vẫn còn máu và năng lượng cũ")
	_check(is_equal_approx(_skill.get("e_cooldown_timer"), 3.0), "Hồi chiêu vẫn chạy khi không ở trên sân")

	# Phối hợp nguyên tố.
	var combos: Array = []
	_party.combo_triggered.connect(func(combo_name: String, hits: int): combos.append([combo_name, hits]))
	var hp_before := float(slime.get("current_health"))
	_skill.set("e_cooldown_timer", 0.0)
	_party.notify_combat_action()
	result = _switch(0)
	_check(result["combo"] == "Hỏa Phong" and combos == [["Hỏa Phong", 1]], "Lửa sang Gió kích hoạt Hỏa Phong trúng 1 mục tiêu")
	_check(is_equal_approx(hp_before - float(slime.get("current_health")), 60.0), "Sát thương phối hợp đúng 60")
	_party.notify_combat_action()
	result = _switch(2)
	_check(result["combo"] == "", "Đang hồi phối hợp thì không kích hoạt")
	_party.set("_combat_window", 0.0)
	_switch(0)
	_party.set("_combo_cooldown", 0.0)
	_party.notify_combat_action()
	hp_before = float(slime.get("current_health"))
	result = _switch(2)
	_check(result["combo"] == "Sương Phong" and is_equal_approx(hp_before - float(slime.get("current_health")), 24.0), "Gió sang Nước: sát thương theo sức tấn công người vào")
	_check(bool(slime.get_node("StatusEffectComponent").get("is_slowed")), "Sương Phong làm chậm kẻ địch")
	_party.set("_combo_cooldown", 0.0)
	_party.set("_combat_window", 0.0)
	_check(_switch(0)["combo"] == "", "Chưa đánh gần đây thì không kích hoạt")
	_party.notify_combat_action()
	_party.call("_process", 5.0)
	_check(_switch(2)["combo"] == "", "Hết cửa sổ thời gian thì không kích hoạt")
	_check(_party.remove_member(WATER) and _party.get_active_id() == HERO, "Bỏ người đang trên sân thì đổi người khác ra")
	_check(_party.add_member(WIND), "Thêm nhân vật cùng nguyên tố Gió")
	_party.notify_combat_action()
	_check(_switch(2)["combo"] == "", "Cùng nguyên tố không phối hợp")
	_switch(1)
	_party.set("_combo_cooldown", 0.0)
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(6, 200)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	scene.add_child(wall)
	wall.global_position = _player.global_position + Vector2(15, 0)
	await physics_frame
	await physics_frame
	_party.notify_combat_action()
	hp_before = float(slime.get("current_health"))
	result = _switch(2)
	_check(result["combo"] != "" and is_equal_approx(hp_before, float(slime.get("current_health"))), "Phối hợp không xuyên tường")
	wall.free()

	# Tăng bậc.
	_switch(1)
	gacha.get("_roster")[FIRE]["souls"] = 1
	_check(gacha.rank_up(FIRE) and is_equal_approx(_player.get("attack_damage"), 28.6) and is_equal_approx(_player.get("max_health"), 121.0), "Tăng bậc tăng chỉ số người đang trên sân")

	# Save/Load.
	_player.set("current_health", 77.0)
	_skill.set("current_energy", 55.0)
	_check(await _save(save_manager), "Lưu game có tổ đội")
	var saved: Dictionary = _party.to_dict()
	_switch(0)
	_party.remove_member(WIND)
	_check(await _load(save_manager), "F9 tải lại tổ đội")
	_check(_party.get_party() == [HERO, FIRE, WIND] and _party.get_active_id() == FIRE, "Khôi phục đúng đội hình và người trên sân")
	_check(is_equal_approx(_player.get("current_health"), 77.0) and is_equal_approx(_player.get("attack_damage"), 28.6), "Khôi phục máu và chỉ số người trên sân")
	_check(is_equal_approx(_skill.get("current_energy"), 55.0) and str(_skill.get("e_skill_name")) == "Hỏa Nhận", "Khôi phục năng lượng và bộ kỹ năng")
	_check(_party.to_dict() == saved, "Dữ liệu tổ đội giống lúc lưu")
	_check(await _load(save_manager) and _party.to_dict() == saved, "Tải liên tiếp không đổi dữ liệu")

	for bad_change: Callable in [
		func(data: Dictionary) -> void: data["party"]["active_index"] = 9,
		func(data: Dictionary) -> void: data["party"]["party"] = ["protagonist", "gacha_char_01", "gacha_char_01"],
		func(data: Dictionary) -> void: data["party"]["party"] = ["gacha_char_01"],
		func(data: Dictionary) -> void: data["party"]["states"] = {"protagonist": {"hp": -1.0}}
	]:
		_check(_rewrite_slot(bad_change), "Tạo file tổ đội không hợp lệ")
		var before_bad: Dictionary = _party.to_dict()
		await create_timer(0.45).timeout
		_check(not bool(save_manager.call("load_game", TEST_SLOT)) and _party.to_dict() == before_bad, "File tổ đội lỗi bị từ chối")

	_check(_rewrite_slot(func(data: Dictionary) -> void:
		data["party"] = saved.duplicate(true)
		data["party"]["active_index"] = 2
		data["gacha"]["roster"].erase("gacha_char_03")), "Giả lập save có người chưa sở hữu")
	_check(await _load(save_manager) and _party.get_party() == [HERO, FIRE] and _party.get_active_id() == HERO, "Người chưa sở hữu bị loại khi tải")
	gacha.debug_unlock_all()

	_check(_rewrite_slot(func(data: Dictionary) -> void: data.erase("party")), "Giả lập save cũ")
	_check(await _load(save_manager) and _party.get_party() == [HERO], "Save cũ về đội chỉ có nhân vật chính")
	_check(is_equal_approx(_player.get("attack_damage"), 20.0) and is_equal_approx(_player.get("max_health"), 100.0) and str(_skill.get("e_skill_name")) == "Phong Nhận", "Save cũ dùng chỉ số gốc")

	# Gục và hồi lại.
	_check(_party.add_member(FIRE) and _party.add_member(WATER), "Lập lại đội ba người")
	_switch(1)
	_player.take_damage(99999.0)
	_check(_party.get_active_id() != FIRE and not bool(_player.get("is_dead")) and _deaths == 0, "Người trên sân gục thì tự đổi người còn sống")
	_check(_party.is_fallen(FIRE), "Ghi nhận nhân vật đã gục")
	_party.set("_switch_cooldown", 0.0)
	var fire_slot: int = _party.get_party().find(FIRE)
	var fallen_result: Dictionary = _party.try_switch(fire_slot)
	_check(not fallen_result["ok"] and str(fallen_result["reason"]).contains("gục"), "Không đổi được sang người đã gục")
	_party.call("_process", 30.0)
	_check(not _party.is_fallen(FIRE) and is_equal_approx(float(_party.get_member_status(FIRE)["hp"]), 121.0 * 0.3), "Hồi lại sau 30 giây với 30% máu")
	for _i in 3:
		_player.take_damage(99999.0)
	_check(bool(_player.get("is_dead")) and _deaths == 1, "Cả đội gục thì kết thúc như cũ")
	_party.call("_process", 40.0)
	_check(_party.is_fallen(_party.get_active_id()), "Không tự hồi khi đang ở màn thua")
	_player.set("is_dead", false)
	_party.bind_player(_player)
	_check(not _party.is_fallen(_party.get_active_id()) and is_equal_approx(_player.get("current_health"), _player.get("max_health")), "Chơi lại thì cả đội hồi đầy")

	# Input và UI.
	var ui: Node = scene.get_node("PartyUI")
	_check(InputMap.has_action("open_party") and InputMap.has_action("party_slot_3"), "Có phím tổ đội")
	_party.set("_switch_cooldown", 0.0)
	var target_slot := (int(_party.get_active_slot()) + 1) % 3
	var event := InputEventAction.new()
	event.action = "party_slot_%d" % (target_slot + 1)
	event.pressed = true
	_player._unhandled_input(event)
	_check(_party.get_active_slot() == target_slot, "Phím số đổi đúng ô")
	await process_frame
	_check(ui.get("_hud_rows").get_child_count() == 3, "Dải HUD có đủ 3 người")
	ui.set_party_visible(true)
	await process_frame
	_check(ui.is_open() and paused and ui.get("_party_list").get_child_count() == 3, "Mở bảng tổ đội và tạm dừng game")
	_check(_party.remove_member(WATER), "Bỏ thành viên khi đang mở bảng")
	await process_frame
	_check(ui.get("_party_list").get_child_count() == 3 and ui.get("_hud_rows").get_child_count() == 2, "Bảng và HUD cập nhật sau khi đổi đội")
	ui.set_party_visible(false)
	await process_frame
	_check(not ui.is_open() and not paused, "Đóng bảng thì game chạy lại")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))
	_finish()

func _ready_switch() -> void:
	_party.set("_switch_cooldown", 0.0)

func _switch(slot: int) -> Dictionary:
	_ready_switch()
	return _party.try_switch(slot)

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
	print("Week 7 party checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
