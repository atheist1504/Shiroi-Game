extends CanvasLayer

# Bản đồ nhỏ hình tròn góc trên phải: chỉ hiện địa hình quanh người chơi (khoảng
# 48 ô bề ngang, rộng hơn màn hình một chút), người chơi luôn ở giữa, bản đồ trượt
# theo. Ảnh lấy mỗi ô tile một điểm ảnh, màu từ chính ảnh tile đã vẽ (lớp
# Obstacles đè lên Ground), nên vẽ lại bản đồ trong editor thì tự đổi theo.
# Phím M mở bản đồ thế giới phủ màn hình (dùng chung ảnh, thấy toàn bộ), có
# tên các vùng đã khám phá; vùng chưa tới ghi "???". Mở thì thế giới tạm dừng.

const DISPLAY_SIZE := Vector2(96, 96)
const DISPLAY_POSITION := Vector2(533, 8)
const PLAYER_DOT_SIZE: float = 4.0
# Mỗi ô tile chiếm bao nhiêu điểm ảnh trên bản đồ nhỏ.
const MINIMAP_PIXELS_PER_CELL: float = 2.0
const WORLD_MAP_SIZE := Vector2(576, 324)
const WORLD_MAP_POSITION := Vector2(32, 28)
const WORLD_DOT_SIZE: float = 6.0
# Mở bản đồ M theo cột mốc (beacon.gd); đống lửa Trại luôn mở và dịch chuyển về được.
const Exploration = preload("res://scripts/exploration.gd")
const REVEAL_RADIUS: float = 420.0
const CAMP_BEACON_POSITION := Vector2(944, 640)
const UNREVEALED_COLOR := Color(0.05, 0.05, 0.09)

var _terrain: Node
var _player: Node2D
var _map_rect: TextureRect
var _player_dot: ColorRect
var _tile_colors: Dictionary = {}
var _world_layer: CanvasLayer
var _world_rect: TextureRect
var _world_dot: ColorRect
var _world_labels: Control
var _paused_before_open: bool = false

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_terrain = get_parent().get_node_or_null("Environment/Terrain")
	_player = get_parent().get_node_or_null("Player") as Node2D
	_build_ui()
	_build_world_map()
	if _terrain:
		# Bản đồ nhỏ và bản đồ M dùng chung một ảnh (lục địa dưới mây + rừng),
		# nên phần rừng lẫn phần viền ngoài rừng trên hai bản đồ giống hệt nhau.
		var world_texture := ImageTexture.create_from_image(build_world_image(build_map_image()))
		_world_rect.texture = world_texture
		_map_rect.texture = world_texture
		_map_rect.size = Vector2(_terrain.WORLD_CELLS) * MINIMAP_PIXELS_PER_CELL
		(_map_rect.material as ShaderMaterial).set_shader_parameter("rect_size", _map_rect.size)

const FOG_COLOR := Color(0.02, 0.02, 0.04)

