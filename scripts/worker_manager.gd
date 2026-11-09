extends Node

# WorkerManager - Nhân vật gacha không ở trong đội sẽ làm việc theo nghề.
# Dùng chung thân NPC và lưới toàn bản đồ của NPCManager; NPC dân làng cũ vẫn do NPCManager lo.

const NPC_SCENE: PackedScene = preload("res://scenes/autonomous_test_npc.tscn")
const SCHEMA_VERSION: int = 1
const JOB_RESOURCES: Dictionary = {
	&"blacksmith": [&"iron_ore"],
	&"alchemist": [&"herb"],
	&"lumberjack": [&"wood"],
	&"miner": [&"stone", &"gold_ore"],
	&"guard": []
}
const SPAWN_POSITION: Vector2 = Vector2(704, 600)
const MOVE_SPEED: float = 80.0
const WORK_DURATION: float = 4.0 # Chia cho tốc độ làm việc của nhân vật
const INTERACTION_RANGE: float = 32.0
const INTERACTION_GAP: float = 16.0
const RETRY_DELAY: float = 2.0
const MAX_PATH_TRIES: int = 3
const MAX_STUCK_REPATHS: int = 3
const GUARD_ALERT_MARGIN: float = 140.0
const GUARD_ATTACK_RANGE: float = 36.0
const GUARD_ATTACK_INTERVAL: float = 1.0
const GUARD_DAMAGE: float = 15.0

class Worker:
	var character_id: StringName
	var npc_id: StringName
	var job: StringName
	var body: Node2D
	var task_kind: String = ""
	var task_node: Node2D = null
	var task_building: Node2D = null
	var work_remaining: float = 0.0
	var idle_retry: float = 0.0
	var attack_timer: float = 0.0
	var repaths: int = 0

var _workers: Dictionary = {} # character_id -> Worker
var _sync_pending: bool = true

func _ready() -> void:
	get_node("/root/GachaManager").roster_changed.connect(_request_sync)
	get_node("/root/PartyManager").party_changed.connect(_request_sync)

func _process(delta: float) -> void:
	var navigation := _navigation()
	if not navigation or not navigation.has_world_navigation():
		return
	if _sync_pending:
		sync_workers()
	for worker: Worker in _workers.values():
		if not is_instance_valid(worker.body):
			continue
		if worker.job == &"guard":
			_update_guard(worker, delta)
		else:
			_update_gatherer(worker, delta)

func get_worker_body(character_id: StringName) -> Node2D:
	return _workers[character_id].body if _workers.has(character_id) else null

func get_worker_ids() -> Array:
	return _workers.keys()

# Ai đã sở hữu mà không ở trong đội thì ở lại căn cứ làm việc.
func sync_workers() -> void:
	var navigation := _navigation()
	if not navigation or not navigation.has_world_navigation():
		return
	_sync_pending = false
	var gacha := get_node("/root/GachaManager")
	var party_ids: Array[StringName] = get_node("/root/PartyManager").get_party()
	var wanted: Dictionary = {}
	for character in gacha.get_characters():
		if gacha.is_owned(character["id"]) and not character["id"] in party_ids:
			wanted[character["id"]] = character
	for character_id in _workers.keys():
		if not wanted.has(character_id):
			_flush_cargo(_workers[character_id])
			_remove_worker(character_id)
	for character_id in wanted:
		if not _workers.has(character_id):
			_spawn_worker(wanted[character_id], {})

func to_dict() -> Dictionary:
	var entries: Array[Dictionary] = []
	for worker: Worker in _workers.values():
		if is_instance_valid(worker.body):
			var entry: Dictionary = worker.body.call("to_save_dict")
			entry["character_id"] = str(worker.character_id)
			entries.append(entry)
	return {"schema_version": SCHEMA_VERSION, "workers": entries}

