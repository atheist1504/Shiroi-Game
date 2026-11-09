extends Area2D

@export var region_id: StringName = &"forest_traces"
@export var prompt_text: String = "[F] Khám phá Di Tích Cổ"

@onready var prompt_label: Label = $PromptLabel

var player_inside: bool = false
var is_discovered: bool = false

func _ready() -> void:
	add_to_group("discovery_points")
	collision_layer = 0
	collision_mask = 2 # Player ở Layer 2
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = prompt_text

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or is_discovered:
		return
	
	# Nhấn F để tương tác/khám phá địa điểm khi đứng trong vùng
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
		_discover()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		_update_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		if prompt_label:
			prompt_label.visible = false

func _update_prompt() -> void:
	if not prompt_label:
		return
	
	var world_state = get_node_or_null("/root/WorldState")
	if world_state and world_state.has_method("is_region_discovered") and world_state.is_region_discovered(region_id):
		is_discovered = true
		prompt_label.text = "✓ Đã khám phá: %s" % str(region_id)
		prompt_label.modulate = Color(0.4, 1.0, 0.7)
		prompt_label.visible = true
	else:
		prompt_label.text = prompt_text
		prompt_label.modulate = Color(1.0, 0.9, 0.4)
		prompt_label.visible = true

func _discover() -> void:
	is_discovered = true
	var world_state = get_node_or_null("/root/WorldState")
	if world_state and world_state.has_method("discover_region"):
		world_state.discover_region(region_id)
	
	if prompt_label:
		prompt_label.text = "✓ Đã khám phá: %s" % str(region_id)
		prompt_label.modulate = Color(0.4, 1.0, 0.7)

func _draw() -> void:
	# Vẽ tảng đá di tích cổ phong cách Pixel Art
	# Bệ đá
	draw_rect(Rect2(-12, -4, 24, 8), Color(0.25, 0.28, 0.35, 1.0))
	draw_rect(Rect2(-10, -2, 20, 6), Color(0.35, 0.38, 0.48, 1.0))
	
	# Cột bia đá khắc cổ tự
	draw_rect(Rect2(-8, -22, 16, 18), Color(0.3, 0.33, 0.42, 1.0))
	draw_rect(Rect2(-6, -20, 12, 15), Color(0.4, 0.45, 0.55, 1.0))
	
	# Hoa văn phát sáng cổ ngữ
	var t := Time.get_ticks_msec() / 250.0
	var glow := 0.6 + sin(t) * 0.3
	var rune_color := Color(0.3, 0.9, 0.8, glow)
	draw_line(Vector2(0, -18), Vector2(0, -8), rune_color, 1.5)
	draw_line(Vector2(-3, -13), Vector2(3, -13), rune_color, 1.5)
	draw_circle(Vector2(0, -6), 1.5, rune_color)
