extends CanvasLayer

# Bảng Điều Khiển Debug (F3) - Tích hợp Kiểm thử Túi đồ Bước 17
@onready var close_btn: Button = $PanelContainer/Margin/VBox/Header/CloseBtn

# Tab 1: Kiểm thử Túi đồ
@onready var inv_status_label: Label = $"PanelContainer/Margin/VBox/TabContainer/Kiểm thử Túi đồ/VBox/InvStatusLabel"
@onready var btn_fill_full: Button = $"PanelContainer/Margin/VBox/TabContainer/Kiểm thử Túi đồ/VBox/BtnsGrid/BtnFillFull"
@onready var btn_fill_partial: Button = $"PanelContainer/Margin/VBox/TabContainer/Kiểm thử Túi đồ/VBox/BtnsGrid/BtnFillPartial"
@onready var btn_spawn_loot: Button = $"PanelContainer/Margin/VBox/TabContainer/Kiểm thử Túi đồ/VBox/BtnsGrid/BtnSpawnLoot"
@onready var btn_restore_inv: Button = $"PanelContainer/Margin/VBox/TabContainer/Kiểm thử Túi đồ/VBox/BtnsGrid/BtnRestoreInv"

# Tab 2: Thế giới & Nhiệm vụ
@onready var regions_label: Label = $"PanelContainer/Margin/VBox/TabContainer/Thế giới & Nhiệm vụ/VBox/StatusGrid/RegionsValue"
@onready var bosses_label: Label = $"PanelContainer/Margin/VBox/TabContainer/Thế giới & Nhiệm vụ/VBox/StatusGrid/BossesValue"
@onready var quests_label: Label = $"PanelContainer/Margin/VBox/TabContainer/Thế giới & Nhiệm vụ/VBox/StatusGrid/QuestsValue"
@onready var flags_label: Label = $"PanelContainer/Margin/VBox/TabContainer/Thế giới & Nhiệm vụ/VBox/ScrollFlags/FlagsLabel"

# Tab 3: EventBus & Thao tác
@onready var events_label: Label = $"PanelContainer/Margin/VBox/TabContainer/EventBus & Thao tác/VBox/ScrollEvents/EventsLabel"
@onready var btn_unlock: Button = $"PanelContainer/Margin/VBox/TabContainer/EventBus & Thao tác/VBox/HBoxButtons/BtnUnlockRegion"
@onready var btn_set_flag: Button = $"PanelContainer/Margin/VBox/TabContainer/EventBus & Thao tác/VBox/HBoxButtons/BtnSetFlag"
@onready var btn_roundtrip: Button = $"PanelContainer/Margin/VBox/TabContainer/EventBus & Thao tác/VBox/HBoxButtons/BtnTestRoundtrip"
@onready var btn_heal: Button = $"PanelContainer/Margin/VBox/TabContainer/EventBus & Thao tác/VBox/HBoxButtons/BtnHeal"
@onready var roundtrip_status: Label = $"PanelContainer/Margin/VBox/TabContainer/EventBus & Thao tác/VBox/RoundtripStatus"
@onready var btn_unlock_base: Button = $"PanelContainer/Margin/VBox/TabContainer/EventBus & Thao tác/VBox/BtnUnlockBase"
@onready var base_status_label: Label = $"PanelContainer/Margin/VBox/TabContainer/EventBus & Thao tác/VBox/BaseStatusLabel"
@onready var enemies_status_label: Label = $"PanelContainer/Margin/VBox/TabContainer/EventBus & Thao tác/VBox/EnemiesStatusLabel"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(func(): toggle_visibility(false))

	# Kết nối các nút Kiểm thử túi đồ
	if btn_fill_full:
		btn_fill_full.pressed.connect(_on_btn_fill_full_pressed)
	if btn_fill_partial:
		btn_fill_partial.pressed.connect(_on_btn_fill_partial_pressed)
	if btn_spawn_loot:
		btn_spawn_loot.pressed.connect(_on_btn_spawn_loot_pressed)
	if btn_restore_inv:
		btn_restore_inv.pressed.connect(_on_btn_restore_inv_pressed)

	# Kết nối các nút thao tác khác
	if btn_unlock:
		btn_unlock.pressed.connect(_on_btn_unlock_pressed)
	if btn_set_flag:
		btn_set_flag.pressed.connect(_on_btn_set_flag_pressed)
	if btn_roundtrip:
		btn_roundtrip.pressed.connect(_on_btn_roundtrip_pressed)
	if btn_heal:
		btn_heal.pressed.connect(_on_btn_heal_pressed)
	if btn_unlock_base:
		btn_unlock_base.pressed.connect(_on_btn_unlock_base_pressed)

	# Lắng nghe EventBus & InventoryManager
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("enemy_defeated"):
			event_bus.enemy_defeated.connect(func(_e, _r): _update_display())
		if event_bus.has_signal("region_unlocked"):
			event_bus.region_unlocked.connect(func(_r): _update_display())
		if event_bus.has_signal("region_discovered"):
			event_bus.region_discovered.connect(func(_r): _update_display())
		if event_bus.has_signal("world_flag_changed"):
			event_bus.world_flag_changed.connect(func(_f, _v): _update_display())
		if event_bus.has_signal("building_placed"):
			event_bus.building_placed.connect(func(_id, _type, _base): _update_display())

	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_signal("inventory_changed"):
		inv_mgr.inventory_changed.connect(_update_display)

