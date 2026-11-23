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
        Write-Host '+=============================================================================================+' -ForegroundColor Cyan
        Write-Host ("|  SYSCARE / JoIT WINDOWS TOOL v{0,-6} - BO CONG CU QUAN TRI VA HA TANG IT DOANH NGHIEP      |" -f $Script:ToolVersion) -ForegroundColor Cyan
        Write-Host '+---------------------------------------------------------------------------------------------+' -ForegroundColor DarkCyan
        $dom = if ([string]::IsNullOrWhiteSpace($env:USERDNSDOMAIN)) { $env:USERDOMAIN } else { $env:USERDNSDOMAIN }
        $adminTag = if ($isAdmin) { '[ADMINISTRATOR: DA KICH HOAT]' } else { '[CANH BAO: CHUA NANG QUYEN ADMIN]' }
        Write-Host ("|  Thiet bi: {0,-14} | User: {1,-12} | Mien: {2,-15} | {3,-15}|" -f $env:COMPUTERNAME, $env:USERNAME, $dom, $adminTag) -ForegroundColor $(if ($isAdmin) { 'Green' } else { 'Yellow' })
        if (-not [string]::IsNullOrWhiteSpace($subTitle)) {
            Write-Host '+---------------------------------------------------------------------------------------------+' -ForegroundColor DarkCyan
            Write-Host ("|  CHUYEN DE: {0,-80}|" -f $subTitle) -ForegroundColor Yellow
        }
        Write-Host '+=============================================================================================+' -ForegroundColor Cyan
        Write-Host ''
    }

    function Pause-Console {
        Write-Host ''
        Write-Host ' [Nhan phim Enter de tiep tuc...]' -ForegroundColor DarkGray
        [void][Console]::ReadLine()
    }

    $running = $true
    while ($running) {
        Show-Banner 'MENU DIEU KHIEN CHINH (ENTERPRISE IT MANAGEMENT)'
        Write-Host '   [1] CHAN DOAN VA SLA QUICK TRIAGE      - Bao cao nhanh, Mang, Domain, Hieu nang, Gateway' -ForegroundColor White
        Write-Host '   [2] CLOUD IDENTITY VA MICROSOFT 365    - Entra ID, PRT Token, WAM Reset, Intune Sync' -ForegroundColor White
        Write-Host '   [3] MAY IN VA SCAN-TO-FOLDER SMB       - Toshiba e-STUDIO 3515AC/2508A, Sua RPC 0x11b' -ForegroundColor White
        Write-Host '   [4] QUAN LY DRIVER VA THIET BI         - Sao luu, Phuc hoi, Tu dong quet driver OEM' -ForegroundColor White
        Write-Host '   [5] BAN QUYEN VA KIEM DINH CRACK       - Chuan ITSO Enterprise Audit 10 tieu chi, M365' -ForegroundColor White
        Write-Host '   [6] THONG TIN TAI SAN VA BITLOCKER     - Specs 1 dong ticket, Trich xuat BitLocker Key' -ForegroundColor White
        Write-Host '   [7] BAO TRI VA TOI UU HE THONG         - Don dep sau C:, Sua Search/Start, Fast Startup' -ForegroundColor White
        Write-Host '   [8] QUAN TRI THIET BI VA HA TANG       - Local Admin, Doi ten may chuan IT, Mo RDP 3389' -ForegroundColor White
        Write-Host '   [9] BAO CAO SU CO VA ESCALATION        - Tao Incident Bundle ZIP (kem SHA-256), DISM/SFC' -ForegroundColor White
        Write-Host '   [0] THOAT KHOI CONG CU' -ForegroundColor Yellow
        Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
        
        $sel = (Read-Host ' Chon phan he lam viec [0-9]').Trim()
        switch ($sel) {
            '1' {
                $sub1 = $true
                while ($sub1) {
                    Show-Banner '[1] CHAN DOAN VA SLA QUICK TRIAGE'
                    Write-Host '   [1] Quick Triage report       - Bao cao nhanh co PASS/ATTENTION, JSON va HTML'
                    Write-Host '   [2] Network details report    - Chi tiet IP, DNS, Adapter, Gateway, Wi-Fi'
                    Write-Host '   [3] Domain details report     - DC, ping gateway/DNS, tin cay may tram'
                    Write-Host '   [4] Performance report        - CPU, RAM, Disk, Uptime, Top tien trinh'
                    Write-Host '   [5] Printer details report    - Hang doi in, cong, Spooler, driver da cai'
                    Write-Host '   [6] Connectivity test         - Kiem tra ket noi Gateway, DNS noi bo, Internet'
                    Write-Host '   [0] Quay lai Menu chinh' -ForegroundColor Yellow
                    Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
                    $c1 = (Read-Host ' Chon chuc nang [0-6]').Trim()
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
                    Show-Banner '[2] CLOUD IDENTITY, ENTRA ID VA MICROSOFT 365'
                    Write-Host '   [1] Chan doan toan dien Cloud Identity va Entra ID (dsregcmd /status, PRT, Intune)'
                    Write-Host '   [2] 1-Click Cuong che Dong bo chinh sach Intune / MDM (DeviceEnroller /urmgred)'
                    Write-Host '   [3] 1-Click Sua loi Blank Screen va Reset WAM (Microsoft.AAD.BrokerPlugin va Token)'
                    Write-Host '   [4] Mo cai dat tai khoan co quan Windows Settings (ms-settings:workplace)'
                    Write-Host '   [5] Xoa toan dien Cache Microsoft 365, Teams va Outlook RoamCache'
                    Write-Host '   [0] Quay lai Menu chinh' -ForegroundColor Yellow
                    Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
                    $c2 = (Read-Host ' Chon chuc nang [0-5]').Trim()
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
                    Show-Banner '[3] MAY IN, SCAN-TO-FOLDER SMB VA SUA LOI RPC'
                    Write-Host '   [1] Chuyen de Scan Toshiba e-STUDIO 3515AC va 2508A (SMB Signing, TopAccess guide)'
                    Write-Host '   [2] Quan ly cau hinh SMB Client, Ky so va Giao thuc SMB 1.0/2.0'
                    Write-Host '   [3] 1-Click Sua loi chia se may in mang LAN RPC 0x0000011b va 0x00000709'
                    Write-Host '   [4] Tro ly cai dat May in USB cuc bo'
                    Write-Host '   [5] Tro ly ket noi May in chia se qua Print Server/PC'
                    Write-Host '   [6] Tro ly ket noi May in qua dia chi IP rieng'
                    Write-Host '   [7] Tro ly tao thu muc Scan-to-folder va phan quyen SMB'
                    Write-Host '   [8] Xoa hang doi in bi ket (Clear Selected Queue)'
                    Write-Host '   [9] Khoi dong lai dich vu Print Spooler an toan'
                    Write-Host '   [0] Quay lai Menu chinh' -ForegroundColor Yellow
                    Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
                    $c3 = (Read-Host ' Chon chuc nang [0-9]').Trim()
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
                    Show-Banner '[4] QUAN LY DRIVER VA THIET BI PHAN CUNG'
                    Write-Host '   [1] Tu dong quet thiet bi thieu driver va mo trang tai driver OEM (Dell, HP, Lenovo...)'
                    Write-Host '   [2] Sao luu toan bo OEM Driver hien tai ra thu muc Desktop (pnputil /export-driver)'
                    Write-Host '   [3] Phuc hoi va cai dat driver hang loat tu thu muc sao luu'
                    Write-Host '   [4] Go bo driver ben thu ba xung dot (pnputil /delete-driver)'
                    Write-Host '   [0] Quay lai Menu chinh' -ForegroundColor Yellow
                    Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
                    $c4 = (Read-Host ' Chon chuc nang [0-4]').Trim()
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
                    Show-Banner '[5] BAN QUYEN WINDOWS, OFFICE 365 VA KIEM DINH CRACK (ITSO AUDIT)'
                    Write-Host '   [1] Kiem tra toan dien Ban quyen Windows, Office 365 va 10 tieu chi ITSO Crack Audit'
                    Write-Host '   [2] Xem thong tin chi tiet giay phep Windows (slmgr /dli)'
                    Write-Host '   [3] Xem thoi han het han ban quyen Windows (slmgr /xpr)'
                    Write-Host '   [0] Quay lai Menu chinh' -ForegroundColor Yellow
                    Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
                    $c5 = (Read-Host ' Chon chuc nang [0-3]').Trim()
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
                    Show-Banner '[6] THONG TIN TAI SAN PHAN CUNG VA BAO MAT BITLOCKER'
                    Write-Host '   [1] Trich xuat Thong tin Tai san 1 dong Ticket (Tu dong chep vao Clipboard)'
                    Write-Host '   [2] Kiem tra trang thai ma hoa BitLocker va chip bao mat TPM (Get-BitLockerVolume)'
                    Write-Host '   [3] Trich xuat an toan BitLocker Recovery Key 48 ky tu ra Desktop'
                    Write-Host '   [0] Quay lai Menu chinh' -ForegroundColor Yellow
                    Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
                    $c6 = (Read-Host ' Chon chuc nang [0-3]').Trim()
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
                    Show-Banner '[7] BAO TRI, DON DEP SAU C: VA TOI UU HE THONG'
                    Write-Host '   [1] Don dep he thong sau 1-Click (Xoa Temp, Prefetch, SoftwareDistribution, Recycle Bin)'
                    Write-Host '   [2] Sua loi Windows Search va Start Menu bi do hoac khong go duoc chu'
                    Write-Host '   [3] Bat / Tat Khoi dong nhanh Fast Startup va Hibernation (powercfg /h)'
                    Write-Host '   [4] Xoa bo nho dem DNS cache (ipconfig /flushdns)'
                    Write-Host '   [5] Dong bo lai thoi gian Windows Time voi may chu chuan (w32tm /resync)'
                    Write-Host '   [6] Khoi dong lai Windows Explorer (Taskbar va Desktop lam moi)'
                    Write-Host '   [0] Quay lai Menu chinh' -ForegroundColor Yellow
                    Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
                    $c7 = (Read-Host ' Chon chuc nang [0-6]').Trim()
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
                    Show-Banner '[8] QUAN TRI THIET BI, TAI KHOAN VA HA TANG MANG'
                    Write-Host '   [1] Quan ly Tai khoan cuc bo va Built-in Administrator (net user, lusrmgr)'
                    Write-Host '   [2] Doi ten may tinh chuan thiet bi IT (Rename-Computer)'
                    Write-Host '   [3] Bat / Tat Remote Desktop (RDP) va Mo cong Firewall 3389'
                    Write-Host '   [4] Sua loi quan he tin cay Domain Active Directory (nltest /sc_reset)'
                    Write-Host '   [5] Sao luu toan bo ho so mang Wi-Fi da luu ra thu muc Desktop'
                    Write-Host '   [6] Phuc hoi cau hinh Wi-Fi tu thu muc Desktop'
                    Write-Host '   [7] Mo trinh quan ly mat khau luu tru Windows (keymgr.dll)'
                    Write-Host '   [8] Mo trinh chinh sua Registry Editor (regedit.exe)'
                    Write-Host '   [9] Mo trinh quan ly Group Policy (gpedit.msc)'
                    Write-Host '   [0] Quay lai Menu chinh' -ForegroundColor Yellow
                    Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
                    $c8 = (Read-Host ' Chon chuc nang [0-9]').Trim()
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
                    Show-Banner '[9] BAO CAO SU CO, KIEM TRA HE THONG VA ESCALATION'
                    Write-Host '   [1] Tao goi su co nen ZIP day du kem ma bam SHA-256 de Escalation'
                    Write-Host '   [2] Quet kiem tra toan ven he thong DISM CheckHealth va SFC VerifyOnly'
                    Write-Host '   [3] Lap bien ban su co nhanh (Case Note) luu tai Desktop'
                    Write-Host '   [4] Mo thu muc ket qua Syscare Support tren Desktop'
                    Write-Host '   [5] Mo tep log phien lam viec hien hanh'
                    Write-Host '   [0] Quay lai Menu chinh' -ForegroundColor Yellow
                    Write-Host '---------------------------------------------------------------------------------------------' -ForegroundColor DarkGray
                    $c9 = (Read-Host ' Chon chuc nang [0-5]').Trim()
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
                Write-Host ' Cam on ban da su dung JoIT / Syscare Windows Tool! Tam biet.' -ForegroundColor Green
            }
            default { }
        }
    }
}
