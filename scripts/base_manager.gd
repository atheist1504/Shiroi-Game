extends Node

signal build_mode_changed(is_active: bool)
signal storage_changed(building_id: StringName)

const BASE_ID: StringName = &"hope_valley_base"
const BASE_NAME: String = "Thung Lũng Hy Vọng"
const BASE_REGION_ID: StringName = &"forest_clearing"
const GRID_SIZE: int = 16
const STORAGE_SLOT_COUNT: int = 30
const STORAGE_INTERACTION_RANGE: float = 48.0
const PLOT_RECT: Rect2 = Rect2(672, 520, 544, 160)
const BUILDING_SCENE: PackedScene = preload("res://scenes/base_building.tscn")
const BUILDING_DEFINITIONS: Dictionary = {
	&"storage": preload("res://data/buildings/storage.tres"),
	&"house": preload("res://data/buildings/house.tres"),
	&"watchtower": preload("res://data/buildings/watchtower.tres"),
	&"fence": preload("res://data/buildings/fence.tres")
}

var is_build_mode: bool = false
var _selected_type: StringName = &""
var _preview: Node2D = null
var _build_ui: CanvasLayer = null
var _build_panel: PanelContainer = null
var _status_label: Label = null
var _building_buttons: Dictionary = {}
var _next_instance_number: int = 1
var _is_loading: bool = false
var _placement_in_progress: bool = false
var _storage_inventories: Dictionary = {}
var is_storage_interaction_open: bool = false
var _storage_ui: CanvasLayer = null
var _storage_panel: PanelContainer = null
var _storage_status_label: Label = null
var _storage_inventory_status: Label = null
var _storage_selection_label: Label = null
var _storage_feedback_label: Label = null
var _storage_deposit_button: Button = null
var _storage_withdraw_button: Button = null
var _storage_transfer_pending: bool = false
var _player_storage_slots: Array[Button] = []
var _base_storage_slots: Array[Button] = []
var _selected_storage_source: StringName = &""
var _selected_storage_slot: int = -1
var _active_storage_building_id: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_build_ui()
	_create_storage_ui()
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory and inventory.has_signal("inventory_changed"):
		inventory.inventory_changed.connect(_on_storage_inventory_changed)
	storage_changed.connect(_on_storage_changed)

func _process(_delta: float) -> void:
	if is_storage_interaction_open:
		var active_storage := _find_building_by_id(_active_storage_building_id)
		if not active_storage or StringName(str(active_storage.get("building_type_id"))) != &"storage":
			close_storage_interaction()
		_hide_storage_prompts()
		return
	if not is_build_mode:
		_update_storage_prompt()
		return
	_hide_storage_prompts()
	if not is_instance_valid(_preview):
		return
	if _other_modal_is_open():
		_exit_build_mode()
		return
	var grid_pos := _world_to_grid(_mouse_world_position())
	_preview.global_position = Vector2(grid_pos) * GRID_SIZE
	var placement_reason := "Chưa chọn công trình."
	if _selected_type != StringName():
		placement_reason = _get_placement_block_reason(_selected_type, grid_pos)
		if placement_reason.is_empty():
			placement_reason = _get_cost_block_reason(get_definition(_selected_type))
	_preview.call("set_preview_valid", _selected_type != StringName() and placement_reason.is_empty())
	if _status_label:
		var validity_text := "Vị trí hợp lệ — Chuột trái để đặt." if placement_reason.is_empty() else placement_reason
		_status_label.text = "%s\nChuột trái: Đặt • Chuột phải: Hủy\nG/Esc: Thoát\nVị trí: %d, %d" % [validity_text, grid_pos.x, grid_pos.y]

func _input(event: InputEvent) -> void:
	if is_storage_interaction_open:
		if event is InputEventKey:
			var storage_key := event as InputEventKey
			if storage_key.pressed and not storage_key.echo and (storage_key.physical_keycode == KEY_ESCAPE or storage_key.is_action_pressed("pause_game")):
				close_storage_interaction()
			get_viewport().set_input_as_handled()
		return

	if not is_build_mode:
		var pressed_build_key: bool = false
		if event.is_action_pressed("toggle_build_mode"):
			pressed_build_key = true
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_G:
				pressed_build_key = true
		if pressed_build_key:
			if get_tree().paused:
				# Debug pauses the game. Let G close that panel and enter build mode
				# directly, so the unlocked base is still reachable from the debug flow.
				var root := get_tree().current_scene
				var debug_panel: Node = null
				if root:
					debug_panel = root.get_node_or_null("DebugPanel")
				if debug_panel and bool(debug_panel.get("visible")):
					if debug_panel.has_method("toggle_visibility"):
						debug_panel.call("toggle_visibility", false)
					else:
						debug_panel.set("visible", false)
						get_tree().paused = false
				if not get_tree().paused:
					_enter_build_mode()
				else:
					_notify("Hãy đóng bảng đang mở trước khi vào chế độ xây dựng.", true)
			else:
				_enter_build_mode()
			get_viewport().set_input_as_handled()
			return
		if _is_interact_pressed(event) and _try_open_nearby_storage():
			get_viewport().set_input_as_handled()
			return
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_G:
			_exit_build_mode()
			get_viewport().set_input_as_handled()
			return

	# _input runs before Control nodes handle mouse clicks. This allows world clicks
	# to reach the autoload even when GUI controls consume the later event stage.
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_placement()
		get_viewport().set_input_as_handled()
		return
	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control:
		if _is_build_ui_control(hovered_control):
			return
		if not _is_world_environment_control(hovered_control):
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and _selected_type != StringName():
				_notify("Không đặt được: chuột đang nằm trên giao diện '%s'. Hãy nhấp vào bản đồ." % hovered_control.name, true)
			return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and _selected_type != StringName():
		place_building(_selected_type, _world_to_grid(_screen_to_world(mouse_event.position)))
		get_viewport().set_input_as_handled()