func _unhandled_input(event: InputEvent) -> void:
	# Bật/tắt bảng Debug bằng phím F3
	if event.is_action_pressed("toggle_debug") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3):
		toggle_visibility(not visible)
		get_viewport().set_input_as_handled()
		return

	if visible and (event.is_action_pressed("pause_game") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE)):
		toggle_visibility(false)
		get_viewport().set_input_as_handled()
		return

func toggle_visibility(show_panel: bool) -> void:
	visible = show_panel
	if visible:
		# Đóng băng thế giới/quái để người chơi xem debug thoải mái
		get_tree().paused = true

		# Đóng nhật ký nhiệm vụ hoặc Balo nếu đang mở để tránh chồng chéo
		var root := get_tree().current_scene
		if root:
			var qj = root.get_node_or_null("QuestJournal")
			if qj and qj.visible and qj.has_method("set_journal_visible"):
				qj.set_journal_visible(false)
			var inv = root.get_node_or_null("InventoryUI")
			if inv and inv.visible and inv.has_method("set_inventory_visible"):
				inv.set_inventory_visible(false)

		_update_display()
	else:
		_check_resume_pause()

func _check_resume_pause() -> void:
	var root := get_tree().current_scene
	if root:
		var pm = root.get_node_or_null("PauseMenu")
		if pm and pm.visible:
			return
		var qj = root.get_node_or_null("QuestJournal")
		if qj and qj.visible:
			return
		var inv = root.get_node_or_null("InventoryUI")
		if inv and inv.visible:
			return
	get_tree().paused = false

# --- CÁC HÀNH ĐỘNG KIỂM THỬ TÚI ĐỒ (BƯỚC 17) ---

func _on_btn_fill_full_pressed() -> void:
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_method("set_debug_fill"):
		inv_mgr.call("set_debug_fill", true)
		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_info("Đã làm đầy 24/24 ô túi đồ (x99) để kiểm thử!")
		_update_display()

func _on_btn_fill_partial_pressed() -> void:
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_method("set_debug_fill"):
		inv_mgr.call("set_debug_fill", false)
		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_info("Đã tạo 23 ô x99 và 1 ô chứa 50 Gỗ (Thử cộng dồn)")
		_update_display()

