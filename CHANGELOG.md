# Changelog

## 2.4.0 - 2026-10-13

### Added

- **Hiện đại hóa toàn diện kiến trúc (Architecture Modernization):**
  - **Tái cấu trúc mô-đun hóa (Modular Architecture):**
    - Phân rã tệp nguyên khối hơn 3.000 dòng thành 8 mô-đun độc lập, chuyên sâu và dễ bảo trì trong thư mục `src/modules/`:
      + `01_Diagnostics.ps1`: Chẩn đoán nhanh SLA, mạng, domain, hiệu năng, máy in, cập nhật, kiểm tra định tuyến.
      + `02_PrinterSuite.ps1`: Chuyên đề scan Toshiba e-STUDIO, ký số SMB, sửa RPC 0x11b, sao lưu/phục hồi driver.
      + `03_Hardware.ps1`: Thông số phần cứng 1 dòng ticket, kiểm tra TPM/BitLocker, sao lưu khóa phục hồi.
      + `04_SystemMaintenance.ps1`: Dọn dẹp sâu đĩa C:, sửa Windows Search/Start, Fast Startup, cache Office.
      + `05_Licensing.ps1`: Kiểm tra bản quyền chuyên sâu, M365 vNext token, 10 tiêu chí ITSO crack audit & xuất HTML.
      + `06_LocalAdmin.ps1`: Quản lý tài khoản cục bộ, bật/tắt Administrator, đổi tên máy, mở RDP 3389.
      + `07_CloudIdentity.ps1`: Entra ID, AzureAdPrt, WamDefaultSet, sửa Blank Screen / TokenBroker, Intune sync.
      + `08_ConsoleUI.ps1`: Giao diện dòng lệnh Modern TUI tiếng Việt UTF-8, ANSI box drawing, menu điều hướng.
    - Nâng cấp `Build-Release.ps1` tự động ghép và biên dịch các mô-đun thành tệp phát hành thống nhất `Syscare.WindowsTool.ps1` có kiểm định cú pháp AST tự động (0 lỗi - PASS).
  - **Giao diện Modern PowerShell TUI Native (`Syscare.Console.ps1`):**
    - Giao diện console hiện đại chạy thuần PowerShell với hỗ trợ 100% tiếng Việt UTF-8 có dấu chuẩn Unicode và bảng màu ANSI VT100.
    - Nạp toàn bộ hàm chức năng vào bộ nhớ phiên, triệt tiêu độ trễ khởi tạo tiến trình con (`powershell.exe -Command`) từ file BAT cũ; tốc độ phản hồi cực nhanh (<10ms).
    - Tích hợp thanh thông tin thiết bị thời gian thực (ComputerName, User, Domain, Phiên bản Windows, Quyền Administrator).
    - Tạo launcher thông minh `00_RUN_ADMIN_FULL.bat` với cơ chế tự động nâng quyền UAC và cho phép người dùng chọn chạy Modern PowerShell TUI hoặc Menu CMD BAT cổ điển.
    - Bổ sung phím tắt `[P]` ngay tại menu chính của `Tool_Windows.bat` để chuyển đổi mượt mà sang Modern TUI bất kỳ lúc nào.
  - **Đóng gói Bản chạy Ngoại tuyến Độc lập (Offline Air-Gapped Portable USB Edition):**
    - Tự động đóng gói bản Portable zip độc lập `Syscare-Windows-Tool-v2.4.0.zip` chứa đầy đủ mã nguồn BAT, PowerShell TUI, Core diagnostics và tài liệu hướng dẫn.
    - Phục vụ cứu hộ và khắc phục sự cố tại chỗ trên các máy tính mạng cách ly hoàn toàn (Air-gapped), ngân hàng, phòng máy chủ, kho bãi hoặc chi nhánh không có Internet.