func _enter_build_mode() -> void:
	var player := _get_player()
	if not player:
		_notify("Không tìm thấy Shiroi trong khu vực hiện tại.", true)
		return
	if not PLOT_RECT.has_point(player.global_position):
		_notify("Bạn cần đứng trong khu căn cứ Thung Lũng Hy Vọng để xây dựng.", true)
		return
	if not is_base_unlocked(BASE_ID):
		_notify("Căn cứ Thung Lũng Hy Vọng chưa được mở khóa. Hãy mở khóa căn cứ trước.", true)
		return
	if _other_modal_is_open():
		_notify("Hãy đóng bảng đang mở trước khi vào chế độ xây dựng.", true)
		return
	if not is_instance_valid(_build_ui) or not is_instance_valid(_build_panel):
		push_error("BaseManager: Build Mode UI chưa được khởi tạo.")
		_notify("Không thể mở giao diện xây dựng. Hãy khởi động lại game.", true)
		return
	is_build_mode = true
	_selected_type = &""
	_build_ui.visible = true
	_build_panel.visible = true
	_update_build_ui()
	build_mode_changed.emit(true)

func _exit_build_mode() -> void:
	if not is_build_mode:
		return
	is_build_mode = false
	_selected_type = &""
	_build_panel.visible = false
	_build_ui.visible = false
	_clear_preview()
	build_mode_changed.emit(false)

func _cancel_placement() -> void:
	_selected_type = &""
	_clear_preview()
	_update_build_ui()

func select_building(building_type_id: StringName) -> bool:
	if not is_build_mode or not BUILDING_DEFINITIONS.has(building_type_id):
		return false
	_selected_type = building_type_id
	_clear_preview()
	var def := get_definition(building_type_id)
	_preview = BUILDING_SCENE.instantiate() as Node2D
	if not _preview:
		_selected_type = &""
		return false
	_preview.call("configure", def, &"preview", BASE_ID, Vector2i.ZERO, true)
	var current_scene := get_tree().current_scene
	if not current_scene:
		_preview.free()
		_preview = null
		return false
	current_scene.add_child(_preview)
	_update_build_ui()
	return true

func get_definition(building_type_id: StringName) -> BuildingDefinition:
	return BUILDING_DEFINITIONS.get(building_type_id) as BuildingDefinition

func is_base_unlocked(base_id: StringName = BASE_ID) -> bool:
	var world_state := get_node_or_null("/root/WorldState")
	return bool(world_state.call("get_flag", _base_unlock_flag(base_id), false)) if world_state else false

func unlock_base_for_debug(base_id: StringName = BASE_ID) -> bool:
	if base_id != BASE_ID:
		return false
	var world_state := get_node_or_null("/root/WorldState")
	if not world_state:
		return false
	world_state.call("set_flag", _base_unlock_flag(base_id), true)
	_notify("Đã mở khóa căn cứ %s (Debug)." % BASE_NAME)
	_update_build_ui()
	return true

func get_current_region_id() -> StringName:
	return BASE_REGION_ID

func get_current_base_id() -> StringName:
	var player := _get_player()
	return BASE_ID if player and PLOT_RECT.has_point(player.global_position) else StringName()

func get_building_count(base_id: StringName = BASE_ID) -> int:
	var count := 0
	for building in get_tree().get_nodes_in_group("placed_buildings"):
		if is_instance_valid(building) and building.get("base_id") == base_id:
			count += 1
	return count

func can_place_at(building_type_id: StringName, grid_pos: Vector2i) -> bool:
	return _get_placement_block_reason(building_type_id, grid_pos).is_empty()

func _get_placement_block_reason(building_type_id: StringName, grid_pos: Vector2i) -> String:
	var def := get_definition(building_type_id)
	if not def:
		return "Không tìm thấy dữ liệu công trình."
	if not is_base_unlocked(BASE_ID):
		return "Căn cứ chưa được mở khóa."
	var center := Vector2(grid_pos) * GRID_SIZE
	var footprint := Vector2(def.footprint_cells) * GRID_SIZE
	var bounds := Rect2(center - footprint * 0.5, footprint)
	if not PLOT_RECT.encloses(bounds):
		return "Công trình nằm ngoài ranh giới căn cứ."
	for existing in get_tree().get_nodes_in_group("placed_buildings"):
		if not is_instance_valid(existing):
			continue
		var other_definition := get_definition(StringName(str(existing.get("building_type_id"))))
		if other_definition:
			var other_center := Vector2(existing.get("grid_position")) * GRID_SIZE
			var other_size := Vector2(other_definition.footprint_cells) * GRID_SIZE
			if bounds.intersects(Rect2(other_center - other_size * 0.5, other_size)):
				return "Vị trí bị công trình '%s' chiếm." % other_definition.display_name

	# Giữ hành lang giữa khu căn cứ luôn đi lại được.
	var path_lane := Rect2(PLOT_RECT.position.x, PLOT_RECT.position.y + PLOT_RECT.size.y * 0.5 - 12.0, PLOT_RECT.size.x, 24.0)
	if bounds.intersects(path_lane):
		return "Vị trí nằm trên lối đi chính của căn cứ."

	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = footprint - Vector2(2, 2)
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	# Include the autonomous NPC layer so buildings cannot be placed on top of it.
	query.collision_mask = 1 | 2 | 4 | 8
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var space := get_viewport().world_2d.direct_space_state
	var collisions: Array[Dictionary] = space.intersect_shape(query, 8)
	if not collisions.is_empty():
		var collider_value: Variant = collisions[0].get("collider")
		var collider_name := "vật cản"
		if collider_value is Node:
			collider_name = (collider_value as Node).name
		return "Vị trí va chạm với '%s'." % collider_name

	# ResourceNode dùng collision layer 0 nên được kiểm tra trực tiếp.
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(node) or node.get("is_harvested") == true:
			continue
		var resource_node := node as Node2D
		if not resource_node:
			continue
		var shape_node := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if not shape_node or shape_node.disabled:
			continue
		var circle := shape_node.shape as CircleShape2D
		if circle:
			var closest := Vector2(clampf(resource_node.global_position.x, bounds.position.x, bounds.end.x), clampf(resource_node.global_position.y, bounds.position.y, bounds.end.y))
			if closest.distance_to(resource_node.global_position) < circle.radius:
				return "Vị trí bị điểm tài nguyên '%s' chiếm." % node.name
	return ""

