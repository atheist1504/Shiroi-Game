extends Node

# Autoload SaveManager - Hệ thống lưu và tải game bền vững (Step 16)
signal save_started(slot_id: int)
signal save_completed(slot_id: int, success: bool, message: String)
signal load_started(slot_id: int)
signal load_completed(slot_id: int, success: bool, message: String)

const SAVE_DIR: String = "user://saves"
const DEFAULT_SLOT: int = 1
const SCHEMA_VERSION: int = 1
const GAME_VERSION: String = "1.0.0"

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

	var save_dict: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"game_version": GAME_VERSION,
		"save_timestamp": Time.get_datetime_string_from_system(false, true),
		"playtime_seconds": playtime_seconds,
		"scene": current_scene_path,
		"player": player_data,
		"world_state": world_state_dict,
		"quest_manager": quest_mgr_dict
	}

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

	# 5. Hoán đổi file tạm thành file chính (Atomic Replace)
	if FileAccess.file_exists(main_path):
		var rm_err := DirAccess.remove_absolute(main_path)
		if rm_err != OK:
			push_warning("Không thể xóa file lưu cũ trước khi thay thế: %s" % main_path)

	var ren_err := DirAccess.rename_absolute(temp_path, main_path)
	if ren_err != OK:
		# Fallback: copy file nếu rename lỗi giữa các partition
		var copy_err := DirAccess.copy_absolute(temp_path, main_path)
		DirAccess.remove_absolute(temp_path)
		if copy_err != OK:
			var err_msg := "Không thể ghi đè file lưu chính thức: %s" % main_path
			_finish_save(slot_id, false, err_msg)
			return false

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
	if not FileAccess.file_exists(main_path):
		var err_msg := "Không tìm thấy file lưu Slot %02d!" % slot_id
		_finish_load(slot_id, false, err_msg)
		return false

	var content := FileAccess.get_file_as_string(main_path)
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

	if not (data.has("player") and data.has("world_state") and data.has("quest_manager")):
		var err_msg := "File lưu thiếu cấu trúc dữ liệu bắt buộc!"
		_finish_load(slot_id, false, err_msg)
		return false

	# 1. Khôi phục thời gian chơi
	playtime_seconds = float(data.get("playtime_seconds", 0.0))

	# 2. Khôi phục WorldState (nạp im lặng)
	var world_state_node = get_node_or_null("/root/WorldState")
	if world_state_node and world_state_node.has_method("load_from_dict"):
		world_state_node.load_from_dict(data.get("world_state", {}))

	# 3. Khôi phục QuestManager (nạp im lặng)
	var quest_mgr_node = get_node_or_null("/root/QuestManager")
	if quest_mgr_node and quest_mgr_node.has_method("load_from_dict"):
		quest_mgr_node.load_from_dict(data.get("quest_manager", {}))

	# 4. Khôi phục Player trong scene hiện tại
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

		# Khôi phục HP (không tự động full máu nếu trong file lưu có HP hợp lệ)
		var saved_hp: float = float(p_data.get("current_health", player.get("max_health")))
		var max_hp: float = float(player.get("max_health"))
		player.set("current_health", clampf(saved_hp, 1.0, max_hp))
		player.set("is_dead", false)

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
