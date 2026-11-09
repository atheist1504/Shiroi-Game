extends Node

# GachaManager - Quay nhân vật 5 sao, bảo hiểm và danh sách nhân vật sở hữu.
# Kết quả mỗi lượt chỉ phụ thuộc seed và số lượt đã quay (đều nằm trong save),
# nên F5 rồi F9 không thể quay lại để đổi kết quả.

signal roster_changed

const SCHEMA_VERSION: int = 1
const COST_PER_PULL: int = 10
const RATE_FIVE_STAR: float = 0.08
const PITY_PULLS: int = 30
const MAX_RANK: int = 5
const RANK_SPEED_BONUS: float = 0.1
const GOLD_PER_OVERFLOW_ITEM: int = 5
const LEGACY_SAVE_SEED: String = "shiroi_legacy_save"

# Dữ liệu tạm: tên, nghề và màu sẽ được thay khi có thiết kế chính thức.
const CHARACTERS: Array = [
	{"id": &"gacha_char_01", "name": "Nhân vật 01", "job": &"blacksmith", "job_name": "Thợ rèn", "work_speed": 2.0, "color": Color(0.85, 0.42, 0.25)},
	{"id": &"gacha_char_02", "name": "Nhân vật 02", "job": &"alchemist", "job_name": "Dược sư", "work_speed": 2.0, "color": Color(0.35, 0.78, 0.5)},
	{"id": &"gacha_char_03", "name": "Nhân vật 03", "job": &"lumberjack", "job_name": "Tiều phu", "work_speed": 2.0, "color": Color(0.62, 0.48, 0.3)},
	{"id": &"gacha_char_04", "name": "Nhân vật 04", "job": &"miner", "job_name": "Thợ mỏ", "work_speed": 2.0, "color": Color(0.55, 0.62, 0.75)},
	{"id": &"gacha_char_05", "name": "Nhân vật 05", "job": &"guard", "job_name": "Lính canh", "work_speed": 2.0, "color": Color(0.8, 0.3, 0.45)}
]

# Trọng số tổng 92 tương ứng 92% lượt không ra nhân vật.
const LOOT_TABLE: Array = [
	{"weight": 37, "gold": true, "min": 20, "max": 60},
	{"weight": 14, "item_id": &"wood", "min": 3, "max": 6},
	{"weight": 13, "item_id": &"stone", "min": 3, "max": 6},
	{"weight": 13, "item_id": &"herb", "min": 2, "max": 5},
	{"weight": 8, "item_id": &"slime_gel", "min": 1, "max": 3},
	{"weight": 7, "item_id": &"wind_crystal", "min": 1, "max": 2}
]

var _seed: String = ""
var _total_pulls: int = 0
var _pity: int = 0
var _roster: Dictionary = {} # character_id -> {"rank": int, "souls": int}

func _ready() -> void:
	_seed = str(randi())

func get_characters() -> Array:
	return CHARACTERS

func get_character(character_id: StringName) -> Dictionary:
	for character in CHARACTERS:
		if character["id"] == character_id:
			return character
	return {}

func is_owned(character_id: StringName) -> bool:
	return _roster.has(character_id)

func get_rank(character_id: StringName) -> int:
	return int(_roster.get(character_id, {}).get("rank", 0))

func get_souls(character_id: StringName) -> int:
	return int(_roster.get(character_id, {}).get("souls", 0))

func get_pity() -> int:
	return _pity

func get_work_speed(character_id: StringName) -> float:
	var character := get_character(character_id)
	if character.is_empty() or not is_owned(character_id):
		return 1.0
	return float(character["work_speed"]) * (1.0 + RANK_SPEED_BONUS * get_rank(character_id))

# Trả về {"ok": bool, "reason": String, "results": Array}.
func pull(count: int) -> Dictionary:
	if count != 1 and count != 10:
		return _failure("Số lượt quay không hợp lệ.")
	var wallet := get_node_or_null("/root/WalletManager")
	var inventory := get_node_or_null("/root/InventoryManager")
	if not wallet or not inventory:
		return _failure("Thiếu hệ thống ví hoặc túi đồ.")
	if bool(inventory.get("is_debug_testing")):
		return _failure("Túi đồ đang ở chế độ kiểm thử.")
	if not wallet.call("spend_tinh_van", COST_PER_PULL * count):
		return _failure("Không đủ Tinh Vẫn.")
	var results: Array = []
	for _i in count:
		results.append(_resolve_pull(wallet, inventory))
	return {"ok": true, "reason": "", "results": results}