func _get_cost_block_reason(definition: BuildingDefinition) -> String:
	if not definition:
		return "Không tìm thấy dữ liệu công trình."
	var inventory := get_node_or_null("/root/InventoryManager")
	if not inventory:
		return "Không tìm thấy túi đồ."
	var missing: Array[String] = []
	for item_id in definition.costs:
		var required := int(definition.costs[item_id])
		var owned := int(inventory.call("get_item_count", StringName(item_id)))
		if owned < required:
			var item_name := str(item_id)
			var item_def = inventory.call("get_item_def", StringName(item_id))
			if item_def:
				item_name = str(item_def.name)
			missing.append("%s %d/%d" % [item_name, owned, required])
	if missing.is_empty():
		return ""
	return "Thiếu nguyên liệu: %s." % ", ".join(PackedStringArray(missing))

func place_building(building_type_id: StringName, grid_pos: Vector2i) -> bool:
	if not is_build_mode or _placement_in_progress:
		return false
	_placement_in_progress = true
	var result := _place_building_transaction(building_type_id, grid_pos)
	_placement_in_progress = false
	return result

func _place_building_transaction(building_type_id: StringName, grid_pos: Vector2i) -> bool:
	if not is_build_mode:
		return false
	var placement_reason := _get_placement_block_reason(building_type_id, grid_pos)
	if not placement_reason.is_empty():
		_notify(placement_reason, true)
		return false
	var definition := get_definition(building_type_id)
	var inventory := get_node_or_null("/root/InventoryManager")
	if not definition or not inventory:
		_notify("Không tìm thấy dữ liệu công trình hoặc túi đồ.", true)
		return false
	var cost_reason := _get_cost_block_reason(definition)
	if not cost_reason.is_empty():
		_notify(cost_reason, true)
		return false
	if not _can_afford(definition):
		_notify("Túi đồ vừa thay đổi; hãy kiểm tra lại nguyên liệu.", true)
		return false

	var building := BUILDING_SCENE.instantiate()
	var current_scene := get_tree().current_scene
	if not building or not current_scene:
		if building:
			building.free()
		_notify("Không thể tạo công trình.", true)
		return false
	var instance_id := StringName("hope_valley_building_%06d" % _next_instance_number)
	_next_instance_number += 1
	building.call("configure", definition, instance_id, BASE_ID, grid_pos, false)
	current_scene.add_child(building)
	if not is_instance_valid(building) or not building.is_inside_tree():
		_notify("Không thể tạo công trình.", true)
		return false
	if not bool(inventory.call("remove_items_atomic", definition.costs)):
		current_scene.remove_child(building)
		building.free()
		_notify("Không đủ nguyên liệu.", true)
		return false
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("building_placed"):
		event_bus.emit_signal("building_placed", instance_id, building_type_id, BASE_ID)
	if building_type_id == &"storage":
		_storage_inventories[instance_id] = _create_empty_storage_slots()
	_notify("Đã xây %s." % definition.display_name)
	return true

func to_dict() -> Dictionary:
	var buildings: Array[Dictionary] = []
	var storage_inventories: Dictionary = {}
	for building in get_tree().get_nodes_in_group("placed_buildings"):
		if is_instance_valid(building) and building.has_method("to_save_dict"):
			var building_data: Dictionary = building.call("to_save_dict")
			buildings.append(building_data)
			if StringName(str(building_data.get("building_type_id", ""))) == &"storage":
				var building_id := StringName(str(building_data.get("instance_id", "")))
				storage_inventories[str(building_id)] = _serialize_storage_slots(_get_or_create_storage_slots(building_id))
	return {"schema_version": 2, "buildings": buildings, "next_instance_number": _next_instance_number, "storage_inventories": storage_inventories}

func validate_save_data(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema_version", 0)) > 2:
		return false
	var entries: Variant = data.get("buildings", [])
	if not entries is Array:
		return false
	var seen: Dictionary = {}
	var storage_buildings: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary:
			return false
		var instance_id := str(entry.get("instance_id", ""))
		var type_id := StringName(str(entry.get("building_type_id", "")))
		var base_id := StringName(str(entry.get("base_id", "")))
		if instance_id.is_empty() or seen.has(instance_id) or not BUILDING_DEFINITIONS.has(type_id) or base_id != BASE_ID:
			return false
		seen[instance_id] = true
		if type_id == &"storage":
			storage_buildings[instance_id] = true
		if abs(int(entry.get("grid_x", 0))) > 100000 or abs(int(entry.get("grid_y", 0))) > 100000:
			return false
	if data.has("storage_inventories"):
		var inventories: Variant = data["storage_inventories"]
		if not inventories is Dictionary:
			return false
		for raw_building_id in inventories:
			var building_id := str(raw_building_id)
			if not storage_buildings.has(building_id):
				return false
			if not _validate_storage_slots(inventories[raw_building_id]):
				return false
	return true

func load_from_dict(data: Dictionary) -> bool:
	if not validate_save_data(data):
		return false
	var staged: Array[Node2D] = []
	var staged_storage: Dictionary = {}
	var saved_storage: Dictionary = data.get("storage_inventories", {})
	for entry in data.get("buildings", []):
		var type_id := StringName(str(entry.get("building_type_id", "")))
		var definition := get_definition(type_id)
		var instance_id := StringName(str(entry["instance_id"]))
		var building := BUILDING_SCENE.instantiate() as Node2D
		if not building:
			for item in staged:
				item.free()
			return false
		building.call("configure", definition, instance_id, StringName(str(entry["base_id"])), Vector2i(int(entry["grid_x"]), int(entry["grid_y"])), false)
		building.rotation = float(entry.get("rotation", 0.0))
		staged.append(building)
		if type_id == &"storage":
			staged_storage[instance_id] = _deserialize_storage_slots(saved_storage.get(str(instance_id), {}))

	var current_scene := get_tree().current_scene
	if not current_scene:
		for item in staged:
			item.free()
		return false
	_is_loading = true
	for existing in get_tree().get_nodes_in_group("placed_buildings"):
		if is_instance_valid(existing):
			existing.get_parent().remove_child(existing)
			existing.free()
	for item in staged:
		current_scene.add_child(item)
	_storage_inventories = staged_storage
	_next_instance_number = maxi(1, int(data.get("next_instance_number", 1)))
	_is_loading = false
	return true

func get_storage_contents(building_id: StringName) -> Array[Dictionary]:
	if not _is_storage_building(building_id):
		return []
	var slots := _get_or_create_storage_slots(building_id)
	return _copy_storage_slots(slots)

func open_storage_interaction(building_id: StringName) -> bool:
	if is_storage_interaction_open or _world_interaction_is_blocked():
		return false
	var building := _find_building_by_id(building_id)
	var player := _get_player()
	if not building or StringName(str(building.get("building_type_id"))) != &"storage" or not player:
		return false
	if _storage_distance_to_building(player.global_position, building) > STORAGE_INTERACTION_RANGE:
		return false
	if not is_instance_valid(_storage_ui) or not is_instance_valid(_storage_panel):
		return false
	_active_storage_building_id = building_id
	_selected_storage_source = &""
	_selected_storage_slot = -1
	if _storage_feedback_label:
		_storage_feedback_label.text = ""
	is_storage_interaction_open = true
	_storage_ui.visible = true
	_update_storage_panel()
	_hide_storage_prompts()
	return true

func close_storage_interaction() -> void:
	if not is_storage_interaction_open:
		return
	is_storage_interaction_open = false
	_active_storage_building_id = &""
	if is_instance_valid(_storage_ui):
		_storage_ui.visible = false
	_selected_storage_source = &""
	_selected_storage_slot = -1

func get_active_storage_building_id() -> StringName:
	return _active_storage_building_id

func _try_open_nearby_storage() -> bool:
	if _world_interaction_is_blocked():
		return false
	var player := _get_player()
	if not player or bool(player.get("is_dead")) or _has_existing_interaction_target():
		return false
	var storage := _get_nearest_storage(player)
	return open_storage_interaction(storage.instance_id) if storage else false

func _is_interact_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F)