func validate_save_data(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema_version", 0)) > SCHEMA_VERSION:
		return false
	var entries: Variant = data.get("workers", [])
	if not entries is Array:
		return false
	var gacha := get_node("/root/GachaManager")
	var inventory := get_node("/root/InventoryManager")
	var seen: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary:
			return false
		var character_id := str(entry.get("character_id", ""))
		if seen.has(character_id) or gacha.get_character(StringName(character_id)).is_empty():
			return false
		seen[character_id] = true
		for key in ["x", "y"]:
			var coordinate := float(entry.get(key, INF))
			if not is_finite(coordinate) or absf(coordinate) > 100000.0:
				return false
		var cargo: Variant = entry.get("cargo", {})
		if not cargo is Dictionary:
			return false
		var total := 0
		for item_key in cargo:
			if int(cargo[item_key]) <= 0 or not inventory.get_item_def(StringName(str(item_key))):
				return false
			total += int(cargo[item_key])
		if total > maxi(1, int(entry.get("cargo_capacity", 10))):
			return false
	return true

# Save cũ không có dữ liệu thợ: bỏ thợ hiện tại rồi tạo lại theo danh sách nhân vật.
func load_from_dict(data: Dictionary) -> bool:
	if not validate_save_data(data):
		return false
	for character_id in _workers.keys():
		_remove_worker(character_id)
	var gacha := get_node("/root/GachaManager")
	var party_ids: Array[StringName] = get_node("/root/PartyManager").get_party()
	for entry in data.get("workers", []):
		var character_id := StringName(str(entry["character_id"]))
		if gacha.is_owned(character_id) and not character_id in party_ids:
			_spawn_worker(gacha.get_character(character_id), entry)
	_sync_pending = true
	return true

func _request_sync() -> void:
	_sync_pending = true

func _navigation() -> Node:
	return get_parent().get_node_or_null("NPCManager") if get_parent() else null

func _spawn_worker(character: Dictionary, saved: Dictionary) -> void:
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	var body := NPC_SCENE.instantiate() as Node2D
	if not body:
		return
	var worker := Worker.new()
	worker.character_id = character["id"]
	worker.npc_id = StringName("worker_%s" % str(character["id"]))
	worker.job = character["job"]
	worker.body = body
	body.set("npc_id", worker.npc_id)
	body.set("move_speed", MOVE_SPEED)
	body.set("tunic_color", character["color"])
	body.set("display_name", character["job_name"])
	if saved.is_empty():
		var spawn: Vector2 = _navigation().find_walkable_near(SPAWN_POSITION + Vector2(_workers.size() * 44, 0))
		body.global_position = spawn if is_finite(spawn.x) else SPAWN_POSITION
	else:
		body.call("restore_saved_state", saved)
		var cargo: Dictionary = {}
		var saved_cargo: Dictionary = saved.get("cargo", {})
		for item_key in saved_cargo:
			cargo[StringName(str(item_key))] = int(saved_cargo[item_key])
		body.set("cargo", cargo)
	scene.add_child(body)
	body.call("set_idle")
	body.connect("repath_requested", _on_repath_requested.bind(worker))
	worker.idle_retry = 0.2 * _workers.size()
	_workers[worker.character_id] = worker

func _remove_worker(character_id: StringName) -> void:
	var worker: Worker = _workers[character_id]
	_release_task(worker)
	if is_instance_valid(worker.body):
		if worker.body.get_parent():
			worker.body.get_parent().remove_child(worker.body)
		worker.body.free()
	_workers.erase(character_id)

func _release_task(worker: Worker) -> void:
	if is_instance_valid(worker.task_node):
		worker.task_node.call("release_npc_reservation", worker.npc_id)
	worker.task_node = null
	worker.task_building = null
	worker.task_kind = ""

func _cancel_task(worker: Worker, reason: String) -> void:
	_release_task(worker)
	worker.body.call("set_idle")
	worker.body.set("status_message", reason)
	worker.idle_retry = 0.5

func _update_gatherer(worker: Worker, delta: float) -> void:
	var body := worker.body
	var state := str(body.call("get_state_name"))
	if state == "MOVING":
		if worker.task_kind == "gather" and not _is_task_node_usable(worker):
			_cancel_task(worker, "Điểm tài nguyên đã cạn.")
		elif worker.task_kind == "deliver" and not is_instance_valid(worker.task_building):
			_cancel_task(worker, "Kho không còn khả dụng.")
		return
	if state == "WORKING":
		worker.work_remaining -= delta
		if worker.work_remaining <= 0.0:
			_complete_gather(worker)
		return
	if state != "IDLE":
		body.call("set_idle")
		return
	if worker.task_kind == "gather":
		if _is_task_node_usable(worker) and body.global_position.distance_to(worker.task_node.global_position) <= INTERACTION_RANGE:
			worker.work_remaining = WORK_DURATION / float(get_node("/root/GachaManager").get_work_speed(worker.character_id))
			body.call("set_working")
		else:
			_cancel_task(worker, "Không tới được điểm tài nguyên.")
		return
	if worker.task_kind == "deliver":
		if is_instance_valid(worker.task_building) and _distance_to_building(body.global_position, worker.task_building) <= INTERACTION_RANGE:
			_deliver(worker)
		else:
			_cancel_task(worker, "Không tới được kho chứa.")
		return
	worker.idle_retry -= delta
	if worker.idle_retry > 0.0:
		return
	worker.idle_retry = RETRY_DELAY
	if _assign_gather(worker):
		return
	if int(body.call("cargo_used")) > 0 and not _assign_delivery(worker):
		body.set("status_message", "Cần xây kho chứa còn chỗ trong căn cứ.")

func _is_task_node_usable(worker: Worker) -> bool:
	return is_instance_valid(worker.task_node) and bool(worker.task_node.call("is_available_for_npc", worker.npc_id))

func _assign_gather(worker: Worker) -> bool:
	var body := worker.body
	var resources: Array = JOB_RESOURCES.get(worker.job, [])
	var free_cargo: int = int(body.get("cargo_capacity")) - int(body.call("cargo_used"))
	var candidates: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("resource_nodes"):
		var node := candidate as Node2D
		if not node or not StringName(str(node.get("resource_id"))) in resources:
			continue
		if int(node.get("yield_amount")) <= free_cargo and bool(node.call("is_available_for_npc", worker.npc_id)):
			candidates.append(node)
	# Chỉ tìm đường cho vài điểm gần nhất để không giật khi nhiều thợ cùng chọn việc.
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return body.global_position.distance_squared_to(a.global_position) < body.global_position.distance_squared_to(b.global_position))
	for node in candidates.slice(0, MAX_PATH_TRIES):
		var stand_point: Vector2 = node.global_position + (body.global_position - node.global_position).normalized() * 20.0
		var path: PackedVector2Array = _navigation().get_world_path(body.global_position, stand_point)
		if path.is_empty() or path[path.size() - 1].distance_to(node.global_position) > INTERACTION_RANGE:
			continue
		if not bool(node.call("reserve_for_npc", worker.npc_id)):
			continue
		worker.task_node = node
		worker.task_kind = "gather"
		worker.repaths = 0
		body.call("set_path", path, path[path.size() - 1])
		return true
	return false

