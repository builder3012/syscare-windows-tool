# Syscare Windows Tool v2.4.0

Bộ công cụ hỗ trợ IT helpdesk và hạ tầng tại chỗ trên Windows 10/11, tối ưu cho thao tác nhanh, lưu bằng chứng xử lý và đáp ứng SLA. Menu chính vẫn chạy bằng BAT; các báo cáo chuyên sâu được thực hiện bởi mô-đun PowerShell đi kèm.

Lệnh sử dụng chính thức:

```powershell
irm https://win.syscare.site | iex
```

## Điểm mới của v2.4.0

- **Sửa lỗi Windows Search & Start Menu (`[1]`, `[A]`):** Tự động restart dịch vụ `WSearch`, reset các tiến trình giao diện SearchHost/StartMenu khi ô Search trên Taskbar bị đơ.
- **Dọn dẹp hệ thống sâu 1-Click (`[3]`, `[A]`):** Dọn dẹp an toàn Temp, Prefetch, SoftwareDistribution\Download và Thùng rác, tự động báo cáo số dung lượng GB/MB đã giải phóng.
- **Bật / Tắt Fast Startup & Hibernation (`[3]`):** 1-Click Bật / Tắt Khởi động nhanh (`powercfg /h on|off`), khắc phục lỗi laptop nóng khi gập nắp, đen màn hình sau Sleep hoặc mất card mạng.
- **Kiểm tra Bản quyền Chi tiết Windows & Office (`[6]`):** Tra cứu kênh License Windows (`slmgr /dli`), thời hạn (`slmgr /xpr`) và tự động kiểm tra bản quyền Microsoft Office (`ospp.vbs /dstatus`).
- **Quản lý User & Built-in Administrator (`[7]`):** Bật/Tắt tài khoản Administrator tích hợp (`net user administrator /active:yes|no`), đổi mật khẩu user nhanh và mở `lusrmgr.msc`.
- **Đổi tên máy tính chuẩn thiết bị IT (`[8]`):** Đổi tên máy (`Rename-Computer`) kiểm tra quy chuẩn NetBIOS kèm tùy chọn hẹn lịch reboot.
- **Bật / Tắt Remote Desktop (RDP) & Mở cổng Firewall 3389 (`[8]`):** Cấu hình trực tiếp Registry và mở Firewall để IT có thể remote qua `mstsc`.
- **Mở nhanh công cụ quản trị nâng cao (`[7]`):** Tích hợp phím tắt mở trực tiếp Registry Editor (`regedit.exe`) và Local Group Policy (`gpedit.msc`).

## Điểm mới của v2.3.0

- **Quản lý & Cài đặt Driver (`[5]`):** Sao lưu toàn bộ OEM Driver tự động theo tên máy/ngày giờ; Phục hồi và cài đặt driver hàng loạt bằng `pnputil /add-driver *.inf /subdirs /install`; Gỡ bỏ driver bên thứ ba xung đột (`pnputil /delete-driver oemXX.inf`); Quét thiết bị thiếu driver và mở trang driver chính hãng (Dell, HP, Lenovo, Asus, Acer, Intel, AMD, NVIDIA).
- **Thông tin phần cứng & Tài sản (`[3]`, `[7]`, `[A]`):** Tra cứu nhanh Serial/Service Tag, Model, Mainboard, BIOS, CPU, RAM Slots & tổng dung lượng; Tự động định dạng 1 dòng tóm tắt và copy thẳng vào Windows Clipboard để dán vào ticket SLA/ITSM.
- **Bảo mật & BitLocker (`[6]`):** Kiểm tra trạng thái mã hóa các phân vùng và chip bảo mật TPM (`Get-Tpm` / `tpmtool`); Trích xuất an toàn BitLocker Recovery Key 48 ký tự ra file text có dấu thời gian trước khi can thiệp BIOS/phần cứng.
- **Tiện ích Doanh nghiệp & M365 (`[8]`):** Clear cache toàn diện cho Microsoft 365, Teams (mới & cổ điển), Outlook RoamCache & OneAuth/IdentityCache sửa lỗi loop đăng nhập và treo profile; Sao lưu & nạp lại profile Wi-Fi (`netsh wlan`).
- **Quản trị Domain & Account (`[7]`, `[8]`, `[A]`):** Sửa lỗi quan hệ tin cậy Domain (`Test-ComputerSecureChannel -Repair`, `nltest /sc_reset`, `klist purge`, `w32tm`, `gpupdate`); Mở nhanh Stored User Names and Passwords (`keymgr.dll`) và Windows Credential Manager.