func _world_interaction_is_blocked() -> bool:
	return get_tree().paused or is_build_mode or is_storage_interaction_open or _other_modal_is_open()

func _has_existing_interaction_target() -> bool:
	# Existing world interactions retain priority over storage.
	for pickup in get_tree().get_nodes_in_group("pickup_items"):
		if is_instance_valid(pickup) and bool(pickup.get("player_inside")) and not bool(pickup.get("is_being_picked")):
			return true
	for resource in get_tree().get_nodes_in_group("resource_nodes"):
		if is_instance_valid(resource) and bool(resource.get("player_inside")) and not bool(resource.get("is_harvested")):
			return true
	for discovery in get_tree().get_nodes_in_group("discovery_points"):
		if is_instance_valid(discovery) and bool(discovery.get("player_inside")) and not bool(discovery.get("is_discovered")):
			return true
	for station in get_tree().get_nodes_in_group("crafting_stations"):
		if not is_instance_valid(station) or not bool(station.get("player_inside")):
			continue
		var player := _get_player()
		var max_distance := float(station.get("max_interact_distance"))
		if player and station is Node2D and player.global_position.distance_to((station as Node2D).global_position) <= max_distance:
			return true
	return false

func _get_nearest_storage(player: Node2D) -> BaseBuilding:
	var nearest: BaseBuilding = null
	var nearest_distance := INF
	var nearest_id := ""
	for node in get_tree().get_nodes_in_group("placed_buildings"):
		var building := node as BaseBuilding
		if not building or building.is_preview or building.building_type_id != &"storage":
			continue
		var distance := _storage_distance_to_building(player.global_position, building)
		var building_id := str(building.instance_id)
		if distance > STORAGE_INTERACTION_RANGE:
			continue
		if distance < nearest_distance and not is_equal_approx(distance, nearest_distance) or (is_equal_approx(distance, nearest_distance) and (nearest_id.is_empty() or building_id < nearest_id)):
			nearest = building
			nearest_distance = distance
			nearest_id = building_id
	return nearest

func _storage_distance_to_building(world_position: Vector2, building: BaseBuilding) -> float:
	var definition := get_definition(building.building_type_id)
	if not definition:
		return INF
	var footprint := Vector2(definition.footprint_cells) * GRID_SIZE
	var bounds := Rect2(building.global_position - footprint * 0.5, footprint)
	var closest := Vector2(clampf(world_position.x, bounds.position.x, bounds.end.x), clampf(world_position.y, bounds.position.y, bounds.end.y))
	return world_position.distance_to(closest)

func _find_building_by_id(building_id: StringName) -> BaseBuilding:
	for node in get_tree().get_nodes_in_group("placed_buildings"):
		var building := node as BaseBuilding
		if building and not building.is_preview and building.instance_id == building_id:
			return building
	return null

func _update_storage_prompt() -> void:
	var player := _get_player()
	var target: BaseBuilding = null
	if player and not _world_interaction_is_blocked() and not bool(player.get("is_dead")) and not _has_existing_interaction_target():
		target = _get_nearest_storage(player)
	for node in get_tree().get_nodes_in_group("placed_buildings"):
		var building := node as BaseBuilding
		if building and building.building_type_id == &"storage":
			building.set_storage_prompt_visible(building == target)

func _hide_storage_prompts() -> void:
	for node in get_tree().get_nodes_in_group("placed_buildings"):
		var building := node as BaseBuilding
		if building and building.building_type_id == &"storage":
			building.set_storage_prompt_visible(false)

func _update_storage_panel() -> void:
	if not _storage_status_label or not _storage_inventory_status:
		return
	var contents := get_storage_contents(_active_storage_building_id)
	var used_slots := 0
	for slot in contents:
		if slot["item_id"] != StringName() and int(slot["amount"]) > 0:
			used_slots += 1
	_storage_status_label.text = "%d/%d ô" % [used_slots, STORAGE_SLOT_COUNT]
	var inventory := get_node_or_null("/root/InventoryManager")
	var player_slots: Array[Dictionary] = inventory.call("get_all_slots") if inventory else []
	var player_used := 0
	for slot in player_slots:
		if slot["item_id"] != StringName() and int(slot["amount"]) > 0:
			player_used += 1
	_storage_inventory_status.text = "%d/%d ô" % [player_used, InventoryManager.MAX_SLOTS]
	_refresh_storage_slot_buttons(_player_storage_slots, player_slots, true)
	_refresh_storage_slot_buttons(_base_storage_slots, contents, false)
	_update_storage_selection(player_slots, contents)

