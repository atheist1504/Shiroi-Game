extends CanvasLayer

# Màn bắt đầu khi mở game: Chơi mới / Tiếp tục / Thoát.
# - Chơi mới: hỏi tên, chiếu mở đầu, rồi vào chặng tập trước màn đêm.
# - Tiếp tục: tải bản lưu (Slot mặc định); chưa có bản lưu thì nút bị mờ.
# Trong lúc hiện màn này thế giới tạm dừng. Kiểm thử headless không tự mở.

signal closed(choice: StringName)

const SYSTEM_COLOR := Color(0.45, 0.95, 0.85)

var _new_button: Button
var _continue_button: Button
var _quit_button: Button
var _status_label: Label
var _was_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 115
	visible = false
	_build_ui()
	if DisplayServer.get_name() != "headless":
		open.call_deferred()

func open() -> void:
	_was_paused = get_tree().paused
	visible = true
	get_tree().paused = true
	_status_label.text = ""
	_continue_button.disabled = not get_node("/root/SaveManager").has_save_file()
	var focus := _new_button if _continue_button.disabled else _continue_button
	focus.grab_focus.call_deferred()

func is_open() -> bool:
	return visible

func start_new_game() -> void:
	if not visible:
		return
	_close(&"new")
	var main := get_parent()
	var narrative := main.get_node_or_null("NarrativeUI")
	if narrative:
		narrative.play_opening_if_needed()
	var night := main.get_node_or_null("FirstNight")
	if night:
		night.start_if_needed()

func continue_game() -> bool:
	if not visible:
		return false
	var save_manager := get_node("/root/SaveManager")
	if not save_manager.has_save_file():
		_status_label.text = "Chưa có bản lưu."
		return false
	# Tải khi thế giới vẫn đang dừng; tải xong mới đóng màn.
	save_manager.load_completed.connect(_on_load_completed, CONNECT_ONE_SHOT)
	if not save_manager.load_game():
		if save_manager.load_completed.is_connected(_on_load_completed):
			save_manager.load_completed.disconnect(_on_load_completed)
		if _status_label.text.is_empty():
			_status_label.text = "Không tải được bản lưu."
		return false
	return not visible

func _on_load_completed(_slot_id: int, success: bool, message: String) -> void:
	if not success:
		_status_label.text = message
		return
	_close(&"continue")
	var night := get_parent().get_node_or_null("FirstNight")
	if night:
		night.start_if_needed()

func _close(choice: StringName) -> void:
	visible = false
	get_tree().paused = _was_paused
	closed.emit(choice)

func _unhandled_input(event: InputEvent) -> void:
	# Chặn phím tắt của game (F5, F9, B, J...) khi đang ở màn bắt đầu.
	if visible and event is InputEventKey:
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(220, 0)
	box.position = Vector2(-110, -90)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "SHIROI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", SYSTEM_COLOR)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "The Lost Heir"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	box.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)
	_new_button = _make_button("Chơi mới", start_new_game)
	box.add_child(_new_button)
	_continue_button = _make_button("Tiếp tục", continue_game)
	box.add_child(_continue_button)
	_quit_button = _make_button("Thoát", func() -> void: get_tree().quit())
	box.add_child(_quit_button)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	box.add_child(_status_label)

func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 28)
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(func() -> void: action.call())
	return button
