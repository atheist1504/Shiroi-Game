extends SceneTree

# Bước 21.3: đồng hồ thế giới, hồi sinh tài nguyên, Save/Load và vòng lặp NPC lặp lại.
const TEST_SLOT := 97

var _passed := 0
var _total := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame
	var npc_manager: Node = scene.get_node("NPCManager")
	npc_manager.set_process(false)
	var clock := root.get_node("WorldClock")
	var world_state := root.get_node("WorldState")
	var save_manager := root.get_node("SaveManager")
	var nodes: Node = scene.get_node("ResourceNodes")

	var base_rect := Rect2(Vector2(672, 520), Vector2(544, 160))
	var base_nodes: Array[Node2D] = []
	for id in [&"hv_tree_01", &"hv_tree_02", &"hv_herb_01", &"hv_herb_02"]:
		var found := _find_node(nodes, id)
		if found and base_rect.has_point(found.global_position):
			base_nodes.append(found)
	_check(base_nodes.size() == 4, "Căn cứ có đủ 4 điểm tài nguyên (2 cây, 2 thảo dược) nằm trong BasePlot")
	if base_nodes.size() != 4:
		_finish()
		return

	var tree := _find_node(nodes, &"hv_tree_01")
	# (2026-11-17) Trại không còn cục đá: thử giờ hồi đá bằng một điểm đá ở mỏ.
	var rock := _find_node(nodes, &"zone_rock_01")
	var herb := _find_node(nodes, &"hv_herb_01")
	_check(is_equal_approx(float(tree.call("get_respawn_duration")), 60.0), "Gỗ hồi sau 60 giây")
	_check(is_equal_approx(float(rock.call("get_respawn_duration")), 90.0), "Đá hồi sau 90 giây")
	_check(is_equal_approx(float(herb.call("get_respawn_duration")), 45.0), "Thảo dược hồi sau 45 giây")

	# Tài nguyên ngoài Trại vẫn hồi sinh; trong Trại khai thác xong là hết.
	var wild := _find_node(nodes, &"zone_tree_01")
	_check(wild != null and not root.get_node("BaseManager").is_in_camp(wild.global_position), "Có cây ngoài Trại để thử hồi sinh")
	var start := float(clock.call("get_time"))
	wild.call("set_harvested", true, false)
	var respawn_at := float(world_state.call("get_flag", &"respawn_at_zone_tree_01", -1.0))
	_check(absf(respawn_at - (start + 60.0)) < 1.0, "Khai thác đặt mốc hồi sinh theo đồng hồ thế giới")
	clock.call("advance", 30.0)
	await process_frame
	_check(bool(wild.get("is_harvested")), "Chưa đến giờ thì tài nguyên chưa hồi")

	# F9 giữ nguyên mốc giờ: lưu khi còn ~30 giây, chơi tiếp đến khi hồi, rồi tải lại.
	_check(await _save(save_manager), "Lưu game khi tài nguyên đang chờ hồi")
	var saved_clock := float(clock.call("get_time"))
	var node_count := nodes.get_child_count()
	clock.call("advance", 40.0)
	await process_frame
	await process_frame
	_check(not bool(wild.get("is_harvested")), "Đến giờ thì tài nguyên hồi lại")
	_check(float(world_state.call("get_flag", &"respawn_at_zone_tree_01", -1.0)) < 0.0 and world_state.call("get_flag", &"harvested_zone_tree_01") != true, "Hồi sinh xóa trạng thái đã cạn trong WorldState")
	_check(await _load(save_manager), "F9 tải lại bản lưu")
	_check(absf(float(clock.call("get_time")) - saved_clock) < 1.0, "F9 khôi phục đồng hồ thế giới")
	_check(bool(wild.get("is_harvested")), "F9 khôi phục tài nguyên về trạng thái đã cạn")
	_check(is_equal_approx(float(world_state.call("get_flag", &"respawn_at_zone_tree_01", -1.0)), respawn_at), "F9 không đặt lại mốc hồi sinh")
	_check(nodes.get_child_count() == node_count, "F9 không tạo thêm node tài nguyên")
	_check(await _load(save_manager), "Tải lại lần hai")
	_check(is_equal_approx(float(world_state.call("get_flag", &"respawn_at_zone_tree_01", -1.0)), respawn_at) and nodes.get_child_count() == node_count, "Tải liên tiếp vẫn giữ nguyên dữ liệu")
	clock.call("advance", 40.0)
	await process_frame
	await process_frame
	_check(not bool(wild.get("is_harvested")), "Sau F9 tài nguyên vẫn hồi theo giờ đã lưu")

	# Save cũ: không có world_clock và không có mốc hồi sinh.
	wild.call("set_harvested", true, false)
	_check(await _save(save_manager), "Lưu bản dùng để giả lập save cũ")
	_check(_strip_to_old_save(), "Chuyển file thành dạng save cũ")
	_check(await _load(save_manager), "Save cũ vẫn tải được")
	_check(float(clock.call("get_time")) < 5.0, "Save cũ bắt đầu đồng hồ từ đầu")
	var old_respawn := float(world_state.call("get_flag", &"respawn_at_zone_tree_01", -1.0))
	_check(bool(wild.get("is_harvested")) and old_respawn > 0.0 and old_respawn <= float(clock.call("get_time")) + 60.5, "Tài nguyên đã cạn trong save cũ được đặt giờ hồi mới")
	clock.call("advance", 61.0)
	await process_frame
	await process_frame
	_check(not bool(wild.get("is_harvested")), "Tài nguyên trong save cũ hồi được")

	# Vòng lặp NPC với kho thật có va chạm: khai thác, giao, chờ hồi, khai thác lại.
	var storage := BaseBuilding.new()
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	storage.add_child(shape)
	storage.configure(load("res://data/buildings/storage.tres"), &"step21_3_storage", &"hope_valley_base", Vector2i(54, 37))
	scene.add_child(storage)
	await physics_frame
	await physics_frame
	npc_manager.call("refresh_navigation")
	for node in base_nodes:
		if node != tree:
			node.set("respawn_seconds", 100000.0)
			node.call("set_harvested", true, false)
	var base_manager := root.get_node("BaseManager")
	base_manager.call("unlock_base_for_debug")
	# Quy tắc dọn đất: tài nguyên đã cạn không còn chặn xây (xây lên thì nó mất hẳn, xem test_camp.gd).
	_check(bool(herb.get("is_harvested")) and not str(base_manager.call("_get_placement_block_reason", &"storage", Vector2i((herb.global_position / 16.0).round()))).contains("tài nguyên"), "Tài nguyên đã cạn không chặn xây")
	var npc: Node = npc_manager.call("spawn_test_npc")
	if not npc:
		_check(false, "NPC tồn tại để chạy vòng lặp")
		_finish()
		return
	# NPC dân làng không còn tự đi khai thác (việc khai thác do trạm khai thác lo).
	npc.set("move_speed", 180.0)
	npc_manager.set_process(true)
	await _wait_until(func() -> bool: return bool(tree.get("is_harvested")), 300)
	_check(not bool(tree.get("is_harvested")) and _stored(storage) == 0, "NPC dân làng không tự đi khai thác")
	tree.call("set_harvested", true, false)
	clock.call("advance", 61.0)
	await process_frame
	await process_frame
	_check(bool(tree.get("is_harvested")) and float(world_state.call("get_flag", &"respawn_at_hv_tree_01", -1.0)) < 0.0, "Tài nguyên trong Trại khai thác xong không hồi sinh")
	_cleanup_slot()
	_finish()

