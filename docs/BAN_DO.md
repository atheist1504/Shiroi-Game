# Bản đồ và khám phá

Mảng 6.

## Đã chốt (2026-11-10)

- Khu vực đầu tiên của game tên là **Rừng Nguyệt Ảnh**, chính là map đang làm.
- Bố cục các khu trong map: chủ dự án sẽ tự vẽ sau.

## Đã có trong game

Một scene 2560×1440 dựng bằng tile tạm, 8 vùng, cổng Tàn Tích mở theo nhiệm vụ. Tên Rừng Nguyệt Ảnh chưa xuất hiện trong game.

Từ 2026-11-10 bản đồ **vẽ tay trong editor**, không còn do code tự tô. Bản đồ cũ đã được chuyển nguyên sang dạng này.

## Cách vẽ bản đồ

1. Mở `scenes/world_map.tscn` trong Godot.
2. Chọn một lớp ở cây Scene, mở bảng **TileMap** ở dưới, chọn tile rồi vẽ:
   - **Ground**: nền, không chặn.
   - **Obstacles**: nước, vách đá; tile ở đây chặn người chơi, quái và đường đi của dân làng.
   - **Decoration**: trang trí đè lên trên, không chặn.
3. Lưu scene (Ctrl+S). Game nạp scene này qua node `Environment/Terrain` của `main.tscn`.

Tileset: `assets/tiles/terrain_tileset.tres`, ảnh tạm `assets/tiles/terrain_placeholder.png` (16×16, cột là loại nền, hàng là 3 biến thể).

- **Thay bằng hình thật**: thêm ảnh tileset mới vào tileset (Add atlas source), giữ ô 16×16.
- Mỗi tile cần **custom data "ground"** đúng loại nền (0 cỏ, 1 rừng, 2 đất, 3 đá, 4 gỉ sắt, 5 vàng, 6 bùn, 7 cát, 8 tàn tích, 9 nước, 10 vách đá) để code biết nền đó là gì.
- Tile chặn đường: vẽ hình va chạm ở mục **Physics** của tile và đặt tile vào lớp Obstacles.
- Kích thước bản đồ đang là 160×90 ô, khai báo trong `scripts/world_terrain.gd` (`MAP_CELLS`); vẽ ra ngoài thì code coi là ngoài bản đồ.
- Tên vùng và viền vùng không nằm trong bản đồ tile: chúng là các node `Environment/Zones/*` trong `main.tscn`.
- Bài thử `tests/test_map_terrain.gd` kiểm tra vị trí đất căn cứ, nước, lối mở qua vách đá; vẽ lại bố cục thì có thể phải sửa các tọa độ trong đó.

## Còn cần chốt

- Bố cục khu vực do chủ dự án vẽ, và phần nào của 8 vùng hiện tại được giữ lại.
- Tên các khu trong map, ví dụ "Khu Rừng" hiện tại dễ trùng ý với Rừng Nguyệt Ảnh.
