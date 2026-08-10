# Báo cáo kiểm thử bản phát hành 2.0.0

Ngày kiểm thử: 2026-08-05

## Kết quả tự động

| Kiểm tra | Kết quả |
|---|---|
| Nhãn BAT | 120 nhãn, không trùng |
| Tham chiếu `goto`/`call` | 113 tham chiếu, không thiếu đích |
| Menu `choice` | 27 menu, ký tự lựa chọn không trùng, `errorlevel` ánh xạ giảm dần đúng |
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