func _refresh_storage_slot_buttons(buttons: Array[Button], slots: Array[Dictionary], is_player: bool) -> void:
	var inventory := get_node_or_null("/root/InventoryManager")
	for index in range(buttons.size()):
		var button := buttons[index]
		var slot: Dictionary = slots[index] if index < slots.size() else {"item_id": StringName(), "amount": 0}
		var item_id := StringName(str(slot.get("item_id", "")))
		var amount := int(slot.get("amount", 0))
		var definition: ItemDefinition = inventory.call("get_item_def", item_id) as ItemDefinition if inventory and item_id != StringName() else null
		var icon := button.get_node_or_null("Icon") as TextureRect
		var count := button.get_node_or_null("Amount") as Label
		var name_label := button.get_node_or_null("ItemName") as Label
		if definition and amount > 0:
			icon.texture = definition.icon
			icon.visible = definition.icon != null
			count.text = str(amount) if amount > 1 else ""
			name_label.text = definition.name
			button.tooltip_text = "%s ×%d" % [definition.name, amount]
		else:
			icon.texture = null
			icon.visible = false
			count.text = ""
			name_label.text = ""
			button.tooltip_text = "Ô trống"
		var selected := _selected_storage_source == (StringName("player") if is_player else StringName("storage")) and _selected_storage_slot == index
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.23, 0.25, 1.0) if selected else (Color(0.12, 0.15, 0.17, 1.0) if item_id != StringName() else Color(0.08, 0.1, 0.12, 1.0))
		style.set_border_width_all(2 if selected else 1)
		style.border_color = Color(0.35, 0.95, 0.68, 1.0) if selected else Color(0.28, 0.36, 0.4, 1.0)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)

func _update_storage_selection(player_slots: Array[Dictionary], storage_slots: Array[Dictionary]) -> void:
	var slots := player_slots if _selected_storage_source == &"player" else storage_slots
	if _selected_storage_source == StringName() or _selected_storage_slot < 0 or _selected_storage_slot >= slots.size():
		_clear_storage_selection()
		return
	var item_id := StringName(str(slots[_selected_storage_slot].get("item_id", "")))
	var amount := int(slots[_selected_storage_slot].get("amount", 0))
	var inventory := get_node_or_null("/root/InventoryManager")
	var definition: ItemDefinition = inventory.call("get_item_def", item_id) as ItemDefinition if inventory and item_id != StringName() else null
	if not definition or amount <= 0:
		_clear_storage_selection()
		return
	_storage_selection_label.text = "%s ×%d  •  %s" % [definition.name, amount, "Túi đồ" if _selected_storage_source == &"player" else "Kho căn cứ"]
	_storage_deposit_button.disabled = _storage_transfer_pending or _selected_storage_source != &"player"
	_storage_withdraw_button.disabled = _storage_transfer_pending or _selected_storage_source != &"storage"

func _clear_storage_selection() -> void:
	_selected_storage_source = &""
	_selected_storage_slot = -1
	if is_instance_valid(_storage_selection_label):
		_storage_selection_label.text = "Chọn một vật phẩm để xem chi tiết."
	if is_instance_valid(_storage_deposit_button):
		_storage_deposit_button.disabled = true
	if is_instance_valid(_storage_withdraw_button):
		_storage_withdraw_button.disabled = true

func _on_storage_slot_selected(source: StringName, index: int) -> void:
	if not is_storage_interaction_open:
		return
	var slots: Array[Dictionary] = []
	if source == &"player":
		var inventory := get_node_or_null("/root/InventoryManager")
		if inventory:
			slots = inventory.call("get_all_slots")
	else:
		slots = get_storage_contents(_active_storage_building_id)
	if index < 0 or index >= slots.size():
		return
	var slot: Dictionary = slots[index]
	if StringName(str(slot.get("item_id", ""))) == StringName() or int(slot.get("amount", 0)) <= 0:
		_selected_storage_source = &""
		_selected_storage_slot = -1
	else:
		_selected_storage_source = source
		_selected_storage_slot = index
	_update_storage_panel()

func _on_storage_transfer_pressed(is_deposit: bool) -> void:
	if not is_storage_interaction_open or _storage_transfer_pending or _selected_storage_slot < 0:
		return
	if (is_deposit and _selected_storage_source != &"player") or (not is_deposit and _selected_storage_source != &"storage"):
		return
	var slots: Array[Dictionary] = []
	if is_deposit:
		var inventory := get_node_or_null("/root/InventoryManager")
		if inventory:
			slots = inventory.call("get_all_slots")
	else:
		slots = get_storage_contents(_active_storage_building_id)
	if _selected_storage_slot >= slots.size():
		_clear_storage_selection()
		_update_storage_panel()
		return
	var slot: Dictionary = slots[_selected_storage_slot]
	var item_id := StringName(str(slot.get("item_id", "")))
	if item_id == StringName() or int(slot.get("amount", 0)) <= 0:
		_storage_feedback_label.text = "Không đủ vật phẩm!"
		_clear_storage_selection()
		_update_storage_panel()
		return
	_storage_transfer_pending = true
	_storage_deposit_button.disabled = true
	_storage_withdraw_button.disabled = true
	var success := deposit_item(_active_storage_building_id, item_id, 1) if is_deposit else withdraw_item(_active_storage_building_id, item_id, 1)
	if is_instance_valid(_storage_feedback_label):
		_storage_feedback_label.text = ("Đã gửi 1 vật phẩm vào kho." if is_deposit else "Đã lấy 1 vật phẩm ra.") if success else _get_storage_transfer_failure_message(is_deposit, item_id, 1)
	if success:
		var updated_slots: Array[Dictionary] = []
		if is_deposit:
			var inventory := get_node_or_null("/root/InventoryManager")
			if inventory:
				updated_slots = inventory.call("get_all_slots")
		else:
			updated_slots = get_storage_contents(_active_storage_building_id)
		var selected_still_exists := _selected_storage_slot < updated_slots.size()
		if selected_still_exists:
			var remaining_slot: Dictionary = updated_slots[_selected_storage_slot]
			selected_still_exists = StringName(str(remaining_slot.get("item_id", ""))) == item_id and int(remaining_slot.get("amount", 0)) > 0
		if not selected_still_exists:
			_selected_storage_source = &""
			_selected_storage_slot = -1
	_update_storage_panel()
	await get_tree().create_timer(0.18).timeout
	_storage_transfer_pending = false
	if is_storage_interaction_open:
		_update_storage_panel()

