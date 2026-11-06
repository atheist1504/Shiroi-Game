extends Node

# Autoload CraftingManager - Quản lý Chế tạo & Chế biến Nguyên liệu (Bước 18)
signal crafting_completed(recipe_id: StringName, amount: int)
signal recipe_list_changed

# Danh mục công thức đã đăng ký: { StringName recipe_id: CraftingRecipe }
var _recipes: Dictionary = {}

# Khóa chống spam click liên tục gây lỗi race condition / nhân đôi vật phẩm
var _is_crafting: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_default_recipes()

# Khởi tạo 5 công thức thử nghiệm chuẩn theo yêu cầu Bước 18
func _init_default_recipes() -> void:
	_recipes.clear()

	# 1. wooden_plank: 3 wood -> 2 wooden_plank
	register_recipe(CraftingRecipe.new(
		&"wooden_plank",
		"Ván gỗ x2",
		"Xẻ 3 súc gỗ thô thành 2 tấm ván gỗ nhẵn mịn phục vụ gia cố và xây cất.",
		{ &"wood": 3 },
		&"wooden_plank",
		2,
		"workbench"
	))

	# 2. processed_stone: 3 stone -> 2 processed_stone
	register_recipe(CraftingRecipe.new(
		&"processed_stone",
		"Đá chế biến x2",
		"Đẽo gọt 3 khối đá thô thành 2 khối đá gạch vuông vắn chịu lực tốt.",
		{ &"stone": 3 },
		&"processed_stone",
		2,
		"workbench"
	))

	# 3. small_health_potion: 3 herb + 1 slime_gel -> 1 small_health_potion
	register_recipe(CraftingRecipe.new(
		&"small_health_potion",
		"Bình hồi phục nhỏ",
		"Dược dịch pha chế từ 3 thảo dược và 1 gel slime, hồi 30 HP khi sử dụng.",
		{ &"herb": 3, &"slime_gel": 1 },
		&"small_health_potion",
		1,
		"workbench"
	))

	# 4. wind_essence: 2 wind_crystal + 3 slime_gel -> 1 wind_essence
	register_recipe(CraftingRecipe.new(
		&"wind_essence",
		"Tinh hoa Phong",
		"Hòa quyện năng lượng của 2 tinh thể phong cùng 3 gel slime làm chất dẫn dung môi.",
		{ &"wind_crystal": 2, &"slime_gel": 3 },
		&"wind_essence",
		1,
		"workbench"
	))

	# 5. basic_building_kit: 2 wooden_plank + 2 processed_stone -> 1 basic_building_kit
	register_recipe(CraftingRecipe.new(
		&"basic_building_kit",
		"Bộ dựng cơ bản",
		"Kết hợp 2 ván gỗ và 2 đá chế biến tạo thành bộ dụng cụ và vật liệu tiền chế.",
		{ &"wooden_plank": 2, &"processed_stone": 2 },
		&"basic_building_kit",
		1,
		"workbench"
	))

	recipe_list_changed.emit()

# Đăng ký công thức mới vào hệ thống (có kiểm tra dữ liệu hợp lệ)
func register_recipe(recipe: CraftingRecipe) -> bool:
	if not recipe or not recipe.is_valid():
		push_error("CraftingManager.register_recipe: Công thức không hợp lệ!")
		return false
	if _recipes.has(recipe.id):
		push_warning("CraftingManager.register_recipe: Ghi đè công thức ID '%s'." % recipe.id)

	_recipes[recipe.id] = recipe
	return true

# Lấy công thức theo ID
func get_recipe(recipe_id: StringName) -> CraftingRecipe:
	if _recipes.has(recipe_id):
		return _recipes[recipe_id] as CraftingRecipe
	return null

# Lấy toàn bộ danh sách công thức
func get_all_recipes() -> Array[CraftingRecipe]:
	var list: Array[CraftingRecipe] = []
	for recipe in _recipes.values():
		list.append(recipe as CraftingRecipe)
	return list

# Lấy danh sách công thức phù hợp với loại bàn chế tạo
func get_recipes_for_station(station_type: String) -> Array[CraftingRecipe]:
	var list: Array[CraftingRecipe] = []
	for recipe in _recipes.values():
		var r: CraftingRecipe = recipe as CraftingRecipe
		if r.station_type == station_type or station_type == "" or station_type == "all":
			list.append(r)
	return list

