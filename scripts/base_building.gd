extends StaticBody2D
class_name BaseBuilding

@export var instance_id: StringName = &""
@export var building_type_id: StringName = &""
@export var base_id: StringName = &"hope_valley_base"
@export var grid_position: Vector2i = Vector2i.ZERO
@export var is_preview: bool = false

const DEFAULT_MAX_HEALTH: float = 250.0
const MAX_HEALTH_BY_TYPE: Dictionary = {&"storage": 400.0, &"watchtower": 350.0, &"fence": 150.0}

var max_health: float = DEFAULT_MAX_HEALTH
var current_health: float = DEFAULT_MAX_HEALTH
var _footprint: Vector2 = Vector2(32, 32)
var _building_color: Color = Color(0.55, 0.38, 0.22, 1)
var _placement_valid: bool = false
var _storage_prompt: Label = null
var _upgrade_prompt: Label = null
# Cấp nhà ở: mỗi cấp làm vòng Trại rộng thêm (BaseManager.get_camp_radius).
var level: int = 1
const HOUSE_MAX_LEVEL: int = 3
# Tháp canh bắn quái đã vào trong vòng Trại.
const TOWER_RANGE: float = 160.0
const TOWER_DAMAGE: float = 12.0
const TOWER_COOLDOWN: float = 1.0
const ARROW_SCRIPT := preload("res://scripts/tower_arrow.gd")
var _tower_timer: float = 0.0
# Trạm khai thác: tự sinh tài nguyên vào kho trạm; đầy thì người làm chở về Kho chứa ở Trại.
const STATION_ITEMS: Dictionary = {&"lumber_camp": &"wood", &"stone_quarry": &"stone", &"iron_mine": &"iron_ore", &"gold_mine": &"gold_ore", &"herb_garden": &"herb"}
# Xuất đặc biệt khi có nhân vật gacha đúng nghề: cứ STATION_SPECIAL_EVERY đơn vị thì thêm 1 món.
const STATION_SPECIAL_ITEMS: Dictionary = {&"lumber_camp": &"wooden_plank", &"stone_quarry": &"processed_stone", &"iron_mine": &"basic_building_kit", &"gold_mine": &"gold_ore", &"herb_garden": &"small_health_potion"}
const STATION_SPECIAL_EVERY: int = 5
const STATION_CAPACITY: int = 30
const STATION_MAX_HIRED: int = 3
const STATION_SECONDS_PER_UNIT: float = 30.0
const STATION_HAUL_SECONDS: float = 20.0
const STATION_HAUL_RETRY: float = 10.0
var stock: Dictionary = {} # item_id -> số lượng trong kho trạm
var hired: int = 0
var station_status: String = ""
var _produce_progress: float = 0.0
var _special_progress: int = 0
var _haul_left: float = -1.0

func _ready() -> void:
	if not is_preview:
		add_to_group("placed_buildings")
	collision_layer = 0 if is_preview else 1
	collision_mask = 0
	_configure_collision()
	if not is_preview and building_type_id == &"storage":
		_create_storage_prompt()
	if not is_preview and (building_type_id == &"house" or is_station()):
		_upgrade_prompt = _make_prompt("UpgradePrompt", "")

func configure(definition: BuildingDefinition, p_instance_id: StringName, p_base_id: StringName, p_grid_position: Vector2i, preview: bool = false) -> void:
	building_type_id = definition.building_type_id
	instance_id = p_instance_id
	base_id = p_base_id
	grid_position = p_grid_position
	_footprint = Vector2(definition.footprint_cells) * 16.0
	_building_color = definition.color
	is_preview = preview
	max_health = float(MAX_HEALTH_BY_TYPE.get(building_type_id, DEFAULT_MAX_HEALTH))
	current_health = max_health
	position = Vector2(grid_position) * 16.0
	if is_inside_tree():
		collision_layer = 0 if is_preview else 1
		_configure_collision()
		queue_redraw()

func get_footprint() -> Vector2:
	return _footprint

func take_damage(amount: float) -> void:
	if is_preview or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	queue_redraw()
	if current_health <= 0.0:
		get_node("/root/BaseManager").destroy_building(self)

func repair_full() -> void:
	current_health = max_health
	queue_redraw()

# Save cũ không có máu công trình sẽ giữ đầy máu.
func restore_health(saved_health: float) -> void:
	if saved_health > 0.0:
		current_health = minf(saved_health, max_health)

func set_preview_valid(valid: bool) -> void:
	if _placement_valid == valid:
		return
	_placement_valid = valid
	queue_redraw()

func set_storage_prompt_visible(is_visible: bool) -> void:
	if is_instance_valid(_storage_prompt):
		_storage_prompt.visible = is_visible and not is_preview and building_type_id == &"storage"

func is_storage_prompt_visible() -> bool:
	return is_instance_valid(_storage_prompt) and _storage_prompt.visible

func _create_storage_prompt() -> void:
	if is_instance_valid(_storage_prompt):
		return
	_storage_prompt = _make_prompt("StoragePrompt", "Nhấn F để mở kho")

