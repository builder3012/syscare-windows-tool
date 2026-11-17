# Báo cáo kiểm thử bản phát hành 2.4.0

## Kiểm thử phiên bản hoàn thiện v2.4.0 (2026-10-13)

- **Hiện đại hóa toàn diện kiến trúc (Architecture Modernization Verification):**
  - **Tái cấu trúc mô-đun hóa (`src/modules/`):** Phân chia thành công 8 mô-đun chuyên biệt (`01_Diagnostics.ps1`, `02_PrinterSuite.ps1`, `03_Hardware.ps1`, `04_SystemMaintenance.ps1`, `05_Licensing.ps1`, `06_LocalAdmin.ps1`, `07_CloudIdentity.ps1`, `08_ConsoleUI.ps1`). Mỗi mô-đun được kiểm tra cú pháp AST độc lập đạt **100% PASS - 0 lỗi**.
  - **Tự động biên dịch tệp hợp nhất:** Quy trình `Build-Release.ps1` tự động ghép 8 mô-đun thành `Syscare.WindowsTool.ps1`, thực hiện kiểm tra AST tự động trước khi đóng gói payload và phát hành.
  - **Giao diện Modern PowerShell TUI Native (`Syscare.Console.ps1`):** Khởi chạy thành công trên PowerShell 5.1/7+, hiển thị tiếng Việt UTF-8 chuẩn xác, hỗ trợ phím điều hướng 9 chuyên đề, nạp hàm vào bộ nhớ giúp phản hồi tức thì (<10ms) không cần mở tiến trình con.
  - **Tệp khởi chạy chính thống nhất (`Tool_Windows.bat`):** Xác lập `Tool_Windows.bat` là tệp chạy chính (chạy với quyền Administrator). Menu chính của `Tool_Windows.bat` tích hợp phím `[P]` chuyển đổi mượt sang Modern PowerShell TUI (`Syscare.Console.ps1`).
  - **Bản phát hành Ngoại tuyến Độc lập (`Syscare-Windows-Tool-v2.4.0.zip`):** Tự động nén và xác thực tính toàn vẹn SHA-256 trong `checksums.sha256` và `release-manifest.json`, sẵn sàng triển khai trên USB cho môi trường Air-Gapped.
- **PowerShell AST & StrictMode 2.0:** Mô-đun `Syscare.WindowsTool.ps1` được phân tích cú pháp đạt **0 lỗi**. Các hàm `Invoke-SyscareConsole`, `Invoke-ToshibaScanSuite`, `Invoke-SmbSecurityConfig`, `Invoke-RpcPrintFix`, `Invoke-CloudIdentitySuite`, `Invoke-SearchFix`, `Invoke-DeepClean`, `Invoke-FastStartupToggle`, `Invoke-LicenseCheck`, `Invoke-LocalUserAdmin`, `Invoke-RenamePC`, `Invoke-ToggleRDP` đều chạy độc lập an toàn, bẫy lỗi bằng `try/catch` và ghi nhận log phiên.
- **Cấu trúc nhãn BAT:** Kiểm tra tự động 182 nhãn trong `Tool_Windows.bat` đạt **100% hợp lệ, 0 nhãn thiếu hoặc trỏ sai**.
- **Chuyên đề Sửa lỗi Máy in & Scan SMB Toshiba (e-STUDIO 3515AC & 2508A - `[8] -> [C]`):**
  - Đã tích hợp bảng đối chiếu Microsoft Security Baseline (SMB Signing, Insecure Guest, SMB1).
  - Tự động kích hoạt phiên SMB live và hiển thị `Get-SmbConnection` với cột `Dialect` (SMB 3.1.1) và `Signed` (`True/False`).
  - Phân tích log lỗi bảo mật `Microsoft-Windows-SmbClient/Security` trong 30 phút gần nhất (Event 31017, Event 31001), chẩn đoán chính xác nguyên nhân lỗi `"The specified network name is no longer available"`.
  - Cung cấp 2 Preset 1-Click: Áp dụng chuẩn bảo mật cao Microsoft (`RequireSecuritySignature = True`, `EnableInsecureGuestLogons = False`) và Chế độ tương thích cho máy 2508A (`RequireSecuritySignature = False`, `EnableInsecureGuestLogons = True`).
