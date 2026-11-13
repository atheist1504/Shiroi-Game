extends CanvasLayer

# Bản đồ nhỏ góc trên phải. Mỗi ô tile là một điểm ảnh, màu lấy từ
# chính ảnh tile đã vẽ (lớp Obstacles đè lên Ground), nên vẽ lại bản đồ trong
# editor thì bản đồ nhỏ tự đổi theo. Chấm sáng là vị trí người chơi.
# Phím M mở bản đồ thế giới phủ màn hình (dùng chung ảnh), có tên các vùng
# đã khám phá; vùng chưa tới ghi "???". Mở bản đồ thì thế giới tạm dừng.

const DISPLAY_SIZE := Vector2(128, 72)
const DISPLAY_POSITION := Vector2(498, 8)
const PLAYER_DOT_SIZE: float = 4.0
const WORLD_MAP_SIZE := Vector2(576, 324)
const WORLD_MAP_POSITION := Vector2(32, 28)
const WORLD_DOT_SIZE: float = 6.0

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
		var texture := ImageTexture.create_from_image(build_map_image())
		_map_rect.texture = texture
		_world_rect.texture = texture

# Ảnh bản đồ: mỗi ô tile một điểm ảnh.
func build_map_image() -> Image:
	var cells: Vector2i = _terrain.MAP_CELLS
	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
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
	var color := Color(0.3, 0.3, 0.3)
	var source := tile_layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source and source.texture:
		var region := source.get_tile_texture_region(coords)
		var tile_image := source.texture.get_image()
		if tile_image:
			if tile_image.is_compressed():
				tile_image.decompress()
			color = tile_image.get_pixelv(region.position + region.size / 2)
			color.a = 1.0
	_tile_colors[key] = color
	return color

func _process(_delta: float) -> void:
	if not _player or not _terrain:
		return
	_player_dot.position = world_to_minimap(_player.global_position) - Vector2.ONE * PLAYER_DOT_SIZE * 0.5

# Đổi tọa độ thế giới sang tọa độ trong khung bản đồ nhỏ.
func world_to_minimap(world_position: Vector2) -> Vector2:
	var map_size := Vector2(_terrain.MAP_CELLS * _terrain.TILE_SIZE)
	var ratio := (world_position / map_size).clamp(Vector2.ZERO, Vector2.ONE)
	return ratio * DISPLAY_SIZE

func _build_ui() -> void:
	var frame := PanelContainer.new()
	frame.name = "MinimapFrame"
	frame.position = DISPLAY_POSITION - Vector2(2, 2)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.85)
	style.border_color = Color(0.45, 0.95, 0.85, 0.6)
	style.set_border_width_all(1)
	style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	var holder := Control.new()
	holder.custom_minimum_size = DISPLAY_SIZE
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	_map_rect = TextureRect.new()
	_map_rect.size = DISPLAY_SIZE
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
func world_to_world_map(world_position: Vector2) -> Vector2:
	return world_to_minimap(world_position) / DISPLAY_SIZE * WORLD_MAP_SIZE

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
	for zone in zones.get_children():
		if not "zone_title" in zone or zone.zone_title == "":
			continue
		var known: bool = world_state == null or zone.region_id == StringName() or world_state.is_region_discovered(zone.region_id)
		var label := Label.new()
		label.name = "Zone_" + zone.name
		label.text = zone.zone_title if known else "???"
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", zone.zone_color.lerp(Color.WHITE, 0.6) if known else Color(0.7, 0.7, 0.75))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(160, 14)
		var center: Vector2 = world_to_world_map(zone.position + zone.zone_size * 0.5)
		label.position = center - label.size * 0.5
		_world_labels.add_child(label)

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
