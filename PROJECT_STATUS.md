# Shiroi - The Lost Heir — Trạng thái dự án

Game 2D top-down, Godot 4.7.2 (`D:\Godot\Godot_v4.7.2-stable_win64.exe`), GDScript, viewport 640×360. Scene chính `main.tscn`. Đồ án 10 tuần, 2026-11-09 là tuần 5; đề tài nhấn mạnh gacha, khám phá thế giới, căn cứ sinh tồn.

**Kế hoạch và thiết kế:** `docs/KE_HOACH.md` là trang điều hướng: lộ trình 8 lớp, không xếp lịch theo hạn, và 12 mảng công việc kèm tài liệu riêng (chia ngày 2026-11-10). Đang ở lớp 1 (ổn định bản hiện có). Lớp 2: đã chốt hướng chính của cốt truyện; trong game mới có lời thoại đoạn đầu, Sổ Sự Thật mới dự kiến. Mảng 1 (2026-11-10): trong `docs/COT_TRUYEN.md` đã chốt thực thể Kuro, người tạo và những người kế thừa Hệ thống, các vùng, dân làng không biết Hệ thống, hướng khép mạch; bỏ thang bí ẩn theo tầng, manh mối tìm khi đi qua khu vực. Chỉ sửa tài liệu nên không chạy kiểm thử. Để sau: tên người tạo, chi tiết vùng, phe phái, chuyện về Việt Nam. Đã duyệt nội dung Rừng Nguyệt Ảnh; chức năng phát sinh (kỹ năng Q theo vùng, manh mối theo vùng...) đã đưa vào `docs/KE_HOACH.md`, mới dự kiến. Đã tạo `docs/NHIEM_VU.md`: ba loại nhiệm vụ, diễn biến đêm đầu và buổi sáng đầu tiên, chuỗi nháp Rừng Nguyệt Ảnh. Lời thoại trong game chưa đổi theo các chốt này.

> "Đã triển khai" là những gì source có; "đã kiểm thử" chỉ ghi khi có lần chạy thật; "dự kiến" là chưa làm.

## Đã triển khai