func _on_btn_restore_inv_pressed() -> void:
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_method("restore_debug_snapshot"):
		var ok: bool = bool(inv_mgr.call("restore_debug_snapshot"))
		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			if ok:
				notif_mgr.show_success("Đã khôi phục túi đồ ban đầu!")
			else:
				notif_mgr.show_warning("Chưa có bản snapshot nào được lưu để khôi phục.")
		_update_display()

func _on_btn_spawn_loot_pressed() -> void:
	var current_sc := get_tree().current_scene
	if not current_sc:
		return

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		player = current_sc.get_node_or_null("Player") as Node2D
	if not player:
		return

	var pickup_scene: PackedScene = load("res://scenes/pickup_item.tscn") as PackedScene
	if not pickup_scene:
		return

	var p: Node2D = pickup_scene.instantiate() as Node2D
	if p:
		# Cấp đúng nguyên liệu xây dựng để có thể kiểm thử công trình từ Debug.
		var chosen_item: StringName = &"processed_stone"
		p.set("item_id", chosen_item)
		p.set("amount", 2)
		var offset := Vector2(randf_range(-30.0, 30.0), randf_range(20.0, 35.0))
		p.global_position = player.global_position + offset
		current_sc.call_deferred("add_child", p)

		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			var inv_mgr = get_node_or_null("/root/InventoryManager")
			var item_def = inv_mgr.get_item_def(chosen_item) if inv_mgr else null
			var item_name: String = item_def.name if item_def else str(chosen_item)
			notif_mgr.show_info("Đã tạo %s x2 rơi gần Player!" % item_name)

func _on_btn_heal_pressed() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player and get_tree().current_scene:
		player = get_tree().current_scene.get_node_or_null("Player") as Node2D
	if player:
		var max_hp: float = float(player.get("max_health"))
		var max_sta: float = float(player.get("max_stamina"))
		player.set("current_health", max_hp)
		player.set("stamina", max_sta)
		if player.has_signal("health_changed"):
			player.health_changed.emit(max_hp, max_hp)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.emit(max_sta, max_sta)

		var skill_comp = player.get_node_or_null("SkillComponent")
		if skill_comp:
			var max_eng: float = float(skill_comp.get("max_energy"))
			skill_comp.set("current_energy", max_eng)
			if skill_comp.has_signal("energy_changed"):
				skill_comp.energy_changed.emit(max_eng, max_eng)

		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_success("Đã hồi đầy Máu, Thể lực và Năng lượng!")
		_update_display()

func _on_btn_unlock_pressed() -> void:
	var world_state = get_node_or_null("/root/WorldState")
	if world_state and world_state.has_method("unlock_region"):
		world_state.unlock_region(&"deep_forest_plot")
		_update_display()

func _on_btn_unlock_base_pressed() -> void:
	var base_manager := get_node_or_null("/root/BaseManager")
	if base_manager and base_manager.has_method("unlock_base_for_debug"):
		base_manager.call("unlock_base_for_debug")
		_update_display()

func _on_btn_set_flag_pressed() -> void:
	var world_state = get_node_or_null("/root/WorldState")
	if world_state and world_state.has_method("set_flag"):
		world_state.set_flag(&"test_forest_cleared", true)
		_update_display()

func _on_btn_roundtrip_pressed() -> void:
	var world_state = get_node_or_null("/root/WorldState")
	var quest_mgr = get_node_or_null("/root/QuestManager")
	var ws_ok: bool = world_state.test_roundtrip() if (world_state and world_state.has_method("test_roundtrip")) else false
	var qm_ok: bool = quest_mgr.test_roundtrip() if (quest_mgr and quest_mgr.has_method("test_roundtrip")) else false

	if roundtrip_status:
		var all_ok := ws_ok and qm_ok
		roundtrip_status.text = "WS & Quest JSON: OK ✓" if all_ok else "JSON Test: LỖI ✗ (WS:%s, QM:%s)" % [str(ws_ok), str(qm_ok)]
		roundtrip_status.modulate = Color(0.3, 1.0, 0.6) if all_ok else Color(1.0, 0.4, 0.4)
	_update_display()