func _make_prompt(node_name: String, text: String) -> Label:
	var prompt := Label.new()
	prompt.name = node_name
	prompt.position = Vector2(-90, -_footprint.y * 0.5 - 22.0)
	prompt.size = Vector2(180, 18)
	prompt.z_index = 10
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.text = text
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	prompt.add_theme_font_size_override("font_size", 8)
	prompt.visible = false
	add_child(prompt)
	return prompt

func set_upgrade_prompt(text: String) -> void:
	if is_instance_valid(_upgrade_prompt):
		_upgrade_prompt.text = text
		_upgrade_prompt.visible = not text.is_empty()

func is_upgrade_prompt_visible() -> bool:
	return is_instance_valid(_upgrade_prompt) and _upgrade_prompt.visible

func set_level(new_level: int) -> void:
	level = clampi(new_level, 1, HOUSE_MAX_LEVEL)
	queue_redraw()

func is_station() -> bool:
	return STATION_ITEMS.has(building_type_id)

func get_station_item() -> StringName:
	return STATION_ITEMS.get(building_type_id, &"")

func get_stock_total() -> int:
	var total := 0
	for item_id in stock:
		total += int(stock[item_id])
	return total

func is_hauling() -> bool:
	return _haul_left >= 0.0

# Số nhân vật gacha đúng nghề đang làm ở trạm (WorkerManager giữ việc phân công).
func _gacha_worker_count() -> int:
	var workers := get_tree().get_first_node_in_group("worker_manager")
	if not workers or not workers.has_method("count_station_workers"):
		return 0
	return int(workers.call("count_station_workers", instance_id))

# Đơn vị tài nguyên mỗi giây: trạm tự sinh 1, mỗi NPC thuê +1, mỗi nhân vật gacha đúng nghề +2.
func get_production_rate() -> float:
	return (1.0 + hired + 2.0 * _gacha_worker_count()) / STATION_SECONDS_PER_UNIT

func hire_npc() -> bool:
	if not is_station() or hired >= STATION_MAX_HIRED:
		return false
	hired += 1
	queue_redraw()
	return true

func _update_station(delta: float) -> void:
	if is_hauling():
		_haul_left -= delta
		if _haul_left <= 0.0:
			_finish_haul()
		return
	if get_stock_total() >= STATION_CAPACITY:
		# Đầy: có người làm thì chở về kho, không có thì đứng chờ.
		if hired + _gacha_worker_count() > 0:
			_haul_left = STATION_HAUL_SECONDS
			station_status = "Đang chở hàng về kho Trại..."
		else:
			station_status = "Kho trạm đầy. Thuê NPC để chở về kho."
		return
	station_status = ""
	_produce_progress += get_production_rate() * delta
	while _produce_progress >= 1.0 and get_stock_total() < STATION_CAPACITY:
		_produce_progress -= 1.0
		_add_stock(get_station_item(), 1)
		if _gacha_worker_count() > 0:
			_special_progress += 1
			if _special_progress >= STATION_SPECIAL_EVERY and STATION_SPECIAL_ITEMS.has(building_type_id) and get_stock_total() < STATION_CAPACITY:
				_special_progress = 0
				_add_stock(STATION_SPECIAL_ITEMS[building_type_id], 1)
	queue_redraw()

func _add_stock(item_id: StringName, amount: int) -> void:
	stock[item_id] = int(stock.get(item_id, 0)) + amount

func _finish_haul() -> void:
	var base := get_node_or_null("/root/BaseManager")
	if base and bool(base.call("deliver_station_stock", stock)):
		stock = {}
		_haul_left = -1.0
		station_status = ""
	else:
		# Kho Trại đầy hoặc chưa có: chờ rồi thử lại.
		_haul_left = STATION_HAUL_RETRY
		station_status = "Không có Kho chứa còn chỗ ở Trại."
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_preview:
		return
	if is_station():
		_update_station(delta)
		return
	if building_type_id != &"watchtower":
		return
	_tower_timer -= delta
	if _tower_timer > 0.0:
		return
	var target := _find_tower_target()
	if not target:
		return
	_tower_timer = TOWER_COOLDOWN
	shoot_at(target)

# Quái gần nhất trong tầm bắn và đã vào vòng Trại (cọc tập không tính).
func _find_tower_target() -> Node2D:
	var base := get_node_or_null("/root/BaseManager")
	var best: Node2D = null
	var best_distance := TOWER_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if not enemy or enemy.is_in_group("training_targets") or enemy.get("is_dead") == true:
			continue
		if base and not bool(base.call("is_in_camp", enemy.global_position)):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best

func shoot_at(target: Node2D) -> void:
	var arrow := Node2D.new()
	arrow.set_script(ARROW_SCRIPT)
	arrow.set("target", target)
	arrow.set("damage", TOWER_DAMAGE)
	get_parent().add_child(arrow)
	arrow.global_position = global_position + Vector2(0, -_footprint.y * 0.5)

