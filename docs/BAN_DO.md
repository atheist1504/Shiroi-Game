# Bản đồ và khám phá

Mảng 6.

## Đã chốt

- (2026-11-10) Khu vực đầu tiên của game tên là **Rừng Nguyệt Ảnh**, chính là map đang làm.
- (2026-11-13, thay ngày 2026-11-15 bằng vùng nối ra lục địa) Vùng chơi hình bầu dục bo tròn, không chữ nhật; rừng chỉ dùng cây trăng tán xanh bạc (hợp tên Nguyệt Ảnh), cây khô ở Tàn Tích. Bản đồ nhỏ hình tròn.
- (2026-11-13) Thế giới là một lục địa lớn (núi tuyết phía bắc, sông, hồ, biển bao quanh). Hiện chỉ Rừng Nguyệt Ảnh chơi được; phần còn lại bị **mây đen** che, vừa là ranh giới trong game vừa che trên bản đồ M. Làm vùng mới thì mở mây chỗ đó.
- (2026-11-13, chốt lại) Rừng Nguyệt Ảnh là **rừng**, không xếp ô: bỏ Đầm Lầy, Đồi Cát và bức vách thẳng chia đôi bản đồ. Giữ 3 mỏ (thành bãi đá lộ quặng giữa rừng) và Tàn Tích (phế tích trong vòng vách đá, cổng ở khe phía bắc). Có sông chảy từ bắc xuống, uốn về tây nam đổ vào hồ, 4 cây cầu.
- (2026-11-13) Khu căn cứ tên **Trại** (bỏ tên Thung Lũng Hy Vọng): vòng tròn quanh đống lửa, bán kính 192, rộng thêm 32 mỗi cấp Nhà ở (2026-11-14), tối đa 320. Không xây sát đống lửa (40). Dân làng không còn tự khai thác; trạm khai thác lo việc này (xem `docs/CAN_CU.md`). Mã nội bộ (`hope_valley_*`) giữ nguyên để save cũ vẫn chạy.
- Chủ dự án có thể tự sửa bố cục sau trong editor.
- Hình bản đồ do code tạo (`tools/gen_world_art.gd`), phong cách tham khảo các bộ tile RPG top-down: cây to tán nhiều chùm, bụi, gốc cây, khúc gỗ, đá rêu, gò đất có vách. Không chép hình từ ảnh tham khảo.

## Đã có trong game

- Rừng Nguyệt Ảnh cũ 2560×1440 (160×90 ô) nay là một phần vùng chơi nối ra lục địa (xem dưới), 6 khu (Trại, Khu Rừng, 3 mỏ, Tàn Tích), cổng Tàn Tích mở theo nhiệm vụ. Khu không còn vẽ khung chữ nhật trong game; tên khu chỉ hiện trên bản đồ M.
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

## Vùng chơi nối ra lục địa (2026-11-15)

Chủ dự án vẽ đường ranh phía bắc trên bản đồ M; vùng chơi là phần lục địa phía nam đường đó tới bờ biển, thay cho hình bầu dục. Đã bỏ cột mốc và % khám phá (thử một lượt rồi bỏ).

- Khung bản đồ 320×134 ô, bắt đầu ở ô (-80, -24) (`MAP_ORIGIN`, `MAP_CELLS` trong `scripts/world_terrain.gd`). Rừng Nguyệt Ảnh cũ giữ nguyên tọa độ 0..160 × 0..90 nên Trại, vật thể, nhiệm vụ không phải dời.
- Phần mới lấy địa hình theo độ cao, độ ẩm của ảnh lục địa: biển nông, bãi cát, cỏ, rừng (cùng nhiễu với rừng cũ để chỗ nối liền), đất cao, núi đá chặn đường, sông. Phía bắc đường ranh là mây; phía nam mở hết tới mép khung, cả biển sâu hai góc dưới (2026-11-15, chủ dự án yêu cầu), chỉ 3 ô sát mép khung là mây. Lá súng chỉ rải ở hồ, sông trong Rừng Nguyệt Ảnh. Vòng vách Tàn Tích chỗ trước bị hình bầu dục cắt đã đắp lại. Phần mới chưa có tài nguyên, quái, nhiệm vụ.
- Mép vùng chơi lưu ở `assets/maps/play_mask.png` (khoảng cách tới mép); mây trong game (`fog_border.gd`) và bản đồ M dùng ảnh này.
- Bản đồ M mở theo chỗ đã đi (bán kính 360 quanh người chơi, lưu cờ `map_revealed` trong WorldState). Chỉ có một nút ◆ ở Trại để dịch chuyển về (không dùng trong đêm đầu). Bản đồ nhỏ góc phải chưa che.
- Đá, sắt, vàng khai thác được vẽ thành cụm đá có tinh thể quặng (xám bạc, cam, vàng), hàng 24 cột 10/12/14 của ảnh tile.
- Lưới đường đi của NPC phủ cả bản đồ (khoảng 65 ms khi dựng lại). Bỏ 4 tường biên cũ.

## Hình do AI vẽ (2026-11-15)

