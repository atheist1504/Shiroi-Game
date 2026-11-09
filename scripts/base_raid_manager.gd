extends Node

# BaseRaidManager - Các đợt quái tấn công căn cứ theo đồng hồ thế giới.
# Trạng thái nằm trong WorldState và quái đột kích được SaveManager lưu như enemy runtime.

const SLIME_SCENE: PackedScene = preload("res://slime.tscn")
const FIRST_RAID_DELAY: float = 300.0
const RAID_INTERVAL: float = 240.0
const BASE_RAIDERS: int = 2
const MAX_RAIDERS: int = 6
const WIN_REWARD_TINH_VAN: int = 15
const SPAWN_POINTS: Array[Vector2] = [Vector2(520, 560), Vector2(1040, 400), Vector2(520, 640), Vector2(1180, 400)]
const FLAG_NEXT_AT: StringName = &"base_raid_next_at"
const FLAG_WAVE: StringName = &"base_raid_wave"
const FLAG_ACTIVE: StringName = &"base_raid_active"

func _process(_delta: float) -> void:
	var now := _now()
	if is_raid_active():
		if get_alive_raider_count() == 0:
			_finish_raid(now)
		return
	# Căn cứ chưa có công trình thì chưa có gì để tấn công.
	if get_tree().get_nodes_in_group("placed_buildings").is_empty():
		return
	var next_at := float(_world().get_flag(FLAG_NEXT_AT, -1.0))
	if next_at < 0.0:
		_world().set_flag(FLAG_NEXT_AT, now + FIRST_RAID_DELAY)
	elif now >= next_at:
		start_raid()

func is_raid_active() -> bool:
	return _world().get_flag(FLAG_ACTIVE, false) == true

func get_wave() -> int:
	return int(_world().get_flag(FLAG_WAVE, 0))

func get_alive_raider_count() -> int:
	var count := 0
	for raider in get_tree().get_nodes_in_group("raiders"):
		if is_instance_valid(raider) and not bool(raider.get("is_dead")):
			count += 1
	return count

func start_raid() -> bool:
	if is_raid_active():
		return false
	var scene := get_tree().current_scene
	if not scene:
		return false
	var wave := get_wave() + 1
	var raider_count := mini(BASE_RAIDERS + wave - 1, MAX_RAIDERS)
	for index in raider_count:
		var raider := SLIME_SCENE.instantiate() as Node2D
		raider.name = "Raider_%d_%d" % [wave, index]
		raider.call("assign_persistent_spawn_id", StringName("raid_%d_%d" % [wave, index]))
		raider.global_position = SPAWN_POINTS[index % SPAWN_POINTS.size()] + Vector2(0, 24 * (index / SPAWN_POINTS.size()))
		scene.add_child(raider)
		raider.call("enable_raid_mode")
	_world().set_flag(FLAG_WAVE, wave)
	_world().set_flag(FLAG_ACTIVE, true)
	_notifications().show_warning("Đợt %d: quái đang tấn công căn cứ!" % wave)
	return true

func _finish_raid(now: float) -> void:
	_world().set_flag(FLAG_ACTIVE, false)
	_world().set_flag(FLAG_NEXT_AT, now + RAID_INTERVAL)
	for building in get_tree().get_nodes_in_group("placed_buildings"):
		building.call("repair_full")
	get_node("/root/WalletManager").add_tinh_van(WIN_REWARD_TINH_VAN)
	_notifications().show_success("Đã đẩy lùi đợt %d! +%d Tinh Vẫn, công trình được sửa." % [get_wave(), WIN_REWARD_TINH_VAN])
	get_node("/root/EventBus").raid_repelled.emit(get_wave())

func _now() -> float:
	return float(get_node("/root/WorldClock").get_time())

func _world() -> Node:
	return get_node("/root/WorldState")

func _notifications() -> Node:
	return get_node("/root/NotificationManager")
