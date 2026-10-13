# Changelog

## 2.3.0 - 2026-10-13

### Added

- **Quản lý Driver & Thiết bị (`[5]`):**
  - Sao lưu toàn bộ OEM Driver (`Export-WindowsDriver` / `dism /export-driver`) tự động tạo thư mục theo tên máy và ngày giờ.
  - Phục hồi và cài đặt driver hàng loạt bằng `pnputil /add-driver *.inf /subdirs /install`.
  - Liệt kê và gỡ bỏ driver bên thứ ba theo Published Name (`pnputil /delete-driver oemXX.inf`).
  - Tự động nhận diện thiết bị thiếu driver và cung cấp liên kết tải driver chính hãng (Dell, HP, Lenovo, Asus, Acer, Intel, AMD, NVIDIA).
- **Thông tin phần cứng & Tài sản (`[3]`, `[7]`, `[A]`):**
  - Tra cứu nhanh Serial Number / Service Tag, Model, Mainboard, BIOS, CPU, dung lượng & số khe RAM.
  - Chuẩn hóa báo cáo tóm tắt 1 dòng và tự động copy vào Windows Clipboard để dán ngay vào Ticket SLA/ITSM.
- **Bảo mật & BitLocker (`[6]`):**
  - Kiểm tra trạng thái mã hóa BitLocker tất cả các ổ đĩa và trạng thái chip bảo mật TPM (`Get-Tpm` / `tpmtool`).
  - Trích xuất an toàn BitLocker Recovery Key 48 ký tự ra file văn bản có dấu thời gian trước khi can thiệp BIOS/phần cứng.
- **Tiện ích Doanh nghiệp & M365 (`[8]`):**
  - Đóng tiến trình và xóa sạch cache Microsoft 365, Teams (New & Classic), Outlook RoamCache & OneAuth/IdentityCache sửa triệt để lỗi loop đăng nhập và treo profile.
  - Sao lưu và khôi phục cấu hình mạng Wi-Fi (`netsh wlan export/add profile`).
- **Quản trị Domain & Account (`[7]`, `[8]`, `[A]`):**
  - Kiểm tra và tự động sửa chữa quan hệ tin cậy Domain (`Test-ComputerSecureChannel -Repair`, `nltest /sc_reset`, `klist purge`, `w32tm`, `gpupdate`).
  - Mở nhanh công cụ quản lý chứng thực Windows Stored Passwords (`keymgr.dll`) và Windows Credential Manager.

### Changed

- Đồng bộ hóa menu CMD và mô-đun PowerShell `Syscare.WindowsTool.ps1` đạt chuẩn đồng nhất.
- Bổ sung xác nhận an toàn `[Y/N]` và các từ khóa bảo vệ cho tất cả các thao tác nhạy cảm.

## 2.2.0 - 2026-10-09

### Added

- Trợ lý `[8] → [C]` chẩn đoán riêng máy in USB, máy in chia sẻ qua PC/print server, máy in IP và scan-to-folder SMB.
- Báo cáo cục bộ với trạng thái queue, driver/port, PnP, DNS, TCP và UNC; hướng dẫn khoanh vùng lỗi Toshiba và quyền share/NTFS.
- Xóa job theo máy in được chọn và khởi động lại Spooler cục bộ, đều cần nhập từ xác nhận riêng.

### Security

- Không hỏi/lưu mật khẩu máy scan, không bật SMB1 hoặc guest, không thay đổi ACL, driver hay cấu hình máy in tự động.
- Nêu rõ kết quả kiểm tra UNC bằng tài khoản PC không đại diện cho tài khoản được cấu hình trong máy photocopy.

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
