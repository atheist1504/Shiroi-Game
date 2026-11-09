extends SceneTree

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
	var npc_manager: Node = scene.get_node("NPCManager")
	var npc: Node = npc_manager.call("get_npc")
	if not npc:
		_check(false, "NPC được tạo để chạy kiểm thử gathering")
		_finish()
		return
	(npc as Node2D).set("move_speed", 180.0)
	var before_wood := int(root.get_node("InventoryManager").call("get_item_count", &"wood"))
	var resource := (load("res://scenes/resource_node.tscn") as PackedScene).instantiate()
	resource.set("node_id", &"step21_test_tree")
	resource.set("resource_id", &"wood")
	resource.set("yield_amount", 3)
	resource.position = Vector2(752, 560)
	scene.get_node("ResourceNodes").add_child(resource)
	var storage := BaseBuilding.new()
	storage.set("instance_id", &"step21_test_storage")
	storage.set("building_type_id", &"storage")
	storage.position = Vector2(864, 560)
	scene.add_child(storage)
	await physics_frame
	_check(bool(npc_manager.call("_assign_gather")), "NPC đặt chỗ một tài nguyên có đường đi")
	await _wait_until(func() -> bool: return bool(resource.get("is_harvested")), 240)
	_check(bool(resource.get("is_harvested")), "NPC hoàn thành khai thác sau thời gian làm việc")
	_check(int(npc.get("cargo").get(&"wood", 0)) == 3, "Hàng khai thác nằm trong túi riêng NPC")
	_check(int(root.get_node("InventoryManager").call("get_item_count", &"wood")) == before_wood, "Khai thác NPC không cộng vật phẩm vào túi người chơi")
	_check(bool(npc_manager.call("_assign_delivery")), "NPC tìm được kho có đường đi và đủ chỗ")
	await _wait_until(func() -> bool: return int(npc.call("cargo_used")) == 0, 240)
	_check(int(npc.call("cargo_used")) == 0, "NPC chỉ bỏ hàng sau khi kho xác nhận nhận")
	var contents: Array = root.get_node("BaseManager").call("get_storage_contents", &"step21_test_storage")
	var stored_wood := 0
	for slot in contents:
		if slot.get("item_id") == &"wood":
			stored_wood += int(slot.get("amount", 0))
	_check(stored_wood == 3, "Kho nhận đúng một lần toàn bộ số gỗ NPC mang")
	var before_storage: Array = contents.duplicate(true)
	_check(not bool(root.get_node("BaseManager").call("deposit_npc_cargo", &"step21_test_storage", {&"invalid_item": 1})), "Kho từ chối vật phẩm không hợp lệ")
	_check(root.get_node("BaseManager").call("get_storage_contents", &"step21_test_storage") == before_storage, "Giao dịch thất bại giữ nguyên dữ liệu kho")
	_finish()

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
	print("Step 21.4+21.5 checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