# Kiểm tra điều kiện chế tạo chi tiết: trả về Dictionary {"can_craft": bool, "reason": String}
func check_craft(recipe_id: StringName, amount: int = 1) -> Dictionary:
	if amount <= 0:
		return {"can_craft": false, "reason": "Số lượng chế tạo phải lớn hơn 0!"}

	var recipe: CraftingRecipe = get_recipe(recipe_id)
	if not recipe:
		return {"can_craft": false, "reason": "Công thức chế tạo không tồn tại!"}

	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if not inv_mgr:
		return {"can_craft": false, "reason": "Không tìm thấy InventoryManager!"}

	# 1. Kiểm tra đủ nguyên liệu
	for mat_id in recipe.materials.keys():
		var req_amt: int = int(recipe.materials[mat_id]) * amount
		var current_amt: int = int(inv_mgr.get_item_count(StringName(mat_id)))
		if current_amt < req_amt:
			return {"can_craft": false, "reason": "Không đủ nguyên liệu"}

	# 2. Tính toán chính xác sức chứa sau khi nguyên liệu bị tiêu hao (Virtual Space Simulation)
	var sim_slots: Array[Dictionary] = inv_mgr.get_all_slots()

	# Trừ ảo nguyên liệu khỏi sim_slots
	for mat_id in recipe.materials.keys():
		var to_remove: int = int(recipe.materials[mat_id]) * amount
		for i in range(sim_slots.size() - 1, -1, -1):
			var slot = sim_slots[i]
			if slot["item_id"] == StringName(mat_id):
				var take: int = mini(to_remove, int(slot["amount"]))
				slot["amount"] -= take
				to_remove -= take
				if slot["amount"] <= 0:
					slot["item_id"] = StringName()
					slot["amount"] = 0
				if to_remove <= 0:
					break

	# Thêm ảo sản phẩm đầu ra vào sim_slots đã giải phóng nguyên liệu
	var out_id: StringName = recipe.output_item_id
	var out_total: int = recipe.output_amount * amount
	var out_def = inv_mgr.get_item_def(out_id)
	var max_s: int = out_def.max_stack if out_def else 99

	var remaining_out: int = out_total
	# Thử điền vào ô cùng loại chưa đầy
	for slot in sim_slots:
		if slot["item_id"] == out_id and slot["amount"] < max_s:
			var can_take: int = max_s - int(slot["amount"])
			var to_add: int = mini(remaining_out, can_take)
			slot["amount"] += to_add
			remaining_out -= to_add
			if remaining_out <= 0:
				break

	# Điền tiếp vào các ô trống (kể cả ô vừa được giải phóng do tiêu hao nguyên liệu)
	if remaining_out > 0:
		for slot in sim_slots:
			if slot["item_id"] == StringName():
				slot["item_id"] = out_id
				var to_add: int = mini(remaining_out, max_s)
				slot["amount"] = to_add
				remaining_out -= to_add
				if remaining_out <= 0:
					break

	if remaining_out > 0:
		return {"can_craft": false, "reason": "Túi đồ không đủ chỗ"}

	return {"can_craft": true, "reason": ""}

# API kiểm tra nhanh can_craft
func can_craft(recipe_id: StringName, amount: int = 1) -> bool:
	return check_craft(recipe_id, amount)["can_craft"]

# Thực hiện giao dịch chế tạo nguyên tử (Atomic Crafting Transaction)
# Đảm bảo trừ nguyên liệu và cấp vật phẩm đầu ra cùng lúc; rollback toàn bộ nếu có bất kỳ lỗi nào.
func craft(recipe_id: StringName, amount: int = 1) -> bool:
	if _is_crafting:
		return false

	var check = check_craft(recipe_id, amount)
	if not check["can_craft"]:
		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_warning(check["reason"])
		return false

	var recipe: CraftingRecipe = get_recipe(recipe_id)
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if not recipe or not inv_mgr:
		return false

	_is_crafting = true

	# Lưu snapshot túi đồ phòng khi cần rollback
	var rollback_snapshot: Dictionary = inv_mgr.to_dict()

	# 1. Trừ nguyên liệu
	var deduct_success: bool = true
	for mat_id in recipe.materials.keys():
		var req_amt: int = int(recipe.materials[mat_id]) * amount
		if not inv_mgr.remove_item(StringName(mat_id), req_amt):
			deduct_success = false
			break

	if not deduct_success:
		# Rollback ngay
		inv_mgr.load_from_dict(rollback_snapshot)
		_is_crafting = false
		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_warning("Không đủ nguyên liệu")
		return false

	# 2. Thêm vật phẩm đầu ra
	var out_total: int = recipe.output_amount * amount
	var excess: int = inv_mgr.add_item(recipe.output_item_id, out_total)

	if excess > 0:
		# Lỗi không lường trước: không nhét đủ đầu ra -> Rollback toàn bộ giao dịch!
		inv_mgr.load_from_dict(rollback_snapshot)
		_is_crafting = false
		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_warning("Túi đồ không đủ chỗ")
		return false

	_is_crafting = false

	# 3. Phát tín hiệu thành công
	crafting_completed.emit(recipe_id, amount)

	# Thông báo thành công
	var out_def = inv_mgr.get_item_def(recipe.output_item_id)
	var out_name: String = out_def.name if out_def else str(recipe.output_item_id)
	var notif_mgr = get_node_or_null("/root/NotificationManager")
	if notif_mgr:
		notif_mgr.show_success("Chế tạo thành công: %s x%d" % [out_name, out_total])

	return true