# Ảnh bản đồ M: lục địa (assets/maps/continent.png), vùng đang chơi thay bằng
# bản đồ thật, phần còn lại phủ mây đen (vẫn lờ mờ thấy hình núi, hồ).
func build_world_image(map_image: Image) -> Image:
	var scale: int = _terrain.CONTINENT_PIXELS_PER_CELL
	var size: Vector2i = _terrain.WORLD_CELLS * scale
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(FOG_COLOR)
	var texture := load(_terrain.CONTINENT_IMAGE) as Texture2D
	if texture:
		var continent := texture.get_image()
		if continent.is_compressed():
			continent.decompress()
		continent.convert(Image.FORMAT_RGBA8)
		image.blit_rect(continent, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	var region := Rect2i(_terrain.REGION_OFFSET * scale, _terrain.MAP_CELLS * scale)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	for y in size.y:
		for x in size.x:
			var p := Vector2i(x, y)
			if region.has_point(p):
				var tile_px := map_image.get_pixelv((p - region.position) / scale)
				if tile_px.a > 0.5:
					image.set_pixelv(p, tile_px)
					continue
			# Khoảng cách (điểm ảnh lục địa) ra ngoài mép vùng chơi hình bầu dục.
			var world_pos: Vector2 = (Vector2(p) / scale - Vector2(_terrain.REGION_OFFSET)) * _terrain.TILE_SIZE
			var shape: float = _terrain.play_shape_value(world_pos)
			var dist: float = maxf(pow(shape, 0.25) - 1.0, 0.0) * _terrain.PLAY_RADIUS_CELLS.y * scale
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var amount := clampf(0.8 + n * 0.17, 0.0, 0.97) * smoothstep(0.0, 3.0, dist + n * 2.0)
			var cloud := FOG_COLOR.lerp(Color(0.16, 0.15, 0.21), n * 0.6)
			image.set_pixelv(p, image.get_pixelv(p).lerp(cloud, amount))
	return image

# Ảnh bản đồ: mỗi ô tile một điểm ảnh.
func build_map_image() -> Image:
	var cells: Vector2i = _terrain.MAP_CELLS
	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	# Ô trống hoặc ô ngoài vùng chơi (tile trong suốt) để trong suốt: dưới là nền mây.
	image.fill(Color(0, 0, 0, 0))
	for layer_name in ["Ground", "Obstacles"]:
		var tile_layer := _terrain.get_node_or_null(layer_name) as TileMapLayer
		if not tile_layer:
			continue
		for cell in tile_layer.get_used_cells():
			if cell.x < 0 or cell.y < 0 or cell.x >= cells.x or cell.y >= cells.y:
				continue
			image.set_pixelv(cell, _tile_color(tile_layer, cell))
	return image

func _tile_color(tile_layer: TileMapLayer, cell: Vector2i) -> Color:
	var source_id := tile_layer.get_cell_source_id(cell)
	var coords := tile_layer.get_cell_atlas_coords(cell)
	var key := Vector3i(source_id, coords.x, coords.y)
	if _tile_colors.has(key):
		return _tile_colors[key]
	var color := Color(0, 0, 0, 0)
	var source := tile_layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source and source.texture:
		var region := source.get_tile_texture_region(coords)
		var tile_image := source.texture.get_image()
		if tile_image:
			if tile_image.is_compressed():
				tile_image.decompress()
			# Màu trung bình của cả ô (tile chi tiết, lấy một điểm dễ trúng hoa, đá).
			var sum := Color(0, 0, 0, 0)
			var count := 0
			for y in region.size.y:
				for x in region.size.x:
					var c := tile_image.get_pixelv(region.position + Vector2i(x, y))
					if c.a > 0.5:
						sum += c
						count += 1
			# Tile trong suốt (ô ngoài vùng chơi) giữ trong suốt.
			if count > 0:
				color = sum / count
				color.a = 1.0
	_tile_colors[key] = color
	return color

func _process(_delta: float) -> void:
	if not _player or not _terrain:
		return
	# Trượt ảnh bản đồ để người chơi nằm giữa khung.
	# Ảnh là cả lục địa; góc trên trái của nó lệch REGION_OFFSET ô so với vùng chơi.
	_map_rect.position = world_to_minimap(-Vector2(_terrain.REGION_OFFSET * _terrain.TILE_SIZE))
	_player_dot.position = DISPLAY_SIZE * 0.5 - Vector2.ONE * PLAYER_DOT_SIZE * 0.5
	# Mặt nạ tròn đi theo khung, không theo ảnh đang trượt.
	(_map_rect.material as ShaderMaterial).set_shader_parameter("circle_center", DISPLAY_SIZE * 0.5 - _map_rect.position)

# Đổi tọa độ thế giới sang tọa độ trong khung bản đồ nhỏ (người chơi ở giữa).
func world_to_minimap(world_position: Vector2) -> Vector2:
	var center := _player.global_position if _player else Vector2.ZERO
	return DISPLAY_SIZE * 0.5 + (world_position - center) / float(_terrain.TILE_SIZE) * MINIMAP_PIXELS_PER_CELL

const CIRCLE_MASK_SHADER := """
shader_type canvas_item;
// Chỉ vẽ phần ảnh nằm trong vòng tròn của khung bản đồ nhỏ.
uniform vec2 rect_size;
uniform vec2 circle_center;
uniform float radius;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (distance(UV * rect_size, circle_center) > radius) {
		c.a = 0.0;
	}
	COLOR = c;
}
"""

func _build_ui() -> void:
	# Khung tròn: nền tối, viền sáng (vẽ trong _draw_frame).
	var frame := Control.new()
	frame.name = "MinimapFrame"
	frame.position = DISPLAY_POSITION - Vector2(3, 3)
	frame.size = DISPLAY_SIZE + Vector2(6, 6)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		var c := frame.size * 0.5
		var r := DISPLAY_SIZE.x * 0.5
		frame.draw_circle(c, r + 2.0, Color(0.03, 0.04, 0.08, 0.9))
	)
	add_child(frame)
	var holder := Control.new()
	holder.position = Vector2(3, 3)
	holder.size = DISPLAY_SIZE
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	var ring := Control.new()
	ring.name = "Ring"
	ring.size = frame.size
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(func() -> void:
		ring.draw_arc(ring.size * 0.5, DISPLAY_SIZE.x * 0.5 + 1.0, 0.0, TAU, 64, Color(0.45, 0.95, 0.85, 0.85), 2.0, true)
	)
	_map_rect = TextureRect.new()
	var mask := ShaderMaterial.new()
	mask.shader = Shader.new()
	mask.shader.code = CIRCLE_MASK_SHADER
	mask.set_shader_parameter("radius", DISPLAY_SIZE.x * 0.5)
	_map_rect.material = mask
	if _terrain:
		_map_rect.size = Vector2(_terrain.MAP_CELLS) * MINIMAP_PIXELS_PER_CELL
	_map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_map_rect)
	_player_dot = ColorRect.new()
	_player_dot.size = Vector2.ONE * PLAYER_DOT_SIZE
	_player_dot.color = Color(1.0, 0.95, 0.4)
	_player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_player_dot)
	frame.add_child(ring)
	mask.set_shader_parameter("rect_size", _map_rect.size)

