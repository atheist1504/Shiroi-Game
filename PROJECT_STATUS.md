# Shiroi - The Lost Heir — Trạng thái dự án

## Tổng quan và kiến trúc

- Game 2D top-down viết bằng GDScript; `project.godot` khai báo Godot 4.7 và viewport 640×360, phóng integer scale.
- Scene khởi chạy là `main.tscn`; Player dùng `player.tscn`, enemy slime dùng `slime.tscn`.
- Các Autoload trong `project.godot`: `EventBus`, `WorldState`, `QuestManager`, `SaveManager`, `InventoryManager`, `NotificationManager`, `CraftingManager`, `BaseManager`, `WorldClock`, `WalletManager`, `GachaManager`, `PartyManager`.
- Luồng chính: Player nhận input và combat; các Autoload giữ trạng thái và dịch vụ dùng chung; UI hiển thị inventory, quest, crafting, debug, pause và storage; `SaveManager` phối hợp lưu/khôi phục trạng thái.

## Tiến độ tính năng

| Phần | Trạng thái theo source | Trạng thái kiểm thử |
|---|---|---|
| Gameplay nền, combat, kỹ năng, quest, inventory, crafting, HUD | Đã triển khai; xem các file chính bên dưới | Có test scripts cho các bước 16–19; lần cập nhật tài liệu này không chạy lại gameplay |
| Bước 19 — xây căn cứ và enemy persistence | Có mã Base Building, dữ liệu building và lưu trạng thái enemy trong source | `tests/test_step19.gd` chạy headless 2026-11-09: 58/58 PASS. Log `step19_*.log` cũ không dùng làm bằng chứng. Chưa kiểm thử thủ công |
| Bước 20.1–20.5 — storage | Có dữ liệu kho theo building ID, UI tương tác và API gửi/rút trong `BaseManager`; có test scripts 20.1, 20.2, 20.3, 20.4+5 | Chạy headless 2026-11-09: 20.1 50/50, 20.2 34/34, 20.3 29/29, 20.4+5 63/63 PASS. Chưa kiểm thử thủ công |
| Bước 21.1 + 21.2 — Autonomous NPC AI và Pathfinding | Đã triển khai bản V1 trong `scripts/npc_manager.gd` và `scripts/autonomous_test_npc.gd`; có NPC thử nghiệm, FSM, A* bị giới hạn trong căn cứ, debug F3 và save/load tùy chọn | `tests/test_step21_1_2.gd` chạy headless 2026-11-09: 29/29 PASS. Chưa kiểm thử gameplay thủ công |
| Bước 21.3 — Resource Respawn | Đã triển khai: `WorldClock` (thời gian chỉ trôi khi đang chơi, lưu trong save), ResourceNode hồi sinh (gỗ 60s, đá 90s, thảo dược 45s), mốc hồi lưu trong WorldState, 6 điểm tài nguyên trong Hope Valley BasePlot, không cho xây đè điểm tài nguyên kể cả đã cạn | `tests/test_step21_3.gd` chạy headless 2026-11-09: 28/28 PASS, gồm F9 liên tiếp, save cũ và NPC khai thác lại sau hồi sinh. Chưa kiểm thử gameplay thủ công |
| Tuần 6 — Gacha | Đã triển khai: ví vàng/Tinh Vẫn (`scripts/wallet_manager.gd`), gacha chỉ nhân vật 5★ 2%, bảo hiểm 40, 10 Tinh Vẫn/lượt, Tinh Hồn riêng từng nhân vật và tăng bậc (`scripts/gacha_manager.gd`), UI phím H (`scripts/gacha_ui.gd`), thưởng Tinh Vẫn theo giai đoạn và khi xong quest, nút F3 +100. Kết quả định sẵn theo seed trong save nên F5/F9 không đổi được. 5 nhân vật là dữ liệu tạm; nhân vật chưa làm việc hay ra sân | `tests/test_week6_gacha.gd` chạy headless 2026-11-09: 44/44 PASS, gồm bảo hiểm trên 3000 lượt, túi đầy, F9, save cũ, UI. Đã chụp màn hình kiểm tra bố cục; chưa thử tay |
| Tuần 7 — Tổ đội | Đã triển khai: `scripts/party_manager.gd` (đội 3 người gồm nhân vật chính, một thân Player trên sân, máu/năng lượng/hồi chiêu riêng từng người, hồi đổi 1,5s, 6 phối hợp nguyên tố khi đổi trong 4s sau khi đánh, người gục tự đổi và hồi sau 30s với 30% máu), `scripts/party_ui.gd` (HUD góc trái dưới, bảng phím P), phím 1/2/3, bộ kỹ năng E/R đổi tên, màu, sát thương theo nguyên tố, nút F3 mở khóa 5 nhân vật. Nguyên tố, chỉ số, tên kỹ năng và phối hợp là dữ liệu tạm; nhân vật dùng sprite người chơi đổi màu | `tests/test_week7_party.gd` chạy headless 2026-11-09: 65/65 PASS, gồm save/load, file lỗi, save cũ, xuyên tường, cả đội gục. Toàn bộ test: 431/431 PASS. Đã chụp màn hình bảng tổ đội và HUD ở 640×360; chưa thử tay chiến đấu |
| Tuần 8 — Thế giới và phòng thủ | Đã triển khai: bản đồ 2560×720 với khu rừng, mỏ đá, mỏ sắt, mỏ vàng (`scripts/map_zone.gd`, 26 điểm tài nguyên), quặng sắt và quặng vàng (quặng vàng đổi thẳng thành vàng), `scripts/worker_manager.gd` (nhân vật đã có mà không ở trong đội tự làm theo nghề, giao hàng về kho, lính canh đánh quái), lưới A* toàn bản đồ cho thợ còn NPC dân làng vẫn trong căn cứ, công trình có máu, `scripts/base_raid_manager.gd` (đợt đầu sau 300s kể từ khi có công trình, cách nhau 240s, 2–6 quái, thắng +15 Tinh Vẫn và sửa công trình), nút F3 gọi đợt quái. Quặng sắt chưa có công thức dùng; thông số là tạm | `tests/test_week8_world.gd` chạy headless 2026-11-09: 50/50 PASS, gồm giao hàng thật, đợt quái, save/load giữa đợt, save cũ. Toàn bộ test: 481/481 PASS trước khi chỉnh khoảng cách điểm xuất hiện của thợ. Đã chụp màn hình khu mới và đợt quái; chưa thử tay |
| Bước 21.4 + 21.5 — NPC gathering và giao tài nguyên | Đã thêm FSM làm việc/giao hàng cho NPC thử nghiệm, túi hàng riêng có lưu save, đặt chỗ tài nguyên theo NPC ID, khai thác im lặng, tìm đường tới resource/storage và API nạp toàn bộ cargo nguyên tử. Chỉ có một NPC thử nghiệm được quản lý hiện tại | `tests/test_step21_4_5.gd` chạy headless 2026-11-09: 9/9 PASS sau khi sửa tầm tương tác (NPC bị hủy việc do lệch tâm ô lưới) và điểm đứng quanh footprint kho. Vẫn chỉ có một NPC; tiêu chí nhiều NPC chưa kiểm được. Chưa kiểm thử gameplay thủ công |

