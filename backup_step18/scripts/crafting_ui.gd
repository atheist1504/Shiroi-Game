extends CanvasLayer

# Giao diện Chế tạo (Crafting UI) - Bước 18
@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $PanelContainer
@onready var recipe_list_container: VBoxContainer = $PanelContainer/Margin/VBox/MainHBox/LeftCol/Scroll/RecipeList
@onready var title_label: Label = $PanelContainer/Margin/VBox/Header/TitleLabel
@onready var close_btn: Button = $PanelContainer/Margin/VBox/Header/CloseBtn

# Phần chi tiết công thức bên phải
@onready var detail_icon: TextureRect = $PanelContainer/Margin/VBox/MainHBox/RightCol/HeaderHBox/IconRect
@onready var detail_name: Label = $PanelContainer/Margin/VBox/MainHBox/RightCol/HeaderHBox/TitleVBox/NameLabel
@onready var detail_output_amt: Label = $PanelContainer/Margin/VBox/MainHBox/RightCol/HeaderHBox/TitleVBox/OutputAmtLabel
@onready var detail_desc: Label = $PanelContainer/Margin/VBox/MainHBox/RightCol/DescLabel
@onready var materials_container: VBoxContainer = $PanelContainer/Margin/VBox/MainHBox/RightCol/MatScroll/MaterialsList
@onready var status_label: Label = $PanelContainer/Margin/VBox/MainHBox/RightCol/ActionBar/StatusLabel
@onready var craft_btn: Button = $PanelContainer/Margin/VBox/MainHBox/RightCol/ActionBar/CraftBtn

var current_station_type: String = "workbench"
var _selected_recipe_id: StringName = &""
var _recipe_buttons: Dictionary = {} # { recipe_id: Button }

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 92
	visible = false

	if close_btn:
		close_btn.pressed.connect(func(): set_crafting_visible(false))
	if craft_btn:
		craft_btn.pressed.connect(_on_craft_pressed)

	# Lắng nghe cập nhật từ InventoryManager & CraftingManager
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_signal("inventory_changed"):
		inv_mgr.inventory_changed.connect(_on_inventory_changed)

	var craft_mgr = get_node_or_null("/root/CraftingManager")
	if craft_mgr and craft_mgr.has_signal("crafting_completed"):
		craft_mgr.crafting_completed.connect(func(_id, _amt): _update_recipe_details())

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Nhấn Esc hoặc F để đóng bàn chế tạo
	if event.is_action_pressed("pause_game") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_F)):
		set_crafting_visible(false)
		get_viewport().set_input_as_handled()

func open_station(station_type: String = "workbench") -> void:
	current_station_type = station_type
	if title_label:
		title_label.text = "BÀN CHẾ TẠO (CÔNG THỨC & NGUYÊN LIỆU)"
	set_crafting_visible(true)

func set_crafting_visible(is_vis: bool) -> void:
	visible = is_vis
	if visible:
		get_tree().paused = true

		# Đóng các giao diện khác để không đè
		var root := get_tree().current_scene
		if root:
			var inv_ui = root.get_node_or_null("InventoryUI")
			if inv_ui and inv_ui.visible and inv_ui.has_method("set_inventory_visible"):
				inv_ui.set_inventory_visible(false)
			var qj = root.get_node_or_null("QuestJournal")
			if qj and qj.visible and qj.has_method("set_journal_visible"):
				qj.set_journal_visible(false)

		_refresh_recipe_list()
	else:
		_check_resume_pause()

func _check_resume_pause() -> void:
	var root := get_tree().current_scene
	if root:
		var pm = root.get_node_or_null("PauseMenu")
		if pm and pm.visible: return
		var inv_ui = root.get_node_or_null("InventoryUI")
		if inv_ui and inv_ui.visible: return
		var qj = root.get_node_or_null("QuestJournal")
		if qj and qj.visible: return
		var dbg = root.get_node_or_null("DebugPanel")
		if dbg and dbg.visible: return
	get_tree().paused = false

func _on_inventory_changed() -> void:
	if visible:
		_refresh_recipe_list(false)
		_update_recipe_details()

