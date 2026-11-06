extends Node

# QuestManager - Hệ thống quản lý nhiệm vụ hướng sự kiện (Event-Driven Quest System)
# Tách bạch định nghĩa nhiệm vụ tĩnh và tiến độ runtime.

const SCHEMA_VERSION: int = 1

enum QuestStatus {
	LOCKED = 0,
	AVAILABLE = 1,
	ACTIVE = 2,
	READY_TO_COMPLETE = 3,
	COMPLETED = 4
}

# Tín hiệu nhiệm vụ
signal quest_status_changed(quest_id: StringName, new_status: int)
signal quest_progress_updated(quest_id: StringName, objective_id: StringName, current: int, required: int)
signal quest_ready_to_complete(quest_id: StringName)
signal quest_completed(quest_id: StringName)
signal quest_notification(message: String)

# 1. DANH MỤC NHIỆM VỤ TĨNH (STATIC DEFINITIONS)
var _quest_definitions: Dictionary = {
	&"main_clear_slimes": {
		"id": &"main_clear_slimes",
		"title": "Thanh Trừng Slime",
		"description": "Tiêu diệt 3 Slime tại khu vực forest_clearing để dọn đường tiến vào rừng sâu.",
		"quest_type": "main",
		"auto_available": true,
		"objectives": [
			{
				"id": &"defeat_3_slimes",
				"description": "Tiêu diệt Slime tại forest_clearing",
				"type": "defeat_enemy",
				"target_id": &"slime",
				"region_id": &"forest_clearing",
				"required_amount": 3
			}
		],
		"rewards": {
			"unlock_regions": [&"deep_forest_plot"],
			"flags": { &"forest_slimes_cleared": true },
			"ledger": ["Mở khóa khu vực: deep_forest_plot", "Cờ: forest_slimes_cleared = true", "50 XP (ghi sổ chờ hệ thống cấp độ)"]
		}
	},
	&"side_forest_traces": {
		"id": &"side_forest_traces",
		"title": "Dấu Vết Trong Rừng",
		"description": "Khám phá địa điểm bí ẩn 'forest_traces' ở góc rừng phía Bắc đấu trường.",
		"quest_type": "side",
		"auto_available": true,
		"objectives": [
			{
				"id": &"discover_traces",
				"description": "Khám phá di tích forest_traces",
				"type": "discover_region",
				"target_id": &"forest_traces",
				"region_id": &"",
				"required_amount": 1
			}
		],
		"rewards": {
			"unlock_regions": [],
			"flags": { &"forest_traces_found": true },
			"ledger": ["Cờ: forest_traces_found = true", "30 XP (ghi sổ chờ hệ thống cấp độ)"]
		}
	}
}

# 2. DỮ LIỆU TIẾN ĐỘ RUNTIME
var _quest_status: Dictionary = {} # quest_id -> QuestStatus
var _quest_progress: Dictionary = {} # quest_id -> { objective_id: current_count }
var _completed_quests: Array[StringName] = []
var _reward_ledger: Array[Dictionary] = [] # Ghi nhận phần thưởng an toàn chống trùng lặp

var _is_loading: bool = false

func _ready() -> void:
	_init_default_quest_states()
	_connect_event_bus()

# Khởi tạo trạng thái ban đầu cho các nhiệm vụ
func _init_default_quest_states() -> void:
	for q_id in _quest_definitions.keys():
		var def: Dictionary = _quest_definitions[q_id]
		if def.get("auto_available", false):
			_quest_status[q_id] = QuestStatus.AVAILABLE
		else:
			_quest_status[q_id] = QuestStatus.LOCKED

		_quest_progress[q_id] = {}
		for obj in def.get("objectives", []):
			_quest_progress[q_id][obj["id"]] = 0

# Lắng nghe sự kiện từ EventBus
func _connect_event_bus() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if not event_bus:
		return

	if event_bus.has_signal("enemy_defeated"):
		event_bus.enemy_defeated.connect(_on_enemy_defeated)
	if event_bus.has_signal("region_discovered"):
		event_bus.region_discovered.connect(_on_region_discovered)

# Xử lý sự kiện tiêu diệt quái: CHỈ đếm cho các nhiệm vụ ACTIVE phù hợp
func _on_enemy_defeated(enemy_id: StringName, region_id: StringName) -> void:
	for q_id in _quest_status.keys():
		if _quest_status[q_id] != QuestStatus.ACTIVE:
			continue # Không đếm nếu chưa nhận nhiệm vụ hoặc đã xong!

		var def: Dictionary = _quest_definitions.get(q_id, {})
		var objectives: Array = def.get("objectives", [])

		for obj in objectives:
			if obj.get("type") == "defeat_enemy":
				var target_match: bool = (obj.get("target_id") == enemy_id)
				var req_region: StringName = obj.get("region_id", &"")
				var region_match: bool = (req_region == StringName() or req_region == region_id)

				if target_match and region_match:
					_advance_objective(q_id, obj["id"], 1, obj["required_amount"], obj.get("description", ""))