## Hệ thống và đường dẫn chính

- Cấu hình, InputMap, Autoload: `project.godot`
- Scene chính và lắp ghép world: `main.tscn`
- Player, movement, combat và input: `scripts/player.gd`, `player.tscn`
- Enemy slime và boss: `scripts/slime.gd`, `slime.tscn`, `scripts/test_boss.gd`, `scenes/test_boss.tscn`
- Save/Load, migration và enemy persistence: `scripts/save_manager.gd`
- Căn cứ, building placement, storage data/UI/API: `scripts/base_manager.gd`, `scripts/base_building.gd`, `scripts/base_plot.gd`, `scripts/building_definition.gd`, `data/buildings/*.tres`
- NPC thử nghiệm, FSM, A* và giao diện debug: `scripts/npc_manager.gd`, `scripts/autonomous_test_npc.gd`, `scenes/autonomous_test_npc.tscn`, `scripts/debug_panel.gd`, `scenes/debug_panel.tscn`
- Inventory và item definitions: `scripts/inventory_manager.gd` (catalog item được tạo trong script), `scripts/inventory_ui.gd`, `scripts/item_definition.gd`
- Crafting: `scripts/crafting_manager.gd`, `scripts/crafting_ui.gd`, `scripts/crafting_station.gd`, `scripts/crafting_recipe.gd` (không thấy thư mục recipe resource trong source hiện tại)
- Quest/world/events/notifications: `scripts/quest_manager.gd`, `scripts/world_state.gd`, `scripts/event_bus.gd`, `scripts/notification_manager.gd`, `scenes/quest_journal.tscn`
- Kỹ năng và hiệu ứng: `scripts/skill_component.gd`, `scripts/wind_blade.gd`, `scripts/cyclone.gd`, `scripts/status_effect_component.gd`
- Test scripts: `tests/test_step17.gd` đến `tests/test_step21_4_5.gd`. Chạy toàn bộ: `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1` (tự sao lưu và khôi phục save). Bản Godot Windows không in ra console nên phải chuyển hướng output. `tests/test_step16.gd` đã lỗi thời, bị bỏ qua (test 17, 18: 11/11 PASS)

