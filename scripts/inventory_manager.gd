extends Node

# Autoload InventoryManager - Quản lý Túi đồ & Tài nguyên (Bước 17)
signal inventory_changed
signal item_added(item_id: StringName, amount: int)
signal item_removed(item_id: StringName, amount: int)
signal inventory_full(item_id: StringName, excess_amount: int)

const MAX_SLOTS: int = 24
const DEFAULT_MAX_STACK: int = 99

# Danh mục định nghĩa vật phẩm chuẩn toàn game
var _catalog: Dictionary = {}

# Mảng 24 ô túi đồ, mỗi ô là Dictionary: {"item_id": StringName, "amount": int}
var _slots: Array[Dictionary] = []

# Cờ nạp dữ liệu im lặng (không kích hoạt notification / tín hiệu thừa khi Load)
var _is_loading: bool = false

# Dữ liệu phục vụ kiểm thử Debug túi đồ (Bước 17)
var is_debug_testing: bool = false
var _debug_snapshot: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_catalog()
	_init_empty_slots()

# Khởi tạo danh mục 10 vật phẩm chuẩn (5 vật phẩm Bước 17 + 5 vật phẩm Bước 18)
func _init_catalog() -> void:
	var wood_tex: Texture2D = load("res://assets/items/wood.png") as Texture2D
	var stone_tex: Texture2D = load("res://assets/items/stone.png") as Texture2D
	var herb_tex: Texture2D = load("res://assets/items/herb.png") as Texture2D
	var gel_tex: Texture2D = load("res://assets/items/slime_gel.png") as Texture2D
	var crystal_tex: Texture2D = load("res://assets/items/wind_crystal.png") as Texture2D

	var plank_tex: Texture2D = load("res://assets/items/wooden_plank.png") as Texture2D
	var proc_stone_tex: Texture2D = load("res://assets/items/processed_stone.png") as Texture2D
	var potion_tex: Texture2D = load("res://assets/items/small_health_potion.png") as Texture2D
	var essence_tex: Texture2D = load("res://assets/items/wind_essence.png") as Texture2D
	var kit_tex: Texture2D = load("res://assets/items/basic_building_kit.png") as Texture2D

	_catalog[&"wood"] = ItemDefinition.new(
		&"wood", "Gỗ",
		"Thân cây gỗ chắc khỏe lấy từ rừng sâu, dùng để chế tạo và gia cố.",
		wood_tex, ItemDefinition.Category.MATERIAL, 99
	)
	_catalog[&"stone"] = ItemDefinition.new(
		&"stone", "Đá",
		"Khối đá xám cứng cáp khai thác từ các vách đá cổ xưa.",
		stone_tex, ItemDefinition.Category.MATERIAL, 99
	)
	_catalog[&"herb"] = ItemDefinition.new(
		&"herb", "Thảo dược",
		"Lá cây thuốc thanh khiết tỏa hương thơm dịu, có dược tính phục hồi.",
		herb_tex, ItemDefinition.Category.MATERIAL, 99
	)
	_catalog[&"slime_gel"] = ItemDefinition.new(
		&"slime_gel", "Gel Slime",
		"Chất keo dẻo xanh lá trong suốt rơi ra từ Slime rừng.",
		gel_tex, ItemDefinition.Category.MATERIAL, 99
	)
	_catalog[&"wind_crystal"] = ItemDefinition.new(
		&"wind_crystal", "Tinh thể Phong",
		"Mảnh pha lê chứa luồng gió cuộn xoáy vĩnh cửu, tỏa sáng ngọc bích.",
		crystal_tex, ItemDefinition.Category.MATERIAL, 99
	)

	# 5 vật phẩm chế tạo và tiêu hao mới (Bước 18)
	_catalog[&"wooden_plank"] = ItemDefinition.new(
		&"wooden_plank", "Ván gỗ",
		"Tấm ván gỗ đã được xẻ mịn và gia công từ gỗ thô.",
		plank_tex, ItemDefinition.Category.MATERIAL, 99
	)
	_catalog[&"processed_stone"] = ItemDefinition.new(
		&"processed_stone", "Đá chế biến",
		"Khối đá được mài phẳng góc cạnh, sẵn sàng cho việc xây dựng cơ bản.",
		proc_stone_tex, ItemDefinition.Category.MATERIAL, 99
	)
	_catalog[&"small_health_potion"] = ItemDefinition.new(
		&"small_health_potion", "Bình hồi phục nhỏ",
		"Dược phẩm pha chế từ thảo dược và gel slime, giúp hồi 30 HP khi uống.",
		potion_tex, ItemDefinition.Category.CONSUMABLE, 99
	)
	_catalog[&"wind_essence"] = ItemDefinition.new(
		&"wind_essence", "Tinh hoa Phong",
		"Tinh chất gió cô đặc tinh khiết từ pha lê phong và chất xúc tác gel.",
		essence_tex, ItemDefinition.Category.MATERIAL, 99
	)
	_catalog[&"basic_building_kit"] = ItemDefinition.new(
		&"basic_building_kit", "Bộ dựng cơ bản",
		"Bộ dụng cụ và vật liệu tiền chế từ ván gỗ và gạch đá.",
		kit_tex, ItemDefinition.Category.MATERIAL, 99
	)