- **Mở rộng Cloud Identity, Entra ID, PRT Token & Intune (`[7] -> [M]`, `[A] -> [C]`):**
  - Chẩn đoán tình trạng gia nhập đám mây: `dsregcmd /status` trích xuất `AzureAdJoined`, `EnterpriseJoined`, `DomainJoined`, `WorkplaceJoined`, DeviceId, TenantId.
  - Giám sát sức khỏe SSO và trạng thái **AzureAdPrt (Primary Refresh Token)**, `AzureAdPrtAuthority`, `WamDefaultSet`, phát hiện và chỉ điểm mã lỗi Client ErrorCode.
  - Tự động nhận diện thiết bị quản lý qua Intune / MDM (`HKLM:\SOFTWARE\Microsoft\Enrollments`), đọc UPN và Discovery Service URL; cảnh báo chính xác khi tenant dùng gói Office 365 Business Standard.
  - 1-Click Kích hoạt Đồng bộ Chính sách Thiết bị Intune / MDM (`DeviceEnroller.exe /c /urmgred`).
  - 1-Click Khắc phục triệt để lỗi Blank Screen / Vòng lặp đăng nhập (Login Loop) / Tam giác vàng "Need Password" trên Outlook và Microsoft 365: Đăng ký lại gói ứng dụng `Microsoft.AAD.BrokerPlugin` và làm sạch bộ nhớ đệm TokenBroker.
  - 1-Click Xuất toàn bộ báo cáo chẩn đoán `dsregcmd /status` chi tiết ra tệp văn bản UTF-8 trên Desktop và mở tự động bằng Notepad.
- **Kiểm thử thực thi thực tế (Live Execution on Windows):**
  - `SearchFix`: Tự động dừng WSearch, ngắt tiến trình tìm kiếm, đặt startup Automatic và khởi động lại dịch vụ thành công trong 2 giây.
  - `LicenseCheck & ITSO Crack Audit`:
    - Nhận diện chính xác Windows 11 Pro, kênh VOLUME_MAK, Partial Key `K4R9M`, Registry Key `D84KV-7NXJR-FTWTG-GYYXG-D3WXM`.
    - Trích xuất thành công bản quyền **Microsoft 365 Apps for business**, Account `tuanpham@phugiavn.onmicrosoft.com`, Tenant ID `b00dd3cf-8273-466e-ab28-c00c6ea93cd4`, Trạng thái `Provisioned` (Active), Ngày gia hạn `11/01/2027`.
    - Bộ 10 tiêu chí an ninh & crack đạt 10/10 `[+] SẠCH`: Chữ ký Authenticode `sppsvc.exe` hợp lệ (Microsoft Windows), Defender Exclusion sạch, không có KMS Host giả lập, không có vết tích PowerShell crack, không có KMS38 IFEO hook, không có thư mục tool lậu, không có task chạy ngầm AutoKMS, Registry SPP sạch, logic bản quyền hợp lệ, log SPP sạch.
    - Xuất file báo cáo HTML `License_Audit_*.html` đầy đủ định dạng bảng biểu, màu sắc cảnh báo chuẩn SAM và hỗ trợ in/xuất PDF trực quan.
  - `Build-Release`: Tạo tự động `Invoke-JoITWindowsTool.ps1`, `index.html`, `checksums.sha256` và `release-manifest.json` cho bản phát hành `v2.4.0`.

## Kết quả kiểm thử v2.3.0 (2026-10-13)

- **PowerShell AST & StrictMode 2.0:** Mô-đun `Syscare.WindowsTool.ps1` được phân tích bằng `[System.Management.Automation.Language.Parser]::ParseFile` đạt **0 lỗi cú pháp**. Đã bổ sung cơ chế kiểm tra thuộc tính an toàn cho đối tượng TPM/WMI nhằm tương thích tuyệt đối cả Windows 10 và Windows 11 (PowerShell 5.1 & PowerShell 7+).
- **Kiểm tra nhãn BAT:** Toàn bộ cấu trúc `Tool_Windows.bat` (154 nhãn) và hơn 450 tham chiếu `goto/call` đã được xác minh tự động, **0 nhãn bị thiếu hoặc trỏ sai**.
- **Kiểm thử thực tế trên Windows (Live Verification):**
  - `AssetSpecs`: Thu thập chính xác Serial Number/Service Tag, Mainboard, BIOS, CPU, RAM Slots và dung lượng. Tạo file tóm tắt tại `Syscare_Support` và tự động copy chuỗi 1 dòng vào Windows Clipboard.
  - `BitLockerStatus`: Truy vấn chính xác trạng thái bảo vệ BitLocker các phân vùng và thông số TPM chip (`TpmPresent`, `TpmReady`).
  - Giao diện điều hướng: Đảm bảo đầy đủ luồng kết thúc `B` (quay lại nhóm), `M` (về menu chính), `0` (thoát) và xác nhận an toàn trước các tác vụ xóa/sửa.
  - Session Logging: Mọi hành động đều được ghi log chi tiết có timestamp vào `%ProgramData%\Syscare\WindowsTool\Logs`.
- **Tính toàn vẹn phát hành:** Quy trình `Build-Release.ps1` nhúng thành công hai payload BAT và Core vào Launcher; hash của `Invoke-JoITWindowsTool.ps1` và `index.html` hoàn toàn trùng khớp (SHA-256).

