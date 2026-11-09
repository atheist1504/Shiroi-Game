extends CanvasLayer

# Giao diện Túi đồ (Inventory UI) - Bước 17
@onready var panel_container: PanelContainer = $PanelContainer
@onready var grid_container: GridContainer = $PanelContainer/Margin/HBox/LeftCol/GridContainer
@onready var close_btn: Button = $PanelContainer/Margin/HBox/LeftCol/Header/CloseBtn

# Các phần tử hiển thị chi tiết vật phẩm bên phải
@onready var detail_icon: TextureRect = $PanelContainer/Margin/HBox/RightCol/DetailBox/Margin/VBox/HeaderHBox/IconRect
@onready var detail_name: Label = $PanelContainer/Margin/HBox/RightCol/DetailBox/Margin/VBox/HeaderHBox/NameLabel
@onready var detail_category: Label = $PanelContainer/Margin/HBox/RightCol/DetailBox/Margin/VBox/CategoryLabel
@onready var detail_desc: Label = $PanelContainer/Margin/HBox/RightCol/DetailBox/Margin/VBox/DescLabel
@onready var detail_stack: Label = $PanelContainer/Margin/HBox/RightCol/DetailBox/Margin/VBox/StackLabel
@onready var use_btn: Button = $PanelContainer/Margin/HBox/RightCol/DetailBox/Margin/VBox/UseBtn

var _slot_panels: Array[PanelContainer] = []
var _hovered_slot_idx: int = -1
var _selected_slot_idx: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(func(): set_inventory_visible(false))
	if use_btn:
		use_btn.pressed.connect(_on_use_btn_pressed)

	_build_slot_grid()

	# Lắng nghe thay đổi từ InventoryManager
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr:
		if inv_mgr.has_signal("inventory_changed"):
			inv_mgr.inventory_changed.connect(_refresh_ui)

func _unhandled_input(event: InputEvent) -> void:
	# Nhấn phím B để mở/đóng túi đồ (Balo)
	if event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B):
		set_inventory_visible(not visible)
		get_viewport().set_input_as_handled()
		return

	if visible:
		# Nhấn Esc để đóng túi đồ
		if event.is_action_pressed("pause_game") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
			set_inventory_visible(false)
			get_viewport().set_input_as_handled()
			return

func set_inventory_visible(is_vis: bool) -> void:
	visible = is_vis
	if visible:
		# Đóng băng thế giới/quái để người chơi không bị tấn công khi đang mở Balo
		get_tree().paused = true

		# Đóng nhật ký nhiệm vụ nếu đang mở để tránh đè giao diện
		var root := get_tree().current_scene
		if root:
			var qj = root.get_node_or_null("QuestJournal")
			if qj and qj.visible and qj.has_method("set_journal_visible"):
				qj.set_journal_visible(false)

		_refresh_ui()
		_show_item_details(-1)
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
		var dbg = root.get_node_or_null("DebugPanel")
		if dbg and dbg.visible:
			return
	get_tree().paused = false

func _build_slot_grid() -> void:
	if not grid_container:
		return

	for child in grid_container.get_children():
		child.queue_free()
	_slot_panels.clear()

	for i in range(24):
		var slot_p := PanelContainer.new()
		slot_p.custom_minimum_size = Vector2(30, 30)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.28, 0.35, 0.45, 1.0)
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_right = 2
		style.corner_radius_bottom_left = 2
		slot_p.add_theme_stylebox_override("panel", style)

		# Icon vật phẩm
		var icon_rect := TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(22, 22)
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_p.add_child(icon_rect)

		# Số lượng badge góc dưới
		var amt_label := Label.new()
		amt_label.name = "AmountLabel"
		amt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amt_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		amt_label.add_theme_font_size_override("font_size", 8)
		amt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		amt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		amt_label.offset_right = -2
		amt_label.offset_bottom = -1
		amt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_p.add_child(amt_label)

		# Kết nối chuột hover để xem thông tin
		var idx := i
		slot_p.mouse_entered.connect(func(): _on_slot_mouse_entered(idx, slot_p))
		slot_p.mouse_exited.connect(func(): _on_slot_mouse_exited(idx, slot_p))

		grid_container.add_child(slot_p)
		_slot_panels.append(slot_p)