- **Chuyên đề Sửa lỗi Máy in, Scan-to-folder SMB và Ký số (Toshiba e-STUDIO & Windows 10/11 - `[8] -> [C]`):**
  - **Chẩn đoán & Kết nối Thư mục Scan Toshiba (`[8] -> [C] -> [1]`):**
    - Hỗ trợ chuyên biệt cặp máy in công ty: e-STUDIO 3515AC (Máy màu - `10.6.0.25`) và e-STUDIO 2508A (Máy trắng đen - `10.6.0.26`).
    - Bổ sung bảng đối chiếu cấu hình an toàn vs tương thích chuẩn Microsoft Security Baseline: `SMB Signing` (Client), `Insecure Guest Logon`, và tính năng `SMB1Protocol-Client`.
    - Tự động kiểm tra TCP 445, đồng bộ thông tin chứng thực (`cmdkey`) cho user `scan` / `@@6868`.
    - Tự động kích hoạt phiên SMB live và hiển thị trực quan phiên kết nối qua `Get-SmbConnection` với phiên bản giao thức (`Dialect`, ví dụ SMB 3.1.1) và trạng thái ký số (`Signed = True/False`).
    - Phân tích chuyên sâu nguyên nhân lỗi `"The specified network name is no longer available"`: (1) Máy 2508A firmware cũ chỉ hỗ trợ SMB 1.0; (2) Chưa bật ký số `SMB Signing of SMB Server = If client agrees` trong TopAccess khiến phiên bị đóng khi Windows 11 yêu cầu ký; (3) Phân quyền tài khoản `scan` trên share `file_share`.
    - Trích xuất 15 sự kiện bảo mật SMB gần nhất (30 phút qua) từ `Microsoft-Windows-SmbClient/Security`, tự động bắt lỗi Event 31017 (lỗi ký số) và Event 31001 (lỗi chặn Guest).
    - Cung cấp 2 Preset 1-Click: **Khôi phục chuẩn bảo mật cao Microsoft** (`RequireSecuritySignature = True`, `EnableInsecureGuestLogons = False`) và **Hạ cấu hình chế độ tương thích** (`RequireSecuritySignature = False`, `EnableInsecureGuestLogons = True`).
    - Hướng dẫn IT từng bước cấu hình TopAccess chuẩn trên máy 2508A và 3515AC.
  - **Quản lý Cấu hình SMB Client & Giao thức SMB 1.0/2.0/3.0 (`[8] -> [C] -> [2]`):**
    - 1-Click Áp dụng Preset Bảo mật cao (Signing = True, InsecureGuest = False) chuẩn Microsoft.
    - 1-Click Áp dụng Preset Tương thích (Signing = False, InsecureGuest = True) cho máy in / scan cũ.
    - 1-Click Bật / Tắt riêng lẻ Bắt buộc Ký số SMB (`RequireSecuritySignature`).
    - 1-Click Bật / Tắt riêng lẻ Đăng nhập Guest (`EnableInsecureGuestLogons`).
    - 1-Click Bật / Tắt giao thức `SMB1Protocol-Client` (hỗ trợ kiểm tra trạng thái online).
    - Hiển thị trực tiếp phiên SMB hiện hành (`Get-SmbConnection: Dialect, Signed`) và xem 15 log sự kiện bảo mật SMB gần nhất.
    - Xóa sạch kết nối SMB/IPC$ bị kẹt (`net use * /delete /y`).
  - **1-Click Sửa lỗi Chia sẻ Máy in Mạng LAN 0x0000011b, 0x00000709 (`[8] -> [C] -> [3]`):**
    - Tự động sửa lỗi RPC Print Restriction (`RpcAuthnLevelPrivacyEnabled = 0`).
    - Sửa lỗi RPC over Named Pipes và Point and Print Policies trên Windows 10 và Windows 11 (22H2/24H2), khởi động lại Print Spooler an toàn.
- **Quản lý Cloud Identity, Entra ID, PRT Token & Intune (Microsoft 365 - `[7] -> [M]`, `[A] -> [C]`, `[A] -> [8] -> [C]`):**
  - Chẩn đoán tình trạng danh tính thiết bị đa tầng: `AzureAdJoined`, `EnterpriseJoined`, `DomainJoined`, `WorkplaceJoined`, DeviceId, TenantId và TenantName thông qua `dsregcmd /status`.
  - Giám sát sức khỏe SSO và trạng thái **AzureAdPrt (Primary Refresh Token)**, `AzureAdPrtAuthority`, `WamDefaultSet`, phát hiện và chỉ điểm mã lỗi Client ErrorCode (ví dụ `0x801c001d`).
  - Tự động nhận diện thiết bị quản lý qua Intune / MDM (`HKLM:\SOFTWARE\Microsoft\Enrollments`), đọc UPN và Discovery Service URL; giải thích rõ cho quản trị viên khi gói Office 365 Business Standard chưa kích hoạt Intune Plan 1.
  - 1-Click Kích hoạt Đồng bộ Chính sách Thiết bị Intune / MDM (`DeviceEnroller.exe /c /urmgred`).
  - 1-Click Khắc phục triệt để lỗi Blank Screen / Vòng lặp đăng nhập (Login Loop) / Tam giác vàng "Need Password" trên Outlook và Microsoft 365: Đăng ký lại gói ứng dụng `Microsoft.AAD.BrokerPlugin` và làm sạch bộ nhớ đệm TokenBroker.
  - Phím tắt mở nhanh cài đặt liên kết tài khoản cơ quan (`ms-settings:workplace`).
  - 1-Click Xuất toàn bộ báo cáo chẩn đoán `dsregcmd /status` chi tiết ra tệp văn bản UTF-8 trên Desktop và mở tự động bằng Notepad.
