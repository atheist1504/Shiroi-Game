extends SceneTree

# Màn bắt đầu: Chơi mới / Tiếp tục. Dùng slot mặc định (run_tests.ps1 sao lưu
# và trả lại save thật). Nút được gọi qua hàm, không mô phỏng chuột.

var _passed := 0
var _total := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_manager := root.get_node("SaveManager")
	var save_path: String = save_manager.get_save_path()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var menu: Node = scene.get_node("TitleMenu")
	var narrative: Node = scene.get_node("NarrativeUI")
	var night: Node = scene.get_node("FirstNight")

	_check(not menu.is_open() and not narrative.visible, "Headless không tự mở màn bắt đầu")
	menu.open()
	_check(menu.is_open() and paused, "Mở màn bắt đầu thì thế giới dừng")
	_check(menu.get("_continue_button").disabled, "Chưa có bản lưu thì nút Tiếp tục bị mờ")
	_check(not menu.continue_game() and menu.is_open(), "Không có bản lưu thì Tiếp tục không vào game")

	# Chơi mới: hỏi tên, mở đầu, rồi tập trước màn đêm.
	menu.start_new_game()
	_check(not menu.is_open(), "Chơi mới thì đóng màn bắt đầu")
	_check(narrative.is_naming() and paused, "Chơi mới thì hỏi tên trước")
	_check(night.stage == night.Stage.MOVE and not night.is_dark(), "Chơi mới vào chặng tập, chưa tối")
	narrative.confirm_player_name("Thử")
	narrative.finish()
	_check(not paused and not narrative.visible, "Xem xong mở đầu thì chơi được")

	# Lưu rồi mở lại màn bắt đầu để Tiếp tục.
	await create_timer(0.45).timeout
	_check(bool(save_manager.save_game()), "Lưu vào slot mặc định")
	night.skip_night()
	menu.open()
	_check(not menu.get("_continue_button").disabled, "Có bản lưu thì Tiếp tục bấm được")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F9
	event.pressed = true
	menu._unhandled_input(event)
	_check(menu.is_open(), "Phím tắt game bị chặn khi ở màn bắt đầu")
	await create_timer(0.45).timeout
	menu.continue_game()
	await process_frame
	_check(not menu.is_open() and not paused, "Tiếp tục thì tải bản lưu và vào game")
	_check(night.stage == night.Stage.MOVE, "Bản lưu lúc chưa qua đêm thì vào lại chặng tập")
	_check(not narrative.visible, "Tiếp tục không chiếu lại mở đầu")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_finish()

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _finish() -> void:
	print("Title menu checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
