extends SceneTree

# Kịch bản kiểm thử toàn diện Bước 18: Crafting, Resource Processing, Consumables & Inventory Tests
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Test tự tạo các manager; bỏ autoload cùng tên để game và test dùng chung một bản.
	for autoload_name in ["InventoryManager", "NotificationManager", "EventBus", "WorldState", "CraftingManager", "SaveManager"]:
		var existing := root.get_node_or_null(autoload_name)
		if existing:
			existing.free()
	print("==================================================")
	print(" BẮT ĐẦU KIỂM THỬ BƯỚC 18: CRAFTING & CONSUMABLES")
	print("==================================================")

	var pass_count: int = 0
	var total_tests: int = 11

	# Nạp các Autoloads độc lập trong môi trường SceneTree headless
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

	var craft_mgr: Node = Node.new()
	var craft_script: Script = load("res://scripts/crafting_manager.gd")
	craft_mgr.set_script(craft_script)
	craft_mgr.name = "CraftingManager"
	root.add_child(craft_mgr)

	var save_mgr: Node = Node.new()
	var sm_script: Script = load("res://scripts/save_manager.gd")
	save_mgr.set_script(sm_script)
	save_mgr.name = "SaveManager"
	root.add_child(save_mgr)

	# TEST 1: Danh mục 10 vật phẩm chuẩn
	print("\n[TEST 1] Kiểm tra danh mục vật phẩm chuẩn (5 cũ + 5 mới Bước 18)...")
	var items: Array[StringName] = [
		&"wood", &"stone", &"herb", &"slime_gel", &"wind_crystal",
		&"wooden_plank", &"processed_stone", &"small_health_potion", &"wind_essence", &"basic_building_kit"
	]
	var catalog_ok: bool = true
	for it_id in items:
		var def = inv_mgr.call("get_item_def", it_id)
		if not def or def.id != it_id or def.name == "" or def.max_stack != 99:
			catalog_ok = false
			printerr("  -> Lỗi catalog với item: %s" % str(it_id))
			break

	var potion_def = inv_mgr.call("get_item_def", &"small_health_potion")
	if potion_def and potion_def.category != ItemDefinition.Category.CONSUMABLE:
		catalog_ok = false
		printerr("  -> small_health_potion phải thuộc Category.CONSUMABLE!")

	if catalog_ok:
		print("  -> PASS: Đủ 10 vật phẩm với max_stack=99, small_health_potion là CONSUMABLE.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Danh mục vật phẩm thiếu hoặc sai thông số!")

	# TEST 2: Đăng ký & Kiểm tra dữ liệu công thức CraftingRecipe
	print("\n[TEST 2] Kiểm tra 5 công thức chế tạo chuẩn...")
	var recipe_ids: Array[StringName] = [&"wooden_plank", &"processed_stone", &"small_health_potion", &"wind_essence", &"basic_building_kit"]
	var recipes_ok: bool = true
	for r_id in recipe_ids:
		var r = craft_mgr.call("get_recipe", r_id)
		if not r or not r.call("is_valid"):
			recipes_ok = false
			printerr("  -> Lỗi recipe: %s không hợp lệ!" % str(r_id))
			break
	var workbench_recipes: Array = craft_mgr.call("get_recipes_for_station", "workbench")
	if recipes_ok and workbench_recipes.size() >= 5:
		print("  -> PASS: 5 công thức đều hợp lệ và gán đúng station 'workbench'.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Công thức chế tạo thiếu hoặc không hợp lệ!")

	# TEST 3: Từ chối chế tạo khi thiếu nguyên liệu
	print("\n[TEST 3] Kiểm tra can_craft & craft khi thiếu nguyên liệu...")
	inv_mgr.call("_init_empty_slots")
	var can_craft_empty: bool = bool(craft_mgr.call("can_craft", &"wooden_plank", 1))
	var check_empty: Dictionary = craft_mgr.call("check_craft", &"wooden_plank", 1)
	var craft_empty_res: bool = bool(craft_mgr.call("craft", &"wooden_plank", 1))
	if not can_craft_empty and not craft_empty_res and check_empty.get("reason") == "Không đủ nguyên liệu":
		print("  -> PASS: Từ chối chế tạo an toàn, trả về lý do 'Không đủ nguyên liệu'.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Kiểm tra thiếu nguyên liệu không đúng mong đợi!")

	# TEST 4: Chế tạo thành công với đủ nguyên liệu (Giao dịch Atomic)
	print("\n[TEST 4] Kiểm tra chế tạo thành công: 3 Gỗ -> 2 Ván gỗ...")
	inv_mgr.call("add_item", &"wood", 6)
	var wood_before: int = int(inv_mgr.call("get_item_count", &"wood"))
	var craft_ok1: bool = bool(craft_mgr.call("craft", &"wooden_plank", 1))
	var wood_mid: int = int(inv_mgr.call("get_item_count", &"wood"))
	var plank_mid: int = int(inv_mgr.call("get_item_count", &"wooden_plank"))

	var craft_ok2: bool = bool(craft_mgr.call("craft", &"wooden_plank", 1))
	var wood_final: int = int(inv_mgr.call("get_item_count", &"wood"))
	var plank_final: int = int(inv_mgr.call("get_item_count", &"wooden_plank"))

	if craft_ok1 and craft_ok2 and wood_before == 6 and wood_mid == 3 and plank_mid == 2 and wood_final == 0 and plank_final == 4:
		print("  -> PASS: Chế tạo thành công 2 lần, trừ đủ 6 gỗ và cấp đủ 4 ván gỗ.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Kết quả chế tạo không khớp: wood=%d, plank=%d" % [wood_final, plank_final])

	# TEST 5: Công thức đa nguyên liệu: Thảo dược (3) + Gel Slime (1) -> Bình hồi phục (1)
	print("\n[TEST 5] Kiểm tra chế tạo Bình hồi phục nhỏ (đa nguyên liệu)...")
	inv_mgr.call("add_item", &"herb", 4)
	inv_mgr.call("add_item", &"slime_gel", 2)
	var potion_craft_ok: bool = bool(craft_mgr.call("craft", &"small_health_potion", 1))
	var herb_left: int = int(inv_mgr.call("get_item_count", &"herb"))
	var gel_left: int = int(inv_mgr.call("get_item_count", &"slime_gel"))
	var potion_count: int = int(inv_mgr.call("get_item_count", &"small_health_potion"))

	if potion_craft_ok and herb_left == 1 and gel_left == 1 and potion_count == 1:
		print("  -> PASS: Chế tạo Bình hồi phục nhỏ thành công, trừ đúng 3 thảo dược và 1 gel slime.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Chế tạo potion thất bại: herb=%d, gel=%d, potion=%d" % [herb_left, gel_left, potion_count])

	# TEST 6: Tính toán Sức chứa Ảo (Túi 24/24 ô đầy nhưng tiêu hao nguyên liệu giải phóng đúng 1 ô)
	print("\n[TEST 6] Kiểm tra tính toán sức chứa ảo (Virtual Space Simulation)...")
	inv_mgr.call("_init_empty_slots")
	# Đổ đầy 23 ô đầu bằng Đá x99
	for i in range(23):
		inv_mgr.call("add_item", &"stone", 99)
	# Ô thứ 24 chứa ĐÚNG 3 GỖ (không dư)
	inv_mgr.call("add_item", &"wood", 3)
	var used_slots_before: int = int(inv_mgr.call("get_used_slot_count"))

	# Lúc này túi có đủ 24/24 ô đầy. Nhưng chế tạo wooden_plank cần 3 gỗ -> khi tiêu hao 3 gỗ, ô thứ 24 sẽ trở thành ô TRỐNG!
	var can_craft_virtual: bool = bool(craft_mgr.call("can_craft", &"wooden_plank", 1))
	var craft_virtual_ok: bool = bool(craft_mgr.call("craft", &"wooden_plank", 1))
	var wood_after_virtual: int = int(inv_mgr.call("get_item_count", &"wood"))
	var plank_after_virtual: int = int(inv_mgr.call("get_item_count", &"wooden_plank"))

	if used_slots_before == 24 and can_craft_virtual and craft_virtual_ok and wood_after_virtual == 0 and plank_after_virtual == 2:
		print("  -> PASS: Thuật toán nhận diện chính xác ô được giải phóng, chuyển đổi 3 gỗ thành 2 ván gỗ an toàn!")
		pass_count += 1
	else:
		printerr("  -> FAIL: Virtual space check thất bại! can=%s, ok=%s, wood=%d, plank=%d" % [str(can_craft_virtual), str(craft_virtual_ok), wood_after_virtual, plank_after_virtual])

	# TEST 7: Từ chối chế tạo khi túi đầy và KHÔNG thể chứa đầu ra (Bảo toàn nguyên liệu)
	print("\n[TEST 7] Kiểm tra từ chối chế tạo khi túi 24/24 ô đầy và không còn chỗ chứa đầu ra...")
	inv_mgr.call("_init_empty_slots")
	# 23 ô chứa Đá x99
	for i in range(23):
		inv_mgr.call("add_item", &"stone", 99)
	# Ô thứ 24 chứa 99 GỖ
	inv_mgr.call("add_item", &"wood", 99)

	# Thử chế tạo wooden_plank: cần 3 gỗ, sau khi trừ còn 96 gỗ (ô thứ 24 vẫn chưa trống). Đầu ra là ván gỗ (item mới chưa có ô).
	var check_full: Dictionary = craft_mgr.call("check_craft", &"wooden_plank", 1)
	var craft_full_ok: bool = bool(craft_mgr.call("craft", &"wooden_plank", 1))
	var wood_preserved: int = int(inv_mgr.call("get_item_count", &"wood"))

	if not check_full.get("can_craft") and check_full.get("reason") == "Túi đồ không đủ chỗ" and not craft_full_ok and wood_preserved == 99:
		print("  -> PASS: Nhận diện chính xác 'Túi đồ không đủ chỗ', bảo toàn nguyên vẹn 99 gỗ không bị mất.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Không chặn được chế tạo khi túi đầy! check=%s, wood=%d" % [str(check_full), wood_preserved])

	# TEST 8: Kiểm tra các công thức còn lại: wind_essence & basic_building_kit
	print("\n[TEST 8] Kiểm tra chế tạo Tinh hoa Phong & Bộ dựng cơ bản...")
	inv_mgr.call("_init_empty_slots")
	inv_mgr.call("add_item", &"wind_crystal", 2)
	inv_mgr.call("add_item", &"slime_gel", 3)
	var essence_ok: bool = bool(craft_mgr.call("craft", &"wind_essence", 1))
	var essence_cnt: int = int(inv_mgr.call("get_item_count", &"wind_essence"))

	inv_mgr.call("add_item", &"wooden_plank", 2)
	inv_mgr.call("add_item", &"processed_stone", 2)
	var kit_ok: bool = bool(craft_mgr.call("craft", &"basic_building_kit", 1))
	var kit_cnt: int = int(inv_mgr.call("get_item_count", &"basic_building_kit"))

	if essence_ok and essence_cnt == 1 and kit_ok and kit_cnt == 1:
		print("  -> PASS: Chế tạo Tinh hoa Phong và Bộ dựng cơ bản thành công 100%.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Lỗi chế tạo essence=%d, kit=%d" % [essence_cnt, kit_cnt])

	# TEST 9: Sử dụng Bình hồi phục nhỏ (Consumable)
	print("\n[TEST 9] Kiểm tra sử dụng Bình hồi phục nhỏ (+30 HP, max cap, chặn khi full)...")
	# Tạo mock Player node
	var mock_player: CharacterBody2D = CharacterBody2D.new()
	mock_player.name = "Player"
	mock_player.add_to_group("player")
	mock_player.set("max_health", 100.0)
	mock_player.set("current_health", 40.0)
	mock_player.set("is_dead", false)
	# Gắn hàm heal cho mock_player
	var player_script = load("res://scripts/player.gd")
	mock_player.set_script(player_script)
	mock_player.current_health = 40.0
	mock_player.max_health = 100.0
	root.add_child(mock_player)
	mock_player.current_health = 40.0 # player.gd đặt đầy máu trong _ready

	inv_mgr.call("_init_empty_slots")
	inv_mgr.call("add_item", &"small_health_potion", 2)

	# Uống bình 1: từ 40 lên 70 HP
	var use1_ok: bool = bool(inv_mgr.call("use_item", &"small_health_potion"))
	var hp_after1: float = float(mock_player.current_health)
	var potions_left1: int = int(inv_mgr.call("get_item_count", &"small_health_potion"))

	# Uống bình 2: từ 70 lên 100 HP (đạt max 100)
	var use2_ok: bool = bool(inv_mgr.call("use_item", &"small_health_potion"))
	var hp_after2: float = float(mock_player.current_health)
	var potions_left2: int = int(inv_mgr.call("get_item_count", &"small_health_potion"))

	# Cấp thêm 1 bình và thử uống khi HP đã 100/100 -> Phải thất bại, không tiêu hao bình
	inv_mgr.call("add_item", &"small_health_potion", 1)
	var use3_fail: bool = bool(inv_mgr.call("use_item", &"small_health_potion"))
	var hp_after3: float = float(mock_player.current_health)
	var potions_left3: int = int(inv_mgr.call("get_item_count", &"small_health_potion"))

	if use1_ok and hp_after1 == 70.0 and potions_left1 == 1 and use2_ok and hp_after2 == 100.0 and potions_left2 == 0 and not use3_fail and hp_after3 == 100.0 and potions_left3 == 1:
		print("  -> PASS: Hồi máu chính xác (+30 HP), không vượt max 100, chặn khi full HP.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Consumable sai! hp1=%.1f, p1=%d, hp2=%.1f, p2=%d, use3=%s, p3=%d" % [hp_after1, potions_left1, hp_after2, potions_left2, str(use3_fail), potions_left3])

	# TEST 10: Kiểm tra Save & Load roundtrip với vật phẩm chế tạo
	print("\n[TEST 10] Kiểm tra Save/Load roundtrip bảo toàn vật phẩm chế tạo...")
	var inv_data: Dictionary = inv_mgr.call("to_dict")
	var saved_json_str: String = JSON.stringify(inv_data)
	var parsed_data = JSON.parse_string(saved_json_str)

	# Khởi tạo lại túi trống rồi nạp từ JSON
	inv_mgr.call("_init_empty_slots")
	var load_ok: bool = bool(inv_mgr.call("load_from_dict", parsed_data))
	var potion_loaded: int = int(inv_mgr.call("get_item_count", &"small_health_potion"))

	if load_ok and potion_loaded == 1:
		print("  -> PASS: Save/Load roundtrip hoàn hảo, bảo toàn chính xác vật phẩm đã chế tạo.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Load inventory thất bại hoặc sai số lượng!")

	# TEST 11: F3 Debug Inventory Snapshot & Block Save during test
	print("\n[TEST 11] Kiểm tra F3 Debug Snapshot, Fill 24/24 và Khôi phục...")
	inv_mgr.call("_init_empty_slots")
	inv_mgr.call("add_item", &"wood", 12)
	inv_mgr.call("add_item", &"herb", 8)

	# Nhấn Fill debug
	inv_mgr.call("set_debug_fill", true)
	var is_testing_now: bool = bool(inv_mgr.get("is_debug_testing"))
	var full_slots_cnt: int = int(inv_mgr.call("get_used_slot_count"))

	# Kiểm tra SaveManager chặn lưu
	var save_attempt: bool = bool(save_mgr.call("save_game", 0))

	# Khôi phục
	var restore_ok: bool = bool(inv_mgr.call("restore_debug_snapshot"))
	var is_testing_after: bool = bool(inv_mgr.get("is_debug_testing"))
	var wood_restored: int = int(inv_mgr.call("get_item_count", &"wood"))
	var herb_restored: int = int(inv_mgr.call("get_item_count", &"herb"))

	if is_testing_now and full_slots_cnt == 24 and not save_attempt and restore_ok and not is_testing_after and wood_restored == 12 and herb_restored == 8:
		print("  -> PASS: Debug Fill tạo đủ 24/24 ô đầy, SaveManager chặn lưu an toàn, Khôi phục trả về đúng 100% snapshot ban đầu.")
		pass_count += 1
	else:
		printerr("  -> FAIL: Debug snapshot/restore lỗi! testing=%s, full=%d, save_block=%s, restore=%s, wood=%d" % [str(is_testing_now), full_slots_cnt, str(not save_attempt), str(restore_ok), wood_restored])

	print("\n==================================================")
	print(" KẾT QUẢ KIỂM THỬ: %d / %d BÀI ĐẠT PASS" % [pass_count, total_tests])
	print("==================================================")

	# Dọn dẹp mock node
	mock_player.queue_free()
	quit()
