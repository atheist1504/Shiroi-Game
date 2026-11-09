extends Node

# PartyManager - Tổ đội tối đa 3 người, mỗi lúc một người trên sân.
# Giữ một thân Player duy nhất và nạp chỉ số, máu, năng lượng, hồi chiêu của
# thành viên đang ra sân. Thành viên khác nằm trong _states theo từng nhân vật.

signal party_changed
signal combo_triggered(combo_name: String, hit_count: int)

const SCHEMA_VERSION: int = 1
const MAX_PARTY_SIZE: int = 3
const PROTAGONIST_ID: StringName = &"protagonist"
const BASE_ATTACK: float = 20.0
const SWITCH_COOLDOWN: float = 1.5
const COMBO_WINDOW: float = 4.0
const COMBO_COOLDOWN: float = 6.0
const COMBO_RADIUS: float = 96.0
const REVIVE_SECONDS: float = 30.0
const REVIVE_HEALTH_RATIO: float = 0.3

const PROTAGONIST_PROFILE: Dictionary = {
	"id": PROTAGONIST_ID, "name": "Nhân vật chính", "job_name": "", "element": &"wind",
	"max_health": 100.0, "attack_damage": 20.0, "color": Color(1.0, 1.0, 1.0)
}

# Dữ liệu tạm: tên kỹ năng và phối hợp sẽ được thay khi có thiết kế chính thức.
const ELEMENTS: Dictionary = {
	&"wind": {"name": "Gió", "color": Color(0.25, 0.95, 0.82), "e_name": "Phong Nhận", "r_name": "Bão Phong"},
	&"fire": {"name": "Lửa", "color": Color(1.0, 0.45, 0.2), "e_name": "Hỏa Nhận", "r_name": "Bão Lửa"},
	&"water": {"name": "Nước", "color": Color(0.3, 0.6, 1.0), "e_name": "Thủy Nhận", "r_name": "Xoáy Nước"},
	&"earth": {"name": "Đất", "color": Color(0.8, 0.62, 0.32), "e_name": "Thạch Nhận", "r_name": "Bão Cát"}
}

# Khóa là hai nguyên tố đã sắp xếp theo bảng chữ cái.
const COMBOS: Dictionary = {
	"fire+wind": {"name": "Hỏa Phong", "damage": 60.0},
	"water+wind": {"name": "Sương Phong", "damage": 30.0, "slow": 0.5, "slow_time": 3.0},
	"earth+wind": {"name": "Sa Bạo", "damage": 30.0, "stun": 1.5},
	"fire+water": {"name": "Hơi Bỏng", "damage": 45.0, "slow": 0.35, "slow_time": 2.0},
	"earth+fire": {"name": "Dung Nham", "damage": 50.0, "stun": 0.8},
	"earth+water": {"name": "Bùn Lầy", "damage": 20.0, "slow": 0.7, "slow_time": 4.0}
}

var _party: Array[StringName] = [PROTAGONIST_ID]
var _active_index: int = 0
var _states: Dictionary = {} # character_id -> {hp, energy, e_cd, r_cd, revive}
var _switch_cooldown: float = 0.0
var _combo_cooldown: float = 0.0
var _combat_window: float = 0.0
var _wiped: bool = false
var _player: Node = null

func _ready() -> void:
	_gacha().roster_changed.connect(_on_roster_changed)

func _process(delta: float) -> void:
	_switch_cooldown = maxf(0.0, _switch_cooldown - delta)
	_combo_cooldown = maxf(0.0, _combo_cooldown - delta)
	_combat_window = maxf(0.0, _combat_window - delta)
	if _wiped:
		return
	var active_id := get_active_id()
	var revived := false
	for character_id in _states:
		var state: Dictionary = _states[character_id]
		if character_id != active_id:
			state["e_cd"] = maxf(0.0, float(state["e_cd"]) - delta)
			state["r_cd"] = maxf(0.0, float(state["r_cd"]) - delta)
		if float(state["revive"]) > 0.0:
			state["revive"] = float(state["revive"]) - delta
			if float(state["revive"]) <= 0.0:
				state["revive"] = 0.0
				state["hp"] = float(get_profile(character_id)["max_health"]) * REVIVE_HEALTH_RATIO
				revived = true
	if revived:
		party_changed.emit()

