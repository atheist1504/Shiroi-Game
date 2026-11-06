extends Node

# WorldState - Quản lý trạng thái thế giới bền vững (Persistent World State)
# Đảm bảo tính Idempotent và đóng gói dữ liệu an toàn.

const SCHEMA_VERSION: int = 1

var _discovered_regions: Array[StringName] = [&"forest_clearing"]
var _unlocked_regions: Array[StringName] = [&"forest_clearing"]
var _world_flags: Dictionary = {}
var _defeated_unique_bosses: Array[StringName] = []

# Cờ kiểm soát nạp dữ liệu: Khi đang nạp (load), không phát tín hiệu thưởng ngoài ý muốn
var _is_loading: bool = false

func _ready() -> void:
	pass

# --- 1. KHU VỰC (REGIONS) ---

# Khám phá khu vực mới
func discover_region(region_id: StringName) -> bool:
	if region_id == StringName():
		push_warning("WorldState.discover_region: region_id rỗng!")
		return false

	if region_id in _discovered_regions:
		return false # Idempotent: Đã khám phá rồi thì không thêm trùng

	_discovered_regions.append(region_id)

	if not _is_loading:
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus and event_bus.has_signal("region_discovered"):
			event_bus.region_discovered.emit(region_id)

	return true

# Mở khóa khu vực
func unlock_region(region_id: StringName) -> bool:
	if region_id == StringName():
		push_warning("WorldState.unlock_region: region_id rỗng!")
		return false

	# Tự động ghi nhận đã khám phá nếu chưa có
	discover_region(region_id)

	if region_id in _unlocked_regions:
		return false # Idempotent: Đã mở khóa rồi thì không xử lý lại

	_unlocked_regions.append(region_id)

	if not _is_loading:
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus and event_bus.has_signal("region_unlocked"):
			event_bus.region_unlocked.emit(region_id)

	return true

func is_region_discovered(region_id: StringName) -> bool:
	return region_id in _discovered_regions

func is_region_unlocked(region_id: StringName) -> bool:
	return region_id in _unlocked_regions

func get_discovered_regions() -> Array[StringName]:
	return _discovered_regions.duplicate()

func get_unlocked_regions() -> Array[StringName]:
	return _unlocked_regions.duplicate()


# --- 2. CỜ THẾ GIỚI (WORLD FLAGS) ---

func set_flag(flag_id: StringName, value: Variant) -> bool:
	if flag_id == StringName():
		push_warning("WorldState.set_flag: flag_id rỗng!")
		return false

	# Idempotent: Nếu cờ đã tồn tại và mang cùng giá trị thì không phát tín hiệu thừa
	if _world_flags.has(flag_id) and _world_flags[flag_id] == value:
		return false

	_world_flags[flag_id] = value

	if not _is_loading:
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus and event_bus.has_signal("world_flag_changed"):
			event_bus.world_flag_changed.emit(flag_id, value)

	return true

func get_flag(flag_id: StringName, default_value: Variant = null) -> Variant:
	return _world_flags.get(flag_id, default_value)

func has_flag(flag_id: StringName) -> bool:
	return _world_flags.has(flag_id)

func get_all_flags() -> Dictionary:
	return _world_flags.duplicate(true)


# --- 3. BOSS DUY NHẤT (UNIQUE BOSSES) ---

func mark_unique_boss_defeated(boss_id: StringName) -> bool:
	if boss_id == StringName():
		push_warning("WorldState.mark_unique_boss_defeated: boss_id rỗng!")
		return false

	if boss_id in _defeated_unique_bosses:
		return false # Idempotent: Boss duy nhất chỉ đánh bại 1 lần

	_defeated_unique_bosses.append(boss_id)
	set_flag("boss_defeated_" + str(boss_id), true)
	return true

func is_unique_boss_defeated(boss_id: StringName) -> bool:
	return boss_id in _defeated_unique_bosses

func get_defeated_unique_bosses() -> Array[StringName]:
	return _defeated_unique_bosses.duplicate()


# --- 4. SERIALIZATION (XUẤT & NẠP DỮ LIỆU JSON AN TOÀN) ---

func to_dict() -> Dictionary:
	var disc_str: Array = []
	for r in _discovered_regions:
		disc_str.append(str(r))

	var unlk_str: Array = []
	for r in _unlocked_regions:
		unlk_str.append(str(r))

	var boss_str: Array = []
	for b in _defeated_unique_bosses:
		boss_str.append(str(b))

	# JSON an toàn: chuyển các key dạng StringName thành String
	var flags_safe: Dictionary = {}
	for k in _world_flags.keys():
		flags_safe[str(k)] = _world_flags[k]

	return {
		"schema_version": SCHEMA_VERSION,
		"discovered_regions": disc_str,
		"unlocked_regions": unlk_str,
		"world_flags": flags_safe,
		"defeated_unique_bosses": boss_str
	}

func load_from_dict(data: Dictionary) -> bool:
	if not (data is Dictionary):
		push_error("WorldState.load_from_dict: Dữ liệu không phải Dictionary!")
		return false

	# Kiểm tra schema_version
	if not data.has("schema_version") or int(data["schema_version"]) > SCHEMA_VERSION:
		push_error("WorldState.load_from_dict: Phiên bản dữ liệu không tương thích!")
		return false

	# Kiểm tra các trường bắt buộc
	if not (data.has("discovered_regions") and data.has("unlocked_regions") and data.has("world_flags") and data.has("defeated_unique_bosses")):
		push_error("WorldState.load_from_dict: Dữ liệu thiếu trường bắt buộc!")
		return false

	# Bật cờ loading để nạp dữ liệu trong im lặng, không kích hoạt phát thưởng trùng
	_is_loading = true

	_discovered_regions.clear()
	for r in data["discovered_regions"]:
		_discovered_regions.append(StringName(str(r)))

	_unlocked_regions.clear()
	for r in data["unlocked_regions"]:
		_unlocked_regions.append(StringName(str(r)))

	_world_flags.clear()
	var in_flags = data["world_flags"]
	if in_flags is Dictionary:
		for k in in_flags.keys():
			_world_flags[StringName(str(k))] = in_flags[k]

	_defeated_unique_bosses.clear()
	for b in data["defeated_unique_bosses"]:
		_defeated_unique_bosses.append(StringName(str(b)))

	_is_loading = false
	return true

# Kiểm tra tính toàn vẹn xuất/nạp vòng lặp (Round-trip test)
func test_roundtrip() -> bool:
	var original_dict := to_dict()
	var json_str := JSON.stringify(original_dict)
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		return false

	var success := load_from_dict(parsed)
	var after_dict := to_dict()
	return success and (original_dict == after_dict)