func _complete_gather(worker: Worker) -> void:
	var body := worker.body
	if is_instance_valid(worker.task_node):
		var item_id := StringName(str(worker.task_node.get("resource_id")))
		var amount := int(worker.task_node.call("harvest_for_npc", worker.npc_id))
		if amount > 0:
			body.call("add_cargo", item_id, amount)
	_release_task(worker)
	body.call("set_idle")
	worker.idle_retry = 0.3

func _split_cargo(body: Node2D) -> Dictionary:
	var storable: Dictionary = {}
	var gold_ore := 0
	var cargo: Dictionary = body.get("cargo")
	for item_key in cargo:
		if StringName(str(item_key)) == &"gold_ore":
			gold_ore += int(cargo[item_key])
		else:
			storable[StringName(str(item_key))] = int(cargo[item_key])
	return {"storable": storable, "gold_ore": gold_ore}

func _assign_delivery(worker: Worker) -> bool:
	var body := worker.body
	var base_manager := get_node("/root/BaseManager")
	var storable: Dictionary = _split_cargo(body)["storable"]
	var storages: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("placed_buildings"):
		var building := candidate as Node2D
		if building and StringName(str(building.get("building_type_id"))) == &"storage":
			if storable.is_empty() or bool(base_manager.can_deposit_npc_cargo(StringName(str(building.get("instance_id"))), storable)):
				storages.append(building)
	storages.sort_custom(func(a: Node2D, b: Node2D) -> bool: return body.global_position.distance_squared_to(a.global_position) < body.global_position.distance_squared_to(b.global_position))
	for building in storages.slice(0, MAX_PATH_TRIES):
		var half: Vector2 = (building.call("get_footprint") as Vector2) * 0.5 + Vector2(INTERACTION_GAP, INTERACTION_GAP)
		var stand_point: Vector2 = body.global_position.clamp(building.global_position - half, building.global_position + half)
		var path: PackedVector2Array = _navigation().get_world_path(body.global_position, stand_point)
		if path.is_empty() or _distance_to_building(path[path.size() - 1], building) > INTERACTION_RANGE:
			continue
		worker.task_building = building
		worker.task_kind = "deliver"
		worker.repaths = 0
		body.call("set_path", path, path[path.size() - 1])
		return true
	return false

