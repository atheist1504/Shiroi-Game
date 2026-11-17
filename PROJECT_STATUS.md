# Shiroi - The Lost Heir — Trạng thái dự án

Game 2D top-down, Godot 4.7.2 (`D:\Godot\Godot_v4.7.2-stable_win64.exe`), GDScript. Scene chính `main.tscn`, script trong `scripts/`. Đồ án 10 tuần (2026-11-09 là tuần 5); đề tài nhấn mạnh gacha, khám phá, căn cứ sinh tồn.

- Kế hoạch: `docs/KE_HOACH.md` (8 lớp, 12 mảng). **Đang ở lớp 1** (ổn định bản hiện có).
- Lịch sử kiểm thử và mô tả chi tiết cũ: `docs/NHAT_KY_KIEM_THU.md`. Chỉ đọc khi cần tra.
- Thiết kế từng mảng: xem tài liệu của mảng trong `docs/`.

> "Đã triển khai" là những gì source có; "đã kiểm thử" chỉ ghi khi có lần chạy thật; "dự kiến" là chưa làm.

## Đã triển khai

| Phần | Hiện trạng | File chính |
|---|---|---|
| Nền | Combat, kỹ năng, quest, túi đồ, chế tạo, HUD, lưu/tải | `player.gd`, `skill_component.gd`, `quest_manager.gd`, `inventory_manager.gd`, `crafting_manager.gd`, `save_manager.gd` |
| Trại (căn cứ) | Vòng tròn quanh đống lửa, rộng theo tổng cấp Nhà ở (+32/cấp, tối đa 320); nâng Nhà ở tới cấp 3 bằng nguyên liệu (F); tháp canh bắn quái trong Trại; quái đột kích phá rào chặn đường; tài nguyên còn thì chặn xây, đã khai thác thì xây lên và mất hẳn; tài nguyên trong Trại không hồi sinh. Mã nội bộ `hope_valley_*` giữ để save cũ chạy. Chi tiết `docs/CAN_CU.md` | `base_manager.gd`, `base_building.gd`, `tower_arrow.gd` |
| Trạm khai thác | 5 trạm (Trại gỗ, Mỏ đá/sắt/vàng, Dược viên) tự sinh vào kho trạm, thuê NPC 50 vàng (tối đa 3) chở về Kho chứa; nhân vật gacha đúng nghề làm nhanh hơn | `worker_manager.gd`, `crafting_station.gd` |
| NPC, thợ, đột kích | NPC FSM + A*; thợ gacha làm theo nghề, lính canh đánh quái; đột kích đầu sau 300s, cách 240s, 2–6 quái | `npc_manager.gd`, `worker_manager.gd`, `base_raid_manager.gd` |
| Thời gian | Đồng hồ chỉ chạy khi chơi, tài nguyên ngoài Trại hồi sinh | `world_clock.gd`, `resource_node.gd` |
| Gacha | Ví vàng/Tinh Vẫn, 5★ 2%, bảo hiểm 40, Tinh Hồn, theo seed | `wallet_manager.gd`, `gacha_manager.gd`, `gacha_ui.gd` |
| Tổ đội | 3 người, đổi 1/2/3, 6 phối hợp nguyên tố, gục hồi sau 30s | `party_manager.gd`, `party_ui.gd` |
| Bản đồ | Vùng chơi là lục địa phía nam (khung 320×134 ô, gốc (-80, -24), mặt nạ `assets/maps/play_mask.png`), Rừng Nguyệt Ảnh giữ tọa độ cũ; ngoài vùng là mây. Vẽ bằng `tools/gen_world_art.gd` (bước layout/expand/images/paint) và hình AI ghép bằng `tools/ai_art.gd`. Cách sửa ở `docs/BAN_DO.md` | `world_terrain.gd`, `map_zone.gd`, `region_gate.gd`, `scenes/world_map.tscn` |
| Bản đồ nhỏ, bản đồ M | Bản đồ nhỏ tròn góc trên phải, trượt theo người chơi; M mở bản đồ thế giới theo chỗ đã đi, nút ◆ ở Trại để dịch chuyển về; Ctrl + lăn chuột zoom 0,75–1,5 | `minimap.gd`, `camera_zoom.gd` |
| Cốt truyện | Mở đầu, lời kết demo (nháp), 6 nhiệm vụ Hệ thống. Khung truyện đã chốt trong `docs/COT_TRUYEN.md`, `docs/NHIEM_VU.md`; lời thoại trong game chưa đổi theo | `narrative_ui.gd`, `quest_manager.gd` |
| Màn bắt đầu | Chơi mới / Tiếp tục (Slot 1) / Thoát; Chơi mới: đặt tên → mở đầu → đêm đầu | `title_menu.gd` |
| Đêm đầu | Tập lướt/chạy, đánh cọc gỗ (chém 3, E 1, R 1), Enter vào đêm: 3 sói + Sói Đầu Đàn; sáng thì +10 Tinh Vẫn → Người Đến Sau → Dựng nơi trú ngụ → Dựng Căn Cứ | `first_night.gd`, `training_dummy.gd` |
| Tên, bảng nhiệm vụ | Tên lưu trong cờ `player_name`; bảng nhiệm vụ 3 ô Chính / Phụ / Vặt | `narrative_ui.gd`, `quest_journal.gd` |

Dữ liệu tạm: chỉ số, nguyên tố, tên kỹ năng, 5 nhân vật gacha (sprite đổi màu). Nhân vật số 2 là Tiểu Mộng (Dược sư, model cũ). Quặng sắt chưa có công thức dùng.

## Điều khiển

WASD di chuyển; chuột trái chém; chuột phải chạy; Space né; E/R kỹ năng; F tương tác; B túi; J nhiệm vụ; G xây; H gacha; P tổ đội; 1/2/3 đổi người; F3 debug; F5/F9 lưu/tải; F11 hoặc Alt+Enter toàn màn hình; Ctrl + lăn chuột zoom; M bản đồ; Esc tạm dừng.

## Kiểm thử

Chạy: `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1` (lọc bằng `-Filter`; tự sao lưu save).

- 2026-11-17, sau khi dọn repo: **759/759 PASS** ở 22 file; `test_step16.gd` bị bộ chạy bỏ qua vì lỗi thời (chạy riêng thì 6/8, lỗi lưu/tải có sẵn).
- **Chưa thử tay:** đêm đầu, thợ và đột kích, tổ đội, trọn chuỗi nhiệm vụ, bản đồ mới, trạm khai thác. Gacha đã được người dùng thử.

## Việc còn lại của lớp 1

1. Thử tay trọn game, bắt đầu bằng đêm đầu.
2. Sửa lỗi phát sinh, merge `week5-foundation` vào `main`.
3. Sửa hoặc bỏ `test_step16.gd` (6/8).
4. Phần đất mới phía nam chưa có tài nguyên, quái, nhiệm vụ; bản đồ nhỏ chưa che theo chỗ đã đi.
5. Xuất bản: đã có `export_presets.cfg`; lần xuất thử 2026-11-10 có một lần tự tắt sau 9 giây, chưa rõ nguyên nhân.

## Nhật ký gần nhất

- 2026-11-17: xóa 8 thư mục `backup_*` và các file `.bak` khỏi git (còn trong lịch sử git); thêm `*.bak`, `backup_*/`, `*.log` vào `.gitignore`; rút gọn file này, chuyển nhật ký cũ sang `docs/NHAT_KY_KIEM_THU.md`.