func _on_slot_mouse_entered(idx: int, slot_p: PanelContainer) -> void:
	_hovered_slot_idx = idx
	var style: StyleBoxFlat = slot_p.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(0.4, 0.85, 1.0, 1.0)
		style.bg_color = Color(0.18, 0.22, 0.28, 1.0)
	_show_item_details(idx)

func _on_slot_mouse_exited(_idx: int, slot_p: PanelContainer) -> void:
	var style: StyleBoxFlat = slot_p.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(0.28, 0.35, 0.45, 1.0)
		style.bg_color = Color(0.12, 0.14, 0.18, 0.95)

func _refresh_ui() -> void:
	if not visible:
		return

	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if not inv_mgr:
		return

	var slots: Array[Dictionary] = inv_mgr.get_all_slots()

	for i in range(min(_slot_panels.size(), slots.size())):
		var slot_p: PanelContainer = _slot_panels[i]
		var data: Dictionary = slots[i]
		var icon_rect: TextureRect = slot_p.get_node_or_null("Icon") as TextureRect
		var amt_label: Label = slot_p.get_node_or_null("AmountLabel") as Label

		var item_id: StringName = data.get("item_id", StringName())
		var amount: int = int(data.get("amount", 0))

		if item_id != StringName() and amount > 0:
			var def = inv_mgr.get_item_def(item_id)
			if def:
				if icon_rect:
					icon_rect.texture = def.icon
					icon_rect.visible = true
				if amt_label:
					amt_label.text = str(amount) if amount > 1 else ""
					amt_label.visible = true
			else:
				if icon_rect: icon_rect.visible = false
				if amt_label: amt_label.visible = false
		else:
			if icon_rect: icon_rect.visible = false
			if amt_label: amt_label.visible = false

	# Cập nhật chi tiết ô đang hover nếu có
	if _hovered_slot_idx >= 0 and _hovered_slot_idx < slots.size():
		_show_item_details(_hovered_slot_idx)

func _show_item_details(idx: int) -> void:
	if idx < 0:
		_selected_slot_idx = -1
		if detail_name: detail_name.text = "Túi Đồ"
		if detail_category: detail_category.text = "Chọn hoặc rê chuột vào ô vật phẩm"
		if detail_desc: detail_desc.text = "Sức chứa: 24 ô.\nNhấn B hoặc Esc để đóng."
		if detail_stack: detail_stack.text = ""
		if detail_icon: detail_icon.texture = null
		if use_btn: use_btn.visible = false
		return

	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if not inv_mgr:
		return

	var slot: Dictionary = inv_mgr.get_slot(idx)
	var item_id: StringName = slot.get("item_id", StringName())
	var amount: int = int(slot.get("amount", 0))

	if item_id == StringName() or amount <= 0:
		_selected_slot_idx = -1
		if detail_name: detail_name.text = "(Ô trống)"
		if detail_category: detail_category.text = "Chưa có vật phẩm"
		if detail_desc: detail_desc.text = "Ô túi đồ này đang để trống."
		if detail_stack: detail_stack.text = ""
		if detail_icon: detail_icon.texture = null
		if use_btn: use_btn.visible = false
		return

	_selected_slot_idx = idx
	var def = inv_mgr.get_item_def(item_id)
	if def:
		if detail_name: detail_name.text = def.name
		if detail_category: detail_category.text = "Loại: " + def.get_category_name()
		if detail_desc: detail_desc.text = def.description
		if detail_stack: detail_stack.text = "Số lượng: %d / %d" % [amount, def.max_stack]
		if detail_icon: detail_icon.texture = def.icon

		# Hiển thị nút "Sử dụng" nếu là vật phẩm tiêu hao (Consumable)
		if use_btn:
			if def.category == ItemDefinition.Category.CONSUMABLE:
				use_btn.visible = true
				use_btn.text = "Sử dụng (%s)" % def.name
			else:
				use_btn.visible = false
	else:
		if use_btn: use_btn.visible = false

func _on_use_btn_pressed() -> void:
	if _selected_slot_idx < 0:
		return

	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if not inv_mgr:
		return

	var ok: bool = inv_mgr.use_item_at_slot(_selected_slot_idx)
	if ok:
		_refresh_ui()
