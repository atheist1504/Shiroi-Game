extends Node

# Autoload SaveManager - Hệ thống lưu và tải game bền vững (Step 16)
signal save_started(slot_id: int)
signal save_completed(slot_id: int, success: bool, message: String)
signal load_started(slot_id: int)
signal load_completed(slot_id: int, success: bool, message: String)

const SAVE_DIR: String = "user://saves"
const DEFAULT_SLOT: int = 1
const SCHEMA_VERSION: int = 3
const GAME_VERSION: String = "1.0.0"
const OPTIONAL_AUTOLOAD_SECTIONS: Dictionary = {"world_clock": "WorldClock", "wallet": "WalletManager", "gacha": "GachaManager", "party": "PartyManager"}

var playtime_seconds: float = 0.0
var is_busy: bool = false
var _last_op_tick: int = 0

# UI Toast thông báo lưu/tải trực quan
var _toast_layer: CanvasLayer = null
var _toast_panel: PanelContainer = null
var _toast_label: Label = null
var _toast_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Luôn chạy kể cả khi Tree đang Pause
	_ensure_save_directory()
	_create_toast_ui()

func _process(delta: float) -> void:
	# Chỉ cộng thời gian chơi khi game không bị Pause
	if not get_tree().paused:
		playtime_seconds += delta

func _unhandled_input(event: InputEvent) -> void:
	# F5: Quick Save
	if event.is_action_pressed("quick_save") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5):
		quick_save()
		get_viewport().set_input_as_handled()
		return
	
	# F9: Quick Load
	if event.is_action_pressed("quick_load") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9):
		quick_load()
		get_viewport().set_input_as_handled()
		return

func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func get_save_path(slot_id: int = DEFAULT_SLOT) -> String:
	return "%s/slot_%02d.json" % [SAVE_DIR, slot_id]

