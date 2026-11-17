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
| NPC, thợ, đột kích | NPC FSM + A* (NPC thử nghiệm không còn tự có khi vào game, chỉ tạo khi kiểm thử); thợ gacha làm theo nghề, lính canh đánh quái; đột kích đầu sau 300s, cách 240s, 2–6 quái | `npc_manager.gd`, `worker_manager.gd`, `base_raid_manager.gd` |
| Thời gian | Đồng hồ chỉ chạy khi chơi, tài nguyên ngoài Trại hồi sinh | `world_clock.gd`, `resource_node.gd` |
| Gacha | Ví vàng/Tinh Vẫn, 5★ 2%, bảo hiểm 40, Tinh Hồn, theo seed | `wallet_manager.gd`, `gacha_manager.gd`, `gacha_ui.gd` |
| Tổ đội | 3 người, đổi 1/2/3, 6 phối hợp nguyên tố, gục hồi sau 30s | `party_manager.gd`, `party_ui.gd` |
| Bản đồ | Không có gò đất; nền đá/quặng chỉ ở 3 bãi mỏ; hòn đá nhỏ trên cỏ, đất nhặt được 1 Đá; bụi quả đỏ là thảo dược nhặt được (1 Thảo dược); gốc cây nhặt được 1 Gỗ; cây tán trơn sẫm chặt được 3 Gỗ, tảng đá đập được 3 Đá; cây và vật không che nhau; cầu rộng 3 ô, sông thẳng vuông góc ở chỗ cầu, đường mòn nở rộng tới cầu; hồ tây nam thông ra biển; không còn mảng nền lẻ dưới 30 ô; Trại không có cục đá. Vùng chơi là lục địa phía nam (khung 320×134 ô, gốc (-80, -24), mặt nạ `assets/maps/play_mask.png`), Rừng Nguyệt Ảnh giữ tọa độ cũ; ngoài vùng là mây. Vẽ bằng `tools/gen_world_art.gd` (bước layout/expand/images/paint) và hình AI ghép bằng `tools/ai_art.gd`. Cách sửa ở `docs/BAN_DO.md` | `world_terrain.gd`, `map_zone.gd`, `region_gate.gd`, `scenes/world_map.tscn` |
| Bản đồ nhỏ, bản đồ M | Bản đồ nhỏ tròn góc trên phải, trượt theo người chơi; M mở bản đồ thế giới theo chỗ đã đi, nút ◆ ở Trại để dịch chuyển về; Ctrl + lăn chuột zoom 0,75–1,5. Bản đồ M che kín giao diện chơi, đang mở thì chỉ M/Esc chạy | `minimap.gd`, `camera_zoom.gd` |
| Cốt truyện | Mở đầu, lời kết demo (nháp), 6 nhiệm vụ Hệ thống. Khung truyện đã chốt trong `docs/COT_TRUYEN.md`, `docs/NHIEM_VU.md`; lời thoại trong game chưa đổi theo | `narrative_ui.gd`, `quest_manager.gd` |
| Màn bắt đầu | Chơi mới / Tiếp tục (Slot 1) / Thoát; Chơi mới: đặt tên → mở đầu → đêm đầu | `title_menu.gd` |
| Đêm đầu | Tập lướt/chạy, đánh cọc gỗ (chém 3, E 1, R 1), Enter vào đêm: 3 sói + Sói Đầu Đàn; sáng thì +10 Tinh Vẫn → Người Đến Sau → Dựng nơi trú ngụ → Dựng Căn Cứ | `first_night.gd`, `training_dummy.gd` |
| Tên, bảng nhiệm vụ | Tên lưu trong cờ `player_name`; bảng nhiệm vụ 3 ô Chính / Phụ / Vặt | `narrative_ui.gd`, `quest_journal.gd` |

Dữ liệu tạm: chỉ số, nguyên tố, tên kỹ năng, 5 nhân vật gacha (sprite đổi màu). Nhân vật số 2 là Tiểu Mộng (Dược sư, model cũ). Quặng sắt chưa có công thức dùng.

## Điều khiển

WASD di chuyển; chuột trái chém; chuột phải chạy; Space né; E/R kỹ năng; F tương tác; B túi; J nhiệm vụ; G xây; H gacha; P tổ đội; 1/2/3 đổi người; F3 debug; F5/F9 lưu/tải; F11 hoặc Alt+Enter toàn màn hình; Ctrl + lăn chuột zoom; M bản đồ; Esc tạm dừng.

## Kiểm thử

Chạy: `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1` (lọc bằng `-Filter`; tự sao lưu save).

