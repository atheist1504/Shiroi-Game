extends StaticBody2D
class_name BaseBuilding

@export var instance_id: StringName = &""
@export var building_type_id: StringName = &""
@export var base_id: StringName = &"hope_valley_base"
@export var grid_position: Vector2i = Vector2i.ZERO
@export var is_preview: bool = false

var _footprint: Vector2 = Vector2(32, 32)
var _building_color: Color = Color(0.55, 0.38, 0.22, 1)
var _placement_valid: bool = false
var _storage_prompt: Label = null

func _ready() -> void:
	if not is_preview:
		add_to_group("placed_buildings")
	collision_layer = 0 if is_preview else 1
	collision_mask = 0
	_configure_collision()
	if not is_preview and building_type_id == &"storage":
		_create_storage_prompt()

func configure(definition: BuildingDefinition, p_instance_id: StringName, p_base_id: StringName, p_grid_position: Vector2i, preview: bool = false) -> void:
	building_type_id = definition.building_type_id
	instance_id = p_instance_id
	base_id = p_base_id
	grid_position = p_grid_position
	_footprint = Vector2(definition.footprint_cells) * 16.0
	_building_color = definition.color
	is_preview = preview
	position = Vector2(grid_position) * 16.0
	if is_inside_tree():
		collision_layer = 0 if is_preview else 1
		_configure_collision()
		queue_redraw()

func get_footprint() -> Vector2:
	return _footprint

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
	_storage_prompt = Label.new()
	_storage_prompt.name = "StoragePrompt"
	_storage_prompt.position = Vector2(-72, -46)
	_storage_prompt.size = Vector2(144, 18)
	_storage_prompt.z_index = 10
	_storage_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storage_prompt.text = "Nhấn F để mở kho"
	_storage_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_storage_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	_storage_prompt.add_theme_font_size_override("font_size", 8)
	_storage_prompt.visible = false
	add_child(_storage_prompt)

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

	if is_preview:
		var outline := Color(0.25, 1.0, 0.4, 0.95) if _placement_valid else Color(1.0, 0.25, 0.2, 0.95)
		draw_rect(rect, outline, false, 3.0)

func to_save_dict() -> Dictionary:
	return {
		"instance_id": str(instance_id),
		"building_type_id": str(building_type_id),
		"base_id": str(base_id),
		"grid_x": grid_position.x,
		"grid_y": grid_position.y,
		"rotation": rotation
	}