func has_save_file(slot_id: int = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(get_save_path(slot_id))

# Quick Save vào Slot 1
func quick_save() -> bool:
	return save_game(DEFAULT_SLOT)

# Quick Load từ Slot 1
func quick_load() -> bool:
	return load_game(DEFAULT_SLOT)

# Thực hiện Lưu game an toàn (Atomic Write qua file tạm .tmp)
func save_game(slot_id: int = DEFAULT_SLOT) -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_op_tick < 400 or is_busy:
		return false
	_last_op_tick = now
	is_busy = true
	save_started.emit(slot_id)

	# 1. Kiểm tra trạng thái nhân vật Player
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		var root := get_tree().current_scene
		if root:
			player = root.get_node_or_null("Player") as Node2D

	if not player:
		var err_msg := "Không tìm thấy nhân vật Player để lưu!"
		_finish_save(slot_id, false, err_msg)
		return false

	if player.get("is_dead") == true or float(player.get("current_health")) <= 0.0:
		var err_msg := "Không thể lưu game khi nhân vật đã gục ngã!"
		_finish_save(slot_id, false, err_msg)
		return false

	# Chặn lưu khi đang bật trạng thái kiểm thử túi đồ (Yêu cầu 10 - Bước 17)
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.get("is_debug_testing") == true:
		var err_msg := "Không thể lưu game khi đang bật kiểm thử túi đồ! Hãy mở F3 và nhấn 'Khôi phục túi đồ' trước."
		_finish_save(slot_id, false, err_msg)
		return false

	_ensure_save_directory()

	# 2. Thu thập dữ liệu trạng thái
	var current_scene_path: String = ""
	if get_tree().current_scene:
		current_scene_path = get_tree().current_scene.scene_file_path

	var skill_comp: Node = player.get_node_or_null("SkillComponent")
	var wind_energy: float = float(skill_comp.get("current_energy")) if skill_comp else 0.0

	var anim_ctrl: Node = player.get_node_or_null("AnimationController")
	var facing: String = str(anim_ctrl.get("current_facing")) if anim_ctrl else "down"

	var player_data: Dictionary = {
		"x": player.global_position.x,
		"y": player.global_position.y,
		"current_health": float(player.get("current_health")),
		"max_health": float(player.get("max_health")),
		"stamina": float(player.get("stamina")),
		"max_stamina": float(player.get("max_stamina")),
		"wind_energy": wind_energy,
		"facing": facing
	}

	# Thu thập WorldState và QuestManager
	var world_state_dict: Dictionary = {}
	var world_state_node = get_node_or_null("/root/WorldState")
	if world_state_node and world_state_node.has_method("to_dict"):
		world_state_dict = world_state_node.to_dict()

	var quest_mgr_dict: Dictionary = {}
	var quest_mgr_node = get_node_or_null("/root/QuestManager")
	if quest_mgr_node and quest_mgr_node.has_method("to_dict"):
		quest_mgr_dict = quest_mgr_node.to_dict()

	# Thu thập Inventory
	var inv_dict: Dictionary = {}
	if inv_mgr and inv_mgr.has_method("to_dict"):
		inv_dict = inv_mgr.to_dict()

	# Thu thập tài nguyên đã thu hoạch trên bản đồ
	var harvested_nodes: Array = []
	var res_nodes = get_tree().get_nodes_in_group("resource_nodes")
	for r in res_nodes:
		if is_instance_valid(r) and r.get("is_harvested") == true:
			harvested_nodes.append(str(r.get("node_id")))

	# Thu thập vật phẩm rơi trên mặt đất chưa nhặt
	var pickups_data: Array = []
	var pickup_nodes = get_tree().get_nodes_in_group("pickup_items")
	for p in pickup_nodes:
		if is_instance_valid(p) and not p.get("is_being_picked"):
			pickups_data.append({
				"pickup_id": str(p.get("pickup_id")),
				"item_id": str(p.get("item_id")),
				"amount": int(p.get("amount")),
				"x": p.global_position.x,
				"y": p.global_position.y
			})

	# Lưu trạng thái kẻ địch theo vùng và persistent_id, không theo instance ID.
	var enemy_snapshot := _collect_enemy_states()
	if not bool(enemy_snapshot.get("ok", false)):
		_finish_save(slot_id, false, str(enemy_snapshot.get("error", "Không thể lưu trạng thái kẻ địch.")))
		return false

	var base_state: Dictionary = {}
	var base_manager := get_node_or_null("/root/BaseManager")
	if base_manager and base_manager.has_method("to_dict"):
		base_state = base_manager.to_dict()
	var npc_state: Dictionary = {}
	var npc_manager := get_tree().current_scene.get_node_or_null("NPCManager") if get_tree().current_scene else null
	if npc_manager and npc_manager.has_method("to_dict"):
		npc_state = npc_manager.call("to_dict")
	var worker_manager := get_tree().current_scene.get_node_or_null("WorkerManager") if get_tree().current_scene else null
	var worker_state: Dictionary = worker_manager.call("to_dict") if worker_manager else {}

	var save_dict: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"game_version": GAME_VERSION,
		"save_timestamp": Time.get_datetime_string_from_system(false, true),
		"playtime_seconds": playtime_seconds,
		"world_clock": _autoload_snapshot("WorldClock"),
		"wallet": _autoload_snapshot("WalletManager"),
		"gacha": _autoload_snapshot("GachaManager"),
		"party": _autoload_snapshot("PartyManager"),
		"scene": current_scene_path,
		"player": player_data,
		"world_state": world_state_dict,
		"quest_manager": quest_mgr_dict,
		"inventory": inv_dict,
		"harvested_resources": harvested_nodes,
		"ground_pickups": pickups_data,
		"enemy_states": enemy_snapshot.get("states", {}),
		"base_state": base_state,
		"npc_state": npc_state,
		"worker_state": worker_state
	}
	var save_validation := _validate_snapshot(save_dict)
	if not bool(save_validation.get("valid", false)):
		_finish_save(slot_id, false, str(save_validation.get("error", "Snapshot không hợp lệ.")))
		return false

	var json_str := JSON.stringify(save_dict, "\t")
	var main_path := get_save_path(slot_id)
	var temp_path := main_path + ".tmp"

	# 3. Ghi ra file tạm thời (.tmp) trước
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if not f:
		var err_msg := "Lỗi mở file tạm để ghi: %s" % temp_path
		_finish_save(slot_id, false, err_msg)
		return false

	f.store_string(json_str)
	f.flush()
	f.close()

	# 4. Kiểm tra tính toàn vẹn của file tạm (Verify JSON)
	var verify_content := FileAccess.get_file_as_string(temp_path)
	var parsed = JSON.parse_string(verify_content)
	if not (parsed is Dictionary) or not parsed.has("schema_version"):
		# Xóa file tạm bị hỏng nếu có
		DirAccess.remove_absolute(temp_path)
		var err_msg := "Dữ liệu lưu kiểm tra không hợp lệ, đã hủy lưu!"
		_finish_save(slot_id, false, err_msg)
		return false

	# Thay file hiện tại có rollback, không xóa bản save hợp lệ trước khi
	# bảo đảm file mới đã được ghi và kiểm tra.
	var old_path := main_path + ".replace_backup"
	var moved_old := false
	if FileAccess.file_exists(old_path):
		if not FileAccess.file_exists(main_path):
			var recover_err := DirAccess.rename_absolute(old_path, main_path)
			if recover_err != OK:
				_finish_save(slot_id, false, "Không thể khôi phục bản save cũ trước khi lưu.")
				return false
		else:
			_finish_save(slot_id, false, "Có bản save dự phòng cần được kiểm tra; không ghi đè an toàn.")
			return false
	if FileAccess.file_exists(main_path):
		var backup_err := DirAccess.rename_absolute(main_path, old_path)
		if backup_err != OK:
			DirAccess.remove_absolute(temp_path)
			_finish_save(slot_id, false, "Không thể bảo vệ file lưu cũ trước khi thay thế.")
			return false
		moved_old = true

	var ren_err := DirAccess.rename_absolute(temp_path, main_path)
	if ren_err != OK:
		if moved_old:
			DirAccess.rename_absolute(old_path, main_path)
		DirAccess.remove_absolute(temp_path)
		_finish_save(slot_id, false, "Không thể thay thế file lưu chính thức; file cũ đã được giữ lại.")
		return false
	if moved_old:
		DirAccess.remove_absolute(old_path)

	var success_msg := "Đã lưu game vào Slot %02d thành công!" % slot_id
	_finish_save(slot_id, true, success_msg)
	return true