# --- Bản đồ thế giới (phím M) ---

func is_world_map_open() -> bool:
	return _world_layer != null and _world_layer.visible

func _unhandled_input(event: InputEvent) -> void:
	# Ô nhập chữ nhận phím trước, nên gõ chữ M khi đặt tên không mở bản đồ.
	# Đang tạm dừng (menu, túi đồ, màn chữ) thì không mở.
	if not is_world_map_open() and _is_key(event, KEY_M) and not get_tree().paused:
		set_world_map_open(true)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Khi đang mở thì bản đồ nhận M/Esc trước menu tạm dừng.
	if is_world_map_open() and (_is_key(event, KEY_M) or _is_key(event, KEY_ESCAPE)):
		set_world_map_open(false)
		get_viewport().set_input_as_handled()

func _is_key(event: InputEvent, keycode: Key) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.physical_keycode == keycode

func set_world_map_open(open: bool) -> void:
	if open == is_world_map_open():
		return
	if open:
		_paused_before_open = get_tree().paused
		_refresh_world_map()
		get_tree().paused = true
	else:
		get_tree().paused = _paused_before_open
	_world_layer.visible = open

# Tọa độ thế giới sang tọa độ trong khung bản đồ thế giới.
# Tọa độ thế giới sang tọa độ trên bản đồ M (cả lục địa, vùng đang chơi lệch REGION_OFFSET).
func world_to_world_map(world_position: Vector2) -> Vector2:
	var cell := world_position / float(_terrain.TILE_SIZE) + Vector2(_terrain.REGION_OFFSET)
	return cell / Vector2(_terrain.WORLD_CELLS) * WORLD_MAP_SIZE