func _init_empty_slots() -> void:
	_slots.clear()
	for i in range(MAX_SLOTS):
		_slots.append({
			"item_id": StringName(),
			"amount": 0
		})

# Lấy định nghĩa vật phẩm từ catalog
func get_item_def(item_id: StringName) -> ItemDefinition:
	if _catalog.has(item_id):
		return _catalog[item_id] as ItemDefinition
	return null

# Kiểm tra túi đồ có đủ chỗ chứa lượng vật phẩm này không (không làm thay đổi dữ liệu)
func can_add_item(item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	var def := get_item_def(item_id)
	if not def:
		return false

	var max_s: int = def.max_stack
	var space_available: int = 0

	for slot in _slots:
		if slot["item_id"] == item_id:
			space_available += max_s - int(slot["amount"])
		elif slot["item_id"] == StringName():
			space_available += max_s

	return space_available >= amount

# Thêm vật phẩm vào túi đồ (hỗ trợ cộng dồn theo max_stack)
# Trả về số lượng còn dư không thể thêm (0 nếu đã thêm trọn vẹn)
func add_item(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return amount
	var def := get_item_def(item_id)
	if not def:
		push_error("InventoryManager.add_item: Không tìm thấy vật phẩm có ID '%s'!" % item_id)
		return amount

	var remaining: int = amount
	var max_s: int = def.max_stack
	var added_total: int = 0

	# 1. Điền vào các ô đã có cùng loại vật phẩm nhưng chưa đầy stack
	for slot in _slots:
		if slot["item_id"] == item_id and slot["amount"] < max_s:
			var can_take: int = max_s - int(slot["amount"])
			var to_add: int = mini(remaining, can_take)
			slot["amount"] += to_add
			remaining -= to_add
			added_total += to_add
			if remaining <= 0:
				break

	# 2. Điền tiếp vào các ô trống nếu vẫn còn dư
	if remaining > 0:
		for slot in _slots:
			if slot["item_id"] == StringName():
				slot["item_id"] = item_id
				var to_add: int = mini(remaining, max_s)
				slot["amount"] = to_add
				remaining -= to_add
				added_total += to_add
				if remaining <= 0:
					break

	if added_total > 0:
		if not _is_loading:
			item_added.emit(item_id, added_total)
		inventory_changed.emit()

	if remaining > 0 and not _is_loading:
		inventory_full.emit(item_id, remaining)

	return remaining

# Loại bỏ số lượng vật phẩm khỏi túi đồ
# Trả về true nếu đủ số lượng và đã gỡ thành công, false nếu không đủ (giao dịch all-or-nothing)
func remove_item(item_id: StringName, amount: int) -> bool:
	if amount <= 0 or not has_item(item_id, amount):
		return false

	var remaining: int = amount

	# Gỡ từ ô sau về ô trước
	for i in range(MAX_SLOTS - 1, -1, -1):
		var slot: Dictionary = _slots[i]
		if slot["item_id"] == item_id:
			var take: int = mini(remaining, int(slot["amount"]))
			slot["amount"] -= take
			remaining -= take
			if slot["amount"] <= 0:
				slot["item_id"] = StringName()
				slot["amount"] = 0
			if remaining <= 0:
				break

	if not _is_loading:
		item_removed.emit(item_id, amount)
	inventory_changed.emit()
	return true

# Gỡ nhiều loại nguyên liệu như một giao dịch: kiểm tra đủ toàn bộ trước,
# cập nhật tất cả ô rồi mới phát tín hiệu để listener không thấy trạng thái nửa chừng.
func remove_items_atomic(costs: Dictionary) -> bool:
	if costs.is_empty():
		return false
	for raw_id in costs:
		var item_id := StringName(raw_id)
		var amount := int(costs[raw_id])
		if amount <= 0 or not _catalog.has(item_id) or not has_item(item_id, amount):
			return false

	for raw_id in costs:
		var item_id := StringName(raw_id)
		var remaining := int(costs[raw_id])
		for i in range(MAX_SLOTS - 1, -1, -1):
			if _slots[i]["item_id"] != item_id:
				continue
			var take := mini(remaining, int(_slots[i]["amount"]))
			_slots[i]["amount"] -= take
			remaining -= take
			if _slots[i]["amount"] <= 0:
				_slots[i]["item_id"] = StringName()
				_slots[i]["amount"] = 0
			if remaining <= 0:
				break
	for raw_id in costs:
		if not _is_loading:
			item_removed.emit(StringName(raw_id), int(costs[raw_id]))
	inventory_changed.emit()
	return true

# Đếm tổng số lượng của vật phẩm trong túi đồ
func get_item_count(item_id: StringName) -> int:
	var total: int = 0
	for slot in _slots:
		if slot["item_id"] == item_id:
			total += int(slot["amount"])
	return total

# Kiểm tra xem có đủ số lượng vật phẩm yêu cầu không
func has_item(item_id: StringName, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount

# Lấy bản sao thông tin ô thứ index (read-only)
func get_slot(index: int) -> Dictionary:
	if index >= 0 and index < MAX_SLOTS:
		return _slots[index].duplicate()
	return {"item_id": StringName(), "amount": 0}

# Lấy bản sao toàn bộ danh sách 24 ô
func get_all_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in _slots:
		result.append(slot.duplicate())
	return result

# Chuyển đổi dữ liệu túi đồ sang Dictionary để lưu game (JSON serializable)
func to_dict() -> Dictionary:
	var slots_data: Array = []
	for i in range(MAX_SLOTS):
		var slot: Dictionary = _slots[i]
		if slot["item_id"] != StringName() and slot["amount"] > 0:
			slots_data.append({
				"slot": i,
				"id": str(slot["item_id"]),
				"amount": int(slot["amount"])
			})

	return {
		"schema_version": 1,
		"max_slots": MAX_SLOTS,
		"slots": slots_data
	}

# Khôi phục dữ liệu túi đồ từ Dictionary (Silent Load)
func load_from_dict(data: Dictionary) -> bool:
	if not (data is Dictionary):
		push_error("InventoryManager.load_from_dict: Dữ liệu không phải Dictionary!")
		return false

	_is_loading = true
	_init_empty_slots()

	var slots_arr = data.get("slots", [])
	if slots_arr is Array:
		for entry in slots_arr:
			if entry is Dictionary:
				var slot_idx: int = int(entry.get("slot", -1))
				var item_str: String = str(entry.get("id", ""))
				var amt: int = int(entry.get("amount", 0))

				if slot_idx >= 0 and slot_idx < MAX_SLOTS and item_str != "" and amt > 0:
					var item_id := StringName(item_str)
					if _catalog.has(item_id):
						var max_s: int = (_catalog[item_id] as ItemDefinition).max_stack
						_slots[slot_idx]["item_id"] = item_id
						_slots[slot_idx]["amount"] = clampi(amt, 1, max_s)

	_is_loading = false
	inventory_changed.emit()
	return true

# Sử dụng vật phẩm tiêu hao tại ô chỉ định (Bước 18 - Consumables)
func use_item_at_slot(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return false

	var slot = _slots[slot_idx]
	var item_id: StringName = slot.get("item_id", StringName())
	var amount: int = int(slot.get("amount", 0))

	if item_id == StringName() or amount <= 0:
		return false

	var def = get_item_def(item_id)
	if not def or def.category != ItemDefinition.Category.CONSUMABLE:
		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_warning("Vật phẩm này không thể sử dụng!")
		return false

	if item_id == &"small_health_potion":
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			var root = get_tree().current_scene
			if root:
				player = root.get_node_or_null("Player")

		if not player:
			return false

		if player.get("is_dead") == true:
			var notif_mgr = get_node_or_null("/root/NotificationManager")
			if notif_mgr:
				notif_mgr.show_warning("Nhân vật đã tử trận, không thể sử dụng vật phẩm!")
			return false

		var cur_hp: float = float(player.get("current_health"))
		var max_hp: float = float(player.get("max_health"))
		if cur_hp >= max_hp:
			var notif_mgr = get_node_or_null("/root/NotificationManager")
			if notif_mgr:
				notif_mgr.show_warning("HP đã đầy")
			return false

		# Hồi 30 HP, không vượt quá max_health
		if player.has_method("heal"):
			player.heal(30.0)
		else:
			player.set("current_health", minf(cur_hp + 30.0, max_hp))
			if player.has_signal("health_changed"):
				player.health_changed.emit(player.get("current_health"), max_hp)

		# Tiêu hao đúng 1 bình
		slot["amount"] -= 1
		if slot["amount"] <= 0:
			slot["item_id"] = StringName()
			slot["amount"] = 0

		item_removed.emit(item_id, 1)
		inventory_changed.emit()

		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_success("Đã sử dụng Bình hồi phục nhỏ")

		return true

	return false

# Sử dụng vật phẩm tiêu hao theo ID (tìm ô đầu tiên có chứa vật phẩm)
func use_item(item_id: StringName) -> bool:
	for i in range(MAX_SLOTS):
		if _slots[i]["item_id"] == item_id and int(_slots[i]["amount"]) > 0:
			return use_item_at_slot(i)
	return false

# Đếm số ô đang chứa vật phẩm
func get_used_slot_count() -> int:
	var count: int = 0
	for slot in _slots:
		if slot["item_id"] != StringName() and int(slot["amount"]) > 0:
			count += 1
	return count

# Làm đầy toàn bộ 24 ô túi đồ bằng 5 vật phẩm hợp lệ theo max_stack (99)
func set_debug_fill(full_stacks: bool = true) -> void:
	if not is_debug_testing:
		_debug_snapshot = to_dict()
		is_debug_testing = true

	var test_items: Array[StringName] = [&"wood", &"stone", &"herb", &"slime_gel", &"wind_crystal"]
	for i in range(MAX_SLOTS):
		var item_id: StringName = test_items[i % test_items.size()]
		var def := get_item_def(item_id)
		var max_s: int = def.max_stack if def else DEFAULT_MAX_STACK
		_slots[i]["item_id"] = item_id
		# Nếu full_stacks = false, để ô đầu tiên chỉ có 50 vật phẩm để kiểm thử cộng dồn
		if not full_stacks and i == 0:
			_slots[i]["amount"] = 50
		else:
			_slots[i]["amount"] = max_s

	inventory_changed.emit()

# Khôi phục trạng thái túi đồ về đúng snapshot trước khi kiểm thử
func restore_debug_snapshot() -> bool:
	if not is_debug_testing or _debug_snapshot.is_empty():
		return false

	var ok := load_from_dict(_debug_snapshot)
	_debug_snapshot.clear()
	is_debug_testing = false
	inventory_changed.emit()
	return ok
