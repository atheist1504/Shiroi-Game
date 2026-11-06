extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var quest_list_vbox: VBoxContainer = $PanelContainer/Margin/VBox/Content/LeftCol/Scroll/QuestListVBox
@onready var close_btn: Button = $PanelContainer/Margin/VBox/Header/CloseBtn

# Các thành phần chi tiết nhiệm vụ bên phải
@onready var detail_title: Label = $PanelContainer/Margin/VBox/Content/RightCol/MarginRight/VBox/TitleLabel
@onready var detail_type: Label = $PanelContainer/Margin/VBox/Content/RightCol/MarginRight/VBox/TypeLabel
@onready var detail_status: Label = $PanelContainer/Margin/VBox/Content/RightCol/MarginRight/VBox/StatusLabel
@onready var detail_desc: Label = $PanelContainer/Margin/VBox/Content/RightCol/MarginRight/VBox/DescLabel
@onready var detail_objectives_box: VBoxContainer = $PanelContainer/Margin/VBox/Content/RightCol/MarginRight/VBox/ObjectivesVBox
@onready var detail_rewards_box: VBoxContainer = $PanelContainer/Margin/VBox/Content/RightCol/MarginRight/VBox/RewardsVBox
@onready var action_btn: Button = $PanelContainer/Margin/VBox/Content/RightCol/MarginRight/VBox/ActionBtn
@onready var status_info_label: Label = $PanelContainer/Margin/VBox/Content/RightCol/MarginRight/VBox/StatusInfoLabel

# Toast thông báo tiến độ nhiệm vụ
@onready var toast_panel: PanelContainer = $ToastPanel
@onready var toast_label: Label = $ToastPanel/Margin/ToastLabel

var selected_quest_id: StringName = &""
var toast_tween: Tween = null

func _ready() -> void:
	visible = false
	if toast_panel:
		toast_panel.visible = false

	if close_btn:
		close_btn.pressed.connect(func(): set_journal_visible(false))

	if action_btn:
		action_btn.pressed.connect(_on_action_btn_pressed)

	# Kết nối tín hiệu từ QuestManager
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr:
		if quest_mgr.has_signal("quest_status_changed"):
			quest_mgr.quest_status_changed.connect(_on_quest_status_changed)
		if quest_mgr.has_signal("quest_progress_updated"):
			quest_mgr.quest_progress_updated.connect(_on_quest_progress_updated)
		if quest_mgr.has_signal("quest_notification"):
			quest_mgr.quest_notification.connect(_show_toast)

func _unhandled_input(event: InputEvent) -> void:
	# Nhấn J để bật/tắt Nhật ký nhiệm vụ
	if event.is_action_pressed("toggle_journal") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J):
		set_journal_visible(not visible)
		get_viewport().set_input_as_handled()
		return

	if visible:
		# Nhấn Esc để đóng Journal nếu đang mở
		if event.is_action_pressed("pause_game") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
			set_journal_visible(false)
			get_viewport().set_input_as_handled()
			return

		# Nhấn F để nhanh chóng nhận hoặc trả thưởng nhiệm vụ đang chọn
		if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
			if action_btn and action_btn.visible and not action_btn.disabled:
				_on_action_btn_pressed()
				get_viewport().set_input_as_handled()
				return

func set_journal_visible(is_vis: bool) -> void:
	visible = is_vis
	if visible:
		_refresh_quest_list()
		if selected_quest_id == StringName():
			var quest_mgr = get_node_or_null("/root/QuestManager")
			if quest_mgr:
				var all_ids: Array = quest_mgr.get_all_quest_ids()
				if not all_ids.is_empty():
					_select_quest(all_ids[0])
		else:
			_update_selected_details()

func _refresh_quest_list() -> void:
	if not quest_list_vbox:
		return

	for child in quest_list_vbox.get_children():
		child.queue_free()

	var quest_mgr = get_node_or_null("/root/QuestManager")
	if not quest_mgr:
		return

	var all_ids: Array = quest_mgr.get_all_quest_ids()
	for q_id in all_ids:
		var def: Dictionary = quest_mgr.get_quest_definition(q_id)
		var status: int = quest_mgr.get_quest_status(q_id)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 9)

		var type_prefix := "[Chính] " if def.get("quest_type") == "main" else "[Phụ] "
		var status_badge := ""
		match status:
			0: # LOCKED
				status_badge = " (Khóa)"
				btn.modulate = Color(0.6, 0.6, 0.6)
			1: # AVAILABLE
				status_badge = " (Có thể nhận)"
				btn.modulate = Color(1.0, 0.9, 0.4)
			2: # ACTIVE
				status_badge = " (Đang làm)"
				btn.modulate = Color(0.3, 0.9, 1.0)
			3: # READY_TO_COMPLETE
				status_badge = " (★ Chờ trả)"
				btn.modulate = Color(0.3, 1.0, 0.6)
			4: # COMPLETED
				status_badge = " (Đã xong)"
				btn.modulate = Color(0.7, 0.7, 0.75)

		btn.text = type_prefix + def.get("title", str(q_id)) + status_badge
		btn.pressed.connect(func(): _select_quest(q_id))
		quest_list_vbox.add_child(btn)