func _get_storage_transfer_failure_message(is_deposit: bool, item_id: StringName, quantity: int) -> String:
	if quantity <= 0 or not _get_item_definition(item_id) or not _is_storage_building(_active_storage_building_id):
		return "Không thể chuyển vật phẩm!"
	var inventory := get_node_or_null("/root/InventoryManager")
	if not inventory:
		return "Không thể chuyển vật phẩm!"
	if is_deposit:
		if not bool(inventory.call("has_item", item_id, quantity)):
			return "Không đủ vật phẩm!"
		return "Kho đã đầy!" if not can_deposit(_active_storage_building_id, item_id, quantity) else "Không thể chuyển vật phẩm!"
	var stored_quantity := 0
	for stored_slot in get_storage_contents(_active_storage_building_id):
		if StringName(str(stored_slot.get("item_id", ""))) == item_id:
			stored_quantity += int(stored_slot.get("amount", 0))
	if stored_quantity < quantity:
		return "Không đủ vật phẩm!"
	if not bool(inventory.call("can_add_item", item_id, quantity)):
		return "Túi đồ đã đầy!"
	return "Không thể chuyển vật phẩm!"

func _on_storage_inventory_changed() -> void:
	if is_storage_interaction_open:
		_update_storage_panel()

func _on_storage_changed(building_id: StringName) -> void:
	if is_storage_interaction_open and building_id == _active_storage_building_id:
		_update_storage_panel()

func _create_storage_ui() -> void:
	_storage_ui = CanvasLayer.new()
	_storage_ui.name = "StorageInteractionUI"
	_storage_ui.layer = 115
	_storage_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_storage_ui.visible = false
	add_child(_storage_ui)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.02, 0.03, 0.58)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_storage_ui.add_child(backdrop)
	_storage_panel = PanelContainer.new()
	_storage_panel.name = "Panel"
	_storage_panel.anchor_left = 0.5
	_storage_panel.anchor_right = 0.5
	_storage_panel.anchor_top = 0.5
	_storage_panel.anchor_bottom = 0.5
	_storage_panel.offset_left = -310.0
	_storage_panel.offset_right = 310.0
	_storage_panel.offset_top = -170.0
	_storage_panel.offset_bottom = 170.0
	_storage_panel.custom_minimum_size = Vector2(620, 340)
	_storage_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_storage_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_storage_panel.add_theme_stylebox_override("panel", _panel_style())
	_storage_ui.add_child(_storage_panel)
	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.add_theme_constant_override("separation", 5)
	_storage_panel.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = "Kho chứa"
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var columns := HBoxContainer.new()
	columns.name = "InventoryColumns"
	columns.add_theme_constant_override("separation", 10)
	box.add_child(columns)
	var player_column := _create_storage_grid_column("TÚI ĐỒ", true)
	columns.add_child(player_column)
	var divider := VSeparator.new()
	columns.add_child(divider)
	var storage_column := _create_storage_grid_column("KHO CĂN CỨ", false)
	columns.add_child(storage_column)
	var details := HBoxContainer.new()
	details.add_theme_constant_override("separation", 5)
	box.add_child(details)
	_storage_selection_label = Label.new()
	_storage_selection_label.text = "Chọn một vật phẩm để xem chi tiết."
	_storage_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_storage_selection_label.add_theme_font_size_override("font_size", 8)
	details.add_child(_storage_selection_label)
	_storage_deposit_button = Button.new()
	_storage_deposit_button.text = "Gửi vào kho"
	_storage_deposit_button.custom_minimum_size = Vector2(86, 24)
	_storage_deposit_button.add_theme_font_size_override("font_size", 8)
	_storage_deposit_button.disabled = true
	_storage_deposit_button.pressed.connect(_on_storage_transfer_pressed.bind(true))
	details.add_child(_storage_deposit_button)
	_storage_withdraw_button = Button.new()
	_storage_withdraw_button.text = "Lấy ra"
	_storage_withdraw_button.custom_minimum_size = Vector2(58, 24)
	_storage_withdraw_button.add_theme_font_size_override("font_size", 8)
	_storage_withdraw_button.disabled = true
	_storage_withdraw_button.pressed.connect(_on_storage_transfer_pressed.bind(false))
	details.add_child(_storage_withdraw_button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	box.add_child(footer)
	_storage_inventory_status = Label.new()
	_storage_inventory_status.add_theme_font_size_override("font_size", 8)
	footer.add_child(_storage_inventory_status)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_storage_status_label = Label.new()
	_storage_status_label.add_theme_font_size_override("font_size", 8)
	footer.add_child(_storage_status_label)
	_storage_feedback_label = Label.new()
	_storage_feedback_label.add_theme_font_size_override("font_size", 8)
	_storage_feedback_label.add_theme_color_override("font_color", Color(0.65, 0.9, 0.7))
	box.add_child(_storage_feedback_label)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Đóng"
	close_button.custom_minimum_size = Vector2(60, 22)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 8)
	close_button.pressed.connect(close_storage_interaction)
	box.add_child(close_button)

func _create_storage_grid_column(heading: String, is_player: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
	heading_label.add_theme_font_size_override("font_size", 9)
	column.add_child(heading_label)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)
	var slot_count := InventoryManager.MAX_SLOTS if is_player else STORAGE_SLOT_COUNT
	var source: StringName = &"player" if is_player else &"storage"
	var destination := _player_storage_slots if is_player else _base_storage_slots
	for index in range(slot_count):
		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(34, 34)
		slot_button.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_button.add_theme_stylebox_override("focus", _panel_style())
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		icon.offset_bottom = 17
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(18, 18)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_button.add_child(icon)
		var amount := Label.new()
		amount.name = "Amount"
		amount.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		amount.offset_left = -20
		amount.offset_right = -1
		amount.offset_top = 0
		amount.offset_bottom = 10
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		amount.add_theme_font_size_override("font_size", 7)
		amount.add_theme_color_override("font_color", Color(1, 0.95, 0.72))
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_button.add_child(amount)
		var name_label := Label.new()
		name_label.name = "ItemName"
		name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		name_label.offset_top = -12
		name_label.offset_bottom = -1
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.add_theme_font_size_override("font_size", 5)
		name_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.9, 1.0))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_button.add_child(name_label)
		slot_button.pressed.connect(_on_storage_slot_selected.bind(source, index))
		grid.add_child(slot_button)
		destination.append(slot_button)
	return column

