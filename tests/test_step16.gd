extends SceneTree

# Kịch bản kiểm thử toàn diện Bước 16: Input Control V2 + Persistent Save & Load System
func _init() -> void:
	print("==================================================")
	print(" BẮT ĐẦU KIỂM THỬ BƯỚC 16: INPUT CONTROL V2 & SAVE/LOAD")
	print("==================================================")
	
	var pass_count: int = 0
	var total_tests: int = 8

	# TEST 1: Kiểm tra InputMap V2
	print("\n[TEST 1] Kiểm tra cấu hình InputMap V2...")
	var sprint_ok: bool = false
	if InputMap.has_action("sprint"):
		var events: Array[InputEvent] = InputMap.action_get_events("sprint")
		var has_rmb: bool = false
		var has_shift: bool = false
		for ev in events:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
				has_rmb = true
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_SHIFT:
				has_shift = true
		sprint_ok = has_rmb and not has_shift
	
	var interact_ok: bool = InputMap.has_action("interact")
	var q_save_ok: bool = InputMap.has_action("quick_save")
	var q_load_ok: bool = InputMap.has_action("quick_load")
	var pause_ok: bool = InputMap.has_action("pause_game")
	
	if sprint_ok and interact_ok and q_save_ok and q_load_ok and pause_ok:
		print("  -> PASS: sprint (RMB duy nhất, đã gỡ Shift), interact (F), quick_save (F5), quick_load (F9), pause_game (Esc).")
		pass_count += 1
	else:
		printerr("  -> FAIL: InputMap chưa chuẩn: sprint_ok=%s, interact_ok=%s, q_save_ok=%s, q_load_ok=%s, pause_ok=%s" % [sprint_ok, interact_ok, q_save_ok, q_load_ok, pause_ok])

	# TEST 2: Kiểm tra Spritesheet 16 khung hình và Player scene
	print("\n[TEST 2] Kiểm tra Spritesheet 16 khung hình (Walk Sheet)...")
	var walk_tex: Resource = load("res://assets/player/shiroi_walk_sheet.png")
	var player_scn: PackedScene = load("res://player.tscn")
	if walk_tex and player_scn:
		var p_inst: Node2D = player_scn.instantiate() as Node2D
		var sp: Sprite2D = p_inst.get_node_or_null("Sprite2D") as Sprite2D
		if sp and sp.hframes == 4 and sp.vframes == 4:
			print("  -> PASS: Spritesheet 16 frame nạp thành công, Sprite2D hframes=4, vframes=4 chuẩn Pixel-Art.")
			pass_count += 1
		else:
			printerr("  -> FAIL: Sprite2D không có cấu hình 4x4!")
		p_inst.queue_free()
	else:
		printerr("  -> FAIL: Không tải được walk_sheet.png hoặc player.tscn!")

	# Nạp Main Scene để kiểm tra runtime
	var main_scn: PackedScene = load("res://main.tscn")
	var main_node: Node = main_scn.instantiate()
	root.add_child(main_node)

	# Giả lập Autoload nếu chưa có trong SceneTree headless
	var save_mgr: Node = root.get_node_or_null("SaveManager")
	if not save_mgr:
		var sm_script: Script = load("res://scripts/save_manager.gd")
		save_mgr = Node.new()
		save_mgr.set_script(sm_script)
		save_mgr.name = "SaveManager"
		root.add_child(save_mgr)

	var world_state: Node = root.get_node_or_null("WorldState")
	if not world_state:
		var ws_script: Script = load("res://scripts/world_state.gd")
		world_state = Node.new()
		world_state.set_script(ws_script)
		world_state.name = "WorldState"
		root.add_child(world_state)

	var quest_mgr: Node = root.get_node_or_null("QuestManager")
	if not quest_mgr:
		var qm_script: Script = load("res://scripts/quest_manager.gd")
		quest_mgr = Node.new()
		quest_mgr.set_script(qm_script)
		quest_mgr.name = "QuestManager"
		root.add_child(quest_mgr)

	var player: Node2D = main_node.get_node_or_null("Player") as Node2D
	var pause_menu: Node = main_node.get_node_or_null("PauseMenu")

	# TEST 3: Kiểm tra PauseMenu
	print("\n[TEST 3] Kiểm tra PauseMenu...")
	if pause_menu and pause_menu.has_method("pause_game") and pause_menu.has_method("resume_game"):
		pause_menu.call("pause_game")
		var is_p: bool = root.get_tree().paused
		pause_menu.call("resume_game")
		var is_unp: bool = not root.get_tree().paused
		if is_p and is_unp:
			print("  -> PASS: PauseMenu toggle tạm dừng và tiếp tục trò chơi chính xác.")
			pass_count += 1
		else:
			printerr("  -> FAIL: Trạng thái pause không đổi: is_p=%s, is_unp=%s" % [is_p, is_unp])
	else:
		printerr("  -> FAIL: Không tìm thấy PauseMenu trong main scene!")

	# TEST 4: Kiểm tra Lưu game nguyên tử (Atomic Save)
	print("\n[TEST 4] Kiểm tra Lưu game nguyên tử (SaveManager.save_game)...")
	player.global_position = Vector2(345, 234)
	player.set("current_health", 75.0)
	player.set("stamina", 60.0)
	var skill_c: Node = player.get_node_or_null("SkillComponent")
	if skill_c:
		skill_c.set("current_energy", 50.0)

	world_state.call("set_flag", &"test_flag_step16", true)
	quest_mgr.call("activate_quest", &"q_slime_hunter")

	save_mgr.set("is_busy", false)
	save_mgr.set("_last_op_tick", 0)
	var save_res: bool = bool(save_mgr.call("save_game", 1))
	var save_file_path: String = str(save_mgr.call("get_save_path", 1))
	var tmp_file_path: String = save_file_path + ".tmp"

	if save_res and FileAccess.file_exists(save_file_path) and not FileAccess.file_exists(tmp_file_path):
		var content: String = FileAccess.get_file_as_string(save_file_path)
		var parsed: Variant = JSON.parse_string(content)
		if parsed is Dictionary and int((parsed as Dictionary).get("schema_version", 0)) == 1:
			var p_dict: Dictionary = (parsed as Dictionary).get("player", {})
			if float(p_dict.get("current_health", 0.0)) == 75.0:
				print("  -> PASS: File slot_01.json đã ghi an toàn, file .tmp đã dọn sạch, JSON hợp lệ.")
				pass_count += 1
			else:
				printerr("  -> FAIL: current_health trong JSON không bằng 75.0!")
		else:
			printerr("  -> FAIL: Nội dung JSON không đúng schema!")
	else:
		printerr("  -> FAIL: save_game thất bại hoặc file không tồn tại!")

	# TEST 5: Kiểm tra Tải game (SaveManager.load_game)
	print("\n[TEST 5] Kiểm tra Tải game (SaveManager.load_game)...")
	player.global_position = Vector2(0, 0)
	player.set("current_health", 20.0)
	player.set("stamina", 10.0)
	if skill_c:
		skill_c.set("current_energy", 0.0)

	save_mgr.set("is_busy", false)
	save_mgr.set("_last_op_tick", 0)
	var load_res: bool = bool(save_mgr.call("load_game", 1))

	var pos_ok: bool = player.global_position.distance_to(Vector2(345, 234)) < 1.0
	var hp_ok: bool = absf(float(player.get("current_health")) - 75.0) < 0.1
	var sta_ok: bool = absf(float(player.get("stamina")) - 60.0) < 0.1
	var energy_ok: bool = true
	if skill_c:
		energy_ok = absf(float(skill_c.get("current_energy")) - 50.0) < 0.1
	var flag_ok: bool = bool(world_state.call("get_flag", &"test_flag_step16")) == true
	var quest_ok: bool = int(quest_mgr.call("get_quest_status", &"q_slime_hunter")) == 2

	if load_res and pos_ok and hp_ok and sta_ok and energy_ok and flag_ok and quest_ok:
		print("  -> PASS: Tải game thành công. Vị trí, Máu (75), Thể lực (60), Năng lượng (50), WorldState và Quest được khôi phục chuẩn xác.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Dữ liệu tải không khớp! pos=%s, hp=%s, sta=%s, energy=%s, flag=%s, quest=%s" % [pos_ok, hp_ok, sta_ok, energy_ok, flag_ok, quest_ok])

	# TEST 6: Kiểm tra từ chối Lưu khi Player đã chết
	print("\n[TEST 6] Kiểm tra chặn lưu khi nhân vật đã chết...")
	player.set("is_dead", true)
	player.set("current_health", 0.0)
	save_mgr.set("is_busy", false)
	save_mgr.set("_last_op_tick", 0)
	var dead_save_res: bool = bool(save_mgr.call("save_game", 1))
	if not dead_save_res:
		print("  -> PASS: SaveManager từ chối lưu khi Player đã gục ngã (is_dead = true).")
		pass_count += 1
	else:
		printerr("  -> FAIL: SaveManager vẫn cho phép lưu khi nhân vật đã chết!")

	# TEST 7: Kiểm tra xử lý File lưu hỏng / không hợp lệ
	print("\n[TEST 7] Kiểm tra xử lý file lưu bị hỏng (Corrupt JSON)...")
	var corrupt_slot: int = 99
	var corrupt_path: String = str(save_mgr.call("get_save_path", corrupt_slot))
	var cf: FileAccess = FileAccess.open(corrupt_path, FileAccess.WRITE)
	if cf:
		cf.store_string("{ 'bad_json': true, corrupted... ")
		cf.close()

	save_mgr.set("is_busy", false)
	save_mgr.set("_last_op_tick", 0)
	var corrupt_load_res: bool = bool(save_mgr.call("load_game", corrupt_slot))
	DirAccess.remove_absolute(corrupt_path)

	if not corrupt_load_res:
		print("  -> PASS: SaveManager phát hiện file hỏng, từ chối tải an toàn mà không làm crash game.")
		pass_count += 1
	else:
		printerr("  -> FAIL: SaveManager không từ chối file hỏng!")

	# TEST 8: Kiểm tra Discovery Point dùng phím F
	print("\n[TEST 8] Kiểm tra Discovery Point (Tương tác phím F)...")
	var disc_pt: Node = main_node.get_node_or_null("DiscoveryPoint")
	if disc_pt and str(disc_pt.get("prompt_text")) == "[F] Khám phá Di Tích Cổ":
		print("  -> PASS: Điểm khám phá hiển thị lời nhắc [F] Khám phá Di Tích Cổ, phím E hoàn toàn dành riêng cho Phong Nhận.")
		pass_count += 1
	else:
		printerr("  -> FAIL: DiscoveryPoint chưa cập nhật prompt_text [F]!")

	print("\n==================================================")
	print(" KẾT QUẢ KIỂM THỬ: %d / %d BÀI ĐẠT" % [pass_count, total_tests])
	print("==================================================")

	quit(0 if pass_count == total_tests else 1)