# Khung vùng đang chơi trên bản đồ M.
func get_region_rect_on_world_map() -> Rect2:
	var top_left := world_to_world_map(Vector2.ZERO)
	var bottom_right := world_to_world_map(Vector2(_terrain.MAP_CELLS * _terrain.TILE_SIZE))
	return Rect2(top_left, bottom_right - top_left)

func _refresh_world_map() -> void:
	if not _terrain:
		return
	if _player:
		_world_dot.position = world_to_world_map(_player.global_position) - Vector2.ONE * WORLD_DOT_SIZE * 0.5
	for child in _world_labels.get_children():
		_world_labels.remove_child(child)
		child.queue_free()
	var zones := get_parent().get_node_or_null("Environment/Zones")
	if not zones:
		return
	var world_state := get_node_or_null("/root/WorldState")
	# Phần vùng chơi chưa mở (xa mọi cột mốc đã kích hoạt) phủ mây; dưới cùng để chữ nằm trên.
	_add_reveal_fog()
	# Tên vùng lớn đặt trên mép khung vùng đang chơi.
	var region_rect := get_region_rect_on_world_map()
	var region_label := Label.new()
	region_label.name = "RegionName"
	var region_progress := Exploration.region_progress(get_tree(), zones.get_children())
	region_label.text = "%s • %d%%" % [str(_terrain.REGION_NAME).to_upper(), Exploration.percent(region_progress)]
	region_label.add_theme_font_size_override("font_size", 12)
	region_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	region_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	region_label.add_theme_constant_override("outline_size", 5)
	region_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_label.size = Vector2(region_rect.size.x, 18)
	region_label.position = region_rect.position - Vector2(0, 20)
	_world_labels.add_child(region_label)
	for zone in zones.get_children():
		if not "zone_title" in zone or zone.zone_title == "":
			continue
		var known: bool = world_state == null or zone.region_id == StringName() or world_state.is_region_discovered(zone.region_id)
		var label := Label.new()
		label.name = "Zone_" + zone.name
		label.text = "%s %d%%" % [zone.zone_title, Exploration.percent(Exploration.zone_progress(get_tree(), zone))] if known else "???"
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", zone.zone_color.lerp(Color.WHITE, 0.6) if known else Color(0.7, 0.7, 0.75))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(110, 12)
		var center: Vector2 = world_to_world_map(zone.position + zone.zone_size * 0.5)
		label.position = center - label.size * 0.5
		_world_labels.add_child(label)
	_add_beacon_markers()

# Các điểm mở bản đồ: đống lửa Trại (luôn mở) và các cột mốc đã kích hoạt.
func get_revealed_points() -> Array[Vector2]:
	var points: Array[Vector2] = [CAMP_BEACON_POSITION]
	for beacon in get_tree().get_nodes_in_group("beacons"):
		if bool(beacon.call("is_active")):
			points.append(beacon.global_position)
	return points

func is_revealed(world_position: Vector2) -> bool:
	for point in get_revealed_points():
		if point.distance_to(world_position) <= REVEAL_RADIUS:
			return true
	return false

func _add_reveal_fog() -> void:
	var cells: Vector2i = _terrain.MAP_CELLS
	var fog := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var points := get_revealed_points()
	for y in cells.y:
		for x in cells.x:
			var world_pos := (Vector2(x, y) + Vector2(0.5, 0.5)) * float(_terrain.TILE_SIZE)
			var nearest := INF
			for point in points:
				nearest = minf(nearest, point.distance_to(world_pos))
			# Mép vùng mở mờ dần trong khoảng 48 đơn vị cho đỡ cứng.
			var amount := clampf((nearest - REVEAL_RADIUS + 48.0) / 48.0, 0.0, 1.0) * 0.9
			fog.set_pixel(x, y, Color(UNREVEALED_COLOR, amount))
	var rect := TextureRect.new()
	rect.name = "RevealFog"
	rect.texture = ImageTexture.create_from_image(fog)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var region_rect := get_region_rect_on_world_map()
	rect.position = region_rect.position
	rect.size = region_rect.size
	_world_labels.add_child(rect)

