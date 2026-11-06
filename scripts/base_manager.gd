extends Node

signal build_mode_changed(is_active: bool)

const BASE_ID: StringName = &"hope_valley_base"
const BASE_NAME: String = "Thung Lũng Hy Vọng"
const BASE_REGION_ID: StringName = &"forest_clearing"
const GRID_SIZE: int = 16
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_build_ui()

func _process(_delta: float) -> void:
	if not is_build_mode or not is_instance_valid(_preview):
		return
	if _other_modal_is_open():
		_exit_build_mode()
		return
	var grid_pos := _world_to_grid(_mouse_world_position())
	_preview.global_position = Vector2(grid_pos) * GRID_SIZE
	_preview.call("set_preview_valid", _selected_type != StringName() and can_place_at(_selected_type, grid_pos) and _can_afford(get_definition(_selected_type)))
	if _status_label:
		_status_label.text = "Chuột trái: Đặt • Chuột phải: Hủy\nG/Esc: Thoát xây dựng\nVị trí: %d, %d" % [grid_pos.x, grid_pos.y]

func _input(event: InputEvent) -> void:
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

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_G:
			_exit_build_mode()
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	# Chỉ đặt/hủy bằng cú nhấp không bị UI tiêu thụ; nút chọn công trình
	# không được đồng thời xem như cú nhấp xuống bản đồ.
	if not is_build_mode or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_placement()
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT and _selected_type != StringName():
		place_building(_selected_type, _world_to_grid(_mouse_world_position()))
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
	var def := get_definition(building_type_id)
	if not def or not is_base_unlocked(BASE_ID):
		return false
	var center := Vector2(grid_pos) * GRID_SIZE
	var footprint := Vector2(def.footprint_cells) * GRID_SIZE
	var bounds := Rect2(center - footprint * 0.5, footprint)
	if not PLOT_RECT.encloses(bounds):
		return false
	for existing in get_tree().get_nodes_in_group("placed_buildings"):
		if not is_instance_valid(existing):
			continue
		var other_definition := get_definition(StringName(str(existing.get("building_type_id"))))
		if other_definition:
			var other_center := Vector2(existing.get("grid_position")) * GRID_SIZE
			var other_size := Vector2(other_definition.footprint_cells) * GRID_SIZE
			if bounds.intersects(Rect2(other_center - other_size * 0.5, other_size)):
				return false

	# Giữ hành lang giữa khu căn cứ luôn đi lại được.
	var path_lane := Rect2(PLOT_RECT.position.x, PLOT_RECT.position.y + PLOT_RECT.size.y * 0.5 - 12.0, PLOT_RECT.size.x, 24.0)
	if bounds.intersects(path_lane):
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = footprint - Vector2(2, 2)
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 1 | 2 | 4
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var space := get_viewport().world_2d.direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false

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
				return false
	return true

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
	if not is_base_unlocked(BASE_ID):
		_notify("Căn cứ chưa được mở khóa.", true)
		return false
	if not can_place_at(building_type_id, grid_pos):
		_notify("Không thể xây tại vị trí này.", true)
		return false
	var definition := get_definition(building_type_id)
	var inventory := get_node_or_null("/root/InventoryManager")
	if not definition or not inventory:
		return false
	if not _can_afford(definition):
		_notify("Không đủ nguyên liệu.", true)
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
	_notify("Đã xây %s." % definition.display_name)
	return true

func to_dict() -> Dictionary:
	var buildings: Array[Dictionary] = []
	for building in get_tree().get_nodes_in_group("placed_buildings"):
		if is_instance_valid(building) and building.has_method("to_save_dict"):
			buildings.append(building.call("to_save_dict"))
	return {"schema_version": 1, "buildings": buildings, "next_instance_number": _next_instance_number}

func validate_save_data(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema_version", 0)) > 1:
		return false
	var entries: Variant = data.get("buildings", [])
	if not entries is Array:
		return false
	var seen: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary:
			return false
		var instance_id := str(entry.get("instance_id", ""))
		var type_id := StringName(str(entry.get("building_type_id", "")))
		var base_id := StringName(str(entry.get("base_id", "")))
		if instance_id.is_empty() or seen.has(instance_id) or not BUILDING_DEFINITIONS.has(type_id) or base_id != BASE_ID:
			return false
		seen[instance_id] = true
		if abs(int(entry.get("grid_x", 0))) > 100000 or abs(int(entry.get("grid_y", 0))) > 100000:
			return false
	return true

func load_from_dict(data: Dictionary) -> bool:
	if not validate_save_data(data):
		return false
	var staged: Array[Node2D] = []
	for entry in data.get("buildings", []):
		var type_id := StringName(str(entry.get("building_type_id", "")))
		var definition := get_definition(type_id)
		var building := BUILDING_SCENE.instantiate() as Node2D
		if not building:
			for item in staged:
				item.free()
			return false
		building.call("configure", definition, StringName(str(entry["instance_id"])), StringName(str(entry["base_id"])), Vector2i(int(entry["grid_x"]), int(entry["grid_y"])), false)
		building.rotation = float(entry.get("rotation", 0.0))
		staged.append(building)

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
	_next_instance_number = maxi(1, int(data.get("next_instance_number", 1)))
	_is_loading = false
	return true

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
