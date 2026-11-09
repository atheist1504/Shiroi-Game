# Shiroi - The Lost Heir — Trạng thái dự án

Game 2D top-down, Godot 4.7.2 (`D:\Godot\Godot_v4.7.2-stable_win64.exe`), GDScript, viewport 640×360. Scene chính `main.tscn`. Đồ án 10 tuần, 2026-11-09 là tuần 5; đề tài nhấn mạnh gacha, khám phá thế giới, căn cứ sinh tồn.

**Kế hoạch và thiết kế:** `docs/KE_HOACH.md`. Đang ở bước 1 (ổn định bản hiện có).

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
| Bản đồ | Một scene 2560×1440 dựng bằng tile tạm, 8 vùng, cổng Tàn Tích theo nhiệm vụ | `world_terrain.gd`, `map_zone.gd`, `region_gate.gd` |
| Cốt truyện | Mở đầu, lời kết demo (bản nháp), 6 nhiệm vụ Hệ thống | `narrative_ui.gd`, `quest_manager.gd` |
| Sửa lỗi | Chơi lại hồi sinh tại chỗ, không mất căn cứ; F9 sau khi chết về bình thường | `player.gd`, `hud.gd` |

Dữ liệu tạm: chỉ số, nguyên tố, tên kỹ năng, 5 nhân vật gacha (sprite đổi màu), tile bản đồ. Quặng sắt chưa có công thức dùng.

File script nằm trong `scripts/`.

## Điều khiển

WASD di chuyển; chuột trái chém; chuột phải chạy; Space né; E/R kỹ năng; F tương tác; B túi; J nhiệm vụ; G xây; H gacha; P tổ đội; 1/2/3 đổi người; F3 debug; F5/F9 lưu/tải; Esc tạm dừng.

## Kiểm thử

Chạy: `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1` (lọc bằng `-Filter`; tự sao lưu save). Bản Godot Windows không in ra console nên script chuyển hướng output.

- Lần chạy toàn bộ gần nhất 2026-11-10: **568/568 PASS**, headless. `tests/test_step16.gd` lỗi thời nên bị bỏ qua.
- Mô phỏng 75 giây tốc độ x6 với 5 thợ, 2 kho, 1 đợt quái: không lỗi.
- **Chưa thử tay:** thợ và đợt quái, tổ đội, trọn chuỗi nhiệm vụ, bản đồ mới. Gacha đã được người dùng thử.

## Xuất bản

Đã có `export_presets.cfg` và template Windows. Lần xuất thử 2026-11-10 tạo được `.exe` rồi đã xóa; một lần chạy game tự tắt trong 9 giây, lần sau chạy bình thường, chưa rõ nguyên nhân. Cần chạy thử kỹ khi xuất chính thức.

## Việc còn lại của bước 1

1. Thử tay trọn game: F3 mở khóa căn cứ và nhân vật, xây kho, gọi đợt quái, đổi người, F5/F9.
2. Sửa lỗi phát sinh, merge `week5-foundation` vào `main`.
3. Bỏ qua `step19_*.log` (log cũ, không dùng làm bằng chứng).
4. Chưa xác minh trong editor lỗi parse `_get_storage_transfer_failure_message()` từng được báo; source chỉ có một khai báo.