## Điểm mới của v2.2.0

- `[8] → [C]` mở trợ lý máy in và scan. Chọn `[1]` USB, `[2]` máy in chia sẻ qua PC/print server, `[3]` máy in IP riêng, `[4]` scan về thư mục SMB.
- Chẩn đoán driver, cổng, trạng thái Spooler, hàng đợi, DNS và cổng TCP phù hợp; báo cáo lưu ở `Desktop\Syscare_Support`.
- `[5]` chỉ xóa lệnh chờ của **một máy in được chọn** sau khi gõ `CLEAR`; `[6]` khởi động lại Spooler trên **máy đang chạy tool** sau khi gõ `RESTART`.
- Với Toshiba/MFP scan-to-folder, nhập server, tên share và thư mục con; tool kiểm tra TCP 445, đường UNC bằng tài khoản PC hiện tại. Nếu chạy trên máy chủ chứa share, tool còn hiển thị share ACL và NTFS ACL gốc.
- Phải kiểm tra trực tiếp trên máy in tài khoản SMB, mật khẩu, đường đi và job log. Bài kiểm tra từ PC **không chứng minh** máy in truy cập được server hoặc có quyền ghi bằng tài khoản lưu trong máy in.

## Thay đổi của v2.1.0

- Thêm `[H] Hướng dẫn sử dụng` ngay tại menu chính.
- Có hướng dẫn bắt đầu nhanh, giới thiệu 10 nhóm tính năng và gợi ý theo tình huống helpdesk.
- Sau mỗi tác vụ hiển thị rõ: `B` về nhóm vừa dùng, `M` về menu chính, `0` thoát.
- Trước danh sách dài hiển thị: `Space` sang trang, `Enter` sang dòng, `Q` dừng danh sách.
- Loại bỏ thông báo `Press any key to continue...` không rõ đích quay lại ở các tác vụ chính.

## Nền tảng chẩn đoán từ v2.0.0

- One-click Quick Triage: hệ thống, ổ đĩa, RAM, mạng, DNS, gateway, Internet, AD, GPO, Kerberos, time, máy in, Defender, Update và Event Log.
- Kết luận nhanh `PASS` hoặc `ATTENTION`, có TXT, JSON và HTML.
- Chẩn đoán riêng theo nhóm: Network, Domain/AD/GPO, Performance, Printer và Windows Update/Security.
- Test hostname/IP và danh sách TCP port tùy chọn, không ghép nội dung người dùng vào lệnh shell.
- Gói Incident Bundle ZIP phục vụ escalation, kèm manifest SHA-256.
- Biên bản ticket: mã sự cố, hiện trạng, tác vụ, kết quả và bước tiếp theo.
- Session log tự động tại `%ProgramData%\Syscare\WindowsTool\Logs`.
- Quy trình build một lệnh, tự nhúng và kiểm tra SHA-256 của cả BAT lẫn mô-đun PowerShell.
- Cảnh báo dữ liệu nhạy cảm được đặt trong mọi thư mục báo cáo.

## Cấu trúc phát hành

| File | Chức năng |
|---|---|
| `Tool_Windows.bat` | Menu chính và các lệnh sửa lỗi/tiện ích tại chỗ. |
| `Syscare.WindowsTool.ps1` | Quick Triage, báo cáo chuyên sâu, ticket và Incident Bundle. |
| `Invoke-JoITWindowsTool.ps1` | Launcher tự chứa; giải nén và xác minh SHA-256 hai payload trước khi chạy. |
| `index.html` | Bản sao byte-for-byte của launcher để phát hành tại `win.syscare.site`. |
| `Build-Release.ps1` | Tự tạo launcher, index, checksum và release manifest. |
| `Build-Release.mjs` | Builder tương đương cho CI/Linux, chỉ dùng module có sẵn của Node.js. |
| `checksums.sha256` | SHA-256 của các file phát hành. |
| `release-manifest.json` | Phiên bản, thời điểm build và metadata payload. |
| `AUDIT_REPORT.md` | Kết quả rà soát, thay đổi và đề xuất lộ trình. |
| `TEST_REPORT.md` | Kết quả kiểm thử tự động và checklist smoke test Windows. |
| `CHANGELOG.md` | Lịch sử phiên bản. |
| `CNAME` | Custom domain GitHub Pages. |
| `.nojekyll` | Phát hành file tĩnh nguyên bản trên GitHub Pages. |