func _finish_save(slot_id: int, success: bool, message: String) -> void:
	is_busy = false
	save_completed.emit(slot_id, success, message)
	show_toast(message, success)

# Thực hiện Tải game
func load_game(slot_id: int = DEFAULT_SLOT) -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_op_tick < 400 or is_busy:
		return false
	_last_op_tick = now
	is_busy = true
	load_started.emit(slot_id)

	var main_path := get_save_path(slot_id)
	var read_path := main_path
	if not FileAccess.file_exists(read_path) and FileAccess.file_exists(main_path + ".replace_backup"):
		read_path = main_path + ".replace_backup"
	if not FileAccess.file_exists(read_path):
		var err_msg := "Không tìm thấy file lưu Slot %02d!" % slot_id
		_finish_load(slot_id, false, err_msg)
		return false

	var content := FileAccess.get_file_as_string(read_path)
	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		var err_msg := "Dữ liệu file lưu bị lỗi hoặc hỏng!"
		_finish_load(slot_id, false, err_msg)
		return false

	var data: Dictionary = parsed

	# Kiểm tra schema version
	if int(data.get("schema_version", 0)) > SCHEMA_VERSION:
		var err_msg := "Phiên bản file lưu quá mới, không tương thích!"
		_finish_load(slot_id, false, err_msg)
		return false

	var validation := _validate_snapshot(data)
	if not bool(validation.get("valid", false)):
		var err_msg := str(validation.get("error", "File lưu không hợp lệ!"))
		_finish_load(slot_id, false, err_msg)
		return false

	# Scene hiện tại là một region duy nhất trong dự án hiện có. Không áp dữ liệu
	# của một scene khác lên runtime sai region.
	var saved_scene := str(data.get("scene", ""))
	var current_scene := get_tree().current_scene
	if saved_scene != "" and current_scene and current_scene.scene_file_path != "" and saved_scene != current_scene.scene_file_path:
		_finish_load(slot_id, false, "File lưu thuộc scene khác; chưa thể khôi phục scene này an toàn.")
		return false

	# 1. Khôi phục thời gian chơi
	playtime_seconds = float(data.get("playtime_seconds", 0.0))
	# Save cũ thiếu các khóa này sẽ nhận trạng thái mặc định.
	for section in OPTIONAL_AUTOLOAD_SECTIONS:
		var section_node := get_node_or_null("/root/" + str(OPTIONAL_AUTOLOAD_SECTIONS[section]))
		if section_node:
			section_node.call("load_from_dict", data.get(section, {}))

	# 2. Khôi phục WorldState (nạp im lặng)
	var world_state_node = get_node_or_null("/root/WorldState")
	if world_state_node and world_state_node.has_method("load_from_dict"):
		world_state_node.load_from_dict(data.get("world_state", {}))

	# 3. Khôi phục QuestManager (nạp im lặng)
	var quest_mgr_node = get_node_or_null("/root/QuestManager")
	if quest_mgr_node and quest_mgr_node.has_method("load_from_dict"):
		quest_mgr_node.load_from_dict(data.get("quest_manager", {}))

	# 4. Khôi phục InventoryManager (hỗ trợ tương thích ngược schema_version 1)
	var inv_mgr_node = get_node_or_null("/root/InventoryManager")
	if inv_mgr_node and inv_mgr_node.has_method("load_from_dict"):
		if data.has("inventory"):
			inv_mgr_node.load_from_dict(data["inventory"])
		else:
			inv_mgr_node.call("_init_empty_slots")
			inv_mgr_node.inventory_changed.emit()

	# 5. Khôi phục các công trình sau khi WorldState và Inventory đã sẵn sàng.
	if data.has("base_state"):
		var base_manager_node := get_node_or_null("/root/BaseManager")
		if base_manager_node and base_manager_node.has_method("load_from_dict"):
			if not bool(base_manager_node.call("load_from_dict", data["base_state"])):
				_finish_load(slot_id, false, "Không thể khôi phục công trình từ file lưu.")
				return false
	else:
		# Save trước Bước 19 không thể có công trình; migration khôi phục căn cứ trống.
		var base_manager_node := get_node_or_null("/root/BaseManager")
		if base_manager_node and base_manager_node.has_method("load_from_dict"):
			base_manager_node.call("load_from_dict", {"schema_version": 1, "buildings": [], "next_instance_number": 1})

	# 6. Khôi phục enemy. Save cũ không có enemy_states: migration an toàn là
	# giữ nguyên trạng thái enemy runtime, vì HP lịch sử không tồn tại trong file.
	if data.has("enemy_states"):
		if not _restore_enemy_states(data["enemy_states"]):
			_finish_load(slot_id, false, "Không thể khôi phục trạng thái kẻ địch.")
			return false
	else:
		push_warning("Save cũ không có enemy_states; giữ enemy runtime hiện tại vì không có HP lịch sử để khôi phục.")

	# 7. Khôi phục NPC sau công trình để A* đọc đúng vật cản mới.
	# Save cũ không có npc_state sẽ xóa NPC thử nghiệm mặc định.
	var npc_manager := get_tree().current_scene.get_node_or_null("NPCManager") if get_tree().current_scene else null
	if npc_manager:
		var npc_snapshot: Dictionary = data.get("npc_state", {"schema_version": 1, "npcs": []})
		if npc_manager.has_method("load_from_dict") and not bool(npc_manager.call("load_from_dict", npc_snapshot)):
			_finish_load(slot_id, false, "Không thể khôi phục NPC từ file lưu.")
			return false
	var worker_manager := get_tree().current_scene.get_node_or_null("WorkerManager") if get_tree().current_scene else null
	if worker_manager and not bool(worker_manager.call("load_from_dict", data.get("worker_state", {}))):
		_finish_load(slot_id, false, "Không thể khôi phục thợ từ file lưu.")
		return false

	# 8. Khôi phục trạng thái thu thập tài nguyên ResourceNode
	var harvested_arr = data.get("harvested_resources", [])
	if harvested_arr is Array:
		var res_nodes = get_tree().get_nodes_in_group("resource_nodes")
		for r in res_nodes:
			if is_instance_valid(r):
				var n_id: String = str(r.get("node_id"))
				if n_id in harvested_arr:
					r.call("set_harvested", true, false)
				else:
					r.call("set_harvested", false, false)

	# 9. Khôi phục vật phẩm rơi trên mặt đất PickupItem
	var existing_pickups = get_tree().get_nodes_in_group("pickup_items")
	for ep in existing_pickups:
		if is_instance_valid(ep):
			ep.get_parent().remove_child(ep)
			ep.free()

	var pickups_arr = data.get("ground_pickups", [])
	if pickups_arr is Array and not pickups_arr.is_empty():
		var pickup_scene: PackedScene = load("res://scenes/pickup_item.tscn") as PackedScene
		var current_sc: Node = get_tree().current_scene
		if pickup_scene and current_sc:
			for pd in pickups_arr:
				if pd is Dictionary:
					var new_p: Node2D = pickup_scene.instantiate() as Node2D
					if new_p:
						new_p.set("pickup_id", StringName(pd.get("pickup_id", "")))
						new_p.set("item_id", StringName(pd.get("item_id", "slime_gel")))
						new_p.set("amount", int(pd.get("amount", 1)))
						new_p.global_position = Vector2(float(pd.get("x", 0)), float(pd.get("y", 0)))
						current_sc.add_child(new_p)

	# 10. Khôi phục Player trong scene hiện tại
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		var root := get_tree().current_scene
		if root:
			player = root.get_node_or_null("Player") as Node2D

	if player:
		var p_data: Dictionary = data.get("player", {})
		var target_x: float = float(p_data.get("x", player.global_position.x))
		var target_y: float = float(p_data.get("y", player.global_position.y))
		player.global_position = Vector2(target_x, target_y)
		# Snap the follow camera to the restored player position instead of
		# smoothing from the position held before loading the save.
		var player_camera := player.get_node_or_null("Camera2D") as Camera2D
		if player_camera:
			player_camera.reset_smoothing()

		# Khôi phục HP (không tự động full máu nếu trong file lưu có HP hợp lệ)
		var saved_hp: float = float(p_data.get("current_health", player.get("max_health")))
		var max_hp: float = float(player.get("max_health"))
		player.set("current_health", clampf(saved_hp, 1.0, max_hp))
		var was_dead := bool(player.get("is_dead"))
		player.set("is_dead", false)
		if was_dead and player.has_method("clear_death_visuals"):
			player.call("clear_death_visuals")

		# Khôi phục Stamina
		var saved_sta: float = float(p_data.get("stamina", player.get("max_stamina")))
		var max_sta: float = float(player.get("max_stamina"))
		player.set("stamina", clampf(saved_sta, 0.0, max_sta))

		# Đặt lại các trạng thái tạm thời
		player.set("velocity", Vector2.ZERO)
		player.set("is_dodging", false)
		player.set("dodge_timer", 0.0)
		player.set("attack_anim_timer", 0.0)
		player.set("attack_cooldown_timer", 0.0)

		# Khôi phục hướng nhìn
		var facing: String = str(p_data.get("facing", "down"))
		var anim_ctrl: Node = player.get_node_or_null("AnimationController")
		if anim_ctrl:
			anim_ctrl.set("current_facing", facing)
			anim_ctrl.set("is_locked", false)
			if anim_ctrl.has_method("_play_anim"):
				anim_ctrl.call("_play_anim", "idle_" + facing)

		# Khôi phục năng lượng gió Wind Energy
		var skill_comp: Node = player.get_node_or_null("SkillComponent")
		if skill_comp:
			var saved_energy: float = float(p_data.get("wind_energy", 0.0))
			var max_energy: float = float(skill_comp.get("max_energy"))
			skill_comp.set("current_energy", clampf(saved_energy, 0.0, max_energy))
			skill_comp.set("e_cooldown_timer", 0.0)
			skill_comp.set("r_cooldown_timer", 0.0)
			if skill_comp.has_signal("energy_changed"):
				skill_comp.energy_changed.emit(skill_comp.get("current_energy"), max_energy)

		# Phát tín hiệu cập nhật HUD
		if player.has_signal("health_changed"):
			player.health_changed.emit(player.get("current_health"), max_hp)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.emit(player.get("stamina"), max_sta)

	# 5. Nếu game đang bị Pause (ví dụ tải từ PauseMenu), hủy Pause sạch sẽ
	if get_tree().paused:
		get_tree().paused = false

	# Đóng PauseMenu tự động nếu đang mở
	var pause_nodes := get_tree().get_nodes_in_group("pause_menu")
	for pm in pause_nodes:
		if pm.has_method("resume_game"):
			pm.call("resume_game")
		elif "visible" in pm:
			pm.visible = false

	var root := get_tree().current_scene
	if root:
		var pause_m = root.get_node_or_null("PauseMenu")
		if pause_m:
			if pause_m.has_method("resume_game"):
				pause_m.call("resume_game")
			elif "visible" in pause_m:
				pause_m.visible = false

	var success_msg := "Đã tải dữ liệu Slot %02d thành công!" % slot_id
	_finish_load(slot_id, true, success_msg)
	return true

