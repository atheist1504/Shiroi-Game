extends CanvasLayer

# Màn chữ kể chuyện: mở đầu xuyên không và lời kết bản demo.
# Lời thoại là bản nháp, chỉ dùng các ý cốt truyện đã chốt.
# "{name}" trong lời thoại được thay bằng tên người chơi đặt khi vào game.

signal sequence_finished(pages: Array[Dictionary])

const FLAG_OPENING_SEEN: StringName = &"opening_seen"
const SYSTEM_COLOR := Color(0.45, 0.95, 0.85)
const STORY_COLOR := Color(0.92, 0.93, 0.97)

const OPENING_PAGES: Array[Dictionary] = [
	{"text": "Bạn chỉ là một người Việt Nam bình thường."},
	{"text": "Rồi một sức mạnh không rõ từ đâu kéo bạn đi."},
	{"text": "Khi mở mắt, trước mặt bạn là một vùng đất bạn chưa từng thấy."},
	{"text": "[HỆ THỐNG]\nXác nhận: {name}.\nSống sót đến sáng.", "system": true}
]

# Màn đen sau khi hạ bầy sói đêm đầu.
const FIRST_NIGHT_END_PAGES: Array[Dictionary] = [
	{"text": "Cứ thế, đêm đầu tiên đã qua, và tôi vẫn còn sống."}
]

const ENDING_PAGES: Array[Dictionary] = [
	{"text": "[HỆ THỐNG]\n{name}, đã khôi phục 1 mảnh bản ghi.", "system": true},
	{"text": "[HỆ THỐNG]\nTên vùng đất: Shiroi Arika.\nDữ liệu còn lại: bị khóa.", "system": true},
	{"text": "Hết bản demo. Cảm ơn bạn đã chơi.\nBạn vẫn có thể tiếp tục khám phá và phát triển căn cứ."}
]

var _pages: Array[Dictionary] = []
var _page_index: int = 0
var _was_paused: bool = false
var _text_label: Label
var _hint_label: Label
var _name_box: Control
var _name_edit: LineEdit
var _name_hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	visible = false
	_build_layout()
	get_node("/root/QuestManager").quest_completed.connect(_on_quest_completed)
	# Màn bắt đầu (title_menu.gd) gọi play_opening_if_needed() khi chọn Chơi mới.

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if is_naming():
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_game"):
		finish()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("dodge"):
		advance()
	if event is InputEventKey:
		get_viewport().set_input_as_handled()

func play_opening_if_needed() -> bool:
	var world_state := get_node("/root/WorldState")
	if world_state.get_flag(FLAG_OPENING_SEEN, false) == true:
		return false
	world_state.set_flag(FLAG_OPENING_SEEN, true)
	if get_node("/root/PartyManager").has_player_name():
		play(OPENING_PAGES)
	else:
		ask_player_name()
	return true

# Game mới: hỏi tên trước lời mở đầu. Xác nhận bằng Enter hoặc nút.
func ask_player_name() -> void:
	_was_paused = get_tree().paused
	visible = true
	get_tree().paused = true
	_name_box.visible = true
	_text_label.visible = false
	_hint_label.visible = false
	_name_hint.text = ""
	_name_edit.clear()
	_name_edit.grab_focus.call_deferred()

func is_naming() -> bool:
	return visible and _name_box.visible

func confirm_player_name(player_name: String) -> bool:
	if not get_node("/root/PartyManager").set_player_name(player_name):
		_name_hint.text = "Hãy nhập tên."
		return false
	_name_box.visible = false
	_text_label.visible = true
	_hint_label.visible = true
	play(OPENING_PAGES)
	return true

func play(pages: Array[Dictionary]) -> void:
	_pages = pages
	_page_index = 0
	if not visible:
		_was_paused = get_tree().paused
	visible = true
	get_tree().paused = true
	_show_page()

func advance() -> void:
	_page_index += 1
	if _page_index >= _pages.size():
		finish()
	else:
		_show_page()

func finish() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	sequence_finished.emit(_pages)

func _show_page() -> void:
	var page: Dictionary = _pages[_page_index]
	_text_label.text = str(page["text"]).replace("{name}", get_node("/root/PartyManager").get_player_name())
	_text_label.add_theme_color_override("font_color", SYSTEM_COLOR if page.get("system", false) else STORY_COLOR)
	_hint_label.text = "%d/%d   Space hoặc nhấp chuột: tiếp   Esc: bỏ qua" % [_page_index + 1, _pages.size()]

func _on_quest_completed(quest_id: StringName) -> void:
	if quest_id == &"sys_06_archive":
		play(ENDING_PAGES)

func _on_backdrop_input(event: InputEvent) -> void:
	if is_naming():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()

func _build_layout() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.05, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	_text_label = Label.new()
	_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_label.offset_left = 70
	_text_label.offset_right = -70
	_text_label.offset_bottom = -30
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.add_theme_font_size_override("font_size", 12)
	add_child(_text_label)
	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -24
	_hint_label.offset_bottom = -8
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_font_size_override("font_size", 8)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.64, 0.72))
	add_child(_hint_label)
	_name_box = VBoxContainer.new()
	_name_box.set_anchors_preset(Control.PRESET_CENTER)
	_name_box.custom_minimum_size = Vector2(200, 0)
	_name_box.position = Vector2(-100, -40)
	_name_box.add_theme_constant_override("separation", 8)
	_name_box.visible = false
	add_child(_name_box)
	var question := Label.new()
	question.text = "Tên của bạn là gì?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 12)
	_name_box.add_child(question)
	_name_edit = LineEdit.new()
	_name_edit.max_length = get_node("/root/PartyManager").PLAYER_NAME_MAX_LENGTH
	_name_edit.placeholder_text = "Nhập tên"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.text_submitted.connect(confirm_player_name)
	_name_box.add_child(_name_edit)
	var confirm := Button.new()
	confirm.text = "Xác nhận"
	confirm.pressed.connect(func() -> void: confirm_player_name(_name_edit.text))
	_name_box.add_child(confirm)
	_name_hint = Label.new()
	_name_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_hint.add_theme_font_size_override("font_size", 8)
	_name_hint.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	_name_box.add_child(_name_hint)
