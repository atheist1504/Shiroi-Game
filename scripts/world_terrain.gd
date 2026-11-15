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
const MAP_CELLS: Vector2i = Vector2i(160, 90)
const GROUND_DATA: String = "ground"

# VOID: ô ngoài vùng chơi (dưới mây đen), trong suốt nhưng chặn đường.
enum Ground { GRASS, FOREST, DIRT, STONE, RUST, GOLD, MUD, SAND, RUIN, WATER, CLIFF, VOID }

const SOLID_GROUNDS: Array[int] = [Ground.WATER, Ground.CLIFF, Ground.VOID]

# Vùng chơi là hình bầu dục bo tròn (siêu elip bậc 4) trong khung MAP_CELLS:
# |x/rx|^4 + |y/ry|^4 <= 1, tính từ tâm khung. Ngoài hình là mây đen.
const PLAY_RADIUS_CELLS: Vector2 = Vector2(76, 42)
const PLAY_SHAPE_POWER: float = 4.0

# < 1 là trong vùng chơi, 1 là đúng mép, > 1 là ngoài.
static func play_shape_value(world_position: Vector2) -> float:
	var center := Vector2(MAP_CELLS * TILE_SIZE) * 0.5
	var rel := (world_position - center) / (PLAY_RADIUS_CELLS * TILE_SIZE)
	return pow(absf(rel.x), PLAY_SHAPE_POWER) + pow(absf(rel.y), PLAY_SHAPE_POWER)

static func is_in_play_area(world_position: Vector2) -> bool:
	return play_shape_value(world_position) <= 1.0

# Lục địa (tính theo ô): vùng đang chơi là Rừng Nguyệt Ảnh nằm ở REGION_OFFSET.
# Phần còn lại chưa làm, bị mây đen che (fog_border.gd trong game, minimap.gd
# trên bản đồ M). Ảnh lục địa 2 điểm ảnh mỗi ô, vẽ bằng tools/gen_world_art.gd.
const WORLD_CELLS: Vector2i = Vector2i(320, 180)
const REGION_OFFSET: Vector2i = Vector2i(80, 70)
const REGION_NAME: String = "Rừng Nguyệt Ảnh"
const CONTINENT_IMAGE: String = "res://assets/maps/continent.png"
const CONTINENT_PIXELS_PER_CELL: int = 2

@onready var ground_layer: TileMapLayer = get_node_or_null("Ground")
@onready var obstacle_layer: TileMapLayer = get_node_or_null("Obstacles")

# Loại nền tại một điểm; lớp vật cản đè lên lớp nền. Ngoài bản đồ trả -1.
func get_ground_at(world_position: Vector2) -> int:
	var cell := Vector2i((world_position / float(TILE_SIZE)).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_CELLS.x or cell.y >= MAP_CELLS.y:
		return -1
	for layer in [obstacle_layer, ground_layer]:
		if not layer:
			continue
		var data := (layer as TileMapLayer).get_cell_tile_data(cell)
		if data:
			return int(data.get_custom_data(GROUND_DATA))
	return -1