## Điều khiển khai báo trong InputMap

- WASD: di chuyển.
- Chuột phải: sprint; chuột trái: tấn công.
- Space: né; E/R: kỹ năng.
- F: tương tác; B: inventory; J: quest journal; G: build mode; H: gacha; P: tổ đội; 1/2/3: đổi người.
- F3: debug; F5: quick save; F9: quick load; Esc: pause/đóng giao diện.

## Lỗi và điểm cần xác minh

- Người dùng từng báo parse error do `_get_storage_transfer_failure_message()` bị khai báo trùng trong `scripts/base_manager.gd`; source hiện tại chỉ thấy một khai báo. Godot 4.7.2 (nay ở `D:\Godot\Godot_v4.7.2-stable_win64.exe`, `tests/run_tests.ps1` ưu tiên đường dẫn này) chạy kiểm tra cú pháp hiện tại không báo lỗi; trạng thái editor đang mở chưa được xác minh bằng thao tác UI.
- Log cũ `step19_*.log` chứa `Lambda capture ... was freed` cùng kết quả đếm PASS/FAIL mâu thuẫn. Không dùng log đó làm bằng chứng test thành công; cần chạy lại test liên quan trong Godot.
- Chưa xác minh giao diện/gameplay bằng kiểm thử thủ công trong lần cập nhật tài liệu này.
- Tỉ lệ gacha (2026-11-09): người dùng thấy 5★ ra nhiều. Mô phỏng headless 120.000 lượt, 400 seed bằng `GachaManager`: tỉ lệ thực 8,6%, 62% lần quay 10 có nhân vật, 20% có từ 2 trở lên, khớp bộ ngẫu nhiên đối chứng nên không phải lỗi RNG. Người dùng chốt lại 2%, bảo hiểm 40; `tests/test_week6_gacha.gd` chạy lại 44/44 PASS với thông số mới. Quest hiện cho tổng 170 Tinh Vẫn, chưa đủ 400 để chạm bảo hiểm; tuần 9 cần cân lại thưởng.

## Nhiệm vụ tiếp theo

Đồ án tốt nghiệp 10 tuần, đề tài nhấn mạnh gacha, khám phá thế giới, căn cứ sinh tồn; 2026-11-09 là tuần 5. Lịch đã duyệt (dự kiến, chưa triển khai từ tuần 9):
- Tuần 9: khám phá, nhiệm vụ Hệ thống, mở đầu xuyên không; dừng tính năng. Tuần 10: sửa lỗi, export, tập demo. Báo cáo viết song song.