func _finish_load(slot_id: int, success: bool, message: String) -> void:
	is_busy = false
	load_completed.emit(slot_id, success, message)
	show_toast(message, success)

func _collect_enemy_states() -> Dictionary:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return {"ok": false, "error": "Không tìm thấy scene để lưu enemy."}
	var grouped: Dictionary = {}
	var seen_ids: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("get_persistence_data"):
			continue
		var row: Dictionary = enemy.call("get_persistence_data", scene_root)
		var persistent_id := str(row.get("persistent_id", ""))
		if persistent_id.is_empty() or seen_ids.has(persistent_id):
			return {"ok": false, "error": "Enemy persistent_id rỗng hoặc bị trùng: %s" % persistent_id}
		seen_ids[persistent_id] = true
		var region_id := str(row.get("region_id", ""))
		if region_id.is_empty():
			return {"ok": false, "error": "Enemy %s thiếu region_id." % persistent_id}
		if not grouped.has(region_id):
			grouped[region_id] = []
		grouped[region_id].append(row)
	return {"ok": true, "states": grouped}

func _autoload_snapshot(autoload_name: String) -> Dictionary:
	var node := get_node_or_null("/root/" + autoload_name)
	return node.call("to_dict") if node else {}

func _validate_snapshot(data: Dictionary) -> Dictionary:
	if not (data.get("player") is Dictionary and data.get("world_state") is Dictionary and data.get("quest_manager") is Dictionary):
		return {"valid": false, "error": "File lưu thiếu player, world_state hoặc quest_manager."}
	var ws: Dictionary = data["world_state"]
	if int(ws.get("schema_version", 0)) > 1 or not (ws.get("discovered_regions") is Array and ws.get("unlocked_regions") is Array and ws.get("world_flags") is Dictionary and ws.get("defeated_unique_bosses") is Array):
		return {"valid": false, "error": "WorldState trong file lưu không hợp lệ."}
	var quests: Dictionary = data["quest_manager"]
	if int(quests.get("schema_version", 0)) > 1 or not (quests.get("quest_status") is Dictionary and quests.get("quest_progress") is Dictionary and quests.get("completed_quests") is Array and quests.get("reward_ledger") is Array):
		return {"valid": false, "error": "QuestManager trong file lưu không hợp lệ."}
	var player_data: Dictionary = data["player"]
	for field in ["x", "y", "current_health", "max_health", "stamina"]:
		if not player_data.has(field):
			return {"valid": false, "error": "Player snapshot thiếu trường %s." % field}
		var numeric := float(player_data[field])
		if not (numeric >= -10000000.0 and numeric <= 10000000.0):
			return {"valid": false, "error": "Player snapshot có giá trị số không hợp lệ."}
	if float(player_data["max_health"]) <= 0.0 or float(player_data["current_health"]) < 0.0:
		return {"valid": false, "error": "HP trong player snapshot không hợp lệ."}
	if data.has("inventory") and not (data["inventory"] is Dictionary):
		return {"valid": false, "error": "Dữ liệu inventory không hợp lệ."}
	for section in OPTIONAL_AUTOLOAD_SECTIONS:
		if data.has(section):
			var section_node := get_node_or_null("/root/" + str(OPTIONAL_AUTOLOAD_SECTIONS[section]))
			if section_node and not section_node.call("is_valid_snapshot", data[section]):
				return {"valid": false, "error": "Dữ liệu '%s' trong file lưu không hợp lệ." % section}
	if data.has("harvested_resources") and not (data["harvested_resources"] is Array):
		return {"valid": false, "error": "Danh sách tài nguyên đã thu thập không hợp lệ."}
	if data.has("ground_pickups"):
		if not (data["ground_pickups"] is Array):
			return {"valid": false, "error": "Danh sách vật phẩm rơi không hợp lệ."}
		var pickup_ids: Dictionary = {}
		for pickup in data["ground_pickups"]:
			if not (pickup is Dictionary):
				return {"valid": false, "error": "Dữ liệu pickup không hợp lệ."}
			var pickup_id := str(pickup.get("pickup_id", ""))
			if pickup_id.is_empty() or pickup_ids.has(pickup_id) or str(pickup.get("item_id", "")).is_empty() or int(pickup.get("amount", 0)) <= 0:
				return {"valid": false, "error": "Pickup thiếu ID, loại vật phẩm hoặc số lượng hợp lệ."}
			pickup_ids[pickup_id] = true
			for axis in ["x", "y"]:
				var coordinate := float(pickup.get(axis, 0.0))
				if not (coordinate >= -10000000.0 and coordinate <= 10000000.0):
					return {"valid": false, "error": "Tọa độ pickup vượt giới hạn."}
	if data.has("enemy_states") and not _validate_enemy_states(data["enemy_states"]):
		return {"valid": false, "error": "Enemy snapshot không hợp lệ hoặc chứa ID trùng."}
	if data.has("base_state"):
		var base_manager := get_node_or_null("/root/BaseManager")
		if not base_manager or not bool(base_manager.call("validate_save_data", data["base_state"])):
			return {"valid": false, "error": "Base snapshot không hợp lệ."}
	if data.has("npc_state"):
		var npc_manager := get_tree().current_scene.get_node_or_null("NPCManager") if get_tree().current_scene else null
		if npc_manager and npc_manager.has_method("validate_save_data") and not bool(npc_manager.call("validate_save_data", data["npc_state"])):
			return {"valid": false, "error": "NPC snapshot không hợp lệ."}
	if data.has("worker_state"):
		var worker_manager := get_tree().current_scene.get_node_or_null("WorkerManager") if get_tree().current_scene else null
		if worker_manager and not bool(worker_manager.call("validate_save_data", data["worker_state"])):
			return {"valid": false, "error": "Dữ liệu thợ không hợp lệ."}
	return {"valid": true, "error": ""}