- 2026-11-17, sau khi sửa `test_step16.gd` (đổi mã nhiệm vụ cũ `q_slime_hunter` sang `main_clear_slimes`, so phiên bản save với `SaveManager.SCHEMA_VERSION`, đặt `current_scene` và chờ một khung hình trước khi lưu) và bỏ dòng bỏ qua file này trong `run_tests.ps1`: **784/784 PASS** ở 23 file, `test_step16.gd` 8/8. Lỗi 6/8 cũ nằm ở test, không phải ở lưu/tải. Chưa thử tay.
- 2026-11-17, sau khi nắn sông ở chỗ cầu, nở đường mòn tới cầu, nối hồ ra biển, gộp mảng nền lẻ, bản đồ M che kín và chặn phím, bỏ NPC thử nghiệm khỏi game, dời bàn chế tạo vào giữa Trại: toàn bộ 22 file PASS. `test_view.gd` thêm 3 mục bản đồ M (nền kín, B không mở túi khi đang xem bản đồ, đối chứng B mở túi khi đã đóng), dời điểm thử bản đồ nhỏ từ (1280, 720) sang (1180, 720) vì giờ sát sông; 4 file test NPC tự gọi `spawn_test_npc()`. Chụp `docs/screenshots/cau_1..4.png`, `kenh_ra_bien.png`, `trai.png`, `ban_do_m.png`. Chưa thử tay.
- 2026-11-17, sau khi bớt cây cột 0 và tảng đá (chặt 3 gỗ, đập 3 đá) và giãn khoảng cách để cây, vật không che nhau: toàn bộ 22 file PASS (`test_map_terrain.gd` 48 mục: thêm cây 3 gỗ, đá 3 đá, tán cây không chồng). Chưa thử tay.
- 2026-11-17, sau khi nới cầu, xóa ô đất lạc giữa nước, bụi xanh nhỏ, tinh thể, đá trên nền mỏ, và cho gốc cây nhặt được gỗ: chạy toàn bộ 22 file đều PASS (`test_map_terrain.gd` 41 mục, có mục đứng hàng dưới cầu cũ vẫn qua sông); sau đó thêm 2 mục gốc cây và chạy riêng: 43/43. Chụp `docs/screenshots/cau.png`, `goc_cay.png`, `mo_sat.png`, `bo_bien_dong.png`. Chưa thử tay.
- 2026-11-17, sau khi thêm bụi thảo dược nhặt được và bỏ đá trong Trại: chạy toàn bộ 22 file đều PASS; sau đó thêm 2 mục thảo dược vào `test_map_terrain.gd` và chạy riêng: 39/39. `test_camp.gd` thử dọn đất bằng cây `hv_tree_02`, `test_step21_3.gd` còn 4 điểm tài nguyên trong Trại, thử giờ hồi đá bằng `zone_rock_01`. Chụp `docs/screenshots/trai.png`, `bui_thao_duoc.png`. Chưa thử tay.
- 2026-11-17, sau khi dọn bản đồ và thêm hòn đá nhặt được: **761/761 PASS** ở 22 file (`test_map_terrain.gd` thêm 2 mục hòn đá, đổi số điểm tài nguyên phía nam 11 → 6); `test_step16.gd` bị bộ chạy bỏ qua vì lỗi thời (chạy riêng thì 6/8, lỗi lưu/tải có sẵn). Chụp màn hình có cửa sổ ở `docs/screenshots/` (thêm `hon_da_nho.png`, `bai_da_cu.png`). Chưa thử tay.
- **Chưa thử tay:** đêm đầu, thợ và đột kích, tổ đội, trọn chuỗi nhiệm vụ, bản đồ mới, trạm khai thác. Gacha đã được người dùng thử.

## Việc còn lại của lớp 1

1. Thử tay trọn game, bắt đầu bằng đêm đầu.
2. Sửa lỗi phát sinh, merge `week5-foundation` vào `main`.
3. Phần đất mới phía nam chưa có tài nguyên, quái, nhiệm vụ; bản đồ nhỏ chưa che theo chỗ đã đi.
4. Xuất bản: đã có `export_presets.cfg`; lần xuất thử 2026-11-10 có một lần tự tắt sau 9 giây, chưa rõ nguyên nhân.

## Nhật ký gần nhất

- 2026-11-17: sửa `test_step16.gd` cho khớp mã nhiệm vụ và phiên bản save hiện tại; bộ chạy test không còn bỏ qua file này.
- 2026-11-17: sông thẳng vuông góc ở chỗ cầu, đường mòn nở rộng tới cầu; hồ tây nam thông ra biển; gộp mảng nền lẻ; bản đồ M che kín giao diện và chặn phím khác; NPC thử nghiệm không còn tự có trong game (save cũ cũng không khôi phục); bàn chế tạo dời từ mép nam Trại (944, 728) vào (1000, 650).
- 2026-11-17: cây tán trơn sẫm bớt còn 47 cây, chặt được 3 Gỗ; tảng đá bớt còn 26, đập được 3 Đá; cây cách nhau 3 ô, vật không nằm dưới tán cây.
- 2026-11-17: cầu rộng 3 ô (đứng hàng dưới cầu cũ bị kẹt); xóa ô đất lạc giữa nước; bỏ bụi xanh nhỏ, tinh thể xanh, tảng đá trên nền mỏ; gốc cây bớt một nửa, gốc còn lại nhặt được 1 Gỗ (25 gốc, `WoodPickups`). Chi tiết `docs/BAN_DO.md`.
- 2026-11-17: bụi tối trên bản đồ thay bằng bụi quả đỏ (ảnh chủ dự án gửi), là thảo dược nhặt được (31 bụi, `HerbPickups`); các điểm thảo dược đặt sẵn cũng dùng hình này; bỏ 2 cục đá trong Trại (`hv_rock_01/02`). `tools/ai_art.gd` bỏ qua điểm ảnh trong suốt của ảnh gốc.
- 2026-11-17: dọn bản đồ theo yêu cầu (chi tiết `docs/BAN_DO.md`, mục "Dọn bản đồ"): bỏ gò đất, cây tán xanh bạc cột 12, bụi hoa 2x2, 5 bãi đá/vàng nhỏ ngoài 3 khu mỏ cùng 7 điểm đá/vàng lạc chỗ; dời `zone_iron_01` vào mỏ sắt; thêm 42 hòn đá nhỏ nhặt được (1 Đá mỗi hòn).
- 2026-11-17: xóa 8 thư mục `backup_*` và các file `.bak` khỏi git (còn trong lịch sử git); thêm `*.bak`, `backup_*/`, `*.log` vào `.gitignore`; rút gọn file này, chuyển nhật ký cũ sang `docs/NHAT_KY_KIEM_THU.md`.
