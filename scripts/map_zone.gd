extends Node2D

# Vùng đất có tên trên bản đồ. Người chơi đi vào lần đầu sẽ khám phá vùng này.

@export var zone_title: String = ""
@export var zone_size: Vector2 = Vector2(560, 280)
@export var zone_color: Color = Color(0.3, 0.3, 0.3)
@export var region_id: StringName = &""
@export var show_area: bool = true

func _ready() -> void:
	if region_id == StringName():
		return
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2 # Player
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = zone_size
	shape.shape = rectangle
	shape.position = zone_size * 0.5
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	get_node("/root/WorldState").discover_region(region_id)

func _draw() -> void:
	if not show_area:
		return
	# Nền vùng đã do Terrain vẽ, ở đây chỉ còn tên vùng và đường viền mờ.
	draw_rect(Rect2(Vector2.ZERO, zone_size), Color(zone_color.r, zone_color.g, zone_color.b, 0.3), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(10, 16), zone_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, zone_color.lerp(Color.WHITE, 0.5))