| Phần | Nội dung | File chính |
|---|---|---|
| Nền | Combat, kỹ năng, quest, túi đồ, chế tạo, HUD, lưu/tải | `player.gd`, `skill_component.gd`, `quest_manager.gd`, `inventory_manager.gd`, `crafting_manager.gd`, `save_manager.gd` |
| Căn cứ | Xây dựng, kho, công trình có máu | `base_manager.gd`, `base_building.gd`, `data/buildings/*.tres` |
| NPC dân làng | Một NPC, FSM, A* trong căn cứ, khai thác, giao kho | `npc_manager.gd`, `autonomous_test_npc.gd` |
| Thời gian | Đồng hồ chỉ chạy khi chơi, tài nguyên hồi sinh | `world_clock.gd`, `resource_node.gd` |
| Gacha | Ví vàng/Tinh Vẫn, 5★ 2%, bảo hiểm 40, Tinh Hồn, kết quả theo seed | `wallet_manager.gd`, `gacha_manager.gd`, `gacha_ui.gd` |
| Tổ đội | 3 người, một thân Player, đổi 1/2/3, 6 phối hợp nguyên tố, người gục hồi sau 30s | `party_manager.gd`, `party_ui.gd` |
| Thợ | Nhân vật không ở trong đội tự làm theo nghề, lính canh đánh quái | `worker_manager.gd` |
| Đột kích | Đợt đầu sau 300s từ khi có công trình, cách nhau 240s, 2–6 quái | `base_raid_manager.gd` |
| Bản đồ | (2026-11-10) Vẽ tay trong editor: `scenes/world_map.tscn` có 3 lớp Ground / Obstacles / Decoration, tileset `assets/tiles/terrain_tileset.tres`; bản đồ cũ được chuyển nguyên sang, cách vẽ ở `docs/BAN_DO.md`. Một scene 2560×1440 dựng bằng tile tạm, 8 vùng, cổng Tàn Tích theo nhiệm vụ; đã đặt tên khu vực đầu là Rừng Nguyệt Ảnh (mới trong tài liệu `docs/BAN_DO.md`) | `world_terrain.gd`, `map_zone.gd`, `region_gate.gd` |
| Cốt truyện | Mở đầu, lời kết demo (bản nháp), 6 nhiệm vụ Hệ thống; lời thoại viết lại 2026-11-10 theo hướng thần bí, chỉ lộ tên Shiroi Arika ở cuối chuỗi | `narrative_ui.gd`, `quest_manager.gd` |
| Màn bắt đầu | (2026-11-13) Mở game hiện menu Chơi mới / Tiếp tục / Thoát, thế giới dừng; Tiếp tục mờ khi chưa có bản lưu, tải Slot 1; chặn phím tắt game khi đang ở menu. Chơi mới: hỏi tên → mở đầu → chặng tập. Mở đầu và đêm đầu không còn tự chạy, do menu gọi | `title_menu.gd`, node TitleMenu trong main.tscn |
| Đêm đầu | Nhiệm vụ đầu "Sống sót đến sáng" (2026-11-10; 2026-11-13 thay sói con bằng cọc gỗ): trời chạng vạng (phủ màu cam nhạt), tập lướt/chạy, rồi đánh cọc gỗ (`training_dummy.gd`, không gãy, không đánh trả): chém trúng 3, E trúng 1, R trúng 1; xong thì bước "Sẵn sàng", vẫn đánh cọc thêm được, nhấn Enter thì trời tối hẳn, dọn cọc, 3 sói và Sói Đầu Đàn xuất hiện trong vùng sáng (cách 90–120px, bán kính sáng 150; trước 170px ngoài tầm nhìn); rớt răng nanh, hướng dẫn F; màn tối độc thoại, trời sáng, +10 Tinh Vẫn, mở "Người Đến Sau". Slime và Thủ Lĩnh Slime chỉ ra sau khi sáng. Sói và cọc không lưu: tải save lúc đang tập thì tập lại từ đầu, đã vào đêm thì về bước Sẵn sàng; save cũ coi như đã qua đêm. Sói là slime đổi màu. Tiếp theo: Người Đến Sau (nay mở khóa căn cứ, không cần F3) → Dựng nơi trú ngụ (9 gỗ, xây Nhà ở; Nhà ở nay chỉ tốn 6 ván gỗ) → Dựng Căn Cứ. Save cũ thiếu nhiệm vụ mới chèn giữa chuỗi thì coi như đã xong | `first_night.gd`, `slime.gd`, `quest_manager.gd`, `narrative_ui.gd` |
| Hướng dẫn đêm đầu | (2026-11-10, sửa theo góp ý) Khung chữ có nền tối, viền, chữ 11/10 (trước 9/8), đặt góc trên phải để không che HUD; tiêu đề ghi "Bước n/7" (lúc tập ghi "Chuẩn bị trước màn đêm"); mỗi bước giải thích phím và chiêu làm gì; đánh cọc sai chiêu thì báo chiêu đúng | `first_night.gd` |
| Góc nhìn | (2026-11-11) Ctrl + lăn chuột zoom camera 0,75–1,5, bước 0,125 (`camera_zoom.gd` gắn vào Camera2D của player.tscn). Bản đồ nhỏ 128×72 (2026-11-13 chuyển sang góc trên phải; khung hướng dẫn đêm đầu và thông báo dời xuống y=88): mỗi ô tile một điểm ảnh, màu lấy từ ảnh tile nên vẽ lại bản đồ thì tự đổi; chấm vàng là người chơi (`minimap.gd`, node Minimap trong main.tscn). (2026-11-13) Phím M mở bản đồ thế giới 576×324 phủ màn hình, dùng chung ảnh với bản đồ nhỏ, ghi tên vùng đã khám phá, vùng chưa tới ghi "???"; mở thì thế giới tạm dừng, M/Esc đóng; đang tạm dừng (menu, túi đồ...) thì M không mở. Giữ góc nhìn top-down, chỉ tham khảo bố cục từ ảnh mẫu. Chưa có điểm đánh dấu nhiệm vụ hay căn cứ | `camera_zoom.gd`, `minimap.gd` |
| Tên nhân vật | (2026-11-10) Game mới hỏi "Tên của bạn là gì?" trước lời mở đầu (Enter hoặc nút Xác nhận, tối đa 16 ký tự, không nhận tên rỗng); tên lưu trong cờ thế giới `player_name` nên đi theo save, hiện ở bảng tổ đội. Save cũ không hỏi lại, dùng tên "Nhân vật chính". Hệ thống gọi tên ở trang cuối mở đầu ("Xác nhận: <tên>.") và trang đầu lời kết; lời thoại dùng `{name}`, giọng kể "bạn/tôi" giữ nguyên | `narrative_ui.gd`, `party_manager.gd` |
| Bảng nhiệm vụ | (2026-11-10) Danh sách chia 3 ô Chính tuyến / Phụ / Vặt; nhiệm vụ Hệ thống xếp vào Chính; ô trống ghi "Chưa có nhiệm vụ"; chưa có nhiệm vụ vặt nào | `quest_journal.gd` |
| Sửa lỗi | Chơi lại hồi sinh tại chỗ, không mất căn cứ; F9 sau khi chết về bình thường | `player.gd`, `hud.gd` |