func get_party() -> Array[StringName]:
	return _party.duplicate()

func get_active_slot() -> int:
	return _active_index

func get_active_id() -> StringName:
	return _party[_active_index]

func get_profile(character_id: StringName) -> Dictionary:
	if character_id == PROTAGONIST_ID:
		return PROTAGONIST_PROFILE
	var character: Dictionary = _gacha().get_character(character_id)
	if character.is_empty():
		return {}
	var profile := character.duplicate()
	var multiplier: float = _gacha().get_combat_multiplier(character_id)
	profile["max_health"] = float(character["max_health"]) * multiplier
	profile["attack_damage"] = float(character["attack_damage"]) * multiplier
	return profile

func is_fallen(character_id: StringName) -> bool:
	return float(_get_state(character_id)["hp"]) <= 0.0

# Trả về máu hiện tại để UI hiển thị; người trên sân đọc trực tiếp từ Player.
func get_member_status(character_id: StringName) -> Dictionary:
	var state := _get_state(character_id)
	var health := float(state["hp"])
	var player := _find_player()
	if player and character_id == get_active_id():
		health = float(player.get("current_health"))
	return {"hp": health, "max_hp": float(get_profile(character_id)["max_health"]), "revive": float(state["revive"])}

func add_member(character_id: StringName) -> bool:
	if character_id == PROTAGONIST_ID or character_id in _party or _party.size() >= MAX_PARTY_SIZE:
		return false
	if not _gacha().is_owned(character_id):
		return false
	_party.append(character_id)
	party_changed.emit()
	return true

func remove_member(character_id: StringName) -> bool:
	if character_id == PROTAGONIST_ID or not character_id in _party:
		return false
	var was_active := character_id == get_active_id()
	if was_active:
		_sync_active_from_player()
		if _first_alive_slot(character_id) < 0:
			return false
	var keep_id := get_active_id()
	if was_active:
		keep_id = _party[_first_alive_slot(character_id)]
	_party.erase(character_id)
	_active_index = _party.find(keep_id)
	if was_active:
		_apply_active_to_player()
	party_changed.emit()
	return true

func try_switch(slot: int) -> Dictionary:
	if slot < 0 or slot >= _party.size():
		return _switch_failure("Ô đội hình này đang trống.")
	if slot == _active_index:
		return _switch_failure("")
	if _switch_cooldown > 0.0:
		return _switch_failure("Chưa đổi người được (%.1fs)." % _switch_cooldown)
	var player := _find_player()
	if not player or bool(player.get("is_dead")) or bool(player.get("is_dodging")):
		return _switch_failure("")
	var target_id := _party[slot]
	if is_fallen(target_id):
		return _switch_failure("%s đã gục, hồi lại sau %ds." % [get_profile(target_id)["name"], ceili(float(_get_state(target_id)["revive"]))])
	var previous_element: StringName = get_profile(get_active_id())["element"]
	_sync_active_from_player()
	_active_index = slot
	_switch_cooldown = SWITCH_COOLDOWN
	_apply_active_to_player()
	var combo_name := _try_trigger_combo(previous_element, player as Node2D)
	party_changed.emit()
	return {"ok": true, "reason": "", "combo": combo_name}

# Gọi khi người trên sân dùng kỹ năng hoặc đánh trúng, mở cửa sổ phối hợp.
func notify_combat_action() -> void:
	_combat_window = COMBO_WINDOW

# Người trên sân hết máu: đổi người còn sống. Trả về false nếu cả đội đã gục.
func handle_active_fallen() -> bool:
	_sync_active_from_player()
	var state := _get_state(get_active_id())
	state["hp"] = 0.0
	state["revive"] = REVIVE_SECONDS
	var next_slot := _first_alive_slot(get_active_id())
	if next_slot < 0:
		_wiped = true
		party_changed.emit()
		return false
	var fallen_name: String = get_profile(get_active_id())["name"]
	_active_index = next_slot
	_apply_active_to_player()
	_send_feedback("%s đã gục!" % fallen_name)
	party_changed.emit()
	return true