func _refresh_recipe_list(reset_selection: bool = true) -> void:
	if not recipe_list_container:
		return

	for child in recipe_list_container.get_children():
		child.queue_free()
	_recipe_buttons.clear()

	var craft_mgr = get_node_or_null("/root/CraftingManager")
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if not craft_mgr or not inv_mgr:
		return

	var recipes: Array[CraftingRecipe] = craft_mgr.get_recipes_for_station(current_station_type)
	if recipes.is_empty():
		recipes = craft_mgr.get_all_recipes()

	for recipe in recipes:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var out_def = inv_mgr.get_item_def(recipe.output_item_id)
		if out_def and out_def.icon:
			btn.icon = out_def.icon
			btn.expand_icon = true

		var can_make: bool = craft_mgr.can_craft(recipe.id, 1)
		btn.text = " " + recipe.name
		if can_make:
			btn.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9, 1.0))
		else:
			btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 0.75))

		var rid: StringName = recipe.id
		btn.pressed.connect(func(): _select_recipe(rid))

		recipe_list_container.add_child(btn)
		_recipe_buttons[recipe.id] = btn

	if reset_selection or _selected_recipe_id == StringName():
		if not recipes.is_empty():
			_select_recipe(recipes[0].id)
		else:
			_select_recipe(StringName())
	else:
		_update_recipe_details()

func _select_recipe(recipe_id: StringName) -> void:
	_selected_recipe_id = recipe_id

	# Đánh dấu viền nút đang chọn
	for rid in _recipe_buttons.keys():
		var btn: Button = _recipe_buttons[rid]
		if rid == recipe_id:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
		else:
			var craft_mgr = get_node_or_null("/root/CraftingManager")
			var can_make: bool = craft_mgr.can_craft(rid, 1) if craft_mgr else false
			if can_make:
				btn.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9, 1.0))
			else:
				btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 0.75))

	_update_recipe_details()

func _update_recipe_details() -> void:
	if not visible:
		return

	if _selected_recipe_id == StringName():
		if detail_name: detail_name.text = "Chưa chọn công thức"
		if detail_output_amt: detail_output_amt.text = ""
		if detail_desc: detail_desc.text = "Hãy chọn một công thức ở danh sách bên trái để xem nguyên liệu và chế tạo."
		if detail_icon: detail_icon.texture = null
		if craft_btn: craft_btn.disabled = true
		if status_label: status_label.text = ""
		_clear_materials_list()
		return

	var craft_mgr = get_node_or_null("/root/CraftingManager")
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if not craft_mgr or not inv_mgr:
		return

	var recipe: CraftingRecipe = craft_mgr.get_recipe(_selected_recipe_id)
	if not recipe:
		return

	var out_def = inv_mgr.get_item_def(recipe.output_item_id)
	if detail_name:
		detail_name.text = recipe.name
	if detail_output_amt:
		var out_name = out_def.name if out_def else str(recipe.output_item_id)
		detail_output_amt.text = "Tạo ra: %s x%d" % [out_name, recipe.output_amount]
	if detail_desc:
		detail_desc.text = recipe.description
	if detail_icon and out_def:
		detail_icon.texture = out_def.icon

	# Điền danh sách nguyên liệu
	_clear_materials_list()
	for mat_id in recipe.materials.keys():
		var req_amt: int = int(recipe.materials[mat_id])
		var current_amt: int = int(inv_mgr.get_item_count(StringName(mat_id)))
		var mat_def = inv_mgr.get_item_def(StringName(mat_id))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var mat_icon := TextureRect.new()
		mat_icon.custom_minimum_size = Vector2(18, 18)
		mat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if mat_def and mat_def.icon:
			mat_icon.texture = mat_def.icon
		row.add_child(mat_icon)

		var mat_name_lbl := Label.new()
		mat_name_lbl.text = mat_def.name if mat_def else str(mat_id)
		mat_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mat_name_lbl.add_theme_font_size_override("font_size", 9)
		row.add_child(mat_name_lbl)

		var amt_lbl := Label.new()
		amt_lbl.text = "Có: %d / Cần: %d" % [current_amt, req_amt]
		amt_lbl.add_theme_font_size_override("font_size", 9)
		if current_amt >= req_amt:
			amt_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5, 1.0))
		else:
			amt_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
		row.add_child(amt_lbl)

		materials_container.add_child(row)

	# Kiểm tra điều kiện chế tạo & trạng thái nút
	var check = craft_mgr.check_craft(recipe.id, 1)
	if check["can_craft"]:
		if craft_btn:
			craft_btn.disabled = false
			craft_btn.text = "Chế tạo (x1)"
		if status_label:
			status_label.text = "Đủ nguyên liệu và chỗ chứa"
			status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1.0))
	else:
		if craft_btn:
			craft_btn.disabled = true
			craft_btn.text = "Chế tạo"
		if status_label:
			status_label.text = check["reason"]
			status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))

func _clear_materials_list() -> void:
	if materials_container:
		for child in materials_container.get_children():
			child.queue_free()

func _on_craft_pressed() -> void:
	if _selected_recipe_id == StringName():
		return

	var craft_mgr = get_node_or_null("/root/CraftingManager")
	if not craft_mgr:
		return

	# Thực hiện chế tạo
	craft_mgr.craft(_selected_recipe_id, 1)
	_refresh_recipe_list(false)
	_update_recipe_details()
