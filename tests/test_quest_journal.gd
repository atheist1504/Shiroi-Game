extends SceneTree

# Bảng nhiệm vụ chia ba ô: Chính tuyến, Phụ, Vặt.
var _passed := 0
var _total := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var journal: Node = scene.get_node("QuestJournal")
	journal.set_journal_visible(true)
	await process_frame

	var main_list: VBoxContainer = journal.get_category_list(&"main")
	var side_list: VBoxContainer = journal.get_category_list(&"side")
	var chore_list: VBoxContainer = journal.get_category_list(&"chore")
	_check(main_list != null and side_list != null and chore_list != null, "Có đủ ba ô Chính, Phụ, Vặt")
	_check(_has_text(main_list, "Sống Sót Đến Sáng") and _has_text(main_list, "Thanh Trừng Slime"), "Nhiệm vụ Hệ thống và nhiệm vụ chính nằm ô Chính")
	_check(_has_text(side_list, "Dấu Vết Trong Rừng") and not _has_text(side_list, "Hệ Thống"), "Nhiệm vụ phụ nằm ô Phụ")
	_check(_has_text(chore_list, "Chưa có nhiệm vụ"), "Ô Vặt trống thì báo chưa có")
	var quests := root.get_node("QuestManager")
	var shown := 0
	for list in [main_list, side_list]:
		for child in list.get_children():
			if child is Button:
				shown += 1
	_check(shown == quests.get_all_quest_ids().size(), "Mỗi nhiệm vụ hiện đúng một lần")

	journal.call("_select_quest", &"sys_00_first_night")
	_check(str(journal.get("detail_type").text).contains("Chính tuyến"), "Chi tiết ghi loại Chính tuyến")
	journal.call("_select_quest", &"side_forest_traces")
	_check(str(journal.get("detail_type").text).contains("Phụ"), "Chi tiết ghi loại Phụ")

	journal.call("_refresh_quest_list")
	await process_frame
	_check(_count_buttons(main_list) + _count_buttons(side_list) == shown, "Làm mới không nhân đôi danh sách")
	journal.set_journal_visible(false)
	_finish()

func _has_text(list: Node, text: String) -> bool:
	for child in list.get_children():
		if (child is Button or child is Label) and str(child.text).contains(text):
			return true
	return false

func _count_buttons(list: Node) -> int:
	var count := 0
	for child in list.get_children():
		if child is Button:
			count += 1
	return count

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _finish() -> void:
	print("Quest journal checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
