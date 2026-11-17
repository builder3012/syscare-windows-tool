function Invoke-SyscareConsole {
    [CmdletBinding()]
    param()

    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $Host.UI.RawUI.WindowTitle = "JoIT / Syscare Windows Tool v$($Script:ToolVersion) - Modern PowerShell TUI"
    } catch { }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    function Show-Banner([string]$subTitle = '') {
        Clear-Host
        Write-Host '╔═════════════════════════════════════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
        Write-Host ("║  SYSCARE / JoIT WINDOWS TOOL v{0,-6} - BỘ CÔNG CỤ QUẢN TRỊ & HẠ TẦNG IT DOANH NGHIỆP      ║" -f $Script:ToolVersion) -ForegroundColor Cyan
        Write-Host '╠═════════════════════════════════════════════════════════════════════════════════════════════╣' -ForegroundColor DarkCyan
        $dom = if ([string]::IsNullOrWhiteSpace($env:USERDNSDOMAIN)) { $env:USERDOMAIN } else { $env:USERDNSDOMAIN }
        $adminTag = if ($isAdmin) { '[ADMINISTRATOR: ĐÃ KÍCH HOẠT]' } else { '[CẢNH BÁO: CHƯA NÂNG QUYỀN ADMIN]' }
        Write-Host ("║  Thiết bị: {0,-14} │ User: {1,-12} │ Miền: {2,-15} │ {3,-15}║" -f $env:COMPUTERNAME, $env:USERNAME, $dom, $adminTag) -ForegroundColor $(if ($isAdmin) { 'Green' } else { 'Yellow' })
        if (-not [string]::IsNullOrWhiteSpace($subTitle)) {
            Write-Host '╠═════════════════════════════════════════════════════════════════════════════════════════════╣' -ForegroundColor DarkCyan
            Write-Host ("║  CHUYÊN ĐỀ: {0,-81}║" -f $subTitle) -ForegroundColor Yellow
        }
        Write-Host '╚═════════════════════════════════════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
        Write-Host ''
    }

    function Pause-Console {
        Write-Host ''
        Write-Host ' [Nhấn phím Enter để tiếp tục...]' -ForegroundColor DarkGray
        [void][Console]::ReadLine()
    }

    $running = $true
    while ($running) {
        Show-Banner 'MENU ĐIỀU KHIỂN CHÍNH (ENTERPRISE IT MANAGEMENT)'
        Write-Host '   [1] CHẨN ĐOÁN & SLA QUICK TRIAGE       - Báo cáo nhanh, Mạng, Domain, Hiệu năng, Gateway' -ForegroundColor White
        Write-Host '   [2] CLOUD IDENTITY & MICROSOFT 365     - Entra ID, PRT Token, WAM Reset, Intune Sync' -ForegroundColor White
        Write-Host '   [3] MÁY IN & SCAN-TO-FOLDER SMB        - Toshiba e-STUDIO 3515AC/2508A, Sửa RPC 0x11b' -ForegroundColor White
        Write-Host '   [4] QUẢN LÝ DRIVER & THIẾT BỊ          - Sao lưu, Phục hồi, Tự động quét driver OEM' -ForegroundColor White
        Write-Host '   [5] BẢN QUYỀN & KIỂM ĐỊNH CRACK        - Chuẩn ITSO Enterprise Audit 10 tiêu chí, M365' -ForegroundColor White
        Write-Host '   [6] THÔNG TIN TÀI SẢN & BITLOCKER      - Specs 1 dòng ticket, Trích xuất BitLocker Key' -ForegroundColor White
        Write-Host '   [7] BẢO TRÌ & TỐI ƯU HỆ THỐNG          - Dọn dẹp sâu C:, Sửa Search/Start, Fast Startup' -ForegroundColor White
        Write-Host '   [8] QUẢN TRỊ THIẾT BỊ & HẠ TẦNG        - Local Admin, Đổi tên máy chuẩn IT, Mở RDP 3389' -ForegroundColor White
        Write-Host '   [9] BÁO CÁO SỰ CỐ & ESCALATION         - Tạo Incident Bundle ZIP (kèm SHA-256), DISM/SFC' -ForegroundColor White
        Write-Host '   [0] THOÁT KHỎI CÔNG CỤ' -ForegroundColor Yellow
        Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
        
        $sel = (Read-Host ' Chọn phân hệ làm việc [0-9]').Trim()
        switch ($sel) {
            '1' {
                $sub1 = $true
                while ($sub1) {
                    Show-Banner '[1] CHẨN ĐOÁN & SLA QUICK TRIAGE'
                    Write-Host '   [1] Quick Triage report       - Báo cáo nhanh có PASS/ATTENTION, JSON và HTML'
                    Write-Host '   [2] Network details report    - Chi tiết IP, DNS, Adapter, Gateway, Wi-Fi'
                    Write-Host '   [3] Domain details report     - DC, ping gateway/DNS, tin cậy máy trạm'
                    Write-Host '   [4] Performance report        - CPU, RAM, Disk, Uptime, Top tiến trình'
                    Write-Host '   [5] Printer details report    - Hàng đợi in, cổng, Spooler, driver đã cài'
                    Write-Host '   [6] Connectivity test         - Kiểm tra kết nối Gateway, DNS nội bộ, Internet'
                    Write-Host '   [0] Quay lại Menu chính' -ForegroundColor Yellow
                    Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
                    $c1 = (Read-Host ' Chọn chức năng [0-6]').Trim()
                    switch ($c1) {
                        '1' { Invoke-QuickTriage; Pause-Console }
                        '2' { Invoke-FocusedReport 'Network' { param($d) Save-NetworkDetails $d }; Pause-Console }
                        '3' { Invoke-FocusedReport 'Domain' { param($d) Save-DomainDetails $d }; Pause-Console }
                        '4' { Invoke-FocusedReport 'Performance' { param($d) Save-SystemDetails $d }; Pause-Console }
                        '5' { Invoke-FocusedReport 'Printer' { param($d) Save-PrinterDetails $d }; Pause-Console }
                        '6' { Invoke-ConnectivityTest; Pause-Console }
                        default { $sub1 = $false }
                    }
                }
            }
            '2' {
                $sub2 = $true
                while ($sub2) {
                    Show-Banner '[2] CLOUD IDENTITY, ENTRA ID & MICROSOFT 365'
                    Write-Host '   [1] Chẩn đoán toàn diện Cloud Identity & Entra ID (dsregcmd /status, PRT, Intune)'
                    Write-Host '   [2] 1-Click Cưỡng chế Đồng bộ chính sách Intune / MDM (DeviceEnroller /urmgred)'
                    Write-Host '   [3] 1-Click Sửa lỗi Blank Screen & Reset WAM (Microsoft.AAD.BrokerPlugin & Token)'
                    Write-Host '   [4] Mở cài đặt tài khoản cơ quan Windows Settings (ms-settings:workplace)'
                    Write-Host '   [5] Xóa toàn diện Cache Microsoft 365, Teams & Outlook RoamCache'
                    Write-Host '   [0] Quay lại Menu chính' -ForegroundColor Yellow
                    Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
                    $c2 = (Read-Host ' Chọn chức năng [0-5]').Trim()
                    switch ($c2) {
                        '1' { Invoke-CloudIdentitySuite; Pause-Console }
                        '2' {
                            try {
                                Write-Host ' Dang gui lenh dong bo Intune...' -ForegroundColor Gray
                                Start-Process -FilePath "$env:SystemRoot\system32\DeviceEnroller.exe" -ArgumentList '/c /urmgred' -NoNewWindow -Wait
                                Write-Host ' [THANH CONG] Da gui lenh dong bo MDM / Intune thanh cong.' -ForegroundColor Green
                            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
                            Pause-Console
                        }
                        '3' {
                            try {
                                $manifest = "$env:SystemRoot\SystemApps\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AppxManifest.xml"
                                if (Test-Path -LiteralPath $manifest) {
                                    Add-AppxPackage -Register $manifest -DisableDevelopmentMode -ForceApplicationShutdown -ErrorAction Stop
                                    Write-Host ' [THANH CONG] Da dang ky lai AAD BrokerPlugin!' -ForegroundColor Green
                                }
                            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
                            Pause-Console
                        }
                        '4' { try { Start-Process 'ms-settings:workplace' } catch { }; Pause-Console }
                        '5' { Invoke-ClearOfficeCache; Pause-Console }
                        default { $sub2 = $false }
                    }
                }
            }
            '3' {
                $sub3 = $true
                while ($sub3) {
                    Show-Banner '[3] MÁY IN, SCAN-TO-FOLDER SMB & SỬA LỖI RPC'
                    Write-Host '   [1] Chuyên đề Scan Toshiba e-STUDIO 3515AC & 2508A (SMB Signing, TopAccess guide)'
                    Write-Host '   [2] Quản lý cấu hình SMB Client, Ký số & Giao thức SMB 1.0/2.0'
                    Write-Host '   [3] 1-Click Sửa lỗi chia sẻ máy in mạng LAN RPC 0x0000011b & 0x00000709'
                    Write-Host '   [4] Trợ lý cài đặt Máy in USB cục bộ'
                    Write-Host '   [5] Trợ lý kết nối Máy in chia sẻ qua Print Server/PC'
                    Write-Host '   [6] Trợ lý kết nối Máy in qua địa chỉ IP riêng'
                    Write-Host '   [7] Trợ lý tạo thư mục Scan-to-folder và phân quyền SMB'
                    Write-Host '   [8] Xóa hàng đợi in bị kẹt (Clear Selected Queue)'
                    Write-Host '   [9] Khởi động lại dịch vụ Print Spooler an toàn'
                    Write-Host '   [0] Quay lại Menu chính' -ForegroundColor Yellow
                    Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
                    $c3 = (Read-Host ' Chọn chức năng [0-9]').Trim()
                    switch ($c3) {
                        '1' { Invoke-ToshibaScanSuite; Pause-Console }
                        '2' { Invoke-SmbSecurityConfig; Pause-Console }
                        '3' { Invoke-RpcPrintFix; Pause-Console }
                        '4' { Invoke-PrinterUsbAssist; Pause-Console }
                        '5' { Invoke-PrinterSharedAssist; Pause-Console }
                        '6' { Invoke-PrinterIpAssist; Pause-Console }
                        '7' { Invoke-ScanFolderAssist; Pause-Console }
                        '8' { Invoke-PrinterClearSelectedQueue; Pause-Console }
                        '9' { Invoke-PrinterRestartSpooler; Pause-Console }
                        default { $sub3 = $false }
                    }
                }
            }
            '4' {
                $sub4 = $true
                while ($sub4) {
                    Show-Banner '[4] QUẢN LÝ DRIVER & THIẾT BỊ PHẦN CỨNG'
                    Write-Host '   [1] Tự động quét thiết bị thiếu driver & mở trang tải driver OEM (Dell, HP, Lenovo...)'
                    Write-Host '   [2] Sao lưu toàn bộ OEM Driver hiện tại ra thư mục Desktop (pnputil /export-driver)'
                    Write-Host '   [3] Phục hồi và cài đặt driver hàng loạt từ thư mục sao lưu'
                    Write-Host '   [4] Gỡ bỏ driver bên thứ ba xung đột (pnputil /delete-driver)'
                    Write-Host '   [0] Quay lại Menu chính' -ForegroundColor Yellow
                    Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
                    $c4 = (Read-Host ' Chọn chức năng [0-4]').Trim()
                    switch ($c4) {
                        '1' { Invoke-DriverAutoScan; Pause-Console }
                        '2' { Invoke-DriverBackup -Destination $DriverFolder; Pause-Console }
                        '3' { Invoke-DriverRestore -SourceFolder $DriverFolder; Pause-Console }
                        '4' { Invoke-DriverUninstall -Name $DriverName -ForceUninstall:$Force; Pause-Console }
                        default { $sub4 = $false }
                    }
                }
            }
            '5' {
                $sub5 = $true
                while ($sub5) {
                    Show-Banner '[5] BẢN QUYỀN WINDOWS, OFFICE 365 & KIỂM ĐỊNH CRACK (ITSO AUDIT)'
                    Write-Host '   [1] Kiểm tra toàn diện Bản quyền Windows, Office 365 & 10 tiêu chí ITSO Crack Audit'
                    Write-Host '   [2] Xem thông tin chi tiết giấy phép Windows (slmgr /dli)'
                    Write-Host '   [3] Xem thời hạn hết hạn bản quyền Windows (slmgr /xpr)'
                    Write-Host '   [0] Quay lại Menu chính' -ForegroundColor Yellow
                    Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
                    $c5 = (Read-Host ' Chọn chức năng [0-3]').Trim()
                    switch ($c5) {
                        '1' { Invoke-LicenseCheck; Pause-Console }
                        '2' { & cscript.exe //nologo "$env:SystemRoot\system32\slmgr.vbs" /dli; Pause-Console }
                        '3' { & cscript.exe //nologo "$env:SystemRoot\system32\slmgr.vbs" /xpr; Pause-Console }
                        default { $sub5 = $false }
                    }
                }
            }
            '6' {
                $sub6 = $true
                while ($sub6) {
                    Show-Banner '[6] THÔNG TIN TÀI SẢN PHẦN CỨNG & BẢO MẬT BITLOCKER'
                    Write-Host '   [1] Trích xuất Thông tin Tài sản 1 dòng Ticket (Tự động chép vào Clipboard)'
                    Write-Host '   [2] Kiểm tra trạng thái mã hóa BitLocker & chip bảo mật TPM (Get-BitLockerVolume)'
                    Write-Host '   [3] Trích xuất an toàn BitLocker Recovery Key 48 ký tự ra Desktop'
                    Write-Host '   [0] Quay lại Menu chính' -ForegroundColor Yellow
                    Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
                    $c6 = (Read-Host ' Chọn chức năng [0-3]').Trim()
                    switch ($c6) {
                        '1' { Invoke-AssetSpecs; Pause-Console }
                        '2' { Invoke-BitLockerStatus; Pause-Console }
                        '3' { Invoke-BitLockerBackupKey; Pause-Console }
                        default { $sub6 = $false }
                    }
                }
            }
            '7' {
                $sub7 = $true
                while ($sub7) {
                    Show-Banner '[7] BẢO TRÌ, DỌN DẸP SÂU C: & TỐI ƯU HỆ THỐNG'
                    Write-Host '   [1] Dọn dẹp hệ thống sâu 1-Click (Xóa Temp, Prefetch, SoftwareDistribution, Recycle Bin)'
                    Write-Host '   [2] Sửa lỗi Windows Search & Start Menu bị đơ hoặc không gõ được chữ'
                    Write-Host '   [3] Bật / Tắt Khởi động nhanh Fast Startup & Hibernation (powercfg /h)'
                    Write-Host '   [4] Xóa bộ nhớ đệm DNS cache (ipconfig /flushdns)'
                    Write-Host '   [5] Đồng bộ lại thời gian Windows Time với máy chủ chuẩn (w32tm /resync)'
                    Write-Host '   [6] Khởi động lại Windows Explorer (Taskbar & Desktop làm mới)'
                    Write-Host '   [0] Quay lại Menu chính' -ForegroundColor Yellow
                    Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
                    $c7 = (Read-Host ' Chọn chức năng [0-6]').Trim()
                    switch ($c7) {
                        '1' { Invoke-DeepClean; Pause-Console }
                        '2' { Invoke-SearchFix; Pause-Console }
                        '3' { Invoke-FastStartupToggle; Pause-Console }
                        '4' { & ipconfig.exe /flushdns; Pause-Console }
                        '5' { & w32tm.exe /resync /rediscover; Pause-Console }
                        '6' {
                            Write-Host ' Dang khoi dong lai Windows Explorer...' -ForegroundColor Gray
                            & taskkill.exe /F /IM explorer.exe 2>&1 | Out-Null
                            Start-Process 'explorer.exe'
                            Write-Host ' [THANH CONG] Windows Explorer da duoc khoi dong lai.' -ForegroundColor Green
                            Pause-Console
                        }
                        default { $sub7 = $false }
                    }
                }
            }
            '8' {
                $sub8 = $true
                while ($sub8) {
                    Show-Banner '[8] QUẢN TRỊ THIẾT BỊ, TÀI KHOẢN & HẠ TẦNG MẠNG'
                    Write-Host '   [1] Quản lý Tài khoản cục bộ & Built-in Administrator (net user, lusrmgr)'
                    Write-Host '   [2] Đổi tên máy tính chuẩn thiết bị IT (Rename-Computer)'
                    Write-Host '   [3] Bật / Tắt Remote Desktop (RDP) & Mở cổng Firewall 3389'
                    Write-Host '   [4] Sửa lỗi quan hệ tin cậy Domain Active Directory (nltest /sc_reset)'
                    Write-Host '   [5] Sao lưu toàn bộ hồ sơ mạng Wi-Fi đã lưu ra thư mục Desktop'
                    Write-Host '   [6] Phục hồi cấu hình Wi-Fi từ thư mục Desktop'
                    Write-Host '   [7] Mở trình quản lý mật khẩu lưu trữ Windows (keymgr.dll)'
                    Write-Host '   [8] Mở trình chỉnh sửa Registry Editor (regedit.exe)'
                    Write-Host '   [9] Mở trình quản lý Group Policy (gpedit.msc)'
                    Write-Host '   [0] Quay lại Menu chính' -ForegroundColor Yellow
                    Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
                    $c8 = (Read-Host ' Chọn chức năng [0-9]').Trim()
                    switch ($c8) {
                        '1' { Invoke-LocalUserAdmin; Pause-Console }
                        '2' { Invoke-RenamePC; Pause-Console }
                        '3' { Invoke-ToggleRDP; Pause-Console }
                        '4' { Invoke-DomainRepair; Pause-Console }
                        '5' { Invoke-WiFiProfileBackup -Destination $WiFiFolder; Pause-Console }
                        '6' { Invoke-WiFiProfileRestore -SourceFolder $WiFiFolder; Pause-Console }
                        '7' { try { Start-Process 'rundll32.exe' 'keymgr.dll,KRShowKeyMgr' } catch { }; Pause-Console }
                        '8' { try { Start-Process 'regedit.exe' } catch { }; Pause-Console }
                        '9' { try { Start-Process 'gpedit.msc' } catch { }; Pause-Console }
                        default { $sub8 = $false }
                    }
                }
            }
            '9' {
                $sub9 = $true
                while ($sub9) {
                    Show-Banner '[9] BÁO CÁO SỰ CỐ, KIỂM TRA HỆ THỐNG & ESCALATION'
                    Write-Host '   [1] Tạo gói sự cố nén ZIP đầy đủ kèm mã băm SHA-256 để Escalation'
                    Write-Host '   [2] Quét kiểm tra toàn vẹn hệ thống DISM CheckHealth & SFC VerifyOnly'
                    Write-Host '   [3] Lập biên bản sự cố nhanh (Case Note) lưu tại Desktop'
                    Write-Host '   [4] Mở thư mục kết quả Syscare Support trên Desktop'
                    Write-Host '   [5] Mở tệp log phiên làm việc hiện hành'
                    Write-Host '   [0] Quay lại Menu chính' -ForegroundColor Yellow
                    Write-Host '─────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
                    $c9 = (Read-Host ' Chọn chức năng [0-5]').Trim()
                    switch ($c9) {
                        '1' { Invoke-IncidentBundle; Pause-Console }
                        '2' { Invoke-HealthScan; Pause-Console }
                        '3' { New-CaseNote; Pause-Console }
                        '4' { try { Start-Process 'explorer.exe' $OutputRoot } catch { }; Pause-Console }
                        '5' {
                            if (-not [string]::IsNullOrWhiteSpace($SessionLog) -and (Test-Path -LiteralPath $SessionLog)) {
                                try { Start-Process 'notepad.exe' $SessionLog } catch { }
                            } else {
                                Write-Host ' [THONG BAO] Chua co log phien lam viec trong session nay.' -ForegroundColor Yellow
                            }
                            Pause-Console
                        }
                        default { $sub9 = $false }
                    }
                }
            }
            '0' {
                $running = $false
                Write-Host ' Cảm ơn bạn đã sử dụng JoIT / Syscare Windows Tool! Tạm biệt.' -ForegroundColor Green
            }
            default { }
        }
    }
}
