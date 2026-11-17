extends SceneTree

# Đặt tên nhân vật khi vào game mới: hỏi trước lời mở đầu, lưu theo save.
const TEST_SLOT := 93

var _passed := 0
var _total := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var narrative: Node = scene.get_node("NarrativeUI")
	var party := root.get_node("PartyManager")
	var world := root.get_node("WorldState")
	var save_manager := root.get_node("SaveManager")

	_check(not party.has_player_name() and party.get_profile(party.PROTAGONIST_ID)["name"] == "Nhân vật chính", "Chưa đặt tên thì dùng tên mặc định")
	_check(narrative.play_opening_if_needed() and narrative.is_naming(), "Game mới hỏi tên trước lời mở đầu")
	_check(paused, "Đang hỏi tên thì game dừng")
	await process_frame
	var notifications := root.get_node("NotificationManager")
	var toasts_before: int = notifications.get("_vbox").get_child_count()
	for letter in ["g", "b", "j"]:
		root.push_input(_key(letter))
	await process_frame
	var name_edit: LineEdit = narrative.get("_name_edit")
	_check(name_edit.text == "gbj", "Gõ G, B, J vào ô tên thì thành chữ")
	_check(not root.get_node("BaseManager").get("is_build_mode") and notifications.get("_vbox").get_child_count() == toasts_before, "Gõ tên không bật xây dựng hay báo lỗi")
	_check(not scene.get_node("InventoryUI").visible and not scene.get_node("QuestJournal").visible, "Gõ tên không mở túi đồ hay bảng nhiệm vụ")
	_check(not narrative.confirm_player_name("   ") and narrative.is_naming(), "Tên rỗng bị từ chối")
	_check(narrative.confirm_player_name("  Minh   Anh  "), "Nhận tên hợp lệ")
	_check(party.get_player_name() == "Minh Anh", "Bỏ khoảng trắng thừa")
	_check(not narrative.is_naming() and narrative.visible and narrative._pages == narrative.OPENING_PAGES, "Đặt tên xong thì chiếu lời mở đầu")
	_check(party.get_profile(party.PROTAGONIST_ID)["name"] == "Minh Anh", "Tổ đội dùng tên đã đặt")
	narrative.finish()
	_check(not paused, "Hết mở đầu thì game chạy tiếp")
	party.set_player_name("Một cái tên rất là dài quá mức")
	_check(party.get_player_name().length() <= party.PLAYER_NAME_MAX_LENGTH, "Tên bị cắt theo độ dài tối đa")
	_check(not narrative.play_opening_if_needed(), "Đã xem mở đầu thì không hỏi lại")

	party.set_player_name("Minh Anh")
	await create_timer(0.45).timeout
	_check(bool(save_manager.call("save_game", TEST_SLOT)), "Lưu game")
	party.set_player_name("Tên Khác")
	await create_timer(0.45).timeout
	_check(bool(save_manager.call("load_game", TEST_SLOT)), "Tải game")
	await process_frame
	_check(party.get_player_name() == "Minh Anh", "Tải save thì khôi phục tên")
	world.set_flag(party.FLAG_PLAYER_NAME, "")
	_check(party.get_player_name() == "Nhân vật chính", "Save cũ không có tên thì dùng tên mặc định")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/slot_%02d.json" % TEST_SLOT))
	_finish()

func _key(letter: String) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = OS.find_keycode_from_string(letter.to_upper())
	event.physical_keycode = event.keycode
	event.unicode = letter.unicode_at(0)
	return event

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _finish() -> void:
	print("Player name checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