Theo quyết định chung ở `docs/KE_HOACH.md` (dùng AI thì ghi rõ): cây, vật thể, quặng, cầu trên bản đồ là **hình do công cụ AI vẽ**, chủ dự án cung cấp, phong cách lấy cây tán xanh bạc làm chính, không chép hình game khác.
- Ảnh gốc: `assets/tiles/source/` (`tileset_ai_ref1.webp` tấm mẫu, `ai_trees`, `ai_shore`, `ai_cliff_bridge`, `ai_resources`, `ai_buildings`). Thư mục có `.gdignore` nên Godot không nhập. Nền ô vuông trong ảnh là vẽ giả, được xóa bằng code.
- `tools/ai_art.gd` cắt từng món theo khung ghi trong file, thu về cỡ ô 16 (cây to 48×48, cụm quặng 32×32) và dán đè lên `terrain_tiles.png` ở bước `-- images`; đồng thời ghi hình công trình vào `assets/art_ai/`. Đổi ảnh gốc thì phải đo lại khung.
- Đã thay: cây to (3 biến thể cây tán xanh bạc ở cột 0, 3, 12 hàng 21, rừng dùng xen kẽ; cây thu, cây hoa hồng), cây 2×2 (thông, cây khô...), bụi hoa, gốc cây, khúc gỗ, cỏ bụi, cụm đá/sắt/vàng, cột đá đổ, tinh thể, cầu gỗ. Điểm tài nguyên cây dùng cây tán xanh bạc, thảo dược dùng bụi quả xanh `assets/art_ai/herb_bush.png`.
- Chưa thay (vẫn vẽ bằng code): ô nền (cỏ, đất, cát, đá...), bờ nước, vách đá, gò đất, đá rêu, nấm. Ảnh mẫu AI có lưới kẻ sẵn, bờ nước và vách vẽ liền thành mảng chứ không phải ô rời theo hướng, nên chưa ghép được; cần AI vẽ lại thành ô 16×16 rời (8 hướng + 4 góc trong).
- (sau, cùng ngày) Hình AI gốc nhiều sắc độ nên trông như ảnh dán lên nền phẳng: `ai_art.gd` `flatten()` gom mỗi hình về 6–10 màu, hạ độ rực, thêm viền tối 1 điểm (công trình 8 màu). Riêng cụm đá xám giữ nguyên (chủ dự án thấy hợp) và thay luôn tảng đá, hòn đá nhỏ cũ. Quặng sắt và vàng cũng dùng cụm đá này, lộ vân gỉ cam / cục vàng trên các mặt sáng (`ore_tint()`), thay hình quặng AI riêng.
- (sau, cùng ngày) Dọn bố cục ở bước `-- expand`: bỏ cát giữa đất liền (chỉ còn cát ven nước), bỏ các dải vách trên đất cao của lục địa, bỏ cát và vách sót dọc mép khung Rừng Nguyệt Ảnh cũ (trừ vòng vách Tàn Tích). Phía đông giờ là bãi đất trống rộng.
- Ảnh chụp để duyệt: `docs/screenshots/` (Trại, rừng, mỏ đá, mỏ sắt, mỏ vàng, phía đông, Tàn Tích, bờ biển).

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
2a. `Godot --headless --path . -s tools/gen_world_art.gd -- expand`: nối bản đồ ra lục địa theo đường ranh `NORTH_EDGE`, ghi lại `play_mask.png`; giữ Rừng Nguyệt Ảnh cũ. Sau đó chạy `--import` rồi bước 3.
2b. (Chỉ khi muốn dựng lại bố cục từ đầu) `Godot --headless --path . -s tools/gen_world_art.gd -- layout`: dựng lại loại nền theo các hằng số đầu phần "bố cục rừng" (sông, cầu, hồ, vòng vách Tàn Tích, bãi đá). Bước này chỉ dựng phần 160×90 cũ, xóa mọi sửa tay ở lớp Ground/Obstacles và báo nếu có vật thể bị nước hay vách đè lên. Sau đó chạy bước 2a rồi bước 3.
3. `Godot --headless --path . -s tools/gen_world_art.gd -- paint`: dựng tileset và tô lại bản đồ. Thêm `regen_highlands` để sinh lại gò đất. Bo hồ và thêm gò chỉ chạy một lần (đánh dấu bằng metadata trên node Terrain), nên chạy lại không làm hồ bị ăn mòn thêm.

Khác:
- Khung bản đồ và vị trí trong lục địa khai báo trong `scripts/world_terrain.gd` (`MAP_ORIGIN`, `MAP_CELLS`, `WORLD_CELLS`, `REGION_OFFSET`); đường ranh phía bắc là `NORTH_EDGE` trong `tools/gen_world_art.gd`. Vật thể nên nằm chỗ `play_shape_value` < 0,85 (cách mép mây hơn khoảng 2 ô).
- Tên khu và viền khu là các node `Environment/Zones/*` trong `main.tscn`.
- `tests/test_map_terrain.gd` kiểm tra Trại, hồ, sông chặn đường và cầu, vòng vách Tàn Tích; đổi bố cục thì có thể phải sửa tọa độ trong đó.

## Còn cần chốt

- Tên và nội dung các vùng ngoài Rừng Nguyệt Ảnh (lore chưa chốt nên trên bản đồ chưa đặt tên).
- Tên các khu trong map, ví dụ "Khu Rừng" hiện tại dễ trùng ý với Rừng Nguyệt Ảnh.
- Bốn khối chướng ngại thử nghiệm cũ (Box1–4) đã xóa khỏi main.tscn.
- Cây hiện đè lên nhân vật khi đi qua (lớp Canopy ở trên); chưa có sắp xếp theo chiều sâu.