# Player mới vào scene. Sau khi cả đội gục và chơi lại, mọi người hồi đầy máu.
func bind_player(player: Node) -> void:
	_player = player
	if _wiped:
		_wiped = false
		_states.clear()
	_apply_active_to_player()
	party_changed.emit()

func to_dict() -> Dictionary:
	_sync_active_from_player()
	var party_ids: Array = []
	for character_id in _party:
		party_ids.append(str(character_id))
	var states: Dictionary = {}
	for character_id in _states:
		var state: Dictionary = _states[character_id]
		states[str(character_id)] = {"hp": state["hp"], "energy": state["energy"], "revive": state["revive"]}
	return {"schema_version": SCHEMA_VERSION, "party": party_ids, "active_index": _active_index, "states": states}

static func is_valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema_version", 0)) > SCHEMA_VERSION:
		return false
	var party: Variant = data.get("party", [str(PROTAGONIST_ID)])
	if not party is Array or party.is_empty() or party.size() > MAX_PARTY_SIZE or str(party[0]) != str(PROTAGONIST_ID):
		return false
	var seen: Dictionary = {}
	for character_id in party:
		if seen.has(str(character_id)):
			return false
		seen[str(character_id)] = true
	var active_index := int(data.get("active_index", 0))
	if active_index < 0 or active_index >= party.size():
		return false
	var states: Variant = data.get("states", {})
	if not states is Dictionary:
		return false
	for state in states.values():
		if not state is Dictionary:
			return false
		if float(state.get("hp", 0.0)) < 0.0 or float(state.get("energy", 0.0)) < 0.0 or float(state.get("revive", 0.0)) < 0.0:
			return false
	return true

# Save cũ không có dữ liệu tổ đội sẽ trở về đội chỉ có nhân vật chính.
func load_from_dict(data: Dictionary) -> bool:
	if not is_valid_snapshot(data):
		return false
	var saved_party: Array = data.get("party", [str(PROTAGONIST_ID)])
	var saved_active_id := StringName(str(saved_party[int(data.get("active_index", 0))]))
	_party.clear()
	for raw_id in saved_party:
		var character_id := StringName(str(raw_id))
		if character_id == PROTAGONIST_ID or _gacha().is_owned(character_id):
			_party.append(character_id)
	_states.clear()
	var saved_states: Dictionary = data.get("states", {})
	for raw_id in saved_states:
		var character_id := StringName(str(raw_id))
		if get_profile(character_id).is_empty():
			continue
		var saved: Dictionary = saved_states[raw_id]
		var state := _get_state(character_id)
		state["hp"] = minf(float(saved.get("hp", state["hp"])), float(get_profile(character_id)["max_health"]))
		state["energy"] = float(saved.get("energy", 0.0))
		state["revive"] = float(saved.get("revive", 0.0))
		if float(state["hp"]) <= 0.0 and float(state["revive"]) <= 0.0:
			state["revive"] = REVIVE_SECONDS
	_switch_cooldown = 0.0
	_combo_cooldown = 0.0
	_combat_window = 0.0
	_wiped = false
	_active_index = maxi(_party.find(saved_active_id), 0)
	if is_fallen(get_active_id()):
		var alive_slot := _first_alive_slot(get_active_id())
		if alive_slot >= 0:
			_active_index = alive_slot
		else:
			var state := _get_state(get_active_id())
			state["hp"] = float(get_profile(get_active_id())["max_health"]) * REVIVE_HEALTH_RATIO
			state["revive"] = 0.0
	_apply_active_to_player()
	party_changed.emit()
	return true

func _gacha() -> Node:
	return get_node("/root/GachaManager")

func _find_player() -> Node:
	if is_instance_valid(_player) and _player.is_inside_tree():
		return _player
	return get_tree().get_first_node_in_group("player")

