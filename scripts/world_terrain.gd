extends Node2D

# Nền bản đồ dựng bằng TileMapLayer từ bảng vùng bên dưới.
# Tile tạm được vẽ bằng code; khi có tileset thật chỉ cần thay _build_atlas_texture().

const TILE_SIZE: int = 16
const MAP_CELLS: Vector2i = Vector2i(160, 90)
const VARIANTS: int = 3

enum Ground { GRASS, FOREST, DIRT, STONE, RUST, GOLD, MUD, SAND, RUIN, WATER, CLIFF }

const GROUND_COLORS: Array[Color] = [
	Color(0.2, 0.33, 0.2), Color(0.13, 0.27, 0.16), Color(0.36, 0.29, 0.2), Color(0.32, 0.34, 0.38),
	Color(0.36, 0.23, 0.18), Color(0.43, 0.35, 0.16), Color(0.2, 0.24, 0.17), Color(0.62, 0.52, 0.32),
	Color(0.3, 0.28, 0.34), Color(0.15, 0.3, 0.46), Color(0.17, 0.15, 0.15)
]
const SOLID_GROUNDS: Array[int] = [Ground.WATER, Ground.CLIFF]

# Vẽ theo thứ tự, mục sau đè mục trước. Đơn vị là pixel thế giới.
const REGIONS: Array = [
	[Rect2(672, 520, 544, 160), Ground.DIRT],
	[Rect2(1320, 60, 580, 280), Ground.FOREST],
	[Rect2(1960, 60, 560, 280), Ground.STONE],
	[Rect2(1320, 400, 580, 280), Ground.RUST],
	[Rect2(1960, 400, 560, 280), Ground.GOLD],
	[Rect2(1216, 592, 104, 16), Ground.DIRT],
	[Rect2(1320, 340, 1200, 60), Ground.DIRT],
	[Rect2(1900, 60, 60, 620), Ground.DIRT],
	[Rect2(60, 780, 760, 620), Ground.MUD],
	[Rect2(880, 780, 760, 620), Ground.SAND],
	[Rect2(1700, 780, 800, 620), Ground.RUIN],
	[Rect2(200, 1000, 160, 96), Ground.WATER],
	[Rect2(560, 1184, 144, 112), Ground.WATER],
	# Dải vách đá ngăn bắc và nam, có ba lối: Đầm Lầy, Đồi Cát, cổng Tàn Tích.
	[Rect2(0, 720, 384, 32), Ground.CLIFF],
	[Rect2(480, 720, 760, 32), Ground.CLIFF],
	[Rect2(1336, 720, 744, 32), Ground.CLIFF],
	[Rect2(2176, 720, 384, 32), Ground.CLIFF],
	[Rect2(1648, 752, 32, 688), Ground.CLIFF]
]

var _cells: PackedInt32Array = PackedInt32Array()
var _layer: TileMapLayer

func _ready() -> void:
	_paint_cells()
	_build_layer()

func get_ground_at(world_position: Vector2) -> int:
	var cell := Vector2i((world_position / float(TILE_SIZE)).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_CELLS.x or cell.y >= MAP_CELLS.y:
		return -1
	return _cells[cell.y * MAP_CELLS.x + cell.x]

func _paint_cells() -> void:
	_cells.resize(MAP_CELLS.x * MAP_CELLS.y)
	_cells.fill(Ground.GRASS)
	for entry in REGIONS:
		var area: Rect2 = entry[0]
		var first := Vector2i((area.position / float(TILE_SIZE)).floor())
		var last := Vector2i((area.end / float(TILE_SIZE)).ceil())
		for y in range(maxi(first.y, 0), mini(last.y, MAP_CELLS.y)):
			for x in range(maxi(first.x, 0), mini(last.x, MAP_CELLS.x)):
				_cells[y * MAP_CELLS.x + x] = entry[1]

func _build_layer() -> void:
	_layer = TileMapLayer.new()
	_layer.name = "Ground"
	_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer.tile_set = _build_tile_set()
	add_child(_layer)
	for y in MAP_CELLS.y:
		for x in MAP_CELLS.x:
			var cell := Vector2i(x, y)
			# Băm theo ô để bản đồ giống nhau mỗi lần chạy.
			_layer.set_cell(cell, 0, Vector2i(_cells[y * MAP_CELLS.x + x], absi(hash(cell)) % VARIANTS))
	_layer.update_internals()

func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)
	var source := TileSetAtlasSource.new()
	source.texture = _build_atlas_texture()
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)
	var half := TILE_SIZE * 0.5
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for ground in GROUND_COLORS.size():
		for variant in VARIANTS:
			var coords := Vector2i(ground, variant)
			source.create_tile(coords)
			if ground in SOLID_GROUNDS:
				var tile_data := source.get_tile_data(coords, 0)
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, square)
	return tile_set

func _build_atlas_texture() -> Texture2D:
	var image := Image.create(GROUND_COLORS.size() * TILE_SIZE, VARIANTS * TILE_SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2809
	for ground in GROUND_COLORS.size():
		var base: Color = GROUND_COLORS[ground]
		for variant in VARIANTS:
			var origin := Vector2i(ground, variant) * TILE_SIZE
			for y in TILE_SIZE:
				for x in TILE_SIZE:
					var shade := rng.randf_range(-0.012, 0.012)
					image.set_pixel(origin.x + x, origin.y + y, Color(base.r + shade, base.g + shade, base.b + shade))
			# Vài đốm sáng tối để nền không phẳng.
			for _i in 5 + variant * 2:
				var speck := Vector2i(rng.randi_range(0, TILE_SIZE - 1), rng.randi_range(0, TILE_SIZE - 1))
				var tint := base.lightened(0.14) if rng.randf() < 0.5 else base.darkened(0.14)
				image.set_pixelv(origin + speck, tint)
			if ground == Ground.CLIFF:
				for x in TILE_SIZE:
					image.set_pixel(origin.x + x, origin.y, base.lightened(0.28))
					image.set_pixel(origin.x + x, origin.y + TILE_SIZE - 1, base.darkened(0.4))
	return ImageTexture.create_from_image(image)
