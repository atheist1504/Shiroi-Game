extends Resource
class_name ItemDefinition

# ItemDefinition - Định nghĩa dữ liệu vật phẩm (Bước 17)
enum Category {
	MATERIAL,    # Nguyên liệu
	CONSUMABLE,  # Tiêu hao
	QUEST,       # Nhiệm vụ
	EQUIPMENT    # Trang bị
}

@export var id: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var category: Category = Category.MATERIAL
@export var max_stack: int = 99

func _init(p_id: StringName = &"", p_name: String = "", p_desc: String = "", p_icon: Texture2D = null, p_cat: Category = Category.MATERIAL, p_stack: int = 99) -> void:
	id = p_id
	name = p_name
	description = p_desc
	icon = p_icon
	category = p_cat
	max_stack = p_stack

func get_category_name() -> String:
	match category:
		Category.MATERIAL:
			return "Nguyên liệu"
		Category.CONSUMABLE:
			return "Tiêu hao"
		Category.QUEST:
			return "Nhiệm vụ"
		Category.EQUIPMENT:
			return "Trang bị"
		_:
			return "Khác"
