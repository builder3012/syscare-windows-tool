# Báo cáo rà soát Syscare Windows Tool

Ngày rà soát gần nhất: 2026-08-10  
Phiên bản đầu vào: 1.0.0  
Phiên bản sau cập nhật: 2.1.0

## Kết luận

Bản 1.0.0 có cấu trúc menu rõ, đầy đủ nhóm lệnh Windows cơ bản và đã có xác nhận ở các thao tác dễ gây gián đoạn. Tuy nhiên, công cụ thiên về “hộp lệnh” hơn là quy trình helpdesk theo SLA: kỹ thuật viên phải mở nhiều mục riêng, không có timeline thao tác, thiếu chẩn đoán domain và đầu ra escalation chưa chuẩn hóa.

Bản 2.0.0 giữ nguyên các chức năng cũ, bổ sung lớp chẩn đoán–bằng chứng–ticket để rút ngắn thời gian xác định nguyên nhân và chuyển cấp. Bản 2.1.0 hoàn thiện trải nghiệm tại hiện trường: hướng dẫn nằm ngay trong tool, mọi tác vụ có đích quay lại rõ ràng và màn hình phân trang giải thích phím sử dụng trước khi chạy.

## Phát hiện và xử lý

| Mức | Phát hiện | Ảnh hưởng | Xử lý đến v2.1.0 |
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
