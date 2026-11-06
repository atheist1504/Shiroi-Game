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

func _draw() -> void:
	# Vẽ bàn chế tạo gỗ pixel art phong cách mộc (kích thước khoảng 32x24)
	# Bóng đổ bàn
	draw_ellipse(Vector2(0, 10), 18.0, 6.0, Color(0.0, 0.0, 0.0, 0.3))

	# 4 chân bàn gỗ sồi đậm
	var leg_dark := Color(0.35, 0.22, 0.12, 1.0)
	var leg_light := Color(0.48, 0.32, 0.18, 1.0)
	draw_rect(Rect2(-14, 0, 4, 10), leg_dark)
	draw_rect(Rect2(-14, 0, 2, 10), leg_light)

	draw_rect(Rect2(10, 0, 4, 10), leg_dark)
	draw_rect(Rect2(10, 0, 2, 10), leg_light)

	draw_rect(Rect2(-10, -3, 3, 7), leg_dark)
	draw_rect(Rect2(7, -3, 3, 7), leg_dark)

	# Mặt bàn dày
	var table_top := Color(0.68, 0.46, 0.26, 1.0)
	var table_highlight := Color(0.82, 0.58, 0.34, 1.0)
	var table_shadow := Color(0.45, 0.28, 0.15, 1.0)
	var table_border := Color(0.25, 0.15, 0.08, 1.0)

	# Khung viền mặt bàn
	draw_rect(Rect2(-17, -10, 34, 12), table_border)
	# Mặt gỗ
	draw_rect(Rect2(-16, -9, 32, 10), table_top)
	# Vát sáng mép trên
	draw_line(Vector2(-16, -9), Vector2(16, -9), table_highlight, 1.0)
	# Mép tối cạnh dưới
	draw_line(Vector2(-16, 0), Vector2(16, 0), table_shadow, 1.0)

	# Chi tiết trên mặt bàn:
	# 1. Kẹp ê-tô sắt (Vise) bên trái
	draw_rect(Rect2(-14, -13, 5, 4), Color(0.3, 0.35, 0.4, 1.0))
	draw_rect(Rect2(-15, -12, 2, 2), Color(0.6, 0.65, 0.7, 1.0))
	# 2. Ván gỗ đang gia công ở giữa
	draw_rect(Rect2(-5, -8, 12, 5), Color(0.85, 0.65, 0.4, 1.0))
	draw_rect(Rect2(-5, -6, 12, 1), Color(0.55, 0.35, 0.2, 1.0)) # vân gỗ
	# 3. Búa nhỏ bên phải
	draw_line(Vector2(9, -7), Vector2(14, -4), Color(0.5, 0.35, 0.2, 1.0), 2.0) # cán
	draw_rect(Rect2(12, -9, 4, 3), Color(0.4, 0.45, 0.5, 1.0)) # đầu búa

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