# --- CẬP NHẬT HIỂN THỊ DỮ LIỆU ---

func _update_display() -> void:
	if not visible:
		return

	# 1. Trạng thái túi đồ
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_status_label:
		var used_slots: int = inv_mgr.get_used_slot_count() if inv_mgr.has_method("get_used_slot_count") else 0
		var is_testing: bool = bool(inv_mgr.get("is_debug_testing"))
		var status_str := "ĐANG BẬT KIỂM THỬ (F5 bị khóa)" if is_testing else "Bình thường (Có thể lưu)"
		var color := Color(1.0, 0.7, 0.3) if is_testing else Color(0.4, 0.9, 0.75)
		inv_status_label.text = "Sức chứa: 24 ô | Đang dùng: %d/24 | Trạng thái: %s" % [used_slots, status_str]
		inv_status_label.modulate = color

	# 2. Cập nhật Thế giới & Nhiệm vụ
	var world_state = get_node_or_null("/root/WorldState")
	if world_state:
		if regions_label and world_state.has_method("get_unlocked_regions"):
			var unlk: Array[StringName] = world_state.get_unlocked_regions()
			regions_label.text = ", ".join(unlk) if not unlk.is_empty() else "(Trống)"

		if bosses_label and world_state.has_method("get_defeated_unique_bosses"):
			var bosses: Array[StringName] = world_state.get_defeated_unique_bosses()
			bosses_label.text = ", ".join(bosses) if not bosses.is_empty() else "(Chưa có)"

		if flags_label and world_state.has_method("get_all_flags"):
			var flags: Dictionary = world_state.get_all_flags()
			if flags.is_empty():
				flags_label.text = "(Chưa có cờ thế giới nào)"
			else:
				var flag_strs: Array[String] = []
				for k in flags.keys():
					flag_strs.append("• %s: %s" % [str(k), str(flags[k])])
				flags_label.text = "\n".join(flag_strs)

	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr and quests_label:
		var active_cnt: int = 0
		var ready_cnt: int = 0
		var done_cnt: int = 0
		for q_id in quest_mgr.get_all_quest_ids():
			var st: int = quest_mgr.get_quest_status(q_id)
			if st == 2: active_cnt += 1
			elif st == 3: ready_cnt += 1
			elif st == 4: done_cnt += 1
		quests_label.text = "Đang làm: %d | Chờ trả: %d | Đã xong: %d" % [active_cnt, ready_cnt, done_cnt]

	# 3. Cập nhật Log EventBus
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and events_label and event_bus.has_method("get_recent_logs"):
		var logs: Array[Dictionary] = event_bus.get_recent_logs()
		if logs.is_empty():
			events_label.text = "(Chưa có sự kiện nào)"
		else:
			var lines: Array[String] = []
			for entry in logs:
				lines.append("[%s] %s" % [entry.get("time", ""), entry.get("detail", "")])
			events_label.text = "\n".join(lines)

	var base_manager := get_node_or_null("/root/BaseManager")
	if base_manager:
		if base_status_label:
			var current_base: StringName = base_manager.call("get_current_base_id")
			base_status_label.text = "Region: %s | Base: %s | Mở khóa: %s | Công trình: %d" % [
				str(base_manager.call("get_current_region_id")),
				str(current_base) if current_base != StringName() else "(ngoài căn cứ)",
				str(base_manager.call("is_base_unlocked")),
				int(base_manager.call("get_building_count"))
			]
		if enemies_status_label:
			var enemy_rows: Array[String] = base_manager.call("get_enemy_debug_rows")
			enemies_status_label.text = "Kẻ địch (%d): %s" % [enemy_rows.size(), ", ".join(PackedStringArray(enemy_rows))]
