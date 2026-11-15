extends Node2D

# Bản đồ vẽ tay trong editor: mở scenes/world_map.tscn, chọn một lớp rồi vẽ.
#   Ground      nền (cỏ, đất, cát...), không chặn.
#   Obstacles   nước, vách đá...: tile có hình va chạm nên chặn người chơi, quái
#               và đường đi của dân làng (NPCManager dò va chạm lớp 1).
#   Decoration  trang trí đặt lên trên, không chặn.
# Tileset: assets/tiles/terrain_tileset.tres. Mỗi tile có custom data "ground"
# (số trong enum Ground) để code biết loại nền; tile mới thêm phải đặt giá trị này.
# Hướng dẫn chi tiết: docs/BAN_DO.md.

const TILE_SIZE: int = 16
# Khung bản đồ tính theo ô: bắt đầu ở MAP_ORIGIN (âm, vì Rừng Nguyệt Ảnh cũ giữ
# nguyên tọa độ 0..160 x 0..90 để mọi vật thể, Trại, nhiệm vụ không phải dời).
const MAP_ORIGIN: Vector2i = Vector2i(-80, -24)
const MAP_CELLS: Vector2i = Vector2i(320, 134)
const GROUND_DATA: String = "ground"

# VOID: ô ngoài vùng chơi (dưới mây đen), trong suốt nhưng chặn đường.
enum Ground { GRASS, FOREST, DIRT, STONE, RUST, GOLD, MUD, SAND, RUIN, WATER, CLIFF, VOID }

const SOLID_GROUNDS: Array[int] = [Ground.WATER, Ground.CLIFF, Ground.VOID]

# Vùng chơi theo địa hình lục địa (phần đất phía nam một đường ranh tới bờ biển),
# lưu thành ảnh khoảng cách tới mép (tools/gen_world_art.gd -- expand):
# mỗi ô một điểm ảnh, kênh R = (khoảng cách ô có dấu + PLAY_MASK_RANGE) / (2 * PLAY_MASK_RANGE),
# dương là trong vùng chơi.
const PLAY_MASK_IMAGE: String = "res://assets/maps/play_mask.png"
const PLAY_MASK_RANGE: float = 32.0
static var _play_mask: Image = null

static func map_rect() -> Rect2:
	return Rect2(Vector2(MAP_ORIGIN * TILE_SIZE), Vector2(MAP_CELLS * TILE_SIZE))

# Khoảng cách (đơn vị thế giới) tới mép vùng chơi: dương là bên trong, âm là bên ngoài.
static func play_distance(world_position: Vector2) -> float:
	if _play_mask == null:
		var texture := load(PLAY_MASK_IMAGE) as Texture2D
		if texture:
			_play_mask = texture.get_image()
			if _play_mask.is_compressed():
				_play_mask.decompress()
	if _play_mask == null:
		return -1.0
	var cell := Vector2i((world_position / float(TILE_SIZE)).floor()) - MAP_ORIGIN
	if cell.x < 0 or cell.y < 0 or cell.x >= _play_mask.get_width() or cell.y >= _play_mask.get_height():
		return -PLAY_MASK_RANGE * TILE_SIZE
	var value := _play_mask.get_pixelv(cell).r
	return (value * 2.0 - 1.0) * PLAY_MASK_RANGE * TILE_SIZE

# 1 là đúng mép, nhỏ hơn là vào trong (0,85 là cách mép khoảng 2,4 ô), lớn hơn là ra ngoài.
static func play_shape_value(world_position: Vector2) -> float:
	return 1.0 - play_distance(world_position) / (16.0 * TILE_SIZE)

static func is_in_play_area(world_position: Vector2) -> bool:
	return play_distance(world_position) >= 0.0

# Lục địa (tính theo ô): ô (0, 0) của bản đồ nằm ở ô REGION_OFFSET của lục địa.
# Phần ngoài vùng chơi bị mây đen che (fog_border.gd trong game, minimap.gd
# trên bản đồ M). Ảnh lục địa 2 điểm ảnh mỗi ô, vẽ bằng tools/gen_world_art.gd.
const WORLD_CELLS: Vector2i = Vector2i(320, 180)
const REGION_OFFSET: Vector2i = Vector2i(80, 70)
const REGION_NAME: String = "Rừng Nguyệt Ảnh"
const CONTINENT_IMAGE: String = "res://assets/maps/continent.png"
const CONTINENT_PIXELS_PER_CELL: int = 2

@onready var ground_layer: TileMapLayer = get_node_or_null("Ground")
@onready var obstacle_layer: TileMapLayer = get_node_or_null("Obstacles")

static func is_cell_in_map(cell: Vector2i) -> bool:
	return Rect2i(MAP_ORIGIN, MAP_CELLS).has_point(cell)

# Loại nền tại một điểm; lớp vật cản đè lên lớp nền. Ngoài bản đồ trả -1.
func get_ground_at(world_position: Vector2) -> int:
	var cell := Vector2i((world_position / float(TILE_SIZE)).floor())
	if not is_cell_in_map(cell):
		return -1
	for layer in [obstacle_layer, ground_layer]:
		if not layer:
			continue
		var data := (layer as TileMapLayer).get_cell_tile_data(cell)
		if data:
			return int(data.get_custom_data(GROUND_DATA))
	return -1
