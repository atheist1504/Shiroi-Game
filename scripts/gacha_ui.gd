extends CanvasLayer

# Giao diện Gacha, mở bằng phím H. UI chỉ gọi GachaManager/WalletManager.

const GOLD_COLOR := Color(1.0, 0.85, 0.35)
const NORMAL_COLOR := Color(0.88, 0.9, 0.95)
const MUTED_COLOR := Color(0.62, 0.66, 0.74)

var _wallet_label: Label
var _pity_label: Label
var _status_label: Label
var _results_list: VBoxContainer
var _roster_list: VBoxContainer
var _pull_one_button: Button
var _pull_ten_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 93
	visible = false
	_build_layout()
	var wallet := get_node_or_null("/root/WalletManager")
	if wallet:
		wallet.wallet_changed.connect(_refresh)
	var gacha := get_node_or_null("/root/GachaManager")
	if gacha:
		gacha.roster_changed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("open_gacha") and not get_tree().paused:
			set_gacha_visible(true)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_game") or event.is_action_pressed("open_gacha"):
		set_gacha_visible(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		# Khóa các phím khác để không mở giao diện chồng lên khi đang quay.
		get_viewport().set_input_as_handled()

func set_gacha_visible(is_visible_now: bool) -> void:
	visible = is_visible_now
	get_tree().paused = is_visible_now
	if is_visible_now:
		_clear_children(_results_list)
		_status_label.text = "Mỗi lượt tốn %d Tinh Vẫn." % _gacha().COST_PER_PULL
		_refresh()

func pull_and_show(count: int) -> void:
	var result: Dictionary = _gacha().pull(count)
	_status_label.text = str(result.get("reason", "")) if not result["ok"] else "Kết quả %d lượt quay:" % count
	if not result["ok"]:
		return
	_clear_children(_results_list)
	for entry in result["results"]:
		_add_result_row(entry)
	_refresh()

func _gacha() -> Node:
	return get_node("/root/GachaManager")

func _wallet() -> Node:
	return get_node("/root/WalletManager")

func _build_layout() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.04, 0.08, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(590, 320)
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
	header.add_child(_label("HỆ THỐNG TRIỆU HỒI", 12, GOLD_COLOR))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_wallet_label = _label("", 9, NORMAL_COLOR)
	header.add_child(_wallet_label)
	var close_button := _button("Đóng")
	close_button.pressed.connect(func(): set_gacha_visible(false))
	header.add_child(close_button)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	root_box.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	columns.add_child(left)
	var pull_row := HBoxContainer.new()
	left.add_child(pull_row)
	_pull_one_button = _button("Quay 1 lượt")
	_pull_one_button.pressed.connect(pull_and_show.bind(1))
	pull_row.add_child(_pull_one_button)
	_pull_ten_button = _button("Quay 10 lượt")
	_pull_ten_button.pressed.connect(pull_and_show.bind(10))
	pull_row.add_child(_pull_ten_button)
	_pity_label = _label("", 9, MUTED_COLOR)
	left.add_child(_pity_label)
	_status_label = _label("", 9, NORMAL_COLOR)
	left.add_child(_status_label)
	var results_scroll := ScrollContainer.new()
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(results_scroll)
	_results_list = VBoxContainer.new()
	_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_scroll.add_child(_results_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(_label("NHÂN VẬT", 10, GOLD_COLOR))
	_roster_list = VBoxContainer.new()
	_roster_list.add_theme_constant_override("separation", 4)
	right.add_child(_roster_list)

func _refresh() -> void:
	if not visible:
		return
	var gacha := _gacha()
	var wallet := _wallet()
	var tinh_van := int(wallet.get_tinh_van())
	_wallet_label.text = "Tinh Vẫn: %d   Vàng: %d   " % [tinh_van, int(wallet.get_gold())]
	_pity_label.text = "Chắc chắn có nhân vật 5★ sau tối đa %d lượt nữa." % (gacha.PITY_PULLS - int(gacha.get_pity()))
	_pull_one_button.disabled = tinh_van < gacha.COST_PER_PULL
	_pull_ten_button.disabled = tinh_van < gacha.COST_PER_PULL * 10
	_clear_children(_roster_list)
	for character in gacha.get_characters():
		_add_roster_row(character)

func _add_roster_row(character: Dictionary) -> void:
	var gacha := _gacha()
	var character_id: StringName = character["id"]
	var owned: bool = gacha.is_owned(character_id)
	var row := HBoxContainer.new()
	_roster_list.add_child(row)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.color = character["color"] if owned else Color(0.25, 0.27, 0.32)
	row.add_child(swatch)
	var text := "%s – %s" % [character["name"], character["job_name"]]
	if owned:
		text += " | Bậc %d | Tinh Hồn: %d" % [gacha.get_rank(character_id), gacha.get_souls(character_id)]
	else:
		text += " | Chưa sở hữu"
	var info := _label(text, 9, NORMAL_COLOR if owned else MUTED_COLOR)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	if owned:
		var upgrade := _button("Tăng bậc")
		upgrade.disabled = gacha.get_souls(character_id) < 1 or gacha.get_rank(character_id) >= gacha.MAX_RANK
		upgrade.pressed.connect(func(): gacha.rank_up(character_id))
		row.add_child(upgrade)

func _add_result_row(entry: Dictionary) -> void:
	var text := ""
	var color := NORMAL_COLOR
	match entry["type"]:
		"character":
			var character: Dictionary = _gacha().get_character(entry["character_id"])
			text = "★★★★★ %s – %s" % [character["name"], character["job_name"]]
			text += " (MỚI!)" if entry["is_new"] else " (trùng: +1 Tinh Hồn)"
			color = GOLD_COLOR
		"gold":
			text = "Vàng x%d" % int(entry["amount"])
		"item":
			var definition = get_node("/root/InventoryManager").get_item_def(entry["item_id"])
			var item_name: String = definition.name if definition else str(entry["item_id"])
			text = "%s x%d" % [item_name, int(entry["amount"])]
			if int(entry["converted_gold"]) > 0:
				text += " (túi đầy: +%d vàng)" % int(entry["converted_gold"])
	_results_list.add_child(_label(text, 9, color))

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