func _stored(storage: Node) -> int:
	var total := 0
	for slot in root.get_node("BaseManager").call("get_storage_contents", storage.get("instance_id")):
		if slot.get("item_id") == &"wood":
			total += int(slot.get("amount", 0))
	return total

func _find_node(parent: Node, id: StringName) -> Node2D:
	for child in parent.get_children():
		if child.get("node_id") == id:
			return child as Node2D
	return null

func _slot_path() -> String:
	return "user://saves/slot_%02d.json" % TEST_SLOT

func _strip_to_old_save() -> bool:
	var file := FileAccess.open(_slot_path(), FileAccess.READ)
	if not file:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return false
	data.erase("world_clock")
	data["world_state"]["world_flags"].erase("respawn_at_zone_tree_01")
	var out := FileAccess.open(_slot_path(), FileAccess.WRITE)
	if not out:
		return false
	out.store_string(JSON.stringify(data))
	out.close()
	return true

func _cleanup_slot() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path()))

func _save(save_manager: Node) -> bool:
	await create_timer(0.45).timeout
	return bool(save_manager.call("save_game", TEST_SLOT))

func _load(save_manager: Node) -> bool:
	await create_timer(0.45).timeout
	return bool(save_manager.call("load_game", TEST_SLOT))

func _wait_until(predicate: Callable, max_frames: int) -> void:
	for _frame in max_frames:
		if predicate.call():
			return
		await physics_frame

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _finish() -> void:
	print("Step 21.3 checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
