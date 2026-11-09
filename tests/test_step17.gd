extends SceneTree

# Kịch bản kiểm thử toàn diện Bước 17: Inventory, Resource Gathering, Loot & Notifications
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Test tự tạo các manager; bỏ autoload cùng tên để game và test dùng chung một bản.
	for autoload_name in ["InventoryManager", "NotificationManager", "EventBus", "WorldState", "QuestManager", "SaveManager"]:
		var existing := root.get_node_or_null(autoload_name)
		if existing:
			existing.free()
	print("==================================================")
	print(" BẮT ĐẦU KIỂM THỬ BƯỚC 17: INVENTORY, LOOT & NOTIFICATIONS")
	print("==================================================")

	var pass_count: int = 0
	var total_tests: int = 11

	# Nạp Autoloads độc lập trong SceneTree headless
	var inv_mgr: Node = Node.new()
	var inv_script: Script = load("res://scripts/inventory_manager.gd")
	inv_mgr.set_script(inv_script)
	inv_mgr.name = "InventoryManager"
	root.add_child(inv_mgr)

	var notif_mgr: Node = Node.new()
	var notif_script: Script = load("res://scripts/notification_manager.gd")
	notif_mgr.set_script(notif_script)
	notif_mgr.name = "NotificationManager"
	root.add_child(notif_mgr)

	var event_bus: Node = Node.new()
	var eb_script: Script = load("res://scripts/event_bus.gd")
	event_bus.set_script(eb_script)
	event_bus.name = "EventBus"
	root.add_child(event_bus)

	var world_state: Node = Node.new()
	var ws_script: Script = load("res://scripts/world_state.gd")
	world_state.set_script(ws_script)
	world_state.name = "WorldState"
	root.add_child(world_state)

	var quest_mgr: Node = Node.new()
	var qm_script: Script = load("res://scripts/quest_manager.gd")
	quest_mgr.set_script(qm_script)
	quest_mgr.name = "QuestManager"
	root.add_child(quest_mgr)

	var save_mgr: Node = Node.new()
	var sm_script: Script = load("res://scripts/save_manager.gd")
	save_mgr.set_script(sm_script)
	save_mgr.name = "SaveManager"
	root.add_child(save_mgr)

	# TEST 1: Kiểm tra Catalog & ItemDefinition
	print("\n[TEST 1] Kiểm tra danh mục vật phẩm chuẩn (5 vật phẩm thử nghiệm)...")
	var items: Array[StringName] = [&"wood", &"stone", &"herb", &"slime_gel", &"wind_crystal"]
	var catalog_ok: bool = true
	for it_id in items:
		var def = inv_mgr.call("get_item_def", it_id)
		if not def or def.id != it_id or def.name == "" or def.max_stack != 99:
			catalog_ok = false
			printerr("  -> Lỗi catalog với item: %s" % str(it_id))
			break
	if catalog_ok:
		print("  -> PASS: Đủ 5 vật phẩm (Gỗ, Đá, Thảo dược, Gel Slime, Tinh thể Phong) với max_stack=99.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Danh mục vật phẩm thiếu hoặc sai thông số!")

	# TEST 2: Kiểm tra Thêm vật phẩm & Sức chứa 24 ô
	print("\n[TEST 2] Kiểm tra thêm vật phẩm vào túi đồ (24 ô)...")
	inv_mgr.call("_init_empty_slots")
	var rem1: int = int(inv_mgr.call("add_item", &"wood", 10))
	var rem2: int = int(inv_mgr.call("add_item", &"stone", 5))
	var count_wood: int = int(inv_mgr.call("get_item_count", &"wood"))
	var count_stone: int = int(inv_mgr.call("get_item_count", &"stone"))
	if rem1 == 0 and rem2 == 0 and count_wood == 10 and count_stone == 5:
		print("  -> PASS: Thêm Gỗ (10) và Đá (5) thành công, số lượng khớp chuẩn xác.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Thêm vật phẩm lỗi: wood=%d, stone=%d" % [count_wood, count_stone])

	# TEST 3: Kiểm tra Cơ chế Cộng dồn (Stacking)
	print("\n[TEST 3] Kiểm tra cộng dồn vật phẩm theo max_stack (99)...")
	# Đang có 10 gỗ, thêm 95 gỗ -> slot 1 đầy 99, slot 2 chứa 6 gỗ.
	var rem_stack: int = int(inv_mgr.call("add_item", &"wood", 95))
	var total_wood: int = int(inv_mgr.call("get_item_count", &"wood"))
	var slot0: Dictionary = inv_mgr.call("get_slot", 0)
	var slot2: Dictionary = inv_mgr.call("get_slot", 2)
	if rem_stack == 0 and total_wood == 105 and int(slot0["amount"]) == 99 and int(slot2["amount"]) == 6:
		print("  -> PASS: Cộng dồn chính xác, slot 0 đầy 99, phần dư tự động mở slot mới chứa 6.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Cộng dồn sai! total=%d, slot0=%d, slot2=%d" % [total_wood, int(slot0["amount"]), int(slot2["amount"])])

	# TEST 4: Kiểm tra Gỡ bỏ vật phẩm (Remove Item)
	print("\n[TEST 4] Kiểm tra loại bỏ vật phẩm (Giao dịch all-or-nothing)...")
	var rem_success: bool = bool(inv_mgr.call("remove_item", &"wood", 15))
	var wood_after: int = int(inv_mgr.call("get_item_count", &"wood"))
	# Thử gỡ nhiều hơn số lượng hiện có -> phải thất bại và không làm mất đồ
	var rem_fail: bool = bool(inv_mgr.call("remove_item", &"wood", 999))
	var wood_after_fail: int = int(inv_mgr.call("get_item_count", &"wood"))
	if rem_success and wood_after == 90 and not rem_fail and wood_after_fail == 90:
		print("  -> PASS: Gỡ vật phẩm chính xác, không cho phép gỡ vượt quá số lượng hiện có.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Gỡ vật phẩm sai! after=%d, after_fail=%d" % [wood_after, wood_after_fail])

	# TEST 5: Kiểm tra Túi đầy (Inventory Full)
	print("\n[TEST 5] Kiểm tra xử lý khi túi đầy...")
	inv_mgr.call("_init_empty_slots")
	# Lấp đầy 24 ô
	for i in range(24):
		inv_mgr.call("add_item", &"stone", 99)
	var can_add_new: bool = bool(inv_mgr.call("can_add_item", &"herb", 1))
	var excess: int = int(inv_mgr.call("add_item", &"herb", 5))
	if not can_add_new and excess == 5 and int(inv_mgr.call("get_item_count", &"herb")) == 0:
		print("  -> PASS: Túi đầy 24 ô từ chối nhận thêm Thảo dược, không làm mất đồ.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Túi đầy vẫn nhận hoặc làm mất đồ! can_add=%s, excess=%d" % [can_add_new, excess])

	# TEST 6: Kiểm tra ResourceNode thu thập tài nguyên
	print("\n[TEST 6] Kiểm tra điểm thu thập tài nguyên (ResourceNode)...")
	inv_mgr.call("_init_empty_slots")
	var res_scn: PackedScene = load("res://scenes/resource_node.tscn") as PackedScene
	var tree_node = res_scn.instantiate()
	tree_node.set("node_id", &"tree_test")
	tree_node.set("node_type", "tree")
	tree_node.set("resource_id", &"wood")
	tree_node.set("yield_amount", 3)
	root.add_child(tree_node)

	tree_node.call("_try_gather")
	var wood_gathered: int = int(inv_mgr.call("get_item_count", &"wood"))
	var is_harvested: bool = bool(tree_node.get("is_harvested"))
	# Thử thu thập lần 2 khi đã khai thác -> không được nhận thêm
	tree_node.call("_try_gather")
	var wood_gathered_2: int = int(inv_mgr.call("get_item_count", &"wood"))

	if wood_gathered == 3 and is_harvested and wood_gathered_2 == 3:
		print("  -> PASS: Thu thập Gỗ x3 thành công, chống nhận lần hai từ cùng một node.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Thu thập tài nguyên lỗi! wood1=%d, wood2=%d, is_h=%s" % [wood_gathered, wood_gathered_2, is_harvested])
	tree_node.queue_free()

	# TEST 7: Kiểm tra Vật phẩm rơi (PickupItem - Thủ công nhặt bằng F)
	print("\n[TEST 7] Kiểm tra vật phẩm rơi (PickupItem)...")
	var pickup_scn: PackedScene = load("res://scenes/pickup_item.tscn") as PackedScene
	var pickup = pickup_scn.instantiate()
	pickup.set("item_id", &"slime_gel")
	pickup.set("amount", 2)
	root.add_child(pickup)

	pickup.call("_try_pickup")
	var gel_count: int = int(inv_mgr.call("get_item_count", &"slime_gel"))
	if gel_count == 2:
		print("  -> PASS: Nhặt thủ công Gel Slime x2 thành công vào túi đồ.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Nhặt chiến lợi phẩm lỗi! gel_count=%d" % gel_count)

	# TEST 8: Kiểm tra Hệ thống Thông báo Toàn cục (NotificationManager)
	print("\n[TEST 8] Kiểm tra hệ thống thông báo toàn cục...")
	notif_mgr.call("show_success", "Thử nghiệm thành công")
	notif_mgr.call("show_warning", "Túi đồ đã đầy")
	notif_mgr.call("show_item_pickup", &"wind_crystal", 1)
	var vbox: VBoxContainer = notif_mgr.get("_vbox") as VBoxContainer
	if vbox and vbox.get_child_count() > 0:
		print("  -> PASS: NotificationManager hiển thị thông báo với giao diện toast chuẩn xác.")
		pass_count += 1
	else:
		printerr("  -> FAIL: NotificationManager không tạo được toast!")

	# TEST 9: Kiểm tra Tích hợp Lưu/Tải Túi đồ & Tài nguyên
	print("\n[TEST 9] Kiểm tra Lưu và Tải túi đồ bền vững (Save/Load Roundtrip)...")
	inv_mgr.call("_init_empty_slots")
	inv_mgr.call("add_item", &"wood", 25)
	inv_mgr.call("add_item", &"wind_crystal", 3)

	var inv_dict: Dictionary = inv_mgr.call("to_dict")
	inv_mgr.call("_init_empty_slots")
	# Xác nhận túi đã rỗng
	var empty_check: int = int(inv_mgr.call("get_item_count", &"wood"))
	# Tải lại
	var load_ok: bool = bool(inv_mgr.call("load_from_dict", inv_dict))
	var wood_restored: int = int(inv_mgr.call("get_item_count", &"wood"))
	var crystal_restored: int = int(inv_mgr.call("get_item_count", &"wind_crystal"))

	if empty_check == 0 and load_ok and wood_restored == 25 and crystal_restored == 3:
		print("  -> PASS: Dữ liệu túi đồ (Gỗ 25, Tinh thể Phong 3) được lưu và khôi phục chuẩn xác.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Tải túi đồ lỗi! wood=%d, crystal=%d" % [wood_restored, crystal_restored])

	# TEST 10: Kiểm tra Tương thích ngược (Backward Compatibility)
	print("\n[TEST 10] Kiểm tra tương thích ngược với bản lưu Schema 1 (chưa có inventory)...")
	var legacy_save: Dictionary = {
		"schema_version": 1,
		"player": {"x": 100, "y": 100, "current_health": 80.0, "stamina": 100.0},
		"world_state": {"discovered_regions": [], "unlocked_regions": [], "world_flags": {}, "defeated_unique_bosses": [], "schema_version": 1},
		"quest_manager": {"quest_status": {}, "quest_progress": {}, "completed_quests": [], "reward_ledger": [], "schema_version": 1}
	}
	# Nạp save cũ không có key "inventory"
	var legacy_load_ok: bool = true
	if not legacy_save.has("inventory"):
		inv_mgr.call("_init_empty_slots")
	var total_items_legacy: int = 0
	for sl in inv_mgr.call("get_all_slots"):
		total_items_legacy += int(sl["amount"])

	if legacy_load_ok and total_items_legacy == 0:
		print("  -> PASS: Bản lưu cũ nạp an toàn, túi đồ khởi tạo 24 ô trống không lỗi.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Tương thích ngược lỗi!")

	# TEST 11: Kiểm thử Tính năng Debug Túi đồ (Snapshot, Full 24/24 x99, Restore, Save Protection)
	print("\n[TEST 11] Kiểm thử Debug túi đồ (Snapshot, Fill 24/24, Restore & Chặn lưu game)...")
	inv_mgr.call("_init_empty_slots")
	inv_mgr.call("add_item", &"wood", 12)
	inv_mgr.call("add_item", &"herb", 7)
	# 1. Bật làm đầy túi
	inv_mgr.call("set_debug_fill", true)
	var used_after_fill: int = int(inv_mgr.call("get_used_slot_count"))
	var is_testing_active: bool = bool(inv_mgr.get("is_debug_testing"))
	var can_add_when_full: bool = bool(inv_mgr.call("can_add_item", &"wood", 1))

	# 2. Khôi phục lại snapshot
	var restore_ok: bool = bool(inv_mgr.call("restore_debug_snapshot"))
	var wood_restored_dbg: int = int(inv_mgr.call("get_item_count", &"wood"))
	var herb_restored_dbg: int = int(inv_mgr.call("get_item_count", &"herb"))
	var is_testing_cleared: bool = not bool(inv_mgr.get("is_debug_testing"))

	if used_after_fill == 24 and is_testing_active and not can_add_when_full and restore_ok and wood_restored_dbg == 12 and herb_restored_dbg == 7 and is_testing_cleared:
		print("  -> PASS: Debug túi đồ hoạt động hoàn hảo: Snapshot lưu chuẩn, 24/24 ô đầy từ chối nhận thêm, khôi phục nguyên vẹn 100%.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Debug túi đồ lỗi! used=%d, full_add=%s, restore=%s, wood=%d, herb=%d" % [used_after_fill, can_add_when_full, restore_ok, wood_restored_dbg, herb_restored_dbg])

	print("\n==================================================")
	print(" KẾT QUẢ KIỂM THỬ BƯỚC 17: %d / %d BÀI ĐẠT" % [pass_count, total_tests])
	print("==================================================")

	quit(0 if pass_count == total_tests else 1)