# Xử lý sự kiện khám phá khu vực
func _on_region_discovered(region_id: StringName) -> void:
	for q_id in _quest_status.keys():
		if _quest_status[q_id] != QuestStatus.ACTIVE:
			continue

		var def: Dictionary = _quest_definitions.get(q_id, {})
		var objectives: Array = def.get("objectives", [])

		for obj in objectives:
			if obj.get("type") == "discover_region":
				if obj.get("target_id") == region_id:
					_advance_objective(q_id, obj["id"], 1, obj["required_amount"], obj.get("description", ""))

# Tăng tiến độ mục tiêu và kiểm tra điều kiện sẵn sàng trả
func _advance_objective(quest_id: StringName, obj_id: StringName, amount: int, required: int, desc: String) -> void:
	if not _quest_progress.has(quest_id):
		_quest_progress[quest_id] = {}

	var cur: int = _quest_progress[quest_id].get(obj_id, 0)
	if cur >= required:
		return # Không tăng vượt required_amount

	cur = mini(required, cur + amount)
	_quest_progress[quest_id][obj_id] = cur

	quest_progress_updated.emit(quest_id, obj_id, cur, required)

	var def: Dictionary = _quest_definitions.get(quest_id, {})
	var title: String = def.get("title", str(quest_id))
	quest_notification.emit("Tiến độ [%s]: %d/%d (%s)" % [title, cur, required, desc])

	# Kiểm tra xem toàn bộ mục tiêu của nhiệm vụ đã đạt chưa
	if _are_all_objectives_completed(quest_id):
		_quest_status[quest_id] = QuestStatus.READY_TO_COMPLETE
		quest_status_changed.emit(quest_id, QuestStatus.READY_TO_COMPLETE)
		quest_ready_to_complete.emit(quest_id)
		quest_notification.emit("★ Nhiệm vụ sẵn sàng hoàn thành: %s! (Nhấn J để trả)" % title)

func _are_all_objectives_completed(quest_id: StringName) -> bool:
	var def: Dictionary = _quest_definitions.get(quest_id, {})
	var objectives: Array = def.get("objectives", [])
	var prog: Dictionary = _quest_progress.get(quest_id, {})

	for obj in objectives:
		var cur: int = prog.get(obj["id"], 0)
		var req: int = obj.get("required_amount", 1)
		if cur < req:
			return false
	return true

# --- 3. PUBLIC APIS ---

# Kích hoạt nhận nhiệm vụ
func activate_quest(quest_id: StringName) -> bool:
	if not _quest_definitions.has(quest_id):
		push_warning("QuestManager.activate_quest: Không tìm thấy quest_id: " + str(quest_id))
		return false

	var status: int = _quest_status.get(quest_id, QuestStatus.LOCKED)
	if status != QuestStatus.AVAILABLE:
		return false # Chỉ nhận được khi AVAILABLE

	_quest_status[quest_id] = QuestStatus.ACTIVE
	quest_status_changed.emit(quest_id, QuestStatus.ACTIVE)

	var title: String = _quest_definitions[quest_id].get("title", str(quest_id))
	quest_notification.emit("Đã nhận nhiệm vụ: " + title)
	return true

# Hoàn thành nhiệm vụ và nhận thưởng đúng một lần
func complete_quest(quest_id: StringName) -> bool:
	if not _quest_definitions.has(quest_id):
		return false

	var status: int = _quest_status.get(quest_id, QuestStatus.LOCKED)
	if status != QuestStatus.READY_TO_COMPLETE:
		return false # Phải đạt trạng thái READY_TO_COMPLETE mới được trả

	var def: Dictionary = _quest_definitions[quest_id]
	var rewards: Dictionary = def.get("rewards", {})

	# Áp dụng phần thưởng qua WorldState API (không sửa trực tiếp)
	var world_state = get_node_or_null("/root/WorldState")
	if world_state:
		# Mở khóa khu vực
		for r_id in rewards.get("unlock_regions", []):
			world_state.unlock_region(r_id)

		# Đặt cờ thế giới
		var flags: Dictionary = rewards.get("flags", {})
		for f_key in flags.keys():
			world_state.set_flag(f_key, flags[f_key])

	# Ghi nhận sổ cái phần thưởng (Reward Ledger)
	var timestamp := Time.get_time_string_from_system()
	for item in rewards.get("ledger", []):
		_reward_ledger.append({
			"time": timestamp,
			"quest_id": str(quest_id),
			"reward": str(item)
		})

	# Cập nhật trạng thái COMPLETED
	_quest_status[quest_id] = QuestStatus.COMPLETED
	if not (quest_id in _completed_quests):
		_completed_quests.append(quest_id)

	# Phát sự kiện toàn cục
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("quest_completed"):
		event_bus.quest_completed.emit(quest_id)

	quest_status_changed.emit(quest_id, QuestStatus.COMPLETED)
	quest_completed.emit(quest_id)

	var title: String = def.get("title", str(quest_id))
	quest_notification.emit("✓ HOÀN THÀNH: %s! Đã nhận thưởng." % title)
	return true