func rank_up(character_id: StringName) -> bool:
	if not is_owned(character_id) or get_souls(character_id) < 1 or get_rank(character_id) >= MAX_RANK:
		return false
	_roster[character_id]["souls"] = get_souls(character_id) - 1
	_roster[character_id]["rank"] = get_rank(character_id) + 1
	roster_changed.emit()
	return true

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "results": []}

func _resolve_pull(wallet: Node, inventory: Node) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [_seed, _total_pulls])
	_total_pulls += 1
	_pity += 1
	if _pity >= PITY_PULLS or rng.randf() < RATE_FIVE_STAR:
		_pity = 0
		return _grant_character(rng)
	return _grant_loot(rng, wallet, inventory)

func _grant_character(rng: RandomNumberGenerator) -> Dictionary:
	var character: Dictionary = CHARACTERS[rng.randi_range(0, CHARACTERS.size() - 1)]
	var character_id: StringName = character["id"]
	var is_new := not is_owned(character_id)
	if is_new:
		_roster[character_id] = {"rank": 0, "souls": 0}
	else:
		_roster[character_id]["souls"] = get_souls(character_id) + 1
	roster_changed.emit()
	return {"type": "character", "character_id": character_id, "is_new": is_new}

func _grant_loot(rng: RandomNumberGenerator, wallet: Node, inventory: Node) -> Dictionary:
	var entry := _pick_loot_entry(rng)
	var amount := rng.randi_range(int(entry["min"]), int(entry["max"]))
	if entry.get("gold", false):
		wallet.call("add_gold", amount)
		return {"type": "gold", "amount": amount}
	var item_id: StringName = entry["item_id"]
	# Túi đầy thì đổi phần dư thành vàng để không mất phần thưởng.
	var overflow := amount
	if inventory.call("can_add_item", item_id, amount):
		overflow = int(inventory.call("add_item", item_id, amount))
	var converted_gold := overflow * GOLD_PER_OVERFLOW_ITEM
	if converted_gold > 0:
		wallet.call("add_gold", converted_gold)
	return {"type": "item", "item_id": item_id, "amount": amount - overflow, "converted_gold": converted_gold}

func _pick_loot_entry(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for entry in LOOT_TABLE:
		total += int(entry["weight"])
	var roll := rng.randi_range(1, total)
	for entry in LOOT_TABLE:
		roll -= int(entry["weight"])
		if roll <= 0:
			return entry
	return LOOT_TABLE[0]

func to_dict() -> Dictionary:
	var roster_safe: Dictionary = {}
	for character_id in _roster:
		roster_safe[str(character_id)] = _roster[character_id].duplicate()
	return {"schema_version": SCHEMA_VERSION, "seed": _seed, "total_pulls": _total_pulls, "pity": _pity, "roster": roster_safe}

static func is_valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema_version", 0)) > SCHEMA_VERSION:
		return false
	if int(data.get("total_pulls", 0)) < 0 or int(data.get("pity", 0)) < 0:
		return false
	var roster: Variant = data.get("roster", {})
	if not roster is Dictionary:
		return false
	for entry in roster.values():
		if not entry is Dictionary or int(entry.get("rank", 0)) < 0 or int(entry.get("souls", 0)) < 0:
			return false
	return true

# Save cũ không có dữ liệu gacha dùng seed cố định để F9 vẫn không đổi được kết quả.
func load_from_dict(data: Dictionary) -> bool:
	if not is_valid_snapshot(data):
		return false
	_seed = str(data.get("seed", LEGACY_SAVE_SEED))
	_total_pulls = int(data.get("total_pulls", 0))
	_pity = clampi(int(data.get("pity", 0)), 0, PITY_PULLS - 1)
	_roster.clear()
	var roster: Dictionary = data.get("roster", {})
	for raw_id in roster:
		var character_id := StringName(str(raw_id))
		if not get_character(character_id).is_empty():
			_roster[character_id] = {"rank": mini(int(roster[raw_id].get("rank", 0)), MAX_RANK), "souls": int(roster[raw_id].get("souls", 0))}
	roster_changed.emit()
	return true
