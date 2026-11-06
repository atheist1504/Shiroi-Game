extends CanvasLayer

# Menu Tạm dừng (Pause Menu) - Bước 16
@onready var color_rect: ColorRect = $ColorRect
@onready var panel_container: PanelContainer = $PanelContainer
@onready var resume_btn: Button = $PanelContainer/Margin/VBox/ResumeBtn
@onready var save_btn: Button = $PanelContainer/Margin/VBox/SaveBtn
@onready var load_btn: Button = $PanelContainer/Margin/VBox/LoadBtn
@onready var restart_btn: Button = $PanelContainer/Margin/VBox/RestartBtn
@onready var status_label: Label = $PanelContainer/Margin/VBox/StatusLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_menu")

	if resume_btn:
		resume_btn.pressed.connect(resume_game)
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	if load_btn:
		load_btn.pressed.connect(_on_load_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		var root := get_tree().current_scene
		if root:
			# Nếu QuestJournal hoặc DebugPanel đang mở thì nhường cho chúng đóng trước
			var journal = root.get_node_or_null("QuestJournal")
			if journal and journal.visible:
				return
			var debug_p = root.get_node_or_null("DebugPanel")
			if debug_p and debug_p.visible:
				return

		if visible:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game() -> void:
	visible = true
	get_tree().paused = true
	_update_slot_status()

func resume_game() -> void:
	visible = false
	get_tree().paused = false

func _on_save_pressed() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("save_game"):
		var ok: bool = save_mgr.save_game(1)
		_update_slot_status()

func _on_load_pressed() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("load_game"):
		var ok: bool = save_mgr.load_game(1)
		if ok:
			resume_game()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _update_slot_status() -> void:
	if not status_label:
		return
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("has_save_file"):
		if save_mgr.has_save_file(1):
			status_label.text = "Slot 1: Có dữ liệu lưu sẵn"
			status_label.modulate = Color(0.4, 0.9, 0.6)
		else:
			status_label.text = "Slot 1: Trống (Chưa có file lưu)"
			status_label.modulate = Color(0.7, 0.7, 0.7)
