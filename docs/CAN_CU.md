# Căn cứ và NPC

Mảng 8. Phần "Nâng cấp công trình" (nâng bằng vàng) chưa triển khai. Các con số là đề xuất khởi điểm, chỉnh sau khi chơi thử.

## Nâng cấp công trình

3 cấp, tốn 100, 250, 500 vàng. Mỗi cấp +30% máu; kho thêm 10 ô.

## Đột kích

Đã chốt: căn cứ càng phát triển càng thu hút sự chú ý, áp lực đột kích tăng dần. Hiện `base_raid_manager.gd` vẫn chạy theo nhịp cố định.

## Đã làm (2026-11-14)

- Trại rộng theo tổng cấp Nhà ở (+32 mỗi cấp, tối đa 320); bấm F cạnh nhà để nâng, tối đa cấp 3.
- Tháp canh bắn quái đã vào vòng Trại; quái đột kích phải phá hàng rào khi bị chặn.
- Dọn đất: tài nguyên trong Trại khai thác xong là hết, không hồi sinh; xây lên chỗ đã khai thác thì chỗ đó mất hẳn.

## Trạm khai thác (đã làm 2026-11-14, chưa thử tay)

Chủ dự án chốt: trạm đặt ở đâu cũng được; trạm tự sinh, NPC làm tăng tốc và chở hàng; thuê NPC 50 vàng, tối đa 3 mỗi trạm; trạm tốn 4 ván gỗ + 2 đá chế biến như Kho chứa; kho trạm chứa 30; nhân vật gacha có nghề làm nhanh hơn và có xuất đặc biệt.

Cách hoạt động (`base_building.gd`, `base_manager.gd`, `worker_manager.gd`):
- 5 trạm trong menu xây (G): Trại gỗ (gỗ), Mỏ đá (đá), Mỏ sắt (quặng sắt), Mỏ vàng (quặng vàng), Dược viên (thảo dược).
- Chế độ xây mở được ở mọi nơi. Công trình thường vẫn phải nằm trong vòng Trại. Trạm phải nằm gọn trong khu của nó và khu đã được khám phá; Dược viên đặt đâu cũng được (chưa có khu dược liệu).
- Tốc độ sinh: (1 + số NPC thuê + 2 × số nhân vật gacha đúng nghề đang làm) đơn vị mỗi 30 giây.
- Đứng cạnh trạm: hiện tình trạng kho và "[F] Khai thác lâu dài: thuê NPC (50 vàng)".
- Kho trạm đầy: có người làm thì chở về Kho chứa ở Trại sau 20 giây (quặng vàng đổi thẳng ra vàng); không có người làm thì đứng chờ. Kho Trại đầy hoặc chưa có thì 10 giây thử lại.
- Nhân vật gacha không ở trong đội tự tới trạm hợp nghề (Tiều phu → Trại gỗ, Thợ mỏ → Mỏ đá/Mỏ vàng, Thợ rèn → Mỏ sắt, Dược sư → Dược viên). Cứ 5 đơn vị có thêm 1 món đặc biệt: ván gỗ, đá chế biến, bộ dụng cụ xây dựng, quặng vàng, bình máu nhỏ.
- NPC dân làng và nhân vật gacha không còn tự đi khai thác điểm tài nguyên.
- Save lưu kho trạm, số NPC, thời gian chở còn lại.

Chưa làm: NPC thuê chưa có thân đi lại thật (chỉ vẽ chấm xanh dưới trạm, việc chở hàng tính bằng thời gian); số liệu chưa cân bằng.

## Hình công trình do AI vẽ (2026-11-15)

Công trình, bàn chế tạo và đống lửa Trại dùng **hình do công cụ AI vẽ** (theo quyết định chung ở `docs/KE_HOACH.md`), cắt từ `assets/tiles/source/ai_buildings.webp` bằng `tools/ai_art.gd`, lưu ở `assets/art_ai/`. Hình đặt sát đáy ô nền, mái nhô lên trên; va chạm và ô nền không đổi.
- Nhà ở cấp 1–3: lều tranh, nhà gỗ, nhà đá (`house_1..3.png`), thay cho chấm vàng báo cấp.
- Tháp canh; Kho chứa tạm dùng lán gỗ; Trại gỗ = lán gỗ + khúc gỗ; hàng rào.
- Mỏ vàng = cửa hầm có quặng vàng; Mỏ đá và Mỏ sắt dùng cùng cửa hầm, quặng nhuộm xám / cam (chưa có hình cửa hầm thường riêng); Dược viên = chậu thảo dược.
- Bàn chế tạo (`crafting_station.gd`) = bàn rèn; đống lửa Trại (`base_plot.gd`) = đống lửa AI, quầng sáng lập lòe vẽ thêm bằng code.
- Loại công trình chưa có hình thì vẫn vẽ khối màu như cũ.