## Kết quả kiểm thử v2.2.0 (2026-10-09)

- BAT: 147 nhãn riêng biệt, 323 đích `goto/call` đã kiểm tra, không thiếu hoặc trùng nhãn.
- Builder tạo v2.2.0; launcher và `index.html` trùng byte; payload BAT/Core giải nén trùng byte nguồn; hash manifest đúng cho 12 file.
- Menu `[8] → [C]` có 6 thao tác; `0` về nhóm `[8]`; màn hình kết quả có `B/M/0`.
- **Chưa chạy thử thực tế trên Windows** vì môi trường build là Linux. Trước phát hành, thử trên Windows 10/11 và Windows Server 2016 nếu định dùng trên server: USB không có queue, máy in share/IP, UNC scan truy cập được/không được; thử hủy xác nhận sửa lỗi rồi chạy trên queue test.
- Với lỗi Toshiba scan, thử job thực trên thiết bị, đối chiếu job log và event trên file server, kiểm tra cả share ACL và NTFS ACL của tài khoản scan. Kiểm tra UNC từ PC không đại diện cho kết nối từ máy in.

## Kết quả lịch sử v2.1.0

Ngày kiểm thử: 2026-08-10

## Kết quả tự động

| Kiểm tra | Kết quả |
|---|---|
| Nhãn BAT | 139 nhãn, không trùng |
| Tham chiếu `goto`/`call` | 435 tham chiếu, không thiếu đích |
| Menu `choice` | 29 menu, ký tự lựa chọn không trùng, `errorlevel` ánh xạ giảm dần đúng |
| Mục hướng dẫn `[H]` | Có đủ bắt đầu nhanh, giới thiệu tính năng, điều hướng và tình huống |
| Điểm kết thúc tác vụ | 70 luồng chuyển qua màn hình điều hướng thống nhất |
| `pause` sau tác vụ | Đã loại bỏ; chỉ còn một `pause` tại cảnh báo thiếu quyền Administrator |
| Danh sách `more` | 5/5 lệnh có hướng dẫn `Space`, `Enter`, `Q` trước khi chạy |
| Phiên bản BAT/Core | Đồng bộ `2.1.0` |
| Payload BAT trong launcher | Trùng byte với `Tool_Windows.bat` |
| Payload Core trong launcher | Trùng byte với `Syscare.WindowsTool.ps1` |
| SHA-256 payload | Cả hai khớp giá trị mong đợi trong launcher |
| Launcher và `index.html` | Trùng byte |
| Checksum release | Tất cả file trong `checksums.sha256` đạt |
| Placeholder build | Không còn placeholder trong launcher/index |
| Cấu trúc PowerShell | Here-string, ngoặc tròn/vuông/nhọn cân bằng |
| Node release builder | `node --check` đạt và build thành công |

## Kiểm tra bảo mật tĩnh

- Không có lệnh tải file hoặc chạy phần mềm bên thứ ba trong BAT/Core.
- Không có lệnh xem khóa Wi-Fi dạng clear text.
- Hai thao tác phá hủy/gián đoạn được phát hiện là xóa print queue và reboot Advanced Startup; cả hai đều có xác nhận người dùng.
- Launcher chỉ xóa payload vừa giải nén khi SHA-256 sai.
- Báo cáo có privacy notice và không tự động upload ra ngoài.

## Giới hạn kiểm thử

Môi trường build không phải Windows nên chưa thể thực thi thật các cmdlet/module phụ thuộc Windows (`NetTCPIP`, `PrintManagement`, `Defender`, `PnpDevice`, `CIM`) hoặc mô phỏng UAC. Trước khi phát hành lên nhánh `main`, cần smoke test trên máy/VM Windows.

## Smoke test bắt buộc trên Windows

1. Windows 10 workgroup: mở BAT, Quick Triage, Network, Printer, Incident Bundle.
2. Windows 11 domain-joined: Domain report, secure channel, gpresult, klist, time source.
3. Launcher cục bộ: giải nén hai payload, xác minh hash, UAC và mở menu.
4. Từ chối từng xác nhận: đảm bảo không reboot/reset/xóa queue.
5. Chạy `Build-Release.ps1`, xác nhận launcher/index giống nhau.
6. Đẩy lên branch thử nghiệm hoặc tag pre-release, kiểm tra URL có query chống cache.
7. Chỉ merge/push `main` sau khi tất cả mục trên đạt.
8. Tại ít nhất một tác vụ trong mỗi nhóm, xác nhận `B` về đúng nhóm, `M` về menu chính và `0` thoát.
9. Kiểm tra một danh sách driver/service dài: `Space`, `Enter`, `Q` hoạt động và sau đó hiện lựa chọn điều hướng.
10. Mở `[H]` và kiểm tra cả bốn trang hướng dẫn trên độ phân giải cửa sổ mặc định.
