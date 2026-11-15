# Bản đồ và khám phá

Mảng 6.

## Đã chốt

- (2026-11-10) Khu vực đầu tiên của game tên là **Rừng Nguyệt Ảnh**, chính là map đang làm.
- (2026-11-13) Vùng chơi hình bầu dục bo tròn, không chữ nhật; rừng chỉ dùng cây trăng tán xanh bạc (hợp tên Nguyệt Ảnh), cây khô ở Tàn Tích. Bản đồ nhỏ hình tròn.
- (2026-11-13) Thế giới là một lục địa lớn (núi tuyết phía bắc, sông, hồ, biển bao quanh). Hiện chỉ Rừng Nguyệt Ảnh chơi được; phần còn lại bị **mây đen** che, vừa là ranh giới trong game vừa che trên bản đồ M. Làm vùng mới thì mở mây chỗ đó.
- (2026-11-13, chốt lại) Rừng Nguyệt Ảnh là **rừng**, không xếp ô: bỏ Đầm Lầy, Đồi Cát và bức vách thẳng chia đôi bản đồ. Giữ 3 mỏ (thành bãi đá lộ quặng giữa rừng) và Tàn Tích (phế tích trong vòng vách đá, cổng ở khe phía bắc). Có sông chảy từ bắc xuống, uốn về tây nam đổ vào hồ, 4 cây cầu.
- (2026-11-13) Khu căn cứ tên **Trại** (bỏ tên Thung Lũng Hy Vọng): vòng tròn quanh đống lửa, bán kính 192, rộng thêm 32 mỗi cấp Nhà ở (2026-11-14), tối đa 320. Không xây sát đống lửa (40). Dân làng không còn tự khai thác; trạm khai thác lo việc này (xem `docs/CAN_CU.md`). Mã nội bộ (`hope_valley_*`) giữ nguyên để save cũ vẫn chạy.
- Chủ dự án có thể tự sửa bố cục sau trong editor.
- Hình bản đồ do code tạo (`tools/gen_world_art.gd`), phong cách tham khảo các bộ tile RPG top-down: cây to tán nhiều chùm, bụi, gốc cây, khúc gỗ, đá rêu, gò đất có vách. Không chép hình từ ảnh tham khảo.

## Đã có trong game

- Vùng chơi 2560×1440 (160×90 ô), 6 khu (Trại, Khu Rừng, 3 mỏ, Tàn Tích), cổng Tàn Tích mở theo nhiệm vụ. Khu không còn vẽ khung chữ nhật trong game; tên khu chỉ hiện trên bản đồ M.
- Các lớp trong `scenes/world_map.tscn` (từ dưới lên):
  - **Ground**: nền theo loại.
  - **Blend**: viền cỏ lấn sang nền khác, đường mòn, mảng cỏ cao, đất trống, đồng hoa.
  - **Obstacles**: nước có bờ và bọt, vách đá, gò đất cao; các tile này chặn đường.
  - **Decoration**: hoa, đá, nấm, sậy, súng, tảng đá, bụi, gốc cây, khúc gỗ.
  - **Canopy**: cây, vẽ đè lên nhân vật.
  - **FogBorder**: mây đen bằng shader quanh vùng chơi.
- Nền đổi sắc theo từng mảng lớn nhờ shader trên lớp Ground và Blend, nên không còn những mảng một màu.
- Bản đồ nhỏ (góc trên phải) hiện vùng quanh người chơi. Bản đồ M hiện cả lục địa (`assets/maps/continent.png`), Rừng Nguyệt Ảnh sáng rõ có tên, phần còn lại dưới mây.
- Tường biên và bốn khối chướng ngại cũ không còn hiện khối màu; va chạm vẫn giữ. Bốn khối cũ được vẽ thành gò đất.

## Cột mốc và % khám phá (2026-11-15)

Chủ dự án chọn làm theo hướng game thế giới mở: cột mốc mở bản đồ và dịch chuyển nhanh, % khám phá theo khu. Chỉ lấy cách thiết kế, không chép tên hay hình của game khác.

- **Cột mốc** (`scenes/beacon.tscn`, `scripts/beacon.gd`): 7 cột trong `main.tscn` dưới node `Beacons` (Khu Rừng, Mỏ Đá, Mỏ Sắt, Mỏ Vàng, Tàn Tích, phía tây, phía nam). Đứng gần bấm F để kích hoạt; lưu cờ `beacon_<beacon_id>` trong WorldState. Thêm cột: nhân bản node, đổi `beacon_id` cho khác.
- **Bản đồ M**: phần vùng chơi xa hơn 420 đơn vị so với mọi cột mốc đã kích hoạt bị phủ tối. Đống lửa Trại luôn mở. Cột mốc đã kích hoạt là nút ◆ xanh, bấm để dịch chuyển; chưa kích hoạt là ◆ xám (chỉ hiện khi chỗ đó đã mở). Không dịch chuyển trong đêm đầu.
- **% khám phá** (`scripts/exploration.gd`): mỗi khu đếm đã đặt chân tới khu, cột mốc đã kích hoạt, điểm tài nguyên người chơi tự tay thu thập ít nhất một lần (cờ `touched_<node_id>`), điểm khám phá. Tên khu và tên vùng trên bản đồ M kèm %.
- Không xây đè lên cột mốc.