func _validate_enemy_states(snapshot: Variant) -> bool:
	if not (snapshot is Dictionary):
		return false
	var seen: Dictionary = {}
	for region_key in snapshot:
		var region_id := str(region_key)
		if region_id.is_empty() or not (snapshot[region_key] is Array):
			return false
		for row in snapshot[region_key]:
			if not (row is Dictionary):
				return false
			var enemy_id := str(row.get("persistent_id", ""))
			if enemy_id.is_empty() or seen.has(enemy_id) or str(row.get("region_id", "")) != region_id:
				return false
			seen[enemy_id] = true
			if str(row.get("enemy_type_id", "")).is_empty() or not (row.get("is_alive") is bool):
				return false
			var hp := float(row.get("current_hp", -1.0))
			var x := float(row.get("position_x", -10000001.0))
			var y := float(row.get("position_y", -10000001.0))
			if not (hp >= 0.0 and hp <= 1000000.0 and x >= -10000000.0 and x <= 10000000.0 and y >= -10000000.0 and y <= 10000000.0):
				return false
			if bool(row.get("runtime_spawn", false)):
				var path := str(row.get("scene_path", ""))
				if path.is_empty() or not ResourceLoader.exists(path):
					return false
				var scene_root := get_tree().current_scene
				if not scene_root or not scene_root.get_node_or_null(NodePath(str(row.get("parent_path", ".")))):
					return false
	return true

