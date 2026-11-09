extends CanvasLayer

# Màn chữ kể chuyện: mở đầu xuyên không và lời kết bản demo.
# Lời thoại là bản nháp, chỉ dùng các ý cốt truyện đã chốt.

const FLAG_OPENING_SEEN: StringName = &"opening_seen"
const SYSTEM_COLOR := Color(0.45, 0.95, 0.85)
const STORY_COLOR := Color(0.92, 0.93, 0.97)

const OPENING_PAGES: Array[Dictionary] = [
	{"text": "Bạn chỉ là một người Việt Nam bình thường."},
	{"text": "Rồi một sức mạnh không rõ từ đâu kéo bạn đi."},
	{"text": "Khi mở mắt, bạn đang ở Shiroi Arika, một thế giới từng rất phồn vinh, có ma pháp, tu tiên và nhiều sức mạnh khác."},
	{"text": "Một ngày nọ, cả nền văn minh ấy bị xóa sổ. Những người còn sống sót đang cố dựng căn cứ để chống lại quái vật bên ngoài."},
	{"text": "[HỆ THỐNG]\nPhát hiện người đến sau.\nHệ thống này được để lại để người đến sau tìm ra sự thật.", "system": true},
	{"text": "[HỆ THỐNG]\nLinh hồn và ký ức của người xưa vẫn được lưu giữ.\nDùng Tinh Vẫn để triệu hồi họ.", "system": true},
	{"text": "[HỆ THỐNG]\nWASD: di chuyển   Chuột trái: chém   E/R: kỹ năng\nJ: nhiệm vụ   H: triệu hồi   P: tổ đội   G: xây dựng\nNhiệm vụ đầu tiên đã được giao.", "system": true}
]

const ENDING_PAGES: Array[Dictionary] = [
	{"text": "[HỆ THỐNG]\nĐã khôi phục một phần bản ghi của di tích.\nNguyên nhân nền văn minh bị xóa sổ: chưa có dữ liệu.", "system": true},
	{"text": "[HỆ THỐNG]\nNgười tạo ra Hệ thống đã biến mất cùng nền văn minh ấy.\nSự thật vẫn còn ở phía trước.", "system": true},
	{"text": "Hết bản demo. Cảm ơn bạn đã chơi.\nBạn vẫn có thể tiếp tục khám phá và phát triển căn cứ."}
]

var _pages: Array[Dictionary] = []
var _page_index: int = 0
var _was_paused: bool = false
var _text_label: Label
var _hint_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	visible = false
	_build_layout()
	get_node("/root/QuestManager").quest_completed.connect(_on_quest_completed)
	# Chạy kiểm thử headless thì không dừng game để chiếu mở đầu.
	if DisplayServer.get_name() != "headless":
		play_opening_if_needed.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
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
	visible = false
	get_tree().paused = _was_paused

func _show_page() -> void:
	var page: Dictionary = _pages[_page_index]
	_text_label.text = page["text"]
	_text_label.add_theme_color_override("font_color", SYSTEM_COLOR if page.get("system", false) else STORY_COLOR)
	_hint_label.text = "%d/%d   Space hoặc nhấp chuột: tiếp   Esc: bỏ qua" % [_page_index + 1, _pages.size()]

func _on_quest_completed(quest_id: StringName) -> void:
	if quest_id == &"sys_06_archive":
		play(ENDING_PAGES)

func _on_backdrop_input(event: InputEvent) -> void:
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
