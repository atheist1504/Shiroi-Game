# Kế hoạch phát triển Shiroi

Tài liệu thống nhất kế hoạch, **chưa triển khai** trừ khi ghi rõ. Trạng thái thực tế xem ở `PROJECT_STATUS.md`.

## Định hướng

Game offline: khám phá vùng đất sau khi nền văn minh bị xóa sổ, triệu hồi linh hồn và ký ức người xưa để cùng chiến đấu hoặc xây căn cứ sống sót, và dần tìm ra sự thật.

Vòng chơi mong muốn: khám phá và làm nhiệm vụ → tài nguyên, vàng, Tinh Vẫn → triệu hồi, chế tạo, nâng cấp → đội và căn cứ mạnh hơn → đi xa hơn.

## Lộ trình

Làm lần lượt, không gắn ngày.

1. **Ổn định bản hiện có:** thử tay trọn game, sửa lỗi, merge vào `main`. Xuất `.exe` khi gần xong.
2. **Khép vòng tiến trình:** cấp độ, vũ khí chế tạo, cửa hàng, nâng cấp công trình.
3. **Bản sắc nhân vật:** kỹ năng riêng từng nhân vật gacha, cây kỹ năng nhân vật chính, nhân vật có tên và hồ sơ thật.
4. **Căn cứ sống:** tháp canh và rào phòng thủ thật, dân làng có việc và nhu cầu, thợ rèn và dược sư chế tạo.
5. **Thế giới sâu hơn:** quái và boss theo vùng, nhiệm vụ thế giới cho vũ khí, bản đồ nhỏ, thêm điểm khám phá.
6. **Cốt truyện:** chốt sự thật về thảm họa, phe phái, ý nghĩa "The Lost Heir", kết thúc.
7. **Hình ảnh và âm thanh:** tileset, sprite, giao diện, nhạc và hiệu ứng.
8. **Đóng gói:** cân bằng, người ngoài chơi thử, bản phát hành, tập demo và hoàn tất báo cáo.

## Bước 2: thiết kế

Đã chốt hướng: cấp độ riêng từng nhân vật, mỗi nhân vật một ô vũ khí, vàng dùng cho cửa hàng và nâng cấp công trình. Các con số dưới đây là **đề xuất khởi điểm**, chỉnh sau khi chơi thử.

### Cấp độ

- Cấp tối đa 20; mỗi cấp cần `50 × cấp hiện tại` kinh nghiệm.
- Người trên sân nhận 100%, hai người còn lại trong đội nhận 50%; thợ ở căn cứ không nhận.
- Slime 10, boss 100, nhiệm vụ 50–150.
- Mỗi cấp +5% máu và sát thương, cộng dồn với bậc Tinh Hồn.

### Vũ khí

| Loại | Nguyên liệu | Sát thương |
|---|---|---|
| Kiếm Sắt Thô | 5 quặng sắt, 3 gỗ | +3 |
| Kiếm Sắt Tốt | 12 quặng sắt, 5 ván gỗ | +7 |
| Kiếm Tinh Luyện | 20 quặng sắt, 2 tinh thể Phong | +12 |

Chế tạo ở trạm hiện có, đổi vũ khí trong bảng tổ đội (phím P). Có Thợ rèn đang làm ở căn cứ thì giảm 20% quặng.

### Cửa hàng

Công trình mới ở căn cứ, bán thuốc hồi máu, ván gỗ, đá gia công, giá khoảng 20–40 vàng. Chỉ bán, chưa thu mua.

### Nâng cấp công trình

3 cấp, tốn 100, 250, 500 vàng. Mỗi cấp +30% máu; kho thêm 10 ô.

Thứ tự làm: cấp độ → vũ khí → cửa hàng → nâng cấp.

## Quyết định khác

- Hình ảnh thật: chủ dự án tự vẽ hoặc dùng AI; nếu dùng AI thì ghi rõ trong báo cáo.

## Còn cần chốt

- Ngày bảo vệ, yêu cầu của hội đồng, mẫu báo cáo.
- Cốt truyện: ai xóa sổ nền văn minh, danh tính người tạo Hệ thống, ý nghĩa "The Lost Heir", phe phái, kết thúc.
- Thiết kế chi tiết các bước 3–8.
