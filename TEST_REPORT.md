# Báo cáo kiểm thử bản phát hành 2.2.0

## Phần mở rộng máy in và scan (2026-10-09)

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
