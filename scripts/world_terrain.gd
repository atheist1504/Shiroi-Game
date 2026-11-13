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

enum Ground { GRASS, FOREST, DIRT, STONE, RUST, GOLD, MUD, SAND, RUIN, WATER, CLIFF }

const SOLID_GROUNDS: Array[int] = [Ground.WATER, Ground.CLIFF]

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