func _deliver(worker: Worker) -> void:
	var body := worker.body
	var parts := _split_cargo(body)
	var storable: Dictionary = parts["storable"]
	var building_id := StringName(str(worker.task_building.get("instance_id")))
	if storable.is_empty() or bool(get_node("/root/BaseManager").deposit_npc_cargo(building_id, storable)):
		_collect_gold(int(parts["gold_ore"]))
		body.set("cargo", {})
	_release_task(worker)
	body.call("set_idle")
	worker.idle_retry = 0.5

func _collect_gold(gold_ore: int) -> void:
	if gold_ore > 0:
		var wallet := get_node("/root/WalletManager")
		wallet.add_gold(gold_ore * wallet.GOLD_PER_ORE)

# Thợ vào đội thì hàng đang mang không bị mất: vào kho, không có kho thì vào túi người chơi.
func _flush_cargo(worker: Worker) -> void:
	if not is_instance_valid(worker.body):
		return
	var parts := _split_cargo(worker.body)
	_collect_gold(int(parts["gold_ore"]))
	worker.body.set("cargo", {})
	var storable: Dictionary = parts["storable"]
	if storable.is_empty():
		return
	var base_manager := get_node("/root/BaseManager")
	for building in get_tree().get_nodes_in_group("placed_buildings"):
		if StringName(str(building.get("building_type_id"))) == &"storage" and bool(base_manager.deposit_npc_cargo(StringName(str(building.get("instance_id"))), storable)):
			return
	var inventory := get_node("/root/InventoryManager")
	for item_id in storable:
		inventory.add_item(item_id, int(storable[item_id]))

func _distance_to_building(point: Vector2, building: Node2D) -> float:
	var half: Vector2 = (building.call("get_footprint") as Vector2) * 0.5
	return point.distance_to(point.clamp(building.global_position - half, building.global_position + half))

func _nearest_raider(guard_position: Vector2) -> Node2D:
	var alert_area: Rect2 = _navigation().get_base_rect().grow(GUARD_ALERT_MARGIN)
	var best: Node2D = null
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("raiders"):
		var raider := candidate as Node2D
		if not raider or bool(raider.get("is_dead")) or not alert_area.has_point(raider.global_position):
			continue
		var distance := guard_position.distance_squared_to(raider.global_position)
		if distance < best_distance:
			best = raider
			best_distance = distance
	return best

# Lính canh đứng giữa căn cứ và đánh quái đột kích vào gần.
func _update_guard(worker: Worker, delta: float) -> void:
	var body := worker.body
	worker.attack_timer = maxf(0.0, worker.attack_timer - delta)
	worker.idle_retry -= delta
	var raider := _nearest_raider(body.global_position)
	if raider and body.global_position.distance_to(raider.global_position) <= GUARD_ATTACK_RANGE:
		if str(body.call("get_state_name")) == "MOVING":
			body.call("set_idle")
		if worker.attack_timer <= 0.0:
			worker.attack_timer = GUARD_ATTACK_INTERVAL
			var damage: float = GUARD_DAMAGE * float(get_node("/root/GachaManager").get_combat_multiplier(worker.character_id))
			raider.call("take_damage", damage, (raider.global_position - body.global_position).normalized())
		return
	if worker.idle_retry > 0.0:
		return
	worker.idle_retry = 0.6
	var post: Vector2 = _navigation().get_base_rect().get_center()
	if not raider and body.global_position.distance_to(post) <= 24.0:
		return
	var destination: Vector2 = raider.global_position if raider else post
	var path: PackedVector2Array = _navigation().get_world_path(body.global_position, destination)
	if not path.is_empty():
		body.call("set_path", path, path[path.size() - 1])

func _on_repath_requested(_npc_id: StringName, destination: Vector2, worker: Worker) -> void:
	if not is_instance_valid(worker.body):
		return
	worker.repaths += 1
	if worker.repaths > MAX_STUCK_REPATHS:
		_cancel_task(worker, "Bị kẹt; đang tìm việc khác.")
		return
	var path: PackedVector2Array = _navigation().get_world_path(worker.body.global_position, destination)
	if path.is_empty():
		_cancel_task(worker, "Không tìm thấy đường.")
	else:
		worker.body.call("set_path", path, path[path.size() - 1])