func _configure_collision() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not col:
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = _footprint - Vector2(2, 2)
	col.shape = rectangle
	col.disabled = is_preview

func _draw() -> void:
	var rect := Rect2(-_footprint * 0.5, _footprint)
	var fill := _building_color
	if is_preview:
		fill.a = 0.45
	draw_rect(rect, fill, true)
	draw_rect(rect, Color(0.12, 0.1, 0.08, 1), false, 2.0)

	match building_type_id:
		&"fence":
			for x in range(int(-_footprint.x * 0.5) + 4, int(_footprint.x * 0.5), 8):
				draw_rect(Rect2(x, -_footprint.y * 0.5, 3, _footprint.y), Color(0.78, 0.58, 0.34, 1), true)
			draw_line(Vector2(-_footprint.x * 0.5, -3), Vector2(_footprint.x * 0.5, -3), Color(0.78, 0.58, 0.34, 1), 3)
			draw_line(Vector2(-_footprint.x * 0.5, 3), Vector2(_footprint.x * 0.5, 3), Color(0.78, 0.58, 0.34, 1), 3)
		&"watchtower":
			draw_rect(Rect2(-_footprint.x * 0.25, -_footprint.y * 0.25, _footprint.x * 0.5, _footprint.y * 0.5), Color(0.72, 0.6, 0.82, 1), true)
			draw_line(Vector2(-_footprint.x * 0.5, -_footprint.y * 0.5), Vector2(_footprint.x * 0.5, _footprint.y * 0.5), Color(0.3, 0.25, 0.4, 1), 2)
			draw_line(Vector2(_footprint.x * 0.5, -_footprint.y * 0.5), Vector2(-_footprint.x * 0.5, _footprint.y * 0.5), Color(0.3, 0.25, 0.4, 1), 2)
		_:
			var roof := Color(fill.r + 0.15, fill.g + 0.12, fill.b + 0.08, 1)
			draw_rect(Rect2(-_footprint.x * 0.35, -_footprint.y * 0.3, _footprint.x * 0.7, _footprint.y * 0.48), roof, true)
			draw_rect(Rect2(-4, _footprint.y * 0.15, 8, _footprint.y * 0.35), Color(0.28, 0.2, 0.14, 1), true)
			if is_station() and not is_preview:
				# Người làm (chấm áo xanh = NPC thuê) và thanh kho trạm.
				for i in hired:
					draw_circle(Vector2(-_footprint.x * 0.5 + 6 + i * 8, _footprint.y * 0.5 + 6), 3.0, Color(0.35, 0.7, 0.95, 1))
				var fill_ratio := float(get_stock_total()) / float(STATION_CAPACITY)
				var stock_bar := Rect2(-_footprint.x * 0.5, _footprint.y * 0.5 + 12, _footprint.x, 3)
				draw_rect(stock_bar, Color(0.1, 0.1, 0.12, 0.9), true)
				draw_rect(Rect2(stock_bar.position, Vector2(stock_bar.size.x * fill_ratio, 3)), Color(0.95, 0.8, 0.3, 1), true)
			if building_type_id == &"house" and not is_preview:
				# Chấm vàng trên mái = cấp nhà.
				for i in level:
					draw_rect(Rect2(-_footprint.x * 0.3 + i * 7.0, -_footprint.y * 0.26, 4, 4), Color(1.0, 0.85, 0.3, 1), true)

	if is_preview:
		var outline := Color(0.25, 1.0, 0.4, 0.95) if _placement_valid else Color(1.0, 0.25, 0.2, 0.95)
		draw_rect(rect, outline, false, 3.0)
	elif current_health < max_health:
		var bar := Rect2(-_footprint.x * 0.5, -_footprint.y * 0.5 - 6.0, _footprint.x, 3.0)
		draw_rect(bar, Color(0.1, 0.1, 0.12, 0.9), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * current_health / max_health, bar.size.y)), Color(0.9, 0.3, 0.25, 1), true)

func to_save_dict() -> Dictionary:
	return {
		"instance_id": str(instance_id),
		"building_type_id": str(building_type_id),
		"base_id": str(base_id),
		"grid_x": grid_position.x,
		"grid_y": grid_position.y,
		"rotation": rotation,
		"health": current_health,
		"level": level,
		"stock": _stock_for_save(),
		"hired": hired,
		"haul_left": _haul_left
	}

func _stock_for_save() -> Dictionary:
	var out := {}
	for item_id in stock:
		out[str(item_id)] = int(stock[item_id])
	return out

# Save cũ không có các trường trạm thì trạm bắt đầu trống.
func restore_station(saved_stock: Dictionary, saved_hired: int, saved_haul_left: float) -> void:
	stock = {}
	for item_key in saved_stock:
		stock[StringName(str(item_key))] = int(saved_stock[item_key])
	hired = clampi(saved_hired, 0, STATION_MAX_HIRED)
	_haul_left = saved_haul_left
	queue_redraw()
