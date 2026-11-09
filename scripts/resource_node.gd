extends Area2D

# ResourceNode - Điểm thu thập tài nguyên (Cây, Tảng đá, Bụi thảo dược) (Bước 17)
@export var node_id: StringName = &"tree_01"
@export var node_type: String = "tree" # "tree", "rock", "herb"
@export var resource_id: StringName = &"wood"
@export var yield_amount: int = 3

@onready var prompt_label: Label = $PromptLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player_inside: bool = false
var is_harvested: bool = false
var _reserved_by_npc: StringName = &""

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	add_to_group("resource_nodes")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = _get_prompt_text()

	# Kiểm tra xem tài nguyên này đã từng thu thập trước đó chưa (từ WorldState)
	var world_state = get_node_or_null("/root/WorldState")
	if world_state and world_state.has_method("get_flag"):
		if world_state.get_flag(StringName("harvested_" + str(node_id))) == true:
			set_harvested(true, false)

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or is_harvested:
		return

	# Nhấn F để thu thập tài nguyên
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
		_try_gather()
		get_viewport().set_input_as_handled()

func _try_gather() -> void:
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if not inv_mgr:
		return

	if not inv_mgr.can_add_item(resource_id, yield_amount):
		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_warning("Túi đồ đã đầy! Không thể thu thập thêm.")
		return

	# Thu thập thành công
	set_harvested(true, true)

func set_harvested(harvested: bool, notify: bool = false) -> void:
	is_harvested = harvested
	if is_harvested:
		if prompt_label:
			prompt_label.visible = false
		if collision_shape:
			collision_shape.set_deferred("disabled", true)

		if notify:
			var inv_mgr = get_node_or_null("/root/InventoryManager")
			if inv_mgr:
				inv_mgr.add_item(resource_id, yield_amount)

			var event_bus = get_node_or_null("/root/EventBus")
			if event_bus:
				event_bus.item_collected.emit(resource_id, yield_amount)

			var notif_mgr = get_node_or_null("/root/NotificationManager")
			if notif_mgr:
				notif_mgr.show_item_pickup(resource_id, yield_amount)

		# Lưu cờ vào WorldState
		var world_state = get_node_or_null("/root/WorldState")
		if world_state and world_state.has_method("set_flag"):
			world_state.set_flag(StringName("harvested_" + str(node_id)), true)

		# Hiệu ứng mờ dần khi biến mất
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		tween.tween_callback(func(): visible = false)
	else:
		visible = true
		modulate.a = 1.0
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
	_reserved_by_npc = &""

func is_available_for_npc(npc_id: StringName) -> bool:
	return not is_harvested and (_reserved_by_npc == StringName() or _reserved_by_npc == npc_id)

func reserve_for_npc(npc_id: StringName) -> bool:
	if npc_id == StringName() or not is_available_for_npc(npc_id):
		return false
	_reserved_by_npc = npc_id
	return true

func release_npc_reservation(npc_id: StringName) -> void:
	if _reserved_by_npc == npc_id:
		_reserved_by_npc = &""

func harvest_for_npc(npc_id: StringName) -> int:
	if npc_id == StringName() or _reserved_by_npc != npc_id or is_harvested or yield_amount <= 0:
		return 0
	# NPC harvesting marks the world node depleted without player inventory/reward events.
	set_harvested(true, false)
	return yield_amount

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_harvested:
		player_inside = true
		if prompt_label:
			prompt_label.text = _get_prompt_text()
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		if prompt_label:
			prompt_label.visible = false

func _get_prompt_text() -> String:
	var item_name: String = str(resource_id)
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr:
		var def = inv_mgr.get_item_def(resource_id)
		if def:
			item_name = def.name
	return "[F] Thu thập %s (x%d)" % [item_name, yield_amount]

func _draw() -> void:
	# Vẽ tài nguyên Pixel Art tự nhiên
	match node_type:
		"tree":
			# Bóng gốc cây
			draw_circle(Vector2(0, 4), 10.0, Color(0.0, 0.0, 0.0, 0.25))
			# Thân cây
			draw_rect(Rect2(-4, -12, 8, 16), Color(0.35, 0.22, 0.14, 1.0))
			draw_rect(Rect2(-3, -10, 6, 12), Color(0.48, 0.32, 0.2, 1.0))
			# Tán lá
			draw_circle(Vector2(0, -18), 14.0, Color(0.18, 0.45, 0.25, 1.0))
			draw_circle(Vector2(-4, -20), 10.0, Color(0.24, 0.58, 0.32, 1.0))
			draw_circle(Vector2(4, -18), 11.0, Color(0.2, 0.52, 0.28, 1.0))
			draw_circle(Vector2(0, -22), 8.0, Color(0.32, 0.68, 0.38, 1.0))
		"rock":
			# Bóng tảng đá
			draw_circle(Vector2(0, 3), 11.0, Color(0.0, 0.0, 0.0, 0.25))
			# Khối đá xám
			draw_rect(Rect2(-10, -8, 20, 12), Color(0.3, 0.35, 0.42, 1.0))
			draw_rect(Rect2(-8, -12, 16, 14), Color(0.42, 0.48, 0.56, 1.0))
			draw_rect(Rect2(-5, -14, 10, 8), Color(0.55, 0.62, 0.72, 1.0))
			draw_line(Vector2(-6, -6), Vector2(4, -8), Color(0.25, 0.28, 0.35, 1.0), 1.0)
		"herb":
			# Bụi thảo dược nhỏ phát sáng
			draw_circle(Vector2(0, 2), 7.0, Color(0.0, 0.0, 0.0, 0.2))
			draw_circle(Vector2(-3, -4), 5.0, Color(0.2, 0.6, 0.3, 1.0))
			draw_circle(Vector2(3, -4), 5.0, Color(0.25, 0.68, 0.35, 1.0))
			draw_circle(Vector2(0, -7), 5.0, Color(0.35, 0.8, 0.45, 1.0))
			# Hoa thảo dược vàng/trắng
			draw_circle(Vector2(0, -6), 2.0, Color(1.0, 0.95, 0.5, 1.0))