## Cách dùng tại hiện trường

1. Mở Windows PowerShell.
2. Kiểm tra nội dung trước khi thực thi:

   ```powershell
   $code = [string](irm 'https://win.syscare.site/?check=1')
   $code.Substring(0, [Math]::Min(500, $code.Length))
   ```

3. Nội dung phải bắt đầu bằng `#requires -Version 5.1` và có tên `Syscare Windows Tool`.
4. Chạy:

   ```powershell
   irm https://win.syscare.site | iex
   ```

5. Chấp nhận UAC; người dùng mới có thể chọn `[H]` để xem hướng dẫn ngay trong tool.
6. Với sự cố chưa rõ nguyên nhân, chạy `[A] → [1] One-click Quick Triage` trước khi sửa.
7. Khi tác vụ kết thúc, chọn `B` để về nhóm vừa dùng, `M` để về menu chính hoặc `0` để thoát.
8. Với sự cố phải chuyển cấp, chạy `[A] → [A]` hoặc `[9] → [2]` để tạo Incident Bundle ZIP.

Khi danh sách dài dừng tại `-- More --`:

- Nhấn `Space` để xem trang tiếp theo.
- Nhấn `Enter` để xem thêm một dòng.
- Nhấn `Q` để dừng danh sách và chuyển tới màn hình điều hướng.

Đầu ra được lưu tại:

```text
Desktop\Syscare_Support
```

Nhật ký thao tác được lưu tại:

```text
%ProgramData%\Syscare\WindowsTool\Logs
```

## Ma trận xử lý SLA gợi ý

| Tình huống | Thao tác đầu tiên | Tác vụ tiếp theo |
|---|---|---|
| Máy chậm/treo | Quick Triage | Performance; kiểm tra top CPU/RAM, dung lượng và Event Log |
| Không vào mạng | Network | Test gateway, DNS, Internet 443; chỉ reset sau khi xác nhận không điều khiển từ xa |
| Không vào domain/share | Domain/AD/GPO | Secure channel, DC discovery, Kerberos, time; test port 53/88/389/445 tùy hệ thống |
| Mất quan hệ tin cậy Domain | `[A] → [2] → [7]` hoặc `[7] → [B]` | Test-ComputerSecureChannel -Repair, nltest reset, sync w32tm, gpupdate |
| Driver lỗi / Cài mới / Backup | `[5]` Driver và Thiết bị | Sao lưu driver OEM, nạp driver qua pnputil, xóa driver lỗi, mở link hãng |
| Lấy cấu hình máy điền ticket | `[A] → [B]` hoặc `[3] → [B]` | Lấy specs, tự động copy 1 dòng tóm tắt vào clipboard để paste ticket SLA |
| Nâng cấp BIOS / Thay mainboard | `[6] → [B] / [C]` | Kiểm tra BitLocker/TPM, trích xuất an toàn Recovery Key 48 ký tự ra TXT |
| M365 / Teams / Outlook loop login | `[8] → [D]` hoặc `[A] → [2] → [8]` | Clear cache Teams/Outlook, sửa lỗi profile và loop xác thực |
| Máy in USB không in | `[8] → [C] → [1]` | Kiểm tra nguồn/cáp, PnP, driver, queue; xử lý có xác nhận ở `[5]` hoặc `[6]` |
| Máy in chia sẻ không kết nối | `[8] → [C] → [2]` | DNS, TCP 445/135, share, quyền in và driver trên print server |
| Máy in IP Toshiba không in | `[8] → [C] → [3]` | Cổng thực tế, IP/port queue, trạng thái trên thiết bị, driver được duyệt |
| Toshiba không scan về folder | `[8] → [C] → [4]` | UNC, TCP 445, quyền share + NTFS, account scan và log trên Toshiba/file server |
| Update lỗi | Windows Update/Security | Kiểm tra service, policy, reboot pending và hotfix |
| Chưa xác định nguyên nhân | Incident Bundle | Gắn mã ticket, rà soát dữ liệu rồi escalation |