func can_deposit(building_id: StringName, item_id: StringName, quantity: int) -> bool:
	if quantity <= 0 or not _is_storage_building(building_id):
		return false
	var item_def := _get_item_definition(item_id)
	if not item_def or item_def.max_stack <= 0:
		return false
	var remaining := quantity
	for slot in _get_or_create_storage_slots(building_id):
		if slot["item_id"] == item_id:
			remaining -= maxi(0, item_def.max_stack - int(slot["amount"]))
	if remaining <= 0:
		return true
	for slot in _get_or_create_storage_slots(building_id):
		if slot["item_id"] == StringName():
			remaining -= item_def.max_stack
			if remaining <= 0:
				return true
	return false

func deposit_item(building_id: StringName, item_id: StringName, quantity: int) -> bool:
	if not can_deposit(building_id, item_id, quantity):
		return false
	var inventory := get_node_or_null("/root/InventoryManager")
	if not inventory or not bool(inventory.call("has_item", item_id, quantity)):
		return false
	var staged := _copy_storage_slots(_get_or_create_storage_slots(building_id))
	if not _add_to_storage_slots(staged, item_id, quantity):
		return false
	if not bool(inventory.call("remove_item", item_id, quantity)):
		return false
	_storage_inventories[building_id] = staged
	storage_changed.emit(building_id)
	return true

# NPC cargo is not part of the player's inventory; validate and commit the whole cargo atomically.
func can_deposit_npc_cargo(building_id: StringName, cargo: Dictionary) -> bool:
	if cargo.is_empty() or not _is_storage_building(building_id):
		return false
	var staged := _copy_storage_slots(_get_or_create_storage_slots(building_id))
	for raw_item_id in cargo:
		var item_id := StringName(str(raw_item_id))
		var quantity := int(cargo[raw_item_id])
		if quantity <= 0 or not _get_item_definition(item_id) or not _add_to_storage_slots(staged, item_id, quantity):
			return false
	return true

func deposit_npc_cargo(building_id: StringName, cargo: Dictionary) -> bool:
	if not can_deposit_npc_cargo(building_id, cargo):
		return false
	var staged := _copy_storage_slots(_get_or_create_storage_slots(building_id))
	for raw_item_id in cargo:
		if not _add_to_storage_slots(staged, StringName(str(raw_item_id)), int(cargo[raw_item_id])):
			return false
	_storage_inventories[building_id] = staged
	storage_changed.emit(building_id)
	return true

func can_withdraw(building_id: StringName, item_id: StringName, quantity: int) -> bool:
	if quantity <= 0 or not _is_storage_building(building_id) or not _get_item_definition(item_id):
		return false
	var stored := 0
	for slot in _get_or_create_storage_slots(building_id):
		if slot["item_id"] == item_id:
			stored += int(slot["amount"])
	if stored < quantity:
		return false
	var inventory := get_node_or_null("/root/InventoryManager")
	return inventory != null and bool(inventory.call("can_add_item", item_id, quantity))

func withdraw_item(building_id: StringName, item_id: StringName, quantity: int) -> bool:
	if not can_withdraw(building_id, item_id, quantity):
		return false
	var staged := _copy_storage_slots(_get_or_create_storage_slots(building_id))
	if not _remove_from_storage_slots(staged, item_id, quantity):
		return false
	var inventory := get_node_or_null("/root/InventoryManager")
	if not inventory:
		return false
	var remainder := int(inventory.call("add_item", item_id, quantity))
	if remainder != 0:
		var added := quantity - remainder
		if added > 0:
			inventory.call("remove_item", item_id, added)
		return false
	_storage_inventories[building_id] = staged
	storage_changed.emit(building_id)
	return true

func _is_storage_building(building_id: StringName) -> bool:
	if building_id == StringName():
		return false
	for building in get_tree().get_nodes_in_group("placed_buildings"):
		if is_instance_valid(building) and StringName(str(building.get("instance_id"))) == building_id:
			return StringName(str(building.get("building_type_id"))) == &"storage"
	return false

func _get_item_definition(item_id: StringName) -> ItemDefinition:
	var inventory := get_node_or_null("/root/InventoryManager")
	return inventory.call("get_item_def", item_id) as ItemDefinition if inventory else null

func _create_empty_storage_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for _index in STORAGE_SLOT_COUNT:
		slots.append({"item_id": StringName(), "amount": 0})
	return slots

func _get_or_create_storage_slots(building_id: StringName) -> Array[Dictionary]:
	if not _storage_inventories.has(building_id):
		_storage_inventories[building_id] = _create_empty_storage_slots()
	return _storage_inventories[building_id] as Array[Dictionary]

func _copy_storage_slots(slots: Array[Dictionary]) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for slot in slots:
		copy.append(slot.duplicate())
	return copy

func _add_to_storage_slots(slots: Array[Dictionary], item_id: StringName, quantity: int) -> bool:
	var item_def := _get_item_definition(item_id)
	if quantity <= 0 or not item_def:
		return false
	var remaining := quantity
	for slot in slots:
		if slot["item_id"] != item_id:
			continue
		var added := mini(remaining, item_def.max_stack - int(slot["amount"]))
		slot["amount"] = int(slot["amount"]) + added
		remaining -= added
		if remaining == 0:
			return true
	for slot in slots:
		if slot["item_id"] != StringName():
			continue
		var added := mini(remaining, item_def.max_stack)
		slot["item_id"] = item_id
		slot["amount"] = added
		remaining -= added
		if remaining == 0:
			return true
	return false

func _remove_from_storage_slots(slots: Array[Dictionary], item_id: StringName, quantity: int) -> bool:
	if quantity <= 0:
		return false
	var stored := 0
	for slot in slots:
		if slot["item_id"] == item_id:
			stored += int(slot["amount"])
	if stored < quantity:
		return false
	var remaining := quantity
	for index in range(slots.size() - 1, -1, -1):
		var slot := slots[index]
		if slot["item_id"] != item_id:
			continue
		var removed := mini(remaining, int(slot["amount"]))
		slot["amount"] = int(slot["amount"]) - removed
		remaining -= removed
		if slot["amount"] <= 0:
			slot["item_id"] = StringName()
			slot["amount"] = 0
		if remaining == 0:
			return true
	return false

