extends Area2D
class_name CraftingStation

# CraftingStation - Bàn chế tạo thử nghiệm (Bước 18)
@export var station_type: String = "workbench"
@export var max_interact_distance: float = 48.0

@onready var prompt_label: Label = $PromptLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player_inside: bool = false
var _player_ref: Node2D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	add_to_group("crafting_stations")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = "[F] Chế tạo"

	queue_redraw()

# Bàn rèn do công cụ AI vẽ (tools/ai_art.gd), đáy hình ở y = 7 như bàn gỗ cũ.
const ART: Texture2D = preload("res://assets/art_ai/anvil.png")

func _draw() -> void:
	draw_texture(ART, Vector2(-ART.get_width() * 0.5, 7 - ART.get_height()))

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or is_queued_for_deletion():
		return

	# Phím F tương tác
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
		# Kiểm tra an toàn: khoảng cách đến người chơi
		if _player_ref:
			var dist: float = global_position.distance_to(_player_ref.global_position)
			if dist > max_interact_distance:
				return

		# Kiểm tra ưu tiên: nếu người chơi đang đứng trên vật phẩm rơi dưới đất, ưu tiên nhặt trước
		var pickups = get_tree().get_nodes_in_group("pickup_items")
		for pickup in pickups:
			if pickup and is_instance_valid(pickup) and pickup.get("player_inside") == true:
				return # Nhường cho lượt nhặt đồ

		_open_crafting_ui()
		get_viewport().set_input_as_handled()

func _open_crafting_ui() -> void:
	var root := get_tree().current_scene
	if not root:
		return

	var crafting_ui = root.get_node_or_null("CraftingUI")
	if crafting_ui and crafting_ui.has_method("open_station"):
		crafting_ui.open_station(station_type)
	elif crafting_ui and crafting_ui.has_method("set_crafting_visible"):
		crafting_ui.set_crafting_visible(true)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		_player_ref = body
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		_player_ref = null
		if prompt_label:
			prompt_label.visible = false
