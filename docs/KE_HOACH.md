# Kế hoạch phát triển Shiroi

Trang điều hướng của kế hoạch, **chưa triển khai** trừ khi ghi rõ. Trạng thái thực tế xem ở `PROJECT_STATUS.md`.

## Định hướng

Game offline: khám phá vùng đất sau khi nền văn minh bị xóa sổ, triệu hồi linh hồn và ký ức người xưa để cùng chiến đấu hoặc xây căn cứ sống sót, và dần tìm ra sự thật.

Vòng chơi mong muốn: khám phá và làm nhiệm vụ → tài nguyên, vàng, Tinh Vẫn → triệu hồi, chế tạo, nâng cấp → đội và căn cứ mạnh hơn → đi xa hơn.

## Lộ trình

Xếp theo thứ tự phụ thuộc, lớp sau dựa trên lớp trước.

1. **Nền:** thử tay trọn game, sửa lỗi, merge vào `main`.
2. **Khung cốt truyện:** thảm họa, người tạo Hệ thống, "The Lost Heir", phe phái, kết thúc. Chỉ chốt khung, lời thoại viết sau.
3. **Vòng tiến trình:** cấp độ → vũ khí → cửa hàng → nâng cấp công trình.
4. **Nhân vật:** kỹ năng riêng từng nhân vật gacha, cây kỹ năng nhân vật chính, combo khi đổi người, tên và hồ sơ thật.
5. **Khám phá:** quái và boss theo vùng, nhiệm vụ thế giới cho vũ khí, bản đồ nhỏ, thêm điểm khám phá.
6. **Cộng đồng căn cứ:** dân làng có nghề, lịch trình, nhu cầu; sản xuất, kho vận; tháp canh và rào phòng thủ; thợ rèn và dược sư chế tạo.
7. **Thế giới sống:** thế giới đổi theo thời gian, lựa chọn để lại hậu quả, quan hệ phe phái.
8. **Hoàn thiện:** hình ảnh, âm thanh, cân bằng, người ngoài chơi thử, bản phát hành.

## 12 mảng công việc

Tài liệu của một mảng chỉ được tạo khi bắt đầu làm mảng đó.

| # | Mảng | Tài liệu | Code chính |
|---|---|---|---|
| 1 | Cốt truyện, nhiệm vụ | `docs/COT_TRUYEN.md`, `docs/NHIEM_VU.md` | `narrative_ui.gd`, `quest_manager.gd` |
| 2 | Nhân vật | `docs/NHAN_VAT.md` | `party_manager.gd` |
| 3 | Kỹ năng, chiến đấu | `docs/KY_NANG.md` (chưa tạo) | `skill_component.gd`, `player.gd` |
| 4 | Gacha | `docs/GACHA.md` (chưa tạo) | `gacha_manager.gd`, `gacha_ui.gd` |
| 5 | Quái, boss | `docs/QUAI_BOSS.md` (chưa tạo) | |
| 6 | Bản đồ, khám phá | `docs/BAN_DO.md` | `world_terrain.gd`, `map_zone.gd`, `region_gate.gd` |
| 7 | Tài nguyên, kinh tế | `docs/KINH_TE.md` | `inventory_manager.gd`, `crafting_manager.gd`, `resource_node.gd`, `wallet_manager.gd` |
| 8 | Căn cứ, NPC | `docs/CAN_CU.md` | `base_manager.gd`, `worker_manager.gd`, `npc_manager.gd`, `base_raid_manager.gd` |
| 9 | Mỹ thuật | `docs/MY_THUAT.md` (chưa tạo) | sprite, tileset |
| 10 | Âm thanh | `docs/AM_THANH.md` (chưa tạo) | |
| 11 | Giao diện | `docs/GIAO_DIEN.md` (chưa tạo) | `hud.gd` |
| 12 | Kỹ thuật | `docs/KY_THUAT.md` (chưa tạo) | `save_manager.gd`, `tests/` |

Cách làm:
- Mỗi phiên làm một mảng, chỉ đọc `PROJECT_STATUS.md`, trang này và tài liệu của mảng đó.
- Việc đụng nhiều mảng thì giao một mảng làm chính, ghi chú sang mảng kia.
- Mỗi lúc chỉ một phiên sửa code.
- Xong việc thì ghi tài liệu, commit, rồi mở phiên mới.

## Chức năng phát sinh từ cốt truyện

Mới dự kiến, trừ màn hướng dẫn đêm đầu (đã làm 2026-11-10, xem `docs/NHIEM_VU.md`; tầm nhìn đêm hiện chỉ là lớp tối cố định của đêm đầu, chưa có chu kỳ ngày đêm). Nội dung truyện xem `docs/COT_TRUYEN.md`.

| Chức năng | Mảng chính | Ghi chú sang |
|---|---|---|
| Kỹ năng phụ riêng của mỗi khu vực, dùng nút Q; đầu tiên là Lưu Ảnh (hồi máu) ở Rừng Nguyệt Ảnh | 3 | 6, 11 |
| Đài đá đón trăng ở Rừng Nguyệt Ảnh để nhận Lưu Ảnh | 6 | 1 |
| Điểm manh mối theo vùng: di tích, đồ vật, dân địa phương, bóng người đêm trăng | 6 | 1 |
| Màn hướng dẫn đêm đầu: sói con một đòn là chết để thử kỹ năng, hạ theo số lượng bằng đánh tay/E/R, rồi máu thường với 3 sói và sói đầu đàn làm boss (rớt răng nanh, hướng dẫn F nhặt lần đầu), chuyển cảnh trời sáng, thưởng 10 Tinh Vẫn; slime và Thủ Lĩnh Slime hiện có chuyển sang sau khi trời sáng | 1 | 3, 5, 11 |
| Khu vực bắt đầu có nền nhà, đường đá cũ dưới lớp cỏ, chỉ lộ rõ khi trời sáng | 6 | 9 |
| Cơ chế sáng tối theo thời gian; game bắt đầu vào buổi tối, đêm đầu chỉ thấy khu vực quanh mình, trời sáng tầm nhìn mở rộng | 6 | 1, 9, 12 |
| Bóng người chỉ hiện vào đêm trăng; đêm Kuro trong năm, khi rừng không có bóng (cần chu kỳ ngày đêm) | 6 | 1, 12 |
| Quái canh giữ không rời chỗ ở đài đá | 5 | 6 |
| Ký ức nhân vật gacha chỉ mở khi đưa họ tới đúng vùng liên quan | 2 | 6 |
| Sổ Sự Thật trong bảng nhiệm vụ | 1 | 11 |
| Chốt nhân vật gacha có thân xác, có thể "chết" không | 2 | 3 |

## Quyết định chung

- Hình ảnh thật: chủ dự án tự vẽ hoặc dùng AI; nếu dùng AI thì ghi rõ trong báo cáo.

## Còn cần chốt

- Ngày bảo vệ, yêu cầu của hội đồng, mẫu báo cáo.
- Cốt truyện: xem `docs/COT_TRUYEN.md`.
- Thiết kế chi tiết các lớp 4–8.