Chưa làm: thưởng theo mốc %; rương, quái tinh anh, câu đố để có thêm thứ tính %; bản đồ nhỏ góc phải vẫn hiện hết địa hình (chưa che theo cột mốc); hình cột mốc vẽ bằng code.

## Sửa bản đồ

**Cách 1, vẽ tay trong editor:** mở `scenes/world_map.tscn`, chọn lớp, mở bảng **TileMap** rồi vẽ, xong lưu (Ctrl+S).
- Tile chặn đường đặt ở lớp Obstacles.
- Mỗi tile nền có **custom data "ground"** (0 cỏ, 1 rừng, 2 đất, 3 đá, 4 gỉ sắt, 5 vàng, 6 bùn, 7 cát, 8 tàn tích, 9 nước, 10 vách đá).
- Tile trong Ground: hàng = loại nền, cột 0–7 = biến thể.

**Cách 2, đổi loại nền rồi cho code tô lại:** sửa loại nền ở lớp Ground/Obstacles, rồi chạy bước 3 dưới đây. Code tự chọn biến thể, bờ nước, viền cỏ, đường mòn, cây và vật thể. Lưu ý: chạy bước 3 sẽ xóa những gì vẽ tay ở lớp Blend, Decoration và Canopy.

**Thay hình:** sửa thẳng `assets/tiles/terrain_tiles.png` bằng phần mềm vẽ, hoặc thay ảnh khác **cùng bố cục**; bản đồ đổi theo ngay. Bố cục từng hàng ghi ở đầu `tools/gen_world_art.gd`. Muốn thêm bộ tile mua hoặc tải về thì thêm atlas source mới vào `terrain_tileset.tres`, giữ ô 16×16 và đặt custom data "ground".

**Chạy lại code sinh hình** (từ thư mục dự án, dùng Godot ở ổ D):
1. `Godot --headless --path . -s tools/gen_world_art.gd -- images`: vẽ lại ảnh tile và ảnh lục địa.
2. `Godot --headless --path . --import`: Godot nhập ảnh mới.
2b. (Chỉ khi muốn dựng lại bố cục từ đầu) `Godot --headless --path . -s tools/gen_world_art.gd -- layout`: dựng lại loại nền theo các hằng số đầu phần "bố cục rừng" (sông, cầu, hồ, vòng vách Tàn Tích, bãi đá). Bước này xóa mọi sửa tay ở lớp Ground/Obstacles và báo nếu có vật thể bị nước hay vách đè lên. Sau đó chạy bước 3.
3. `Godot --headless --path . -s tools/gen_world_art.gd -- paint`: dựng tileset và tô lại bản đồ. Thêm `regen_highlands` để sinh lại gò đất. Bo hồ và thêm gò chỉ chạy một lần (đánh dấu bằng metadata trên node Terrain), nên chạy lại không làm hồ bị ăn mòn thêm.

Khác:
- Kích thước vùng chơi, hình bầu dục và vị trí trong lục địa khai báo trong `scripts/world_terrain.gd` (`MAP_CELLS`, `PLAY_RADIUS_CELLS`, `WORLD_CELLS`, `REGION_OFFSET`); `tools/gen_world_art.gd` có bản sao `PLAY_RADIUS_PX`, đổi thì đổi cả hai. Vật thể nên nằm trong vùng có `play_shape_value` < 0,85 để không bị mây che.
- Tên khu và viền khu là các node `Environment/Zones/*` trong `main.tscn`.
- `tests/test_map_terrain.gd` kiểm tra Trại, hồ, sông chặn đường và cầu, vòng vách Tàn Tích; đổi bố cục thì có thể phải sửa tọa độ trong đó.

## Còn cần chốt

- Tên và nội dung các vùng ngoài Rừng Nguyệt Ảnh (lore chưa chốt nên trên bản đồ chưa đặt tên).
- Tên các khu trong map, ví dụ "Khu Rừng" hiện tại dễ trùng ý với Rừng Nguyệt Ảnh.
- Bốn khối chướng ngại thử nghiệm cũ (Box1–4) đã xóa khỏi main.tscn.
- Cây hiện đè lên nhân vật khi đi qua (lớp Canopy ở trên); chưa có sắp xếp theo chiều sâu.
