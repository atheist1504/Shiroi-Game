extends Resource
class_name BuildingDefinition

@export var building_type_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: String = ""
@export var footprint_cells: Vector2i = Vector2i.ONE
@export var costs: Dictionary = {}
@export var scene: PackedScene
@export var color: Color = Color(0.6, 0.45, 0.3)