func _get_state(character_id: StringName) -> Dictionary:
	if not _states.has(character_id):
		_states[character_id] = {"hp": float(get_profile(character_id)["max_health"]), "energy": 0.0, "e_cd": 0.0, "r_cd": 0.0, "revive": 0.0}
	return _states[character_id]

func _first_alive_slot(excluded_id: StringName) -> int:
	for slot in _party.size():
		if _party[slot] != excluded_id and not is_fallen(_party[slot]):
			return slot
	return -1

func _switch_failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "combo": ""}

func _sync_active_from_player() -> void:
	var player := _find_player()
	if not player:
		return
	var state := _get_state(get_active_id())
	var health := float(player.get("current_health"))
	if health > 0.0:
		state["revive"] = 0.0
		_wiped = false
	state["hp"] = health
	var skill := player.get_node_or_null("SkillComponent")
	if skill:
		state["energy"] = float(skill.get("current_energy"))
		state["e_cd"] = float(skill.get("e_cooldown_timer"))
		state["r_cd"] = float(skill.get("r_cooldown_timer"))

func _apply_active_to_player() -> void:
	var player := _find_player()
	if not player or not player.has_method("apply_party_member"):
		return
	var character_id := get_active_id()
	var profile := get_profile(character_id)
	var state := _get_state(character_id)
	player.call("apply_party_member", profile, float(state["hp"]))
	var skill := player.get_node_or_null("SkillComponent")
	if skill:
		var element: Dictionary = ELEMENTS[profile["element"]]
		var kit := {"e_name": element["e_name"], "r_name": element["r_name"], "tint": element["color"], "damage_scale": float(profile["attack_damage"]) / BASE_ATTACK}
		skill.call("apply_member_kit", kit, float(state["energy"]), float(state["e_cd"]), float(state["r_cd"]))

func _on_roster_changed() -> void:
	# Tăng bậc làm đổi chỉ số của người đang trên sân.
	_sync_active_from_player()
	_apply_active_to_player()
	party_changed.emit()

func _combo_key(first: StringName, second: StringName) -> String:
	var names := [str(first), str(second)]
	names.sort()
	return "%s+%s" % names

func _try_trigger_combo(previous_element: StringName, player: Node2D) -> String:
	var profile := get_profile(get_active_id())
	var new_element: StringName = profile["element"]
	if _combat_window <= 0.0 or _combo_cooldown > 0.0 or previous_element == new_element:
		return ""
	var combo: Dictionary = COMBOS[_combo_key(previous_element, new_element)]
	_combat_window = 0.0
	_combo_cooldown = COMBO_COOLDOWN
	var damage: float = float(combo["damage"]) * float(profile["attack_damage"]) / BASE_ATTACK
	var hit_count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if not enemy or bool(enemy.get("is_dead")):
			continue
		if player.global_position.distance_to(enemy.global_position) > COMBO_RADIUS or _is_wall_between(player, enemy.global_position):
			continue
		var status := enemy.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
		if status and combo.has("slow"):
			status.apply_slow(float(combo["slow"]), float(combo["slow_time"]))
		if status and combo.has("stun"):
			status.apply_hard_cc(float(combo["stun"]))
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", damage, (enemy.global_position - player.global_position).normalized())
			hit_count += 1
	_spawn_combo_ring(player, ELEMENTS[new_element]["color"])
	_send_feedback("Phối hợp: %s!" % combo["name"])
	combo_triggered.emit(combo["name"], hit_count)
	return combo["name"]

func _is_wall_between(player: Node2D, target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(player.global_position, target)
	query.collision_mask = 1
	return not player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _spawn_combo_ring(player: Node2D, color: Color) -> void:
	var ring: Node2D = preload("res://scripts/combo_ring.gd").new()
	ring.set("radius", COMBO_RADIUS)
	ring.set("color", color)
	var parent := get_tree().current_scene if get_tree().current_scene else player.get_parent()
	parent.add_child(ring)
	ring.global_position = player.global_position

func _send_feedback(message: String) -> void:
	var player := _find_player()
	var skill := player.get_node_or_null("SkillComponent") if player else null
	if skill:
		skill.skill_feedback.emit(message)
