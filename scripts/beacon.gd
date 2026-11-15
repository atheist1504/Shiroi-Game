extends Area2D

# Cột mốc: đứng gần bấm F để kích hoạt. Kích hoạt rồi thì bản đồ M mở phần
# quanh cột mốc và dịch chuyển nhanh tới đây được (xem minimap.gd).
# Trạng thái lưu bằng cờ "beacon_<beacon_id>" trong WorldState (có trong save).
# Đặt thêm cột mốc: nhân bản node trong main.tscn (Ctrl+D) và đổi beacon_id cho khác nhau.

const REVEAL_RADIUS: float = 420.0 # bán kính mở bản đồ M quanh cột mốc (đơn vị thế giới)

@export var beacon_id: StringName = &"beacon_01"

@onready var prompt_label: Label = $PromptLabel

var player_inside: bool = false

func _ready() -> void:
	add_to_group("beacons")
	collision_layer = 0
	collision_mask = 2 # Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.visible = false

func _process(_delta: float) -> void:
	queue_redraw() # tinh thể nhấp nháy

func _flag_id() -> StringName:
	return StringName("beacon_" + str(beacon_id))

func is_active() -> bool:
	var world_state := get_node_or_null("/root/WorldState")
	return world_state != null and world_state.get_flag(_flag_id(), false) == true

func activate() -> bool:
	if is_active():
		return false
	get_node("/root/WorldState").set_flag(_flag_id(), true)
	var notifications := get_node_or_null("/root/NotificationManager")
	if notifications:
		notifications.show_success("Đã kích hoạt cột mốc. Mở bản đồ (M) để dịch chuyển tới đây.")
	_update_prompt()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or is_active() or get_tree().paused:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
		activate()
		get_viewport().set_input_as_handled()

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
	prompt_label.text = "✓ Cột mốc đã kích hoạt" if is_active() else "[F] Kích hoạt cột mốc"
	prompt_label.visible = player_inside

func _draw() -> void:
	# Bệ đá và trụ đá, trên đỉnh là tinh thể: tắt thì xám, kích hoạt thì sáng xanh.
	draw_ellipse(Vector2(0, 4), 14.0, 5.0, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-12, -2, 24, 6), Color(0.3, 0.32, 0.38, 1))
	draw_rect(Rect2(-7, -26, 14, 25), Color(0.38, 0.4, 0.48, 1))
	draw_rect(Rect2(-5, -24, 4, 21), Color(0.48, 0.5, 0.6, 1))
	var active := is_active()
	var glow := 0.75 + sin(Time.get_ticks_msec() / 300.0) * 0.25 if active else 1.0
	var crystal := Color(0.4, 1.0, 0.9, glow) if active else Color(0.55, 0.58, 0.65, 1)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -42), Vector2(6, -32), Vector2(0, -26), Vector2(-6, -32)]), crystal)
	if active:
		draw_circle(Vector2(0, -34), 10.0, Color(0.4, 1.0, 0.9, 0.15 * glow))
