extends Node

# Autoload NotificationManager - Hệ thống Thông báo Toàn cục (Bước 17)
enum Type {
	SUCCESS,  # Xanh ngọc / lục: Thành công, nhặt đồ, hoàn thành
	INFO,     # Lam / Cyan: Thông tin, khám phá
	WARNING,  # Vàng cam: Cảnh báo, túi đầy
	ERROR     # Đỏ hồng: Thất bại, lỗi
}

const MAX_TOASTS: int = 3
const TOAST_DURATION: float = 3.0
const ANTI_SPAM_WINDOW_MS: int = 800
const REGION_NAMES: Dictionary = {
	&"hope_valley_area": "Thung Lũng Hy Vọng", &"zone_forest": "Khu Rừng", &"zone_stone_mine": "Mỏ Đá",
	&"zone_iron_mine": "Mỏ Sắt", &"zone_gold_mine": "Mỏ Vàng", &"zone_swamp": "Đầm Lầy", &"zone_dunes": "Đồi Cát",
	&"zone_ruins": "Tàn Tích", &"ruins": "Tàn Tích", &"ancient_archive": "Bản ghi cổ", &"forest_traces": "Di Tích Cổ"
}

var _canvas_layer: CanvasLayer = null
var _vbox: VBoxContainer = null
var _toast_tweens: Dictionary = {}

# Lịch sử chống spam: {"hash": last_tick_ms}
var _recent_messages: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_ui()
	_connect_game_signals()

func _create_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 120
	_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas_layer)

	_vbox = VBoxContainer.new()
	_vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	_vbox.anchors_preset = Control.PRESET_TOP_RIGHT
	_vbox.anchor_left = 1.0
	_vbox.anchor_right = 1.0
	_vbox.anchor_top = 0.0
	_vbox.anchor_bottom = 0.0
	_vbox.offset_left = -230.0
	_vbox.offset_top = 10.0
	_vbox.offset_right = -10.0
	_vbox.offset_bottom = 160.0
	_vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_theme_constant_override("separation", 5)
	_canvas_layer.add_child(_vbox)

func _connect_game_signals() -> void:
	# Lắng nghe các sự kiện từ EventBus
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("region_discovered"):
			event_bus.region_discovered.connect(func(r_id: StringName):
				show_info("Khám phá vùng đất: %s" % str(REGION_NAMES.get(r_id, r_id)))
			)
		if event_bus.has_signal("region_unlocked"):
			event_bus.region_unlocked.connect(func(r_id: StringName):
				show_success("Mở khóa khu vực mới: %s" % str(REGION_NAMES.get(r_id, r_id)))
			)
		if event_bus.has_signal("quest_completed"):
			event_bus.quest_completed.connect(func(q_id: StringName):
				show_success("Hoàn thành nhiệm vụ: %s!" % str(get_node("/root/QuestManager").get_quest_definition(q_id).get("title", q_id)))
			)

	# Lắng nghe QuestManager
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr and quest_mgr.has_signal("quest_notification"):
		quest_mgr.quest_notification.connect(func(msg: String):
			show_info(msg)
		)

	# Lắng nghe SaveManager
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		if save_mgr.has_signal("save_completed"):
			save_mgr.save_completed.connect(func(_slot: int, ok: bool, msg: String):
				if ok:
					show_success(msg)
				else:
					show_error(msg)
			)
		if save_mgr.has_signal("load_completed"):
			save_mgr.load_completed.connect(func(_slot: int, ok: bool, msg: String):
				if ok:
					show_success(msg)
				else:
					show_error(msg)
			)

# Hiển thị thông báo nhặt vật phẩm
func show_item_pickup(item_id: StringName, amount: int) -> void:
	var item_name: String = str(item_id)
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_method("get_item_def"):
		var def = inv_mgr.get_item_def(item_id)
		if def:
			item_name = def.name

	show_success("Đã nhận: %s x%d" % [item_name, amount])

func show_success(text: String) -> void:
	show_notification(text, Type.SUCCESS)

func show_info(text: String) -> void:
	show_notification(text, Type.INFO)

func show_warning(text: String) -> void:
	show_notification(text, Type.WARNING)

func show_error(text: String) -> void:
	show_notification(text, Type.ERROR)

# Hiển thị thông báo toàn cục với hàng đợi và chống spam
func show_notification(text: String, type: Type = Type.INFO) -> void:
	if text.strip_edges().is_empty():
		return

	# Chống spam thông báo trùng lặp trong thời gian ngắn
	var now := Time.get_ticks_msec()
	if _recent_messages.has(text):
		if now - int(_recent_messages[text]) < ANTI_SPAM_WINDOW_MS:
			return
	_recent_messages[text] = now

	# Dọn các toast cũ cùng tween của chúng trước khi vượt giới hạn.
	while _vbox.get_child_count() >= MAX_TOASTS:
		var oldest: Control = null
		for child in _vbox.get_children():
			if child is Control and not child.is_queued_for_deletion():
				oldest = child as Control
				break
		if not oldest:
			break
		_remove_toast(oldest)

	# Tạo Toast PanelContainer
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 26)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.94)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3

	var text_color: Color = Color.WHITE
	var icon_prefix: String = "ℹ "

	match type:
		Type.SUCCESS:
			style.border_color = Color(0.3, 0.85, 0.55, 1.0)
			text_color = Color(0.85, 1.0, 0.9)
			icon_prefix = "✓ "
		Type.INFO:
			style.border_color = Color(0.35, 0.75, 0.95, 1.0)
			text_color = Color(0.85, 0.95, 1.0)
			icon_prefix = "✦ "
		Type.WARNING:
			style.border_color = Color(1.0, 0.75, 0.3, 1.0)
			text_color = Color(1.0, 0.95, 0.8)
			icon_prefix = "⚠ "
		Type.ERROR:
			style.border_color = Color(0.95, 0.35, 0.4, 1.0)
			text_color = Color(1.0, 0.85, 0.85)
			icon_prefix = "✕ "

	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = icon_prefix + text
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", 9)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)

	_vbox.add_child(panel)

	# Hiệu ứng mờ dần và trượt mượt mà
	panel.modulate.a = 0.0
	var tween := create_tween()
	var toast_instance_id := panel.get_instance_id()
	_toast_tweens[toast_instance_id] = tween
	tween.set_parallel(false)
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(TOAST_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_finish_toast.bind(toast_instance_id))

func _remove_toast(panel: Control) -> void:
	var toast_instance_id := panel.get_instance_id()
	var tween := _toast_tweens.get(toast_instance_id) as Tween
	if tween and tween.is_valid():
		tween.kill()
	_toast_tweens.erase(toast_instance_id)
	panel.queue_free()

func _finish_toast(toast_instance_id: int) -> void:
	_toast_tweens.erase(toast_instance_id)
	var toast := instance_from_id(toast_instance_id)
	if is_instance_valid(toast) and toast is Node:
		(toast as Node).queue_free()
