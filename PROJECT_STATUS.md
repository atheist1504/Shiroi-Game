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
| Bản đồ | Một scene 2560×1440 dựng bằng tile tạm, 8 vùng, cổng Tàn Tích theo nhiệm vụ; đã đặt tên khu vực đầu là Rừng Nguyệt Ảnh (mới trong tài liệu `docs/BAN_DO.md`) | `world_terrain.gd`, `map_zone.gd`, `region_gate.gd` |
| Cốt truyện | Mở đầu, lời kết demo (bản nháp), 6 nhiệm vụ Hệ thống; lời thoại viết lại 2026-11-10 theo hướng thần bí, chỉ lộ tên Shiroi Arika ở cuối chuỗi | `narrative_ui.gd`, `quest_manager.gd` |
| Đêm đầu | Nhiệm vụ đầu "Sống sót đến sáng" (2026-11-10): đêm tối chỉ sáng quanh nhân vật; sói con một đòn chết để tập lướt/chạy, chém 1, E 2, R 3; rồi 3 sói và Sói Đầu Đàn, rớt răng nanh, hướng dẫn F; màn tối độc thoại, trời sáng, +10 Tinh Vẫn, mở "Người Đến Sau". Slime và Thủ Lĩnh Slime chỉ ra sau khi sáng. Sói không lưu: tải save giữa đêm thì làm lại đêm; save cũ coi như đã qua đêm. Sói là slime đổi màu. Tiếp theo: Người Đến Sau (nay mở khóa căn cứ, không cần F3) → Dựng nơi trú ngụ (9 gỗ, xây Nhà ở; Nhà ở nay chỉ tốn 6 ván gỗ) → Dựng Căn Cứ. Save cũ thiếu nhiệm vụ mới chèn giữa chuỗi thì coi như đã xong | `first_night.gd`, `slime.gd`, `quest_manager.gd`, `narrative_ui.gd` |
| Sửa lỗi | Chơi lại hồi sinh tại chỗ, không mất căn cứ; F9 sau khi chết về bình thường | `player.gd`, `hud.gd` |

Dữ liệu tạm: chỉ số, nguyên tố, tên kỹ năng, 5 nhân vật gacha (sprite đổi màu), tile bản đồ. Quặng sắt chưa có công thức dùng.

File script nằm trong `scripts/`.

## Điều khiển

WASD di chuyển; chuột trái chém; chuột phải chạy; Space né; E/R kỹ năng; F tương tác; B túi; J nhiệm vụ; G xây; H gacha; P tổ đội; 1/2/3 đổi người; F3 debug; F5/F9 lưu/tải; Esc tạm dừng.

## Kiểm thử

Chạy: `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1` (lọc bằng `-Filter`; tự sao lưu save). Bản Godot Windows không in ra console nên script chuyển hướng output.

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
