extends Resource
class_name CraftingRecipe

# CraftingRecipe - Định nghĩa công thức chế tạo (Bước 18)
@export var id: StringName = &""
@export var name: String = ""
@export var description: String = ""
# Dictionary các nguyên liệu yêu cầu: { StringName item_id: int amount }
@export var materials: Dictionary = {}
@export var output_item_id: StringName = &""
@export var output_amount: int = 1
@export var station_type: String = "workbench"

func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_desc: String = "",
	p_materials: Dictionary = {},
	p_output_item_id: StringName = &"",
	p_output_amount: int = 1,
	p_station_type: String = "workbench"
) -> void:
	id = p_id
	name = p_name
	description = p_desc
	materials = p_materials.duplicate()
	output_item_id = p_output_item_id
	output_amount = p_output_amount
	station_type = p_station_type

# Kiểm tra tính hợp lệ của dữ liệu công thức
func is_valid() -> bool:
	if id == StringName() or name.strip_edges() == "":
		return false
	if output_item_id == StringName() or output_amount <= 0:
		return false
	if materials.is_empty():
		return false
	for mat_id in materials.keys():
		var amt: int = int(materials[mat_id])
		if StringName(mat_id) == StringName() or amt <= 0:
			return false
	return true
