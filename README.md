# JoIT Windows Tool

Bộ công cụ sửa lỗi, chẩn đoán và bảo trì Windows 10/11. Tool chạy bằng menu CMD, tự kiểm tra tính toàn vẹn của file BAT và yêu cầu quyền Administrator khi cần.

## Cấu trúc

```text
JoIT-Windows-Tool
├── index.html
├── Invoke-JoITWindowsTool.ps1
├── Tool_Windows.bat
├── .nojekyll
└── README.md
```

| File | Chức năng |
|---|---|
| `index.html` | Bản sao nguyên vẹn của launcher PowerShell để GitHub Pages trả về khi truy cập tên miền gốc. |
| `Invoke-JoITWindowsTool.ps1` | Launcher tự chứa: giải nén BAT, kiểm tra SHA-256, xin quyền Administrator và mở tool. |
| `Tool_Windows.bat` | Mã nguồn menu công cụ Windows. |
| `.nojekyll` | Yêu cầu GitHub Pages phát hành tệp tĩnh nguyên bản. |
| `README.md` | Hướng dẫn triển khai và sử dụng. |

## Chức năng chính

- SFC, DISM và CHKDSK.
- Sửa mạng: Flush DNS, Winsock, TCP/IP, DHCP và Wi-Fi.
- Kiểm tra ổ đĩa, RAM, pin và nguồn.
- Công cụ khởi động, phục hồi, driver và thiết bị.
- Windows Defender, Firewall, Windows Update và bản quyền.
- Chẩn đoán, quản trị, máy in và các tiện ích hệ thống.
- Tạo báo cáo chẩn đoán tổng hợp trên Desktop.

## Chạy trực tiếp trên máy

### Dùng file BAT

Nhấp chuột phải vào `Tool_Windows.bat`, chọn **Run as administrator**.

### Dùng launcher PowerShell

Mở Windows PowerShell trong thư mục dự án và chạy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-JoITWindowsTool.ps1
```

## Triển khai lên GitHub Pages

1. Tạo repository public trên GitHub, ví dụ `joit-windows-tool`.
2. Đưa toàn bộ năm file trong thư mục này lên thư mục gốc của nhánh `main`.
3. Vào **Settings → Pages**.
4. Chọn **Deploy from a branch**, nhánh `main`, thư mục `/ (root)`.
5. Trong **Custom domain**, nhập `win.syscare.site` và lưu.
6. Tại nơi quản lý DNS của `syscare.site`, tạo bản ghi:

   | Type | Host | Value | TTL |
   |---|---|---|---|
   | CNAME | `win` | `TEN_GITHUB.github.io` | Auto hoặc 300 |

7. Thay `TEN_GITHUB` bằng đúng tên tài khoản GitHub. Không thêm `https://` hoặc tên repository vào giá trị CNAME.
8. Khi GitHub xác nhận DNS hợp lệ, bật **Enforce HTTPS**.

GitHub có thể tự tạo file `CNAME` khi lưu custom domain. Nếu tạo thủ công, file `CNAME` chỉ chứa một dòng:

```text
win.syscare.site
```

## Kiểm tra trước khi chạy

Đầu tiên chỉ tải nội dung để kiểm tra, chưa thực thi:

```powershell
$code = [string](irm https://win.syscare.site)
$code.Substring(0, [Math]::Min(500, $code.Length))
```

Nội dung phải bắt đầu bằng `#requires -Version 5.1`, không phải trang HTML hoặc lỗi 404.

Sau khi kiểm tra, chạy tool bằng câu lệnh chính thức:

```powershell
irm https://win.syscare.site | iex
```

Nếu đang ở Command Prompt:

```bat
powershell -NoProfile -Command "irm https://win.syscare.site | iex"
```

## Cập nhật tool

Launcher đang chứa toàn bộ `Tool_Windows.bat` ở dạng nén. Vì vậy, sau khi sửa BAT phải tạo lại launcher và cập nhật đồng thời ba file:

```text
Tool_Windows.bat
Invoke-JoITWindowsTool.ps1
index.html
```

`index.html` phải luôn giống hoàn toàn `Invoke-JoITWindowsTool.ps1`.

## SHA-256 phiên bản hiện tại

```text
Invoke-JoITWindowsTool.ps1
48292C15AB88D7A0015727BAF55A078573B4B266DF36BA4DAD2124AB6D584A7E

Tool_Windows.bat
8C0B68A9EE775C4449C4831188C0E7EA3B74D383C43A34998F232484CD53DFA7
```

Tính lại mã kiểm tra sau khi cập nhật:

```powershell
Get-FileHash .\Invoke-JoITWindowsTool.ps1 -Algorithm SHA256
Get-FileHash .\Tool_Windows.bat -Algorithm SHA256
```

## Lưu ý bảo mật

Lệnh `irm ... | iex` tải và chạy mã từ Internet với quyền cao. Chỉ sử dụng URL do chính bạn quản lý, bật MFA cho GitHub, giới hạn quyền ghi repository và luôn kiểm tra nội dung trước khi phát hành.