func _select_quest(quest_id: StringName) -> void:
	selected_quest_id = quest_id
	_update_selected_details()

func _update_selected_details() -> void:
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if not quest_mgr or selected_quest_id == StringName():
		return

	var def: Dictionary = quest_mgr.get_quest_definition(selected_quest_id)
	if def.is_empty():
		return

	var status: int = quest_mgr.get_quest_status(selected_quest_id)

	# 1. Tiêu đề và phân loại
	if detail_title:
		detail_title.text = def.get("title", str(selected_quest_id))
	if detail_type:
		detail_type.text = "Loại: " + ("Nhiệm vụ chính" if def.get("quest_type") == "main" else "Nhiệm vụ phụ")
	if detail_status:
		detail_status.text = "Trạng thái: " + quest_mgr.get_status_name(status)
		match status:
			1: detail_status.modulate = Color(1.0, 0.9, 0.3)
			2: detail_status.modulate = Color(0.3, 0.9, 1.0)
			3: detail_status.modulate = Color(0.3, 1.0, 0.6)
			4: detail_status.modulate = Color(0.6, 0.8, 0.6)
			_: detail_status.modulate = Color.WHITE

	# 2. Mô tả
	if detail_desc:
		detail_desc.text = def.get("description", "")

	# 3. Mục tiêu & Tiến độ
	if detail_objectives_box:
		for c in detail_objectives_box.get_children():
			c.queue_free()

		var objectives: Array = def.get("objectives", [])
		for obj in objectives:
			var obj_id: StringName = obj["id"]
			var req: int = obj.get("required_amount", 1)
			var cur: int = quest_mgr.get_objective_progress(selected_quest_id, obj_id)

			var hbox := HBoxContainer.new()
			var lbl := Label.new()
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.text = "• %s: %d / %d" % [obj.get("description", ""), cur, req]
			if cur >= req:
				lbl.modulate = Color(0.4, 1.0, 0.6)
			else:
				lbl.modulate = Color(0.9, 0.9, 0.95)

			hbox.add_child(lbl)
			detail_objectives_box.add_child(hbox)

	# 4. Phần thưởng
	if detail_rewards_box:
		for c in detail_rewards_box.get_children():
			c.queue_free()

		var rewards: Dictionary = def.get("rewards", {})
		for item in rewards.get("ledger", []):
			var r_lbl := Label.new()
			r_lbl.add_theme_font_size_override("font_size", 8)
			r_lbl.text = "+ " + str(item)
			r_lbl.modulate = Color(1.0, 0.85, 0.4)
			detail_rewards_box.add_child(r_lbl)

	# 5. Nút hành động tương ứng với trạng thái
	if action_btn and status_info_label:
		match status:
			1: # AVAILABLE
				action_btn.visible = true
				action_btn.text = "Nhận nhiệm vụ"
				action_btn.disabled = false
				status_info_label.visible = false
			2: # ACTIVE
				action_btn.visible = false
				status_info_label.visible = true
				status_info_label.text = "Đang thực hiện mục tiêu..."
				status_info_label.modulate = Color(0.3, 0.85, 1.0)
			3: # READY_TO_COMPLETE
				action_btn.visible = true
				action_btn.text = "Hoàn thành & Nhận thưởng"
				action_btn.disabled = false
				status_info_label.visible = false
			4: # COMPLETED
				action_btn.visible = false
				status_info_label.visible = true
				status_info_label.text = "✓ Nhiệm vụ đã hoàn thành"
				status_info_label.modulate = Color(0.5, 0.9, 0.5)
			_:
				action_btn.visible = false
				status_info_label.visible = true
				status_info_label.text = "Nhiệm vụ đang bị khóa"
				status_info_label.modulate = Color(0.6, 0.6, 0.6)

func _on_action_btn_pressed() -> void:
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if not quest_mgr or selected_quest_id == StringName():
		return

	var status: int = quest_mgr.get_quest_status(selected_quest_id)
	if status == 1: # AVAILABLE -> Nhận
		quest_mgr.activate_quest(selected_quest_id)
	elif status == 3: # READY_TO_COMPLETE -> Trả
		quest_mgr.complete_quest(selected_quest_id)

	_refresh_quest_list()
	_update_selected_details()

func _on_quest_status_changed(_q_id: StringName, _new_status: int) -> void:
	if visible:
		_refresh_quest_list()
		_update_selected_details()

func _on_quest_progress_updated(_q_id: StringName, _obj_id: StringName, _cur: int, _req: int) -> void:
	if visible:
		_update_selected_details()

# Hiển thị Toast thông báo trên màn hình
func _show_toast(msg: String) -> void:
	if not toast_panel or not toast_label:
		return

	toast_label.text = msg
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0

	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()

	toast_tween = create_tween()
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	toast_tween.finished.connect(func(): toast_panel.visible = false)