Dữ liệu tạm: chỉ số, nguyên tố, tên kỹ năng, 5 nhân vật gacha (sprite đổi màu), tile bản đồ. Ngoại lệ (2026-11-10): nhân vật số 2 là **Tiểu Mộng**, Dược sư, dùng model cũ của nhân vật chính (`assets/characters/tieu_mong/`) khi ra sân; nhân vật chính dùng model mới. Game dùng `tieu_mong_walk_sheet_160x170.png`: bản thu nhỏ ×0,72 về khung 160×170, chân căn ở y≈163 như nhân vật chính (tạo bằng script Godot); `tieu_mong_walk_sheet.png` là ảnh gốc 180×256, giữ nguyên. Chưa xem cỡ trong game. Thợ ở căn cứ vẫn vẽ hình tạm. Quặng sắt chưa có công thức dùng.

File script nằm trong `scripts/`.

## Điều khiển

WASD di chuyển; chuột trái chém; chuột phải chạy; Space né; E/R kỹ năng; F tương tác; B túi; J nhiệm vụ; G xây; H gacha; P tổ đội; 1/2/3 đổi người; F3 debug; F5/F9 lưu/tải; F11 hoặc Alt+Enter toàn màn hình (cũng có nút trong menu Esc); Ctrl + lăn chuột phóng to/thu nhỏ (0,75–1,5); M bản đồ thế giới; Esc tạm dừng.

## Kiểm thử

- 2026-11-13, sau khi thêm màn bắt đầu và cọc gỗ: **698/698 PASS** (`test_title_menu.gd` mới 14 mục; `test_first_night.gd` viết lại phần tập, 50 mục: cọc, sai chiêu, Enter vào đêm, bầy sói trong vùng sáng, tải save lúc tập). Lỗi bắt được: cọc thiếu `is_runtime_spawn` làm hỏng tải save. Chụp màn hình có cửa sổ: menu, tập với cọc, vào đêm thấy cả bầy sói. Chưa thử tay bằng chuột/phím thật; màu chạng vạng khá nhạt.

- 2026-11-13, sau khi dời bản đồ nhỏ và thêm bản đồ thế giới phím M: **680/680 PASS** (`test_view.gd` thêm 10 mục: góc trên phải, M mở/tạm dừng, tên vùng và "???", chấm người chơi, Esc/M đóng, không mở khi đang tạm dừng; phím gọi thẳng hàm, không mô phỏng bàn phím thật). Chụp màn hình có cửa sổ: bản đồ nhỏ góc phải, bản đồ thế giới đúng. Thông báo "Khám phá vùng đất" vẫn đè lên khung hướng dẫn đêm đầu (đã đè từ trước); chưa thử tay.

- 2026-11-11, sửa lỗi gõ tên bị phím tắt chen vào (G bật xây dựng vì `base_manager.gd` nhận phím bằng `_input`, chạy trước ô nhập): bỏ qua phím khi đang gõ vào LineEdit/TextEdit. **670/670 PASS** (`test_player_name.gd` thêm 3 mục gõ G, B, J; đã thử gỡ phần sửa thì 2 mục báo lỗi).
- 2026-11-11: **667/667 PASS** (thêm `test_view.gd` 11 mục; `test_first_night.gd` thêm mục răng nanh rơi cạnh sói). Sói "không rớt đồ" là do node gốc Main lại bị kéo lệch (-119, -815) khi lưu trong editor: đồ rơi và sói tạo lúc chạy lệch theo nên ở ngoài màn hình. Đã đưa Main về (0, 0) và khóa node (`_edit_lock_`). Còn hơn chục chỗ tạo vật theo tọa độ toàn cục nên vẫn phụ thuộc Main ở gốc; bài thử đêm đầu bắt lỗi này. Đêm đầu: vùng sáng 150 (trước 110), sói con mới ra sau 1,2 giây (trước 2,5). Chụp màn hình có cửa sổ: bản đồ nhỏ, vùng sáng, thu nhỏ 0,75 đều đúng.
- 2026-11-10, thêm Alt+Enter (laptop có F11 là phím đa phương tiện): chạy có cửa sổ, Alt+Enter đổi 1280×720 → 1920×1080 và về lại; menu Esc vẫn vừa khung. Người dùng báo F11 không chạy khi đã tắt nhúng, chưa rõ nguyên nhân (nghi phím Fn).
- 2026-11-10, đổi `window/stretch/scale_mode` từ integer sang fractional để hình lấp cửa sổ phóng to: chạy cửa sổ 1900×990 thì hệ số 2,75 (trước dừng ở ×2). Chạy nhúng trong editor thì F11 và phóng to không có tác dụng, phải tắt Embed Game.
- 2026-11-10, sau khi thêm toàn màn hình: 655/655 PASS (không có bài thử riêng vì headless không có cửa sổ). Chạy có cửa sổ: F11 đổi 1280×720 → 1920×1080 và về lại, nút menu đổi chữ theo; chụp menu Esc thấy nút mới.
- 2026-11-10, sửa lỗi "không thấy sói": node gốc `Main` trong `main.tscn` bị kéo lệch (-1220, -326) khi lưu từ editor, sói tạo lúc chạy lệch theo nên nằm ngoài màn hình; đưa về (0, 0). **655/655 PASS** (`test_first_night.gd` thêm 2 mục: scene ở gốc, sói con trong vùng sáng). Chụp màn hình thấy sói con trong vùng sáng.
- 2026-11-10, sau khi sửa hướng dẫn đêm đầu: **653/653 PASS** (`test_first_night.gd` 43 mục). Chụp màn hình khi chạy có cửa sổ: màn đặt tên, bước 1 và bước 2 (có dòng báo hạ sai cách), chữ đọc rõ, không che thanh máu. Chưa thử tay độ khó bầy sói.
Chạy: `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1` (lọc bằng `-Filter`; tự sao lưu save). Bản Godot Windows không in ra console nên script chuyển hướng output.