func _restore_enemy_states(snapshot: Dictionary) -> bool:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return false
	var by_id: Dictionary = {}
	var active_regions: Dictionary = {}
	var base_manager := get_node_or_null("/root/BaseManager")
	if base_manager and base_manager.has_method("get_current_region_id"):
		active_regions[str(base_manager.call("get_current_region_id"))] = true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var id := str(enemy.get("persistent_id"))
			if id.is_empty() or by_id.has(id):
				push_warning("Enemy persistent_id rỗng hoặc trùng trong scene: %s" % id)
				return false
			by_id[id] = enemy
			active_regions[str(enemy.get("region_id"))] = true

	var wanted: Dictionary = {}
	var rows: Array[Dictionary] = []
	for region_key in snapshot:
		if not active_regions.has(str(region_key)):
			continue
		for raw_row in snapshot[region_key]:
			var row: Dictionary = raw_row
			var id := str(row["persistent_id"])
			wanted[id] = true
			rows.append(row)

	# Stage mọi enemy cần tái tạo trước khi xóa hoặc sửa runtime hiện tại.
	var staged_spawns: Dictionary = {}
	for row in rows:
		var id := str(row["persistent_id"])
		if by_id.has(id) or not bool(row.get("runtime_spawn", false)):
			continue
		var parent := scene_root.get_node_or_null(NodePath(str(row.get("parent_path", "."))))
		var packed := ResourceLoader.load(str(row["scene_path"])) as PackedScene
		if not parent or not packed:
			for staged in staged_spawns.values():
				staged[0].free()
			return false
		var new_enemy := packed.instantiate()
		if not new_enemy:
			for staged in staged_spawns.values():
				staged[0].free()
			return false
		new_enemy.name = str(row.get("node_name", "Enemy"))
		new_enemy.set("persistent_id", StringName(id))
		new_enemy.set("region_id", StringName(str(row["region_id"])))
		new_enemy.set("enemy_id", StringName(str(row["enemy_type_id"])))
		new_enemy.set("is_runtime_spawn", true)
		staged_spawns[id] = [new_enemy, parent]

	# Xóa runtime-spawn enemies phát sinh sau thời điểm save; enemy scene-authored
	# vẫn tồn tại và được khôi phục theo persistent_id.
	for id in by_id.keys():
		var enemy: Node = by_id[id]
		if active_regions.has(str(enemy.get("region_id"))) and bool(enemy.get("is_runtime_spawn")) and not wanted.has(id):
			enemy.get_parent().remove_child(enemy)
			enemy.free()
			by_id.erase(id)

	for row in rows:
		var id := str(row["persistent_id"])
		var enemy: Node = by_id.get(id)
		if not enemy:
			if not bool(row.get("runtime_spawn", false)):
				push_warning("Không tìm thấy enemy scene-authored ID %s; giữ nguyên snapshot." % id)
				continue
			var staged: Array = staged_spawns[id]
			enemy = staged[0]
			(staged[1] as Node).add_child(enemy)
			by_id[id] = enemy
		if enemy.has_method("restore_persistence_data"):
			enemy.call("restore_persistence_data", row)

	return true