Việc còn lại của tuần 5–8:

1. Kiểm thử thủ công trong Godot: thợ theo nghề và đợt quái (F3 mở khóa nhân vật, xây kho, F3 gọi đợt quái), tổ đội (F3 mở khóa, P, 1/2/3, phối hợp khi đánh slime), gacha (H, F3 +100 Tinh Vẫn), NPC khai thác/giao hàng, respawn, F5/F9; NPC đi ngang có thể tạm chặn ô đặt công trình.
2. Viết lại `tests/test_step16.gd` nếu cần cho báo cáo.
3. Kiểm thử thủ công FSM, đặt chỗ tài nguyên, đầy kho, nhiều kho, vật cản động và F5/F9 khi NPC đang mang hàng.
4. Xác minh lỗi parse BaseManager người dùng từng báo trong đúng editor; source có một khai báo `_get_storage_transfer_failure_message()`.

> Phân loại: “Đã triển khai” mô tả những gì source hiện có; “đã kiểm thử” chỉ ghi khi có lần chạy và kết quả đáng tin cậy; “dự kiến” là mục tiêu chưa có implementation xác nhận.

## Ghi chú kiểm tra dung lượng (2026-11-09)
- Ổ C: tổng sử dụng khoảng 218.82 GB, còn trống 12.86 GB tại thời điểm kiểm tra; thư mục dự án Shiroi nằm trên ổ D nên không phải nguồn trực tiếp làm đầy ổ C.
- Không xóa hoặc thay đổi dữ liệu. Chưa xác định được thư mục chiếm nhiều nhất trên C; cần xem Storage trong Windows hoặc dùng công cụ phân tích dung lượng để có số liệu chính xác.
- Kiểm thử: chỉ đọc trạng thái ổ đĩa và danh sách thư mục; không chạy test dự án.
- Việc còn lại: rà soát Storage/temporary files trên C nếu cần tìm chính xác thủ phạm trước khi dọn.


- Kiểm tra tiếp ổ C (2026-11-09): thư mục tạm Windows, tải cập nhật Windows, cache Godot/NVIDIA/DirectX và Thùng rác lần lượt không có lượng đáng kể (dưới 0.01 GB ở mỗi vị trí được đo). Thư mục có dung lượng lớn đã thấy: Riot Games ~47.72 GB, Program Files ~22.99 GB, Program Files (x86) ~8.23 GB, ProgramData ~7.17 GB; trong profile có .gemini ~10.51 GB, .vscode ~3.72 GB, .gradle ~1.60 GB, .cache ~1.58 GB. Chưa phân loại nội dung cụ thể của các thư mục ứng dụng; không xóa gì.
- Quét lại ổ C (2026-11-09, chỉ đọc): còn 5,6 GB trống. Riot Games 47,7 GB, AppData 49,9 GB (`NVIDIA` 4,8 GB và `Temp` 3,7 GB mới ghi trong 7 ngày), Windows 39,4 GB, pagefile 10–14,5 GB. Dữ liệu Claude chỉ khoảng 0,45 GB, không chuyển. Godot đã chuyển sang `D:\Godot`. Theo yêu cầu đã xóa bản Godot cũ, 1,77 GB cache `DXCache` (3 GB còn lại đang bị khóa) và thư mục gói cài Visual Studio `Temp\gkzktrf1` 2,57 GB; ổ C còn 9,96 GB trống.

- Kiểm tra mở rộng ổ C (2026-11-09): dung lượng theo hệ thống hiện khoảng 220.3 GB đã dùng, 11.4 GB còn trống. Quét đệ quy toàn bộ thư mục không hoàn tất trong phiên kiểm tra, nên chưa có bảng phân bổ đầy đủ; các số đo thư mục trước đó chỉ là một phần, không cộng được thành tổng ổ (có thể gồm quyền truy cập bị giới hạn và thư mục hệ thống). Không có thay đổi hoặc xóa dữ liệu.
