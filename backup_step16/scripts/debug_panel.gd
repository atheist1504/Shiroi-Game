extends CanvasLayer

@onready var panel_container: PanelContainer = $PanelContainer
@onready var events_label: Label = $PanelContainer/MarginContainer/VBox/ScrollEvents/EventsLabel
@onready var regions_label: Label = $PanelContainer/MarginContainer/VBox/StatusGrid/RegionsValue
@onready var flags_label: Label = $PanelContainer/MarginContainer/VBox/StatusGrid/FlagsValue
@onready var bosses_label: Label = $PanelContainer/MarginContainer/VBox/StatusGrid/BossesValue
@onready var roundtrip_status: Label = $PanelContainer/MarginContainer/VBox/HBoxButtons/RoundtripStatus

@onready var btn_unlock: Button = $PanelContainer/MarginContainer/VBox/HBoxButtons/BtnUnlockRegion
@onready var btn_set_flag: Button = $PanelContainer/MarginContainer/VBox/HBoxButtons/BtnSetFlag
@onready var btn_roundtrip: Button = $PanelContainer/MarginContainer/VBox/HBoxButtons/BtnTestRoundtrip

func _ready() -> void:
	visible = false

	if btn_unlock:
		btn_unlock.pressed.connect(_on_btn_unlock_pressed)
	if btn_set_flag:
		btn_set_flag.pressed.connect(_on_btn_set_flag_pressed)
	if btn_roundtrip:
		btn_roundtrip.pressed.connect(_on_btn_roundtrip_pressed)

	# Kết nối lắng nghe EventBus để cập nhật giao diện khi có sự kiện mới
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

func _unhandled_input(event: InputEvent) -> void:
	# Bật/tắt bảng Debug bằng phím F3
	if event.is_action_pressed("toggle_debug") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3):
		toggle_visibility()

func toggle_visibility() -> void:
	visible = not visible
	if visible:
		_update_display()

func _update_display() -> void:
	if not visible:
		return

	# 1. Cập nhật danh sách sự kiện gần nhất từ EventBus
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_method("get_recent_logs"):
		var logs: Array[Dictionary] = event_bus.get_recent_logs()
		if logs.is_empty():
			events_label.text = "(Chưa có sự kiện nào)"
		else:
			var lines: Array[String] = []
			for entry in logs:
				lines.append("[%s] %s" % [entry.get("time", ""), entry.get("detail", "")])
			events_label.text = "\n".join(lines)

	# 2. Cập nhật dữ liệu từ WorldState
	var world_state = get_node_or_null("/root/WorldState")
	if world_state:
		if regions_label and world_state.has_method("get_unlocked_regions"):
			var unlk: Array[StringName] = world_state.get_unlocked_regions()
			regions_label.text = ", ".join(unlk) if not unlk.is_empty() else "(Trống)"

		if flags_label and world_state.has_method("get_all_flags"):
			var flags: Dictionary = world_state.get_all_flags()
			if flags.is_empty():
				flags_label.text = "(Trống)"
			else:
				var flag_strs: Array[String] = []
				for k in flags.keys():
					flag_strs.append("%s: %s" % [str(k), str(flags[k])])
				flags_label.text = "; ".join(flag_strs)

		if bosses_label and world_state.has_method("get_defeated_unique_bosses"):
			var bosses: Array[StringName] = world_state.get_defeated_unique_bosses()
			bosses_label.text = ", ".join(bosses) if not bosses.is_empty() else "(Chưa có)"

	# 3. Cập nhật thông tin QuestManager
	var quest_mgr = get_node_or_null("/root/QuestManager")
	var quests_val_node = get_node_or_null("PanelContainer/MarginContainer/VBox/StatusGrid/QuestsValue")
	if quest_mgr and quests_val_node:
		var active_cnt: int = 0
		var ready_cnt: int = 0
		var done_cnt: int = 0
		for q_id in quest_mgr.get_all_quest_ids():
			var st: int = quest_mgr.get_quest_status(q_id)
			if st == 2: active_cnt += 1
			elif st == 3: ready_cnt += 1
			elif st == 4: done_cnt += 1
		quests_val_node.text = "Đang làm: %d | Chờ trả: %d | Xong: %d" % [active_cnt, ready_cnt, done_cnt]

func _on_btn_unlock_pressed() -> void:
	var world_state = get_node_or_null("/root/WorldState")
	if world_state and world_state.has_method("unlock_region"):
		world_state.unlock_region(&"deep_forest_plot")
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