func _serialize_storage_slots(slots: Array[Dictionary]) -> Dictionary:
	var data: Array[Dictionary] = []
	for index in slots.size():
		var slot := slots[index]
		if slot["item_id"] != StringName() and int(slot["amount"]) > 0:
			data.append({"slot": index, "id": str(slot["item_id"]), "amount": int(slot["amount"])})
	return {"schema_version": 1, "max_slots": STORAGE_SLOT_COUNT, "slots": data}

func _validate_storage_slots(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema_version", 0)) > 1 or int(data.get("max_slots", 0)) != STORAGE_SLOT_COUNT:
		return false
	var slots: Variant = data.get("slots", [])
	if not slots is Array:
		return false
	var seen_slots: Dictionary = {}
	for entry in slots:
		if not entry is Dictionary:
			return false
		var slot_index := int(entry.get("slot", -1))
		var item_id := StringName(str(entry.get("id", "")))
		var quantity := int(entry.get("amount", 0))
		var item_def := _get_item_definition(item_id)
		if slot_index < 0 or slot_index >= STORAGE_SLOT_COUNT or seen_slots.has(slot_index) or not item_def or quantity <= 0 or quantity > item_def.max_stack:
			return false
		seen_slots[slot_index] = true
	return true

func _deserialize_storage_slots(data: Variant) -> Array[Dictionary]:
	var slots := _create_empty_storage_slots()
	if not _validate_storage_slots(data):
		return slots
	for entry in data.get("slots", []):
		var slot_index := int(entry["slot"])
		slots[slot_index] = {"item_id": StringName(str(entry["id"])), "amount": int(entry["amount"])}
	return slots

func get_enemy_debug_rows() -> Array[String]:
	var rows: Array[String] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			rows.append("%s (%s)" % [str(enemy.get("persistent_id")), str(enemy.get("region_id"))])
	return rows

func _create_build_ui() -> void:
	_build_ui = CanvasLayer.new()
	_build_ui.name = "BaseBuildUI"
	_build_ui.layer = 110
	_build_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui.visible = false
	add_child(_build_ui)
	_build_panel = PanelContainer.new()
	_build_panel.position = Vector2(8, 24)
	_build_panel.custom_minimum_size = Vector2(170, 0)
	_build_panel.add_theme_stylebox_override("panel", _panel_style())
	_build_ui.add_child(_build_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_build_panel.add_child(box)
	var title := Label.new()
	title.text = "XÂY DỰNG • THUNG LŨNG HY VỌNG"
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
	box.add_child(title)
	_status_label = Label.new()
	_status_label.text = "Chọn công trình"
	_status_label.add_theme_font_size_override("font_size", 8)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status_label)
	for type_id in [&"storage", &"house", &"watchtower", &"fence"]:
		var captured_type: StringName = type_id
		var definition := get_definition(type_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		box.add_child(row)
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.color = definition.color
		icon.tooltip_text = definition.display_name
		row.add_child(icon)
		var button := Button.new()
		button.custom_minimum_size = Vector2(154, 28)
		button.add_theme_font_size_override("font_size", 8)
		button.text = "%s\n%s" % [definition.display_name, _format_cost(definition)]
		button.pressed.connect(func(): select_building(captured_type))
		row.add_child(button)
		_building_buttons[type_id] = button
	var exit_button := Button.new()
	exit_button.text = "Thoát xây dựng • G / Esc"
	exit_button.add_theme_font_size_override("font_size", 8)
	exit_button.pressed.connect(_exit_build_mode)
	box.add_child(exit_button)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.1, 0.94)
	style.border_color = Color(0.3, 0.75, 0.53, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _format_cost(definition: BuildingDefinition) -> String:
	var inventory := get_node_or_null("/root/InventoryManager")
	var labels: Array[String] = []
	for item_id in definition.costs:
		var item_name := str(item_id)
		if inventory:
			var item_def = inventory.call("get_item_def", StringName(item_id))
			if item_def:
				item_name = item_def.name
		labels.append("%s x%d" % [item_name, int(definition.costs[item_id])])
	return " • ".join(PackedStringArray(labels))

func _update_build_ui() -> void:
	for type_id in _building_buttons:
		var button: Button = _building_buttons[type_id]
		var definition := get_definition(type_id)
		button.modulate = Color(0.55, 1.0, 0.72) if type_id == _selected_type else Color.WHITE
		button.tooltip_text = definition.description

func _clear_preview() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null

func _world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(roundi(world_position.x / GRID_SIZE), roundi(world_position.y / GRID_SIZE))

func _mouse_world_position() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()

func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func _can_afford(definition: BuildingDefinition) -> bool:
	if not definition:
		return false
	var inventory := get_node_or_null("/root/InventoryManager")
	if not inventory:
		return false
	for item_id in definition.costs:
		if not bool(inventory.call("has_item", StringName(item_id), int(definition.costs[item_id]))):
			return false
	return true

func _base_unlock_flag(base_id: StringName) -> StringName:
	return StringName("base_unlocked_" + str(base_id))

func _get_player() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player and get_tree().current_scene:
		player = get_tree().current_scene.get_node_or_null("Player") as Node2D
	return player

func _is_build_ui_control(control: Control) -> bool:
	return is_instance_valid(_build_panel) and (control == _build_panel or _build_panel.is_ancestor_of(control))

func _is_world_environment_control(control: Control) -> bool:
	var current_scene := get_tree().current_scene
	if not current_scene:
		return false
	var environment := current_scene.get_node_or_null("Environment")
	return environment != null and environment.is_ancestor_of(control)

func _other_modal_is_open() -> bool:
	var root := get_tree().current_scene
	if not root:
		return false
	for child_name in ["PauseMenu", "InventoryUI", "QuestJournal", "DebugPanel", "CraftingUI"]:
		var control := root.get_node_or_null(child_name)
		if control and control.get("visible") == true:
			return true
	return false

func _notify(message: String, warning: bool = false) -> void:
	var notifications := get_node_or_null("/root/NotificationManager")
	if not notifications:
		return
	if warning:
		notifications.call("show_warning", message)
	else:
		notifications.call("show_success", message)