# Tạo UI Toast nhẹ nhàng hiển thị thông báo
func _create_toast_ui() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 128
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast_layer)

	_toast_panel = PanelContainer.new()
	_toast_panel.custom_minimum_size = Vector2(260, 32)
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 0.0
	_toast_panel.anchor_bottom = 0.0
	_toast_panel.offset_left = -130
	_toast_panel.offset_right = 130
	_toast_panel.offset_top = 10
	_toast_panel.offset_bottom = 42
	_toast_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	style.border_color = Color(0.3, 0.7, 0.9, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	_toast_panel.add_theme_stylebox_override("panel", style)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 10)
	_toast_panel.add_child(_toast_label)

	_toast_layer.add_child(_toast_panel)

func show_toast(text: String, is_success: bool = true) -> void:
	# Nếu NotificationManager đang hoạt động, để NotificationManager hiển thị thông báo hợp nhất
	if get_node_or_null("/root/NotificationManager"):
		return

	if not _toast_panel or not _toast_label:
		return

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_label.text = text
	var style: StyleBoxFlat = _toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if is_success:
			style.border_color = Color(0.2, 0.9, 0.5, 1.0)
			_toast_label.modulate = Color(0.85, 1.0, 0.9)
		else:
			style.border_color = Color(0.95, 0.35, 0.35, 1.0)
			_toast_label.modulate = Color(1.0, 0.85, 0.85)

	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_panel.position.y = 4.0

	_toast_tween = create_tween()
	_toast_tween.set_parallel(false)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.15)
	_toast_tween.parallel().tween_property(_toast_panel, "position:y", 12.0, 0.15)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)