func get_quest_status(quest_id: StringName) -> int:
	return _quest_status.get(quest_id, QuestStatus.LOCKED)

func get_quest_definition(quest_id: StringName) -> Dictionary:
	return _quest_definitions.get(quest_id, {}).duplicate(true)

func get_all_quest_ids() -> Array:
	return _quest_definitions.keys()

func get_objective_progress(quest_id: StringName, obj_id: StringName) -> int:
	if _quest_progress.has(quest_id):
		return _quest_progress[quest_id].get(obj_id, 0)
	return 0

func get_reward_ledger() -> Array[Dictionary]:
	return _reward_ledger.duplicate(true)

func get_status_name(status: int) -> String:
	match status:
		QuestStatus.LOCKED: return "Chưa mở"
		QuestStatus.AVAILABLE: return "Có thể nhận"
		QuestStatus.ACTIVE: return "Đang thực hiện"
		QuestStatus.READY_TO_COMPLETE: return "Sẵn sàng trả"
		QuestStatus.COMPLETED: return "Đã hoàn thành"
		_: return "Không xác định"

# --- 4. SERIALIZATION (XUẤT & NẠP DỮ LIỆU) ---

func to_dict() -> Dictionary:
	var status_str: Dictionary = {}
	for k in _quest_status.keys():
		status_str[str(k)] = _quest_status[k]

	var prog_str: Dictionary = {}
	for q_key in _quest_progress.keys():
		prog_str[str(q_key)] = {}
		for o_key in _quest_progress[q_key].keys():
			prog_str[str(q_key)][str(o_key)] = _quest_progress[q_key][o_key]

	var comp_str: Array = []
	for c in _completed_quests:
		comp_str.append(str(c))

	return {
		"schema_version": SCHEMA_VERSION,
		"quest_status": status_str,
		"quest_progress": prog_str,
		"completed_quests": comp_str,
		"reward_ledger": _reward_ledger.duplicate(true)
	}

func load_from_dict(data: Dictionary) -> bool:
	if not (data is Dictionary):
		push_error("QuestManager.load_from_dict: Dữ liệu không hợp lệ!")
		return false

	if not data.has("schema_version") or int(data["schema_version"]) > SCHEMA_VERSION:
		push_error("QuestManager.load_from_dict: Schema không tương thích!")
		return false

	if not (data.has("quest_status") and data.has("quest_progress") and data.has("completed_quests") and data.has("reward_ledger")):
		push_error("QuestManager.load_from_dict: Thiếu trường bắt buộc!")
		return false

	_is_loading = true

	# Nạp status (chỉ chấp nhận các quest ID còn tồn tại trong danh mục)
	var in_status: Dictionary = data["quest_status"]
	for k in in_status.keys():
		var s_name := StringName(k)
		if _quest_definitions.has(s_name):
			_quest_status[s_name] = int(in_status[k])

	# Nạp progress
	var in_prog: Dictionary = data["quest_progress"]
	for q_key in in_prog.keys():
		var q_name := StringName(q_key)
		if _quest_definitions.has(q_name):
			if not _quest_progress.has(q_name):
				_quest_progress[q_name] = {}
			for o_key in in_prog[q_key].keys():
				_quest_progress[q_name][StringName(o_key)] = int(in_prog[q_key][o_key])

	# Nạp completed quests
	_completed_quests.clear()
	for c in data["completed_quests"]:
		var c_name := StringName(c)
		if _quest_definitions.has(c_name):
			_completed_quests.append(c_name)

	# Nạp reward ledger
	_reward_ledger.clear()
	for r in data["reward_ledger"]:
		if r is Dictionary:
			_reward_ledger.append(r)

	_is_loading = false
	return true

func test_roundtrip() -> bool:
	var original := to_dict()
	var json_str := JSON.stringify(original)
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		return false

	var ok := load_from_dict(parsed)
	var after := to_dict()
	return ok and (original == after)
