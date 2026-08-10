# Changelog

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