# Cột mốc trên bản đồ M: đã kích hoạt là nút bấm để dịch chuyển, chưa thì chấm xám
# (chỉ hiện khi chỗ đó đã được mở).
func _add_beacon_markers() -> void:
	var entries: Array = [[CAMP_BEACON_POSITION, true, "Trại"]]
	for beacon in get_tree().get_nodes_in_group("beacons"):
		entries.append([beacon.global_position, bool(beacon.call("is_active")), "Cột mốc"])
	for entry in entries:
		var world_pos: Vector2 = entry[0]
		var active: bool = entry[1]
		if not active and not is_revealed(world_pos):
			continue
		var marker := Button.new()
		marker.name = "Beacon_%d_%d" % [int(world_pos.x), int(world_pos.y)]
		marker.text = "◆"
		marker.flat = true
		marker.add_theme_font_size_override("font_size", 10)
		marker.add_theme_color_override("font_color", Color(0.4, 1.0, 0.9) if active else Color(0.6, 0.62, 0.68))
		marker.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.6))
		marker.size = Vector2(14, 14)
		marker.position = world_to_world_map(world_pos) - marker.size * 0.5
		marker.tooltip_text = "%s: bấm để dịch chuyển" % entry[2] if active else "Cột mốc chưa kích hoạt"
		marker.disabled = not active
		marker.pressed.connect(teleport_to.bind(world_pos))
		_world_labels.add_child(marker)

# Dịch chuyển nhanh tới cột mốc đã kích hoạt rồi đóng bản đồ.
func teleport_to(beacon_position: Vector2) -> bool:
	if not _player or bool(_player.get("is_dead")) or _paused_before_open:
		return false
	var night := get_parent().get_node_or_null("FirstNight")
	if night and (bool(night.call("is_night_active")) or bool(night.call("is_practicing"))):
		var notifications := get_node_or_null("/root/NotificationManager")
		if notifications:
			notifications.show_warning("Chưa dịch chuyển được trong đêm đầu.")
		return false
	# Chỉ tới được đống lửa Trại và cột mốc đã kích hoạt.
	if not get_revealed_points().has(beacon_position):
		return false
	_player.global_position = beacon_position + Vector2(0, 28)
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	set_world_map_open(false)
	return true

func _build_world_map() -> void:
	_world_layer = CanvasLayer.new()
	_world_layer.name = "WorldMap"
	_world_layer.layer = 90
	_world_layer.visible = false
	add_child(_world_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.92)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_layer.add_child(backdrop)
	var title := Label.new()
	title.text = "BẢN ĐỒ THẾ GIỚI"
	title.position = Vector2(WORLD_MAP_POSITION.x, 7)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.85))
	_world_layer.add_child(title)
	var hint := Label.new()
	hint.text = "M / Esc: đóng"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size = Vector2(160, 16)
	hint.position = Vector2(WORLD_MAP_POSITION.x + WORLD_MAP_SIZE.x - hint.size.x, 9)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	_world_layer.add_child(hint)
	var frame := Panel.new()
	frame.position = WORLD_MAP_POSITION - Vector2(2, 2)
	frame.size = WORLD_MAP_SIZE + Vector2(4, 4)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 1)
	style.border_color = Color(0.45, 0.95, 0.85, 0.7)
	style.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", style)
	_world_layer.add_child(frame)
	var holder := Control.new()
	holder.position = WORLD_MAP_POSITION
	holder.size = WORLD_MAP_SIZE
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_layer.add_child(holder)
	_world_rect = TextureRect.new()
	_world_rect.size = WORLD_MAP_SIZE
	_world_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_world_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_world_rect)
	_world_labels = Control.new()
	_world_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_world_labels)
	_world_dot = ColorRect.new()
	_world_dot.size = Vector2.ONE * WORLD_DOT_SIZE
	_world_dot.color = Color(1.0, 0.95, 0.4)
	_world_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_world_dot)
