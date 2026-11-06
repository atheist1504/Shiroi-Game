extends Area2D
class_name PickupItem

# PickupItem - Vật phẩm rơi trên mặt đất cần nhấn F để nhặt (Bước 17)
@export var pickup_id: StringName = &""
@export var item_id: StringName = &"slime_gel"
@export var amount: int = 1

@onready var prompt_label: Label = $PromptLabel
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player_inside: bool = false
var is_being_picked: bool = false
var _initial_pos_y: float = 0.0
var _anim_time: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	add_to_group("pickup_items")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if pickup_id == StringName():
		pickup_id = StringName("pickup_%d_%d" % [Time.get_ticks_msec(), randi() % 10000])

	_initial_pos_y = position.y
	_anim_time = randf() * 6.28 # ngẫu nhiên pha nhấp nhô

	_update_appearance()

func _process(delta: float) -> void:
	_anim_time += delta * 3.5
	# Hiệu ứng nảy nhẹ nhấp nhô trên mặt đất
	if sprite_2d:
		sprite_2d.position.y = sin(_anim_time) * 2.5

func _update_appearance() -> void:
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr:
		var def = inv_mgr.get_item_def(item_id)
		if def and sprite_2d:
			sprite_2d.texture = def.icon
			sprite_2d.scale = Vector2(0.8, 0.8)

	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = _get_prompt_text()

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or is_being_picked:
		return

	# Nhấn F để nhặt chiến lợi phẩm
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
		_try_pickup()
		get_viewport().set_input_as_handled()

func _try_pickup() -> void:
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if not inv_mgr:
		return

	if not inv_mgr.can_add_item(item_id, amount):
		var notif_mgr = get_node_or_null("/root/NotificationManager")
		if notif_mgr:
			notif_mgr.show_warning("Túi đồ đã đầy!")
		return

	# Nhặt thành công
	is_being_picked = true
	if prompt_label:
		prompt_label.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	inv_mgr.add_item(item_id, amount)

	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.item_collected.emit(item_id, amount)

	var notif_mgr = get_node_or_null("/root/NotificationManager")
	if notif_mgr:
		notif_mgr.show_item_pickup(item_id, amount)

	# Hiệu ứng bay lên và tan biến khi nhặt
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 12.0, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_being_picked:
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
	var item_name: String = str(item_id)
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr:
		var def = inv_mgr.get_item_def(item_id)
		if def:
			item_name = def.name
	return "[F] Nhặt %s (x%d)" % [item_name, amount]
