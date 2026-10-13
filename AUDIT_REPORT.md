# Báo cáo rà soát Syscare Windows Tool

Ngày rà soát gần nhất: 2026-10-13  
Phiên bản đầu vào: 2.3.0  
Phiên bản sau cập nhật: 2.4.0

## Kết luận

Bản 2.3.0 đã hoàn thiện nhóm chức năng Driver, Asset Specs, BitLocker, M365 Cache và Domain Repair. Để tiến tới phiên bản toàn diện nhất (v2.4.0) đáp ứng 100% các tình huống Helpdesk và Quản trị Hạ tầng thường gặp tại doanh nghiệp, đợt rà soát này đã phát hiện và xử lý tiếp 7 tác vụ nghiệp vụ quan trọng:
1. Sửa lỗi ô Search và Start Menu bị đơ trên Windows 10/11.
2. Dọn dẹp rác hệ thống sâu 1-Click (giải phóng dung lượng ổ C: và báo cáo số MB/GB).
3. Bật/Tắt Fast Startup (Khởi động nhanh & Hibernation) xử lý triệt để lỗi sleep/nóng máy của laptop.
4. Kiểm tra bản quyền chi tiết Windows (kênh OEM/Retail/Volume) và Microsoft Office (`ospp.vbs`).
5. Quản lý tài khoản cục bộ, Bật/Tắt tài khoản Built-in Administrator và mở `lusrmgr.msc`.
6. Đổi tên máy tính chuẩn NetBIOS IT (`Rename-Computer`) có hẹn lịch reboot.
7. Bật/Tắt Remote Desktop (RDP) và tự động mở/đóng cổng Firewall 3389.

## Phát hiện và xử lý (GAP ANALYSIS v2.4.0)

| Mức | Phát hiện | Ảnh hưởng | Xử lý tại v2.4.0 |
|---|---|---|---|
| Cao | Ô Search trên Taskbar hoặc Start Menu thường xuyên bị đơ/treo | Người dùng không tìm được ứng dụng hoặc file làm việc | Tự động restart dịch vụ `WSearch`, kết thúc tiến trình `SearchHost` |
| Cao | Ổ đĩa C: báo đỏ/đầy dung lượng làm máy chậm và không update được | User bị tràn ổ đĩa, tốn thời gian dọn dẹp thủ công | 1-Click Deep Clean an toàn `%TEMP%`, `Prefetch`, Update cache và Thùng rác |
| Cao | Fast Startup gây lỗi nóng laptop khi gập máy hoặc đen màn hình | Lỗi driver nguồn/ACPI phổ biến trên Dell, ThinkPad, HP | Thêm tùy chọn 1-click Bật / Tắt Fast Startup (`powercfg /h off\|on`) |
| Cao | Bản quyền Office 365 theo năm không nhận diện được; thiếu kiểm định crack chuyên sâu | Máy tính doanh nghiệp dùng M365 bị sót bản quyền, IT không phát hiện được tool kích hoạt lậu | Tích hợp vNext token parser (Email/Tenant/Expiry) và bộ 10 tiêu chí kiểm định Crack chuẩn ITSO kèm xuất HTML |
| Trung bình | Quên mật khẩu cục bộ, tài khoản Administrator bị khóa | IT mất thời gian gõ lệnh tay ngoài command prompt | Thêm menu quản lý user cục bộ, bật/tắt Built-in Admin và đổi pass |
| Trung bình | Đổi tên máy tính khi bàn giao máy mới tốn nhiều bước | Tên máy không chuẩn quy ước công ty, khó quản lý | Tích hợp `Rename-Computer` kiểm tra chuẩn 15 ký tự và hẹn reboot |
| Thấp | Remote Desktop bị tắt hoặc tường lửa chặn cổng 3389 | IT không thể remote hỗ trợ người dùng qua LAN | Thêm 1-click Bật / Tắt RDP qua Registry và mở Firewall 3389 |

## Phát hiện và xử lý lịch sử (v2.3.0)

| Mức | Phát hiện | Ảnh hưởng | Xử lý tại v2.3.0 |
|---|---|---|---|
| Cao | Thiếu công cụ sao lưu và khôi phục Driver OEM | Cài lại Windows mất nhiều thời gian tìm driver hãng | Thêm Export Driver tự động và cài đặt hàng loạt bằng `pnputil` |
| Cao | Không có cơ chế gỡ driver bên thứ ba xung đột | Lỗi màn hình xanh (BSOD) do driver khó xử lý nhanh | Thêm danh sách OEM driver và gỡ bỏ theo Published Name |
| Cao | Nguy cơ khóa máy khi can thiệp BIOS/phần cứng | Mất mã BitLocker Recovery dẫn đến kẹt ổ đĩa | Thêm trích xuất an toàn Recovery Key 48 ký tự ra TXT |
| Cao | Lỗi mất tin cậy Domain làm user không đăng nhập được | IT phải gỡ máy ra khỏi domain và join lại | Thêm quy trình tự sửa kênh bảo mật `Test-ComputerSecureChannel -Repair` |
| Trung bình | M365/Teams/Outlook thường xuyên loop xác thực/treo | Tốn thời gian xóa profile và cấu hình lại thủ công | Tự đóng tiến trình và dọn dẹp OneAuth, RoamCache, Teams cache |
| Trung bình | Nhập cấu hình phần cứng vào ticket SLA thủ công | Mất thời gian gõ Serial/CPU/RAM, dễ sai sót | Thêm Asset Specs, xuất 1 dòng và tự copy vào Clipboard |
| Trung bình | Mất cấu hình Wi-Fi nội bộ khi chuyển máy | Phải nhập lại key bảo mật nội bộ | Thêm sao lưu & nạp lại profile Wi-Fi bằng `netsh wlan` |
| Thấp | Truy cập Credential Manager mất nhiều thao tác | Khó xử lý mật khẩu mạng lưu cũ bị kẹt | Tích hợp mở trực tiếp `keymgr.dll` và Windows Credential Manager |

