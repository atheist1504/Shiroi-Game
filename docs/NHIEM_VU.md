# Nhiệm vụ

Mảng 1. Nội dung truyện xem `docs/COT_TRUYEN.md`. Những gì ở đây chưa làm trong game, trừ khi ghi rõ.

## Phân loại (đã chốt 2026-11-10)

| Loại | Nội dung |
|---|---|
| Chính tuyến | Tìm hiểu khu vực đang ở, dần hướng tới chân tướng thế giới |
| Phụ | Chuyện riêng của từng vùng đất |
| Vặt | Việc lặt vặt như chặt củi, giúp dân làng |

Bảng nhiệm vụ (J) hiện ba ô theo đúng ba loại này (đã làm 2026-11-10). Trong code: `quest_type` "main"/"system" vào Chính tuyến, "side" vào Phụ, "chore" vào Vặt.

## Quy tắc

- Nhiệm vụ mới phải thảo luận với chủ dự án trước khi thêm.
- Nhiệm vụ đã có thì không thêm trùng.

## Đã có trong game

6 nhiệm vụ Hệ thống, chưa phân loại và chưa đối chiếu với các nhiệm vụ dưới đây.

## Rừng Nguyệt Ảnh

### Chính tuyến (bản nháp, chờ duyệt)

Chưa đối chiếu với 6 nhiệm vụ đang có trong game. Hệ thống chỉ thông báo, không giải thích. Dân làng không thấy Hệ thống.

Mở đầu (đã chốt): **Sống sót đến sáng.** Nhiệm vụ đầu tiên, chỉ một dòng hiện giữa đêm tối.

Diễn biến đêm đầu (đã chốt). **Đã làm 2026-11-10** trong `scripts/first_night.gd`, nhiệm vụ `sys_00_first_night`, trừ nền nhà và đường đá dưới cỏ (mảng 6). Sói đang dùng hình slime đổi màu. "Dựng nơi trú ngụ" đã thêm (`sys_01b_shelter`): lấy 9 gỗ, xây Nhà ở (giá đổi thành 6 ván gỗ, bỏ đá). Thứ tự hiện tại: đêm đầu → Người Đến Sau (tới Thung Lũng, mở căn cứ) → Dựng nơi trú ngụ → Dựng Căn Cứ (kho), vì muốn xây phải đứng trong căn cứ.

- Một con sói con xuất hiện để người chơi thử di chuyển: Space lướt, chuột phải chạy.
- Để thử kỹ năng, sói con một đòn là chết. Người chơi lần lượt được hướng dẫn: đánh tay hạ 1 con, E (đâm xuyên theo đường thẳng) hạ 2 con, R (gom quái lại) hạ 3 con.
- Thử chiêu xong, máu quái dày lên như bình thường: 3 sói thường và sói đầu đàn (boss) kéo đến. Sói rớt răng nanh; lần đầu có đồ rơi, người chơi được hướng dẫn nhấn F để nhặt.
- Hạ xong, màn hình tắt tối và nhân vật chính độc thoại: "Cứ thế, đêm đầu tiên đã qua, và tôi vẫn còn sống."
- Suốt đêm người chơi chỉ thấy khu vực quanh mình; trời sáng tầm nhìn mới mở rộng ra xa.
- Cảnh sau trời sáng, Hệ thống hiện: "Hoàn thành nhiệm vụ. Nhận 10 Tinh Vẫn." Không một lời giải thích.
- Tầm nhìn mở ra, lộ những nền nhà và con đường đá dưới lớp cỏ: đêm qua người chơi đã chiến đấu giữa một thị trấn cũ.
- Slime và Thủ Lĩnh Slime đã có trong game chuyển sang xuất hiện sau khi trời sáng.
- Hệ thống giao việc tiếp theo: "Dựng nơi trú ngụ. Cần: gỗ." Người chơi nhặt gỗ về xây nhà ở, bắt đầu dựng căn cứ. Nếu 6 nhiệm vụ đang có đã gồm việc này thì dùng lại, không thêm trùng.

1. **Ánh sáng không có nguồn.** Hệ thống: "Tìm nơi ánh sáng không có nguồn." Đêm trăng, người chơi gặp bóng một người đang quét một cái sân không còn tồn tại. Bóng quét được vài nhát thì khựng lại, rồi lặp lại từ đầu.
2. **Người giữ đèn.** Hệ thống: "Hỏi người còn sống." Ở khu định cư ven rừng, người giữ đèn nói: "Rừng thì đêm nào cũng vào được. Trừ đêm Kuro." Hỏi Kuro là gì: "Là đêm Kuro. Bà ta đã kiêng, mẹ ta đã kiêng." Rồi nhíu mày: "Mà ngươi cứ nhìn vào khoảng không gật gù làm gì thế?"
3. **Ba cái bóng.** Hệ thống: "Quan sát. Số lượng: 3." Người chơi tìm ba bóng ở ba nơi: người bán hàng đang đưa tiền thối, đứa trẻ đang chạy, người học phép đang đọc dở một câu. Cả ba đều dừng khi việc còn dang dở.
4. **Đài đá đón trăng.** Hệ thống: "Đến nơi nó không rời đi." Một con quái không chịu rời đài đá, khác hẳn đám lang thang. Hạ nó xong, bóng một người hiện lên làm nghi thức chữa thương. Hệ thống: "Đã ghi nhận: Lưu Ảnh."
5. **Cùng một khoảnh khắc.** Hệ thống: "Đối chiếu." Dùng Lưu Ảnh trên đài, bóng của chính người chơi hiện ra bên cạnh các bóng cũ, và người chơi nhận ra chúng đều dừng ở cùng một nhịp. Hệ thống: "Thời điểm: không xác định. Đã lưu." Người giữ đèn, nếu được hỏi: "Đêm Kuro, trong rừng không có bóng nào. Ta cũng không biết vì sao."

Điều người chơi có sau chuỗi này: bóng người là dấu vết của cùng một khoảnh khắc, và Kuro là một đêm mà rừng tối hẳn. Chưa ai nói hai điều đó liên quan với nhau.

### Phụ

Chưa có.

### Vặt

Chưa có.