- 2026-11-10, sau khi cho Hệ thống gọi tên: **651/651 PASS** (`test_week9_story.gd` thêm 1 mục).
- 2026-11-10, sau khi thêm đặt tên nhân vật: **650/650 PASS** (thêm `test_player_name.gd` 15 mục, `test_week9_story.gd` thêm 1 mục đặt tên; chạy toàn bộ thì 2 mục ở week9 hỏng do bài thử chưa đặt tên, sửa bài thử rồi chạy lại riêng file đó qua hết). Chưa xem ô nhập tên trên màn hình, chưa thử gõ tiếng Việt có dấu.
- 2026-11-10, sau khi chuyển bản đồ sang vẽ tay: **634/634 PASS** (`test_map_terrain.gd` thay mục "dựng lại bằng code" bằng 5 mục kiểm tra scene và tileset); chụp màn hình khi chạy có cửa sổ, bản đồ trông như cũ. Chưa mở thử trong editor.
- 2026-11-10, sau khi chia bảng nhiệm vụ 3 ô: 630/630 PASS (thêm `test_quest_journal.gd` 8 mục); đã chụp màn hình bảng khi chạy có cửa sổ.
- 2026-11-10, sau khi chỉnh cỡ Tiểu Mộng: 622/622 PASS.
- 2026-11-10, sau khi gán Tiểu Mộng: 622/622 PASS (thêm 2 mục ở `test_week7_party.gd`; đã chạy `--import` để Godot nhập ảnh mới).
- 2026-11-10, sau khi thêm nhiệm vụ nơi trú ngụ: chạy toàn bộ thì 16 file khác qua hết (579 mục), `test_first_night.gd` lỗi chờ khung hình trong bài thử; đã sửa bài thử và chạy riêng 3 lần đều 41/41. Tổng 620 mục. Lần trước: **611/611 PASS**, headless (`test_first_night.gd` 41 mục; đòn đánh gọi theo thứ tự trong game, không mô phỏng chuột/phím). `tests/test_step16.gd` lỗi thời nên bị bỏ qua. `test_week9_story.gd` bỏ qua đêm đầu bằng `skip_night()`. Chạy game có cửa sổ 300 khung hình: không lỗi.
- Mô phỏng 75 giây tốc độ x6 với 5 thợ, 2 kho, 1 đợt quái: không lỗi.
- **Chưa thử tay:** đêm đầu (độ khó bầy sói, độ rộng vùng sáng, chữ hướng dẫn), thợ và đợt quái, tổ đội, trọn chuỗi nhiệm vụ, bản đồ mới. Gacha đã được người dùng thử.

## Xuất bản

Đã có `export_presets.cfg` và template Windows. Lần xuất thử 2026-11-10 tạo được `.exe` rồi đã xóa; một lần chạy game tự tắt trong 9 giây, lần sau chạy bình thường, chưa rõ nguyên nhân. Cần chạy thử kỹ khi xuất chính thức.

## Việc còn lại của lớp 1

1. Thử tay trọn game, bắt đầu bằng đêm đầu (game mới phải chơi qua đêm, F3 chưa có nút bỏ qua): F3 mở khóa căn cứ và nhân vật, xây kho, gọi đợt quái, đổi người, F5/F9.
2. Sửa lỗi phát sinh, merge `week5-foundation` vào `main`.
3. Bỏ qua `step19_*.log` (log cũ, không dùng làm bằng chứng).
4. Chưa xác minh trong editor lỗi parse `_get_storage_transfer_failure_message()` từng được báo; source chỉ có một khai báo.
