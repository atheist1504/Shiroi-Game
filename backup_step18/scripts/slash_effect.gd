extends Node2D

@export var arc_radius: float = 48.0
@export var arc_angle_deg: float = 90.0
@export var duration: float = 0.14

var timer: float = 0.0
var active: bool = false

func _ready() -> void:
	visible = false

func play(target_angle: float) -> void:
	rotation = target_angle
	timer = duration
	active = true
	visible = true
	modulate.a = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return

	timer -= delta
	if timer <= 0.0:
		active = false
		visible = false
	else:
		modulate.a = timer / duration
		queue_redraw()

func _draw() -> void:
	if not active:
		return

	var half_angle := deg_to_rad(arc_angle_deg / 2.0)
	var points := PackedVector2Array()
	var colors := PackedColorArray()

	var num_segments := 16
	var inner_radius := arc_radius * 0.45
	var outer_radius := arc_radius

	# Tạo dải cung kiếm hình bán nguyệt sắc nét
	for i in range(num_segments + 1):
		var t := float(i) / float(num_segments)
		var angle := -half_angle + t * (half_angle * 2.0)
		var dir := Vector2.from_angle(angle)

		points.append(dir * outer_radius)
		# Màu trắng xanh cyan rực rỡ ở rìa ngoài
		colors.append(Color(0.85, 0.95, 1.0, 0.9))

		points.append(dir * inner_radius)
		# Màu xanh biển nhạt dịu hơn ở phần thân kiếm
		colors.append(Color(0.35, 0.75, 1.0, 0.2))

	# Vẽ dải tam giác nối các điểm
	for i in range(num_segments):
		var idx := i * 2
		var p1 := points[idx]
		var p2 := points[idx + 1]
		var p3 := points[idx + 2]
		var p4 := points[idx + 3]

		var tri1 := PackedVector2Array([p1, p3, p2])
		var col1 := PackedColorArray([colors[idx], colors[idx + 2], colors[idx + 1]])
		draw_polygon(tri1, col1)

		var tri2 := PackedVector2Array([p2, p3, p4])
		var col2 := PackedColorArray([colors[idx + 1], colors[idx + 2], colors[idx + 3]])
		draw_polygon(tri2, col2)

	# Vẽ thêm đường viền sắc bén bên ngoài
	var arc_points := PackedVector2Array()
	for i in range(num_segments + 1):
		var t := float(i) / float(num_segments)
		var angle := -half_angle + t * (half_angle * 2.0)
		arc_points.append(Vector2.from_angle(angle) * outer_radius)
	draw_polyline(arc_points, Color(1.0, 1.0, 1.0, 0.95), 1.5)
