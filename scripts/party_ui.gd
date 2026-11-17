extends Node

# Giao diện tổ đội: dải trạng thái luôn hiện ở góc trái dưới và bảng chọn đội mở bằng phím P.

const GOLD_COLOR := Color(1.0, 0.85, 0.35)
const NORMAL_COLOR := Color(0.88, 0.9, 0.95)
const MUTED_COLOR := Color(0.62, 0.66, 0.74)
const HUD_REFRESH_SECONDS := 0.2

var _modal_layer: CanvasLayer
var _hud_rows: VBoxContainer
var _party_list: VBoxContainer
var _roster_list: VBoxContainer
var _hud_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_modal()
	_party().party_changed.connect(_refresh_all.call_deferred)
	get_node("/root/GachaManager").roster_changed.connect(_refresh_all.call_deferred)
	_refresh_all()

func _process(delta: float) -> void:
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = HUD_REFRESH_SECONDS
		_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		if event.is_action_pressed("open_party") and not get_tree().paused:
			set_party_visible(true)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_game") or event.is_action_pressed("open_party"):
		set_party_visible(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return _modal_layer.visible

func set_party_visible(is_visible_now: bool) -> void:
	_modal_layer.visible = is_visible_now
	get_tree().paused = is_visible_now
	if is_visible_now:
		_refresh_all()

func _party() -> Node:
	return get_node("/root/PartyManager")

func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 1
	add_child(hud_layer)
	_hud_rows = VBoxContainer.new()
	_hud_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_rows.position = Vector2(14, 306)
	_hud_rows.custom_minimum_size = Vector2(190, 42)
	_hud_rows.add_theme_constant_override("separation", 1)
	hud_layer.add_child(_hud_rows)

func _build_modal() -> void:
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 92
	_modal_layer.visible = false
	add_child(_modal_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.04, 0.08, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(590, 300)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.11, 0.16)
	panel_style.set_border_width_all(1)
	panel_style.border_color = GOLD_COLOR
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	panel.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 6)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	root_box.add_child(header)
	header.add_child(_label("TỔ ĐỘI", 12, GOLD_COLOR))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_button := _button("Đóng")
	close_button.pressed.connect(func(): set_party_visible(false))
	header.add_child(close_button)

	root_box.add_child(_label("Phím 1/2/3 đổi người. Đánh rồi đổi sang nguyên tố khác trong %d giây để kích hoạt phối hợp." % int(_party().COMBO_WINDOW), 9, MUTED_COLOR))
	root_box.add_child(_label("Nhân vật không ở trong đội sẽ tự làm việc theo nghề; cần có kho chứa để giao hàng.", 9, MUTED_COLOR))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	root_box.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(285, 0)
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)
	left.add_child(_label("ĐỘI HÌNH", 10, GOLD_COLOR))
	_party_list = VBoxContainer.new()
	_party_list.add_theme_constant_override("separation", 4)
	left.add_child(_party_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	columns.add_child(right)
	right.add_child(_label("NHÂN VẬT ĐÃ CÓ", 10, GOLD_COLOR))
	_roster_list = VBoxContainer.new()
	_roster_list.add_theme_constant_override("separation", 4)
	right.add_child(_roster_list)

func _refresh_all() -> void:
	_refresh_hud()
	if is_open():
		_refresh_modal()

func _refresh_hud() -> void:
	var party_ids: Array[StringName] = _party().get_party()
	while _hud_rows.get_child_count() > party_ids.size():
		var extra := _hud_rows.get_child(_hud_rows.get_child_count() - 1)
		_hud_rows.remove_child(extra)
		extra.queue_free()
	while _hud_rows.get_child_count() < party_ids.size():
		_hud_rows.add_child(_make_hud_row())
	for slot in party_ids.size():
		_update_hud_row(_hud_rows.get_child(slot), slot, party_ids[slot])

func _make_hud_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(8, 8)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	row.add_child(_label("", 9, NORMAL_COLOR))
	return row

func _update_hud_row(row: Node, slot: int, character_id: StringName) -> void:
	var party := _party()
	var profile: Dictionary = party.get_profile(character_id)
	var status: Dictionary = party.get_member_status(character_id)
	var is_active: bool = slot == party.get_active_slot()
	(row.get_child(0) as ColorRect).color = party.ELEMENTS[profile["element"]]["color"]
	var label := row.get_child(1) as Label
	var state_text := _health_text(status)
	label.text = "%d %s  %s" % [slot + 1, profile["name"], state_text]
	var color := GOLD_COLOR if is_active else NORMAL_COLOR
	label.add_theme_color_override("font_color", MUTED_COLOR if float(status["hp"]) <= 0.0 else color)

func _health_text(status: Dictionary) -> String:
	if float(status["hp"]) <= 0.0:
		return "gục %ds" % ceili(float(status["revive"]))
	return "%d/%d" % [ceili(float(status["hp"])), roundi(float(status["max_hp"]))]

func _refresh_modal() -> void:
	var party := _party()
	var party_ids: Array[StringName] = party.get_party()
	_clear_children(_party_list)
	for slot in party.MAX_PARTY_SIZE:
		if slot < party_ids.size():
			_add_party_row(slot, party_ids[slot])
		else:
			_party_list.add_child(_label("%d  (trống)" % (slot + 1), 9, MUTED_COLOR))
	_clear_children(_roster_list)
	var gacha := get_node("/root/GachaManager")
	var owned_count := 0
	for character in gacha.get_characters():
		if gacha.is_owned(character["id"]):
			owned_count += 1
			_add_roster_row(character["id"], party_ids)
	if owned_count == 0:
		_roster_list.add_child(_label("Chưa có nhân vật. Nhấn H để triệu hồi.", 9, MUTED_COLOR))

func _add_party_row(slot: int, character_id: StringName) -> void:
	var party := _party()
	var row := HBoxContainer.new()
	_party_list.add_child(row)
	var marker := "▶ " if slot == party.get_active_slot() else ""
	var info := _label("%d %s%s  %s" % [slot + 1, marker, _describe(character_id), _health_text(party.get_member_status(character_id))], 9, NORMAL_COLOR)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	if character_id != party.PROTAGONIST_ID:
		var remove_button := _button("Rời đội")
		remove_button.pressed.connect(func(): party.remove_member(character_id))
		row.add_child(remove_button)

func _add_roster_row(character_id: StringName, party_ids: Array[StringName]) -> void:
	var party := _party()
	var row := HBoxContainer.new()
	_roster_list.add_child(row)
	var info := _label("%s · %s" % [_describe(character_id), party.get_profile(character_id)["job_name"]], 9, NORMAL_COLOR)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var join_button := _button("Trong đội" if character_id in party_ids else "Vào đội")
	join_button.disabled = character_id in party_ids or party_ids.size() >= party.MAX_PARTY_SIZE
	join_button.pressed.connect(func(): party.add_member(character_id))
	row.add_child(join_button)

func _describe(character_id: StringName) -> String:
	var party := _party()
	var profile: Dictionary = party.get_profile(character_id)
	return "%s (%s)" % [profile["name"], party.ELEMENTS[profile["element"]]["name"]]

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 9)
	return button
