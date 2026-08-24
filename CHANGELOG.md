# Changelog

## 2.2.0 - 2026-08-24

### Added

- Tính năng **Tự động nhận diện thông tin máy tính/Laptop & Cài đặt Driver** thuộc menu `[5.8]`:
  - Tự động nhận diện Hãng sản xuất (Dell, HP, Lenovo, ASUS, Acer, MSI, Surface,...), Model, Serial/Service Tag, phiên bản BIOS & HĐH.
  - Phát hiện danh sách thiết bị chưa nhận driver hoặc bị lỗi Code 28 (Yellow Exclamation Mark / Unknown Device).
  - Tích hợp Windows Update Driver Engine (WHQL): Tự động tìm kiếm, tải về và nạp driver chính hãng chuẩn từ Microsoft Update Catalog.
  - Trích xuất tự động link hỗ trợ driver chính hãng theo Service Tag/Serial Number của thiết bị.
  - Hỗ trợ nạp Driver offline từ thư mục local hoặc USB chứa file `.inf` bằng `pnputil`.
  - Hỗ trợ lối tắt tải nhanh Driver Card đồ họa (NVIDIA, AMD, Intel) và Card mạng/Bluetooth (Intel, Realtek).

## 2.1.0 - 2026-08-10

### Added

- Mục `[H] Hướng dẫn sử dụng` trên menu chính, gồm bắt đầu nhanh, giới thiệu tính năng, phím điều hướng và gợi ý theo tình huống.
- Lời nhắc riêng cho danh sách dài: `Space` xem trang tiếp, `Enter` xem dòng tiếp, `Q` dừng danh sách.
- Điều hướng thống nhất sau tác vụ: `B` về nhóm vừa dùng, `M` về menu chính, `0` thoát tool.

### Changed

- Thay toàn bộ `pause` sau tác vụ bằng màn hình kết thúc có lựa chọn rõ ràng.
- Chuẩn hóa luồng quay lại cho các nhóm sửa Windows, mạng, ổ đĩa, boot, driver, bảo mật, quản trị, tiện ích, SLA và báo cáo.
- Các lệnh `more` dùng chế độ mở rộng và hiển thị hướng dẫn trước khi phân trang.

## 2.0.0 - 2026-08-05

### Added

- SLA Quick Triage và báo cáo PASS/ATTENTION dạng TXT, JSON, HTML.
- Chẩn đoán Network, Domain/AD/GPO/Kerberos/time, Performance, Printer, Windows Update/Security.
- Test hostname/IP và TCP port tùy chọn.
- Incident Bundle ZIP kèm SHA-256 manifest.
- Biên bản ticket và session log tự động.
- Mô-đun `Syscare.WindowsTool.ps1` và quy trình `Build-Release.ps1`.
- Kiểm tra toàn vẹn hai payload trong launcher.

### Changed

- Đổi tên hiển thị thành Syscare Windows Tool.
- Tách báo cáo chậm SFC/DISM thành Health Scan có xác nhận.
- Báo cáo tổng hợp cũ được thay bằng Quick Triage và Incident Bundle có cấu trúc.
- Chuẩn hóa thư mục đầu ra tại `Desktop\Syscare_Support`.

### Security

- Không thu thập khóa/mật khẩu Wi-Fi.
- Thêm privacy notice vào từng báo cáo.
- Giữ xác nhận trước các tác vụ gián đoạn hoặc xóa dữ liệu hàng đợi.

## 1.0.0

- Menu BAT gồm sửa Windows, mạng, ổ đĩa/RAM/nguồn, boot/recovery, driver, security/update, quản trị, máy in/tiện ích và báo cáo tổng hợp.
- Launcher tự chứa một payload BAT và xác minh SHA-256.