## Phát hiện và xử lý lịch sử (v2.0.0 - v2.2.0)

| Mức | Phát hiện | Ảnh hưởng | Xử lý |
|---|---|---|---|
| Cao | Không có one-click triage | Mất thời gian đi qua nhiều menu, kết quả không đồng nhất | Thêm Quick Triage và kết luận PASS/ATTENTION |
| Cao | Không có audit/session log | Khó chứng minh thời gian và tác vụ đã thực hiện | Tự ghi log mọi action tại ProgramData |
| Cao | Thiếu AD/GPO/Kerberos/time | Chẩn đoán lỗi domain/share/login không đủ | Thêm secure channel, DC discovery, gpresult, klist, w32tm |
| Cao | Launcher chỉ kiểm tra payload BAT | Mô-đun mới có thể bị hỏng nếu không được kiểm tra | Launcher v2 xác minh SHA-256 cả BAT và Core |
| Trung bình | Báo cáo cũ ghi 01/17 nhưng kết thúc 18/18 | Gây nhầm trạng thái tiến trình | Thay bằng báo cáo có bước nhất quán và manifest |
| Trung bình | Báo cáo mặc định chạy SFC VerifyOnly | Tăng thời gian onsite dù chưa chắc cần | Tách thành Health Scan có xác nhận |
| Trung bình | Không có test host/port tùy chọn | Khó phân biệt DNS, route và firewall/service | Thêm Connectivity test an toàn bằng tham số PowerShell |
| Trung bình | Không có gói escalation | Phải gom file thủ công, dễ thiếu dữ liệu | Incident Bundle ZIP, privacy notice và SHA-256 |
| Trung bình | Quy trình cập nhật thủ công ba file | Dễ để BAT, launcher và index lệch phiên bản | Build-Release tự tạo toàn bộ artifact |
| Thấp | Không hiển thị phiên bản/session log | Khó xác nhận máy đang chạy release nào | Hiển thị phiên bản hiện hành và đường dẫn log tại menu chính |
| Trung bình | Không có hướng dẫn ngay trong menu | Người dùng mới khó chọn đúng quy trình, tăng thời gian onsite | Thêm mục `[H]` với bắt đầu nhanh, giới thiệu nhóm và gợi ý theo tình huống |
| Trung bình | `pause` không nói rõ sẽ quay về đâu | Dễ đóng nhầm cửa sổ hoặc tưởng tool đã treo | Thay bằng `B` về nhóm, `M` về menu chính, `0` thoát |
| Trung bình | `-- More --` không có giải thích | Người dùng không biết `Space`, `Enter` hoặc `Q` | Hiển thị hướng dẫn phân trang trước mọi danh sách dài |

## Kiểm soát rủi ro được giữ nguyên

- Administrator được kiểm tra trước khi vào menu.
- DHCP release/renew cảnh báo không dùng khi remote.
- TCP/IP reset cảnh báo IP tĩnh.
- Advanced Startup/reboot, full Defender scan, CHKDSK fix, clear print queue và restart Explorer đều có xác nhận.
- Tool không hiển thị Wi-Fi key và không tự tải tiện ích bên thứ ba.

## Rủi ro còn lại và khuyến nghị

1. `irm https://win.syscare.site | iex` bảo vệ tính toàn vẹn payload sau khi launcher đã tải, nhưng không chứng minh launcher online là bản do đúng người phát hành. Nên bật MFA, branch protection, review bắt buộc và ký Authenticode nếu dùng ở quy mô lớn.
2. Chưa tự động tải báo cáo lên ticket/cloud để tránh phát sinh luồng dữ liệu ngoài doanh nghiệp. Chỉ bổ sung khi có API, phân quyền, retention và phê duyệt bảo mật rõ ràng.
3. SMART/NVMe chi tiết có thể cần công cụ hãng hoặc API không đồng nhất. Bản hiện tại chỉ dùng cmdlet Windows có sẵn.
4. Các lệnh repair vẫn cần kỹ thuật viên đánh giá bối cảnh; công cụ không tự chạy chuỗi sửa phá vỡ mạng hoặc reboot.
5. Nên thử nghiệm trên ít nhất một máy Windows 10, một Windows 11, một máy domain-joined và một máy workgroup trước khi phát hành chính thức.

## Tiêu chí nghiệm thu đề xuất

- Menu không có `goto`/`call` tới nhãn không tồn tại.
- `Tool_Windows.bat` và Core nhúng trong launcher trùng byte với file nguồn.
- Hash launcher bằng hash `index.html`.
- Quick Triage tạo đủ summary TXT/JSON/HTML và privacy notice.
- Máy workgroup không báo lỗi cưỡng bức khi chạy Domain report.
- Incident Bundle tạo ZIP và SHA-256 manifest.
- Tác vụ SLA và lệnh cũ đều ghi session log.
- Người dùng từ chối xác nhận không làm thay đổi cấu hình.