## Chạy cục bộ

Giữ hai file sau trong cùng thư mục:

```text
Tool_Windows.bat
Syscare.WindowsTool.ps1
```

Nhấp phải `Tool_Windows.bat` và chọn **Run as administrator**. Nếu thiếu mô-đun PowerShell, các menu Windows truyền thống vẫn hoạt động; nhóm SLA sẽ dừng an toàn và báo file bị thiếu.

## Quy trình cập nhật chuẩn

### 1. Sửa nguồn

- Menu/lệnh tại chỗ: sửa `Tool_Windows.bat`.
- Báo cáo/chẩn đoán chuyên sâu: sửa `Syscare.WindowsTool.ps1`.
- Cập nhật `TOOL_VERSION` trong BAT theo SemVer.
- Ghi thay đổi vào `CHANGELOG.md`.

### 2. Build phát hành

Chạy trong Windows PowerShell 5.1 trở lên:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Release.ps1
```

Build sẽ tự động:

1. Đọc phiên bản từ BAT.
2. Nén và nhúng BAT + Core PowerShell vào launcher.
3. Cập nhật hash mong đợi cho cả hai payload.
4. Tạo `Invoke-JoITWindowsTool.ps1`.
5. Tạo `index.html` giống hệt launcher.
6. Tạo `checksums.sha256` và `release-manifest.json`.

### 3. Kiểm tra trước phát hành

```powershell
$a = (Get-FileHash .\Invoke-JoITWindowsTool.ps1 -Algorithm SHA256).Hash
$b = (Get-FileHash .\index.html -Algorithm SHA256).Hash
$a -eq $b
Get-Content .\release-manifest.json | ConvertFrom-Json | Format-List
```

Kết quả so sánh phải là `True`. Sau đó chạy BAT trực tiếp trên máy test, rồi chạy launcher cục bộ.

### 4. Đẩy lên GitHub

```powershell
git status
git add .
git commit -m "Release v2.4.0 - Add System Clean, Search fix, Fast Startup, License check, Local Users, Rename PC and RDP toggle"
git push origin main
git tag -a v2.4.0 -m "Syscare Windows Tool v2.4.0"
git push origin v2.4.0
```

Chờ workflow **pages build and deployment** thành công. Không sửa DNS, CNAME hoặc custom domain khi chỉ cập nhật tính năng.

### 5. Kiểm tra bản online

```powershell
$url = 'https://win.syscare.site/?v=2.4.0'
$online = [string](irm $url)
$online | Select-String "ToolVersion = '2.4.0'"
irm $url | iex
```

## Nguyên tắc an toàn

- Không chạy release/renew, reset TCP/IP, Winsock hoặc reboot khi đang điều khiển máy từ xa.
- Không xóa hàng đợi in nếu chưa xác nhận với người dùng.
- Incident Bundle có thể chứa tên máy, user, IP, domain, Event Log và inventory; phải rà soát trước khi chia sẻ ra ngoài.
- Tool không thu thập mật khẩu Wi-Fi và không tự tải/chạy phần mềm bên thứ ba.
- `irm | iex` phụ thuộc an toàn của repository và tài khoản GitHub. Bật MFA, branch protection, giới hạn quyền ghi và cân nhắc ký Authenticode cho môi trường kiểm soát cao.
- Kiểm thử mọi thay đổi trên máy test hoặc VM trước khi phát hành diện rộng.

## Rollback

Khôi phục từ Git tag ổn định bằng một commit mới, rồi để GitHub Pages triển khai lại. Không cần thay đổi DNS hoặc URL.

```powershell
git show v1.0.0:Tool_Windows.bat > Tool_Windows.bat
# Khôi phục các file nguồn tương ứng, chạy lại Build-Release.ps1 rồi commit/push.
```

Không dùng `git reset --hard` trên thư mục làm việc có dữ liệu chưa lưu.