- **Sửa lỗi Windows Search & Start Menu (`[1]`, `[A]`):**
  - Tự động dừng dịch vụ `WSearch`, kết thúc các tiến trình tìm kiếm (`SearchHost.exe`, `SearchIndexer.exe`, `StartMenuExperienceHost.exe`, `ShellExperienceHost.exe`) và khởi động lại dịch vụ để sửa lỗi ô Search trên Taskbar bị đơ hoặc không gõ được.
- **Dọn dẹp hệ thống sâu 1-Click (Deep System Clean - `[3]`, `[A]`):**
  - Quét và dọn dẹp sạch sẽ: `%TEMP%` người dùng, `C:\Windows\Temp`, `Prefetch`, bộ nhớ đệm cập nhật `SoftwareDistribution\Download` và Thùng rác (Recycle Bin).
  - Tự động đo lường và hiển thị dung lượng đĩa C: đã được giải phóng (tính bằng MB/GB).
- **Bật / Tắt Fast Startup & Hibernation (`[3]`):**
  - Hỗ trợ kiểm tra và 1-click Bật / Tắt tính năng Khởi động nhanh (`powercfg /h off` & `powercfg /h on`), giải phóng file `hiberfil.sys` và khắc phục triệt để lỗi laptop nóng máy khi gập nắp, đen màn hình sau Sleep hoặc mất card mạng.
- **Kiểm tra Bản quyền Chuyên sâu & Kiểm định Crack (Chuẩn ITSO Enterprise Audit - `[6]`, `[9]`):**
  - Nhận diện toàn diện bản quyền Windows: Kênh cấp phép (`slmgr /dli`), thời hạn kích hoạt (`slmgr /xpr`), Partial Product Key, Registry Backup Key và BIOS OA3 OEM Key.
  - Hỗ trợ chuyên sâu **Microsoft 365 Subscription** (Click-to-Run / vNext Licensing): Tự động trích xuất tài khoản email được cấp phép, Tenant ID, SKU gói bản quyền (Business / Enterprise), ngày gia hạn/hết hạn và trạng thái kích hoạt hiện hành (`Provisioned`/`Active`). Quét fallback qua `root\Office16\ospp.vbs`.
  - **10 tiêu chí kiểm định Crack & An ninh bản quyền chuyên sâu (chuẩn ITSO Checker):**
    1. Chữ ký số tệp hệ thống (`sppsvc.exe` Authenticode)
    2. Ngoại lệ Windows Defender (KMS Exclusions)
    3. Máy chủ KMS Crack (Rogue KMS host check)
    4. Lịch sử PowerShell (Vết tích script crack MAS / KMS)
    5. Móc nối KMS38 Hook (IFEO Debugger hook trên `SppExtComObj.exe` / `osppsvc.exe`)
    6. Thư mục Tool lậu (AAct, KMSAuto, MAS, KMSPico, HEU...)
    7. Tác vụ chạy ngầm kích hoạt lậu (Scheduled Tasks AutoKMS/KMSPico)
    8. Can thiệp Registry (SPP bypass keys, KMS port overrides)
    9. Logic Bản Quyền (Kiểm tra chéo Channel vs Windows Edition)
    10. Lịch sử kích hoạt hệ thống (Security-SPP Event Log)
  - Đánh giá tổng thể và rủi ro tuân thủ SAM (Software Asset Management).
  - Tích hợp 1-Click xuất Báo cáo Kiểm định chi tiết định dạng HTML trực quan, sẵn sàng In hoặc Lưu PDF nộp kiểm toán.
- **Quản lý Tài khoản Cục bộ & Built-in Administrator (`[7]`):**
  - Liệt kê tài khoản cục bộ, 1-Click Bật / Tắt tài khoản `Administrator` tích hợp (`net user administrator /active:yes|no`), đổi mật khẩu tài khoản và mở `lusrmgr.msc`.
- **Đổi tên máy tính chuẩn thiết bị IT (Rename Computer - `[8]`):**
  - Kiểm tra quy chuẩn tên máy (tối đa 15 ký tự, không ký tự đặc biệt), thực thi `Rename-Computer` và hỗ trợ hẹn giờ khởi động lại máy an toàn.
- **Bật / Tắt Remote Desktop (RDP) & Mở cổng Firewall 3389 (`[8]`):**
  - Bật/tắt RDP trực tiếp qua Registry (`fDenyTSConnections`) và tự động bật/tắt nhóm rule Firewall cho phép kết nối `mstsc` qua cổng 3389.
- **Mở nhanh công cụ quản trị nâng cao (`[7]`):**
  - Tích hợp phím tắt mở trực tiếp Registry Editor (`regedit.exe`) và Local Group Policy Editor (`gpedit.msc`).

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
