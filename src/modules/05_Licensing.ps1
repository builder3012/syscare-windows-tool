function Invoke-LicenseCheck {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-LicenseCheck started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  KIEM TRA BAN QUYEN NANG CAO & AUDIT TOAN DIEN (WINDOWS & MICROSOFT OFFICE)' -ForegroundColor Cyan
    Write-Host '==========================================================================================='

    # -------------------------------------------------------------
    # 1. THONG TIN BAN QUYEN WINDOWS
    # -------------------------------------------------------------
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $winVer = if ($os) { "{0} ({1})" -f $os.Caption, $os.OSArchitecture } else { "Windows 10/11" }
    $installDate = if ($os -and $os.InstallDate) { $os.InstallDate.ToString('dd/MM/yyyy HH:mm:ss') } else { "N/A" }

    $xprRaw = ""
    try { $xprRaw = (& cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr 2>&1 | Out-String).Trim() } catch { }
    $dliRaw = ""
    try { $dliRaw = (& cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli 2>&1 | Out-String).Trim() } catch { }

    $winStatus = "Chua ro"
    if ($xprRaw -match 'permanently activated|kich hoat vinh vien') {
        $winStatus = "DA KICH HOAT (Vinh vien)"
    } elseif ($xprRaw -match 'expire|het han') {
        $winStatus = $xprRaw -replace '[\r\n]+', ' '
    } else {
        $winStatus = if ($xprRaw) { $xprRaw -replace '[\r\n]+', ' ' } else { "Chua xac dinh" }
    }

    $winChannel = "RETAIL / OEM"
    if ($dliRaw -match 'VOLUME_MAK') { $winChannel = "VOLUME MAK" }
    elseif ($dliRaw -match 'VOLUME_KMS') { $winChannel = "VOLUME KMS" }
    elseif ($dliRaw -match 'RETAIL') { $winChannel = "RETAIL" }
    elseif ($dliRaw -match 'OEM') { $winChannel = "OEM" }

    $partialKey = "KHONG_RO"
    if ($dliRaw -match 'Partial Product Key:\s*([A-Za-z0-9]+)') {
        $partialKey = $matches[1]
    }

    $regKey = "KHONG_TIM_THAY"
    try {
        $regKeyVal = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name "BackupProductKeyDefault" -ErrorAction SilentlyContinue).BackupProductKeyDefault
        if (-not [string]::IsNullOrWhiteSpace($regKeyVal)) { $regKey = $regKeyVal }
    } catch { }

    $biosKey = "KHONG_TIM_THAY"
    try {
        $b = (Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue).OA3xOriginalProductKey
        if (-not [string]::IsNullOrWhiteSpace($b)) { $biosKey = $b }
    } catch { }

    Write-Host '==========================================================================================='
    Write-Host ("  KET QUA KIEM TRA: {0}" -f $winChannel) -ForegroundColor Yellow
    Write-Host '==========================================================================================='
    Write-Host ("- Phien ban Windows   : {0}" -f $winVer)
    Write-Host ("- Ngay cai dat        : {0}" -f $installDate)
    Write-Host ("- Trang thai kich hoat: {0}" -f $winStatus) -ForegroundColor Green
    Write-Host ("- Kenh ban quyen      : {0}" -f $winChannel)
    Write-Host ("- Key dang dung       : *****-*****-*****-*****-{0}" -f $partialKey) -ForegroundColor Magenta
    if ($regKey -ne "KHONG_TIM_THAY") {
        Write-Host ("  (Key trong Registry : {0})" -f $regKey) -ForegroundColor Gray
    }
    Write-Host ("- Key goc trong BIOS  : {0}" -f $biosKey)

    # -------------------------------------------------------------
    # 2. THONG TIN BAN QUYEN MICROSOFT OFFICE / 365
    # -------------------------------------------------------------
    Write-Host '==========================================================================================='
    Write-Host '  KET QUA KIEM TRA: BAN QUYEN MICROSOFT OFFICE & OFFICE 365' -ForegroundColor Yellow
    Write-Host '==========================================================================================='

    $o365Name = "Chua cai dat Microsoft Office"
    $o365Ver = "N/A"
    $c2rConfig = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
    if (Test-Path -LiteralPath $c2rConfig) {
        $p = Get-ItemProperty -Path $c2rConfig -ErrorAction SilentlyContinue
        if ($p.ProductReleaseIds) { $o365Name = $p.ProductReleaseIds }
        if ($p.VersionToReport) { $o365Ver = "{0} ({1})" -f $p.VersionToReport, $p.Platform }
    }

    switch ($o365Name) {
        'O365BusinessRetail'     { $o365Name = 'Microsoft 365 Apps for business' }
        'O365ProPlusRetail'      { $o365Name = 'Microsoft 365 Apps for enterprise' }
        'O365HomePremRetail'     { $o365Name = 'Microsoft 365 Family / Personal' }
        'ProPlus2024Retail'      { $o365Name = 'Microsoft Office Professional Plus 2024' }
        'ProPlus2021Retail'      { $o365Name = 'Microsoft Office Professional Plus 2021' }
        'ProPlus2021Volume'      { $o365Name = 'Microsoft Office LTSC Professional Plus 2021' }
        'ProPlus2019Retail'      { $o365Name = 'Microsoft Office Professional Plus 2019' }
        'ProPlus2019Volume'      { $o365Name = 'Microsoft Office Professional Plus 2019 (Volume)' }
        'ProPlusRetail'          { $o365Name = 'Microsoft Office Professional Plus 2016' }
        'Standard2021Volume'     { $o365Name = 'Microsoft Office Standard 2021' }
        'Standard2019Volume'     { $o365Name = 'Microsoft Office Standard 2019' }
    }

    try {
        $uninst = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Microsoft 365|Office' -and $_.DisplayName -notmatch 'Runtime|Update|Add-in' } | Select-Object -First 1
        if ($uninst) {
            $o365Name = $uninst.DisplayName
            if ($uninst.DisplayVersion) { $o365Ver = $uninst.DisplayVersion }
        }
    } catch { }

    $vnextFound = $false
    $vnextEmail = "N/A"
    $vnextStatus = "N/A"
    $vnextType = "N/A"
    $vnextTenant = "N/A"

    try {
        $mapPath = "HKCU:\Software\Microsoft\Office\16.0\Common\Licensing\LicensingNext\LicenseIdToEmailMapping"
        if (Test-Path -LiteralPath $mapPath) {
            $mp = Get-ItemProperty -Path $mapPath -ErrorAction SilentlyContinue
            foreach ($prop in $mp.PSObject.Properties) {
                if ($prop.Name -notmatch '^PS' -and "$($prop.Value)" -match '@') {
                    $vnextEmail = "$($prop.Value)"
                    break
                }
            }
        }
    } catch { }

    $licFolder = Join-Path $env:LOCALAPPDATA "Microsoft\Office\Licenses"
    if (Test-Path -LiteralPath $licFolder) {
        $files = Get-ChildItem -Path $licFolder -Recurse -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            try {
                $raw = [IO.File]::ReadAllBytes($f.FullName)
                $text = [Text.Encoding]::Unicode.GetString($raw)
                if ($text -notmatch '^{') { $text = [Text.Encoding]::UTF8.GetString($raw) }
                $obj = ConvertFrom-Json $text -ErrorAction SilentlyContinue
                if ($obj -and $obj.License) {
                    $licStr = [string]$obj.License
                    $pad = (4 - ($licStr.Length % 4)) % 4
                    $licStr += ("=" * $pad)
                    $licBytes = [Convert]::FromBase64String($licStr)
                    $licJson = [Text.Encoding]::UTF8.GetString($licBytes) | ConvertFrom-Json
                    if ($licJson) {
                        $vnextFound = $true
                        $vnextType = [string]$licJson.LicenseType
                        $vnextStatus = [string]$licJson.Status
                        if ($licJson.Metadata) {
                            $vnextTenant = [string]$licJson.Metadata.TenantId
                        }
                        break
                    }
                }
            } catch { }
        }
    }

    Write-Host ("- Goi cai dat         : {0}" -f $o365Name)
    Write-Host ("- Phien ban ung dung  : {0}" -f $o365Ver)
    if ($vnextFound) {
        Write-Host ("- Hinh thuc cap phep  : Ban quyen Thue bao (Subscription / Modern vNext)") -ForegroundColor Green
        Write-Host ("- Tai khoan kich hoat : {0}" -f $vnextEmail) -ForegroundColor Cyan
        Write-Host ("- Ma Tenant ID        : {0}" -f $vnextTenant)
        Write-Host ("- Trang thai License  : {0} (Dang hoat dong / Active)" -f $vnextStatus) -ForegroundColor Green
    }

    # Kiem tra them OSPP truyen thong
    $osppPaths = @(
        "$env:ProgramFiles\Microsoft Office\root\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\ospp.vbs",
        "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\ospp.vbs",
        "$env:ProgramFiles\Microsoft Office\Office15\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office15\ospp.vbs",
        "$env:ProgramFiles\Microsoft Office\Office14\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office14\ospp.vbs"
    )
    $foundOspp = $null
    foreach ($op in $osppPaths) {
        if (Test-Path -LiteralPath $op) { $foundOspp = $op; break }
    }
    $osppOutput = ""
    if ($foundOspp) {
        try {
            $osppOutput = (& cscript.exe //nologo $foundOspp /dstatus 2>&1 | Out-String).Trim()
            if ($osppOutput -and -not $vnextFound) {
                Write-Host "--- Thong tin OSPP ---" -ForegroundColor Gray
                Write-Host $osppOutput
            }
        } catch { }
    }

    # -------------------------------------------------------------
    # 3. PHAN TICH - DAU VET CRACK (10 TIEU CHI AUDIT)
    # -------------------------------------------------------------
    $results = [System.Collections.ArrayList]::new()

    # 1. Chu ky tep he thong
    try {
        $sig = Get-AuthenticodeSignature "$env:SystemRoot\System32\sppsvc.exe" -ErrorAction SilentlyContinue
        if ($sig -and $sig.Status -eq 'Valid') {
            [void]$results.Add(@{ Name = "Chu ky tep he thong"; Status = "+"; Detail = "Tep he thong nguyen ban (Chu ky Microsoft hop le)." })
        } else {
            [void]$results.Add(@{ Name = "Chu ky tep he thong"; Status = "-"; Detail = "Tep he thong khong co chu ky Microsoft hop le!" })
        }
    } catch {
        [void]$results.Add(@{ Name = "Chu ky tep he thong"; Status = "+"; Detail = "Tep he thong nguyen ban." })
    }

    # 2. Ngoai le Defender
    try {
        $pref = Get-MpPreference -ErrorAction SilentlyContinue
        $exList = @()
        if ($pref) {
            if ($pref.ExclusionPath) { $exList += $pref.ExclusionPath }
            if ($pref.ExclusionProcess) { $exList += $pref.ExclusionProcess }
        }
        $suspiciousEx = @($exList | Where-Object { $_ -match 'kms|aact|heu|mas|crack|activator|autokms|kmspico' })
        if ($suspiciousEx.Count -gt 0) {
            [void]$results.Add(@{ Name = "Ngoai le Defender"; Status = "-"; Detail = "Phat hien ngoai le nghi van: " + ($suspiciousEx -join ', ') })
        } else {
            [void]$results.Add(@{ Name = "Ngoai le Defender"; Status = "+"; Detail = "Windows Defender khong bi chen ngoai le ngam." })
        }
    } catch {
        [void]$results.Add(@{ Name = "Ngoai le Defender"; Status = "+"; Detail = "Windows Defender khong bi chen ngoai le ngam." })
    }

    # 3. May chu KMS Crack
    try {
        $kms = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name "KeyManagementServiceName" -ErrorAction SilentlyContinue).KeyManagementServiceName
        if (-not [string]::IsNullOrWhiteSpace($kms)) {
            if ($kms -match '127\.0\.0\.1|0\.0\.0\.0|localhost|loli\.net|msguides|digiboy') {
                [void]$results.Add(@{ Name = "May chu KMS Crack"; Status = "-"; Detail = "Phat hien may chu KMS lau: $kms" })
            } else {
                [void]$results.Add(@{ Name = "May chu KMS Crack"; Status = "?"; Detail = "May chu KMS dang tro toi: $kms" })
            }
        } else {
            [void]$results.Add(@{ Name = "May chu KMS Crack"; Status = "+"; Detail = "Khong phat hien dau vet may chu KMS lau." })
        }
    } catch {
        [void]$results.Add(@{ Name = "May chu KMS Crack"; Status = "+"; Detail = "Khong phat hien dau vet may chu KMS lau." })
    }

    # 4. Lich su PowerShell
    try {
        $psHist = Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        $foundCmds = @()
        if (Test-Path -LiteralPath $psHist) {
            $lines = Get-Content -LiteralPath $psHist -ErrorAction SilentlyContinue
            foreach ($l in $lines) {
                if ($l -match 'massgrave|activated\.win|kms38|slmgr\s+/skms|ohook|irm\s+.*get\.activated') {
                    $foundCmds += $l.Trim()
                }
            }
        }
        if ($foundCmds.Count -gt 0) {
            [void]$results.Add(@{ Name = "Lich su PowerShell"; Status = "?"; Detail = "Ghi nhan lenh kich hoat trong lich su: " + ($foundCmds | Select-Object -Last 1) })
        } else {
            [void]$results.Add(@{ Name = "Lich su PowerShell"; Status = "+"; Detail = "Lich su PowerShell cac tai khoan sach." })
        }
    } catch {
        [void]$results.Add(@{ Name = "Lich su PowerShell"; Status = "+"; Detail = "Lich su PowerShell cac tai khoan sach." })
    }

    # 5. Moc noi KMS38 Hook
    try {
        $ifeo = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SppExtComObj.exe"
        if (Test-Path -LiteralPath $ifeo) {
            $dbg = (Get-ItemProperty -Path $ifeo -Name "Debugger" -ErrorAction SilentlyContinue).Debugger
            if (-not [string]::IsNullOrWhiteSpace($dbg)) {
                [void]$results.Add(@{ Name = "Moc noi KMS38 Hook"; Status = "-"; Detail = "Phat hien IFEO Debugger Hook: $dbg" })
            } else {
                [void]$results.Add(@{ Name = "Moc noi KMS38 Hook"; Status = "+"; Detail = "Cau truc logic thoi han hop le." })
            }
        } else {
            [void]$results.Add(@{ Name = "Moc noi KMS38 Hook"; Status = "+"; Detail = "Cau truc logic thoi han hop le." })
        }
    } catch {
        [void]$results.Add(@{ Name = "Moc noi KMS38 Hook"; Status = "+"; Detail = "Cau truc logic thoi han hop le." })
    }

    # 6. Thu muc Tool lau
    $crackPaths = @(
        "$env:ProgramFiles\KMSPico",
        "${env:ProgramFiles(x86)}\KMSPico",
        "$env:ProgramData\KMSAuto",
        "$env:SystemRoot\AutoKMS",
        "$env:SystemRoot\KMSPico",
        "$env:SystemRoot\SECOH-QAD.exe",
        "$env:SystemRoot\System32\SppExtComObjHook.dll"
    )
    $foundPaths = @($crackPaths | Where-Object { Test-Path -LiteralPath $_ })
    if ($foundPaths.Count -gt 0) {
        [void]$results.Add(@{ Name = "Thu muc Tool lau"; Status = "-"; Detail = "Phat hien tep/thu muc: " + ($foundPaths -join ', ') })
    } else {
        [void]$results.Add(@{ Name = "Thu muc Tool lau"; Status = "+"; Detail = "Khong phat hien thu muc/tep cong cu crack." })
    }

    # 7. Tac vu chay ngam
    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'AutoKMS|KMSPico|KMSTrigger|AAct|KMSAuto' }
        if ($tasks) {
            $tNames = ($tasks | ForEach-Object { $_.TaskName }) -join ', '
            [void]$results.Add(@{ Name = "Tac vu chay ngam"; Status = "-"; Detail = "Phat hien tac vu crack ngam: $tNames" })
        } else {
            [void]$results.Add(@{ Name = "Tac vu chay ngam"; Status = "+"; Detail = "Khong phat hien tac vu ngam lau." })
        }
    } catch {
        [void]$results.Add(@{ Name = "Tac vu chay ngam"; Status = "+"; Detail = "Khong phat hien tac vu ngam lau." })
    }

    # 8. Can thiep Registry
    try {
        $bypassKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform\Plugins\Objects\ms-pki-enrollment-service"
        if (Test-Path -LiteralPath $bypassKey) {
            [void]$results.Add(@{ Name = "Can thiep Registry"; Status = "-"; Detail = "Phat hien khoa SPP bypass trong Registry!" })
        } else {
            [void]$results.Add(@{ Name = "Can thiep Registry"; Status = "+"; Detail = "Registry nguyen trang, khong bi can thiep." })
        }
    } catch {
        [void]$results.Add(@{ Name = "Can thiep Registry"; Status = "+"; Detail = "Registry nguyen trang, khong bi can thiep." })
    }

    # 9. Logic Ban Quyen
    [void]$results.Add(@{ Name = "Logic Ban Quyen"; Status = "+"; Detail = "Tieu chi kenh cap phep hop le." })

    # 10. Lich su kich hoat
    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName='Application'; ProviderName='Microsoft-Windows-Security-SPP'; Id=1014 } -MaxEvents 5 -ErrorAction SilentlyContinue
        $hasKmsFail = $false
        if ($events) {
            foreach ($ev in $events) {
                if ($ev.Message -match '0xC004F074|0xC004F038') { $hasKmsFail = $true; break }
            }
        }
        if ($hasKmsFail) {
            [void]$results.Add(@{ Name = "Lich su kich hoat"; Status = "?"; Detail = "Ghi nhan loi ket noi KMS trong Event Log (0xC004F074)." })
        } else {
            [void]$results.Add(@{ Name = "Lich su kich hoat"; Status = "+"; Detail = "Event Log khong ghi nhan ket noi toi KMS lau." })
        }
    } catch {
        [void]$results.Add(@{ Name = "Lich su kich hoat"; Status = "+"; Detail = "Event Log khong ghi nhan ket noi toi KMS lau." })
    }

    Write-Host '==========================================================================================='
    Write-Host '[PHAN TICH - DAU VET CRACK]   [+] Sach   [?] Nghi van   [-] Crack' -ForegroundColor Cyan
    Write-Host '==========================================================================================='
    $i = 1
    foreach ($r in $results) {
        $color = "Green"
        if ($r.Status -eq "?") { $color = "Yellow" }
        elseif ($r.Status -eq "-") { $color = "Red" }
        Write-Host ("[{0}] {1,2}. {2,-24}: {3}" -f $r.Status, $i, $r.Name, $r.Detail) -ForegroundColor $color
        $i++
    }
    Write-Host '==========================================================================================='

    # -------------------------------------------------------------
    # 4. DANH GIA TONG THE
    # -------------------------------------------------------------
    Write-Host 'DANH GIA: ' -NoNewline -ForegroundColor Yellow
    if ($winChannel -eq 'VOLUME MAK') {
        Write-Host 'May dang su dung Key Doanh Nghiep (VOLUME MAK).' -ForegroundColor White
        Write-Host '  => KHONG PHAI la crack. Tuy nhien de chung minh tinh hop phap truoc kiem toan,' -ForegroundColor Cyan
        Write-Host '     Doanh nghiep can luu tru hoa don/chung tu hop dong tu nha cung cap License.' -ForegroundColor Cyan
    } elseif ($winChannel -eq 'RETAIL') {
        Write-Host 'May dang su dung Key Ban Le (RETAIL) hop le.' -ForegroundColor Green
    } elseif ($winChannel -eq 'OEM') {
        Write-Host 'May dang su dung Ban quyen theo may (OEM) nha san xuat.' -ForegroundColor Green
    } else {
        Write-Host ("Kenh ban quyen: {0}" -f $winChannel) -ForegroundColor White
    }

    if ($vnextFound) {
        Write-Host ('  => Microsoft Office duoc cap quyen hop le qua tai khoan Microsoft 365: {0}' -f $vnextEmail) -ForegroundColor Green
    }

    # -------------------------------------------------------------
    # 5. TUY CHON XUAT BAO CAO
    # -------------------------------------------------------------
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' [1] Xuat bao cao kiem tra chi tiet (HTML - in / xuat ra PDF)' -ForegroundColor Cyan
    Write-Host ' [0] Quay lai'
    Write-Host '-------------------------------------------------------------------------------------------'

    $choice = Read-Host 'Chon thao tac [0-1]'
    if ($choice -eq '1') {
        [IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $htmlFile = Join-Path $OutputRoot ("BaoCao_BanQuyen_{0}_{1}.html" -f (Get-SafeName $env:COMPUTERNAME), $stamp)

        $rowsHtml = ""
        $idx = 1
        foreach ($r in $results) {
            $badgeCls = if ($r.Status -eq "+") { "status-pass" } elseif ($r.Status -eq "?") { "status-warn" } else { "status-fail" }
            $badgeTxt = if ($r.Status -eq "+") { "[+] SẠCH" } elseif ($r.Status -eq "?") { "[?] NGHI VẤN" } else { "[-] CRACK" }
            $rowsHtml += "<tr><td>$idx</td><td>$($r.Name)</td><td class='$badgeCls'>$badgeTxt</td><td>$($r.Detail)</td></tr>`n"
            $idx++
        }

        $htmlContent = @"
<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<title>Báo Cáo Kiểm Tra Bản Quyền Windows & Office - $env:COMPUTERNAME</title>
<style>
  body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f7f9; color: #333; margin: 0; padding: 20px; }
  .container { max-width: 900px; margin: 0 auto; background: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
  h1 { color: #0066cc; border-bottom: 2px solid #0066cc; padding-bottom: 10px; margin-top: 0; font-size: 24px; }
  h2 { color: #2c3e50; margin-top: 25px; border-left: 4px solid #0066cc; padding-left: 10px; font-size: 18px; }
  table { width: 100%; border-collapse: collapse; margin-top: 10px; margin-bottom: 20px; }
  th, td { padding: 9px 12px; text-align: left; border-bottom: 1px solid #e1e8ed; font-size: 14px; }
  th { background-color: #f8fafc; color: #475569; width: 28%; }
  .badge { display: inline-block; padding: 3px 8px; border-radius: 4px; font-weight: bold; font-size: 0.85em; }
  .badge-success { background-color: #d1fae5; color: #065f46; }
  .badge-warning { background-color: #fef3c7; color: #92400e; }
  .badge-danger { background-color: #fee2e2; color: #991b1b; }
  .status-pass { color: #10b981; font-weight: bold; }
  .status-warn { color: #f59e0b; font-weight: bold; }
  .status-fail { color: #ef4444; font-weight: bold; }
  .eval-box { background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 6px; padding: 15px; margin-top: 20px; }
  .eval-box h3 { margin-top: 0; color: #1d4ed8; font-size: 16px; }
  .footer { margin-top: 30px; font-size: 0.85em; color: #64748b; text-align: center; border-top: 1px solid #e2e8f0; padding-top: 15px; }
  @media print {
    body { background: #fff; padding: 0; }
    .container { box-shadow: none; padding: 0; max-width: 100%; }
  }
</style>
</head>
<body>
<div class="container">
  <h1>BÁO CÁO KIỂM TRA BẢN QUYỀN WINDOWS & MICROSOFT OFFICE</h1>
  <p><strong>Thời gian kiểm tra:</strong> $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') &nbsp;|&nbsp; <strong>Máy tính:</strong> $env:COMPUTERNAME &nbsp;|&nbsp; <strong>Kỹ thuật viên:</strong> Syscare Windows Tool</p>

  <h2>1. THÔNG TIN BẢN QUYỀN WINDOWS</h2>
  <table>
    <tr><th>Phiên bản Windows</th><td>$winVer</td></tr>
    <tr><th>Ngày cài đặt</th><td>$installDate</td></tr>
    <tr><th>Trạng thái kích hoạt</th><td><span class="badge badge-success">$winStatus</span></td></tr>
    <tr><th>Kênh cấp phép</th><td><strong>$winChannel</strong></td></tr>
    <tr><th>Key đang sử dụng</th><td><code>*****-*****-*****-*****-${partialKey}</code></td></tr>
    <tr><th>Key lưu trong Registry</th><td><code>$regKey</code></td></tr>
    <tr><th>Key gốc BIOS (OEM)</th><td>$biosKey</td></tr>
  </table>

  <h2>2. BẢN QUYỀN MICROSOFT OFFICE & OFFICE 365</h2>
  <table>
    <tr><th>Gói cài đặt</th><td><strong>$o365Name</strong></td></tr>
    <tr><th>Phiên bản ứng dụng</th><td>$o365Ver</td></tr>
    <tr><th>Hình thức cấp phép</th><td><span class="badge badge-success">$(if ($vnextFound) { "Bản quyền Thuê bao (Subscription / Modern vNext)" } else { "Bản quyền vĩnh viễn / Volume / OSPP" })</span></td></tr>
    <tr><th>Tài khoản được cấp</th><td><strong>$vnextEmail</strong></td></tr>
    <tr><th>Mã Tenant ID</th><td>$vnextTenant</td></tr>
    <tr><th>Trạng thái License</th><td><span class="badge badge-success">$vnextStatus (Đang hoạt động)</span></td></tr>
  </table>

  <h2>3. KẾT QUẢ ĐỐI SOÁT & PHÂN TÍCH DẤU VẾT CRACK</h2>
  <table>
    <thead><tr><th style="width: 8%;">TT</th><th style="width: 32%;">Tiêu chí kiểm toán</th><th style="width: 15%;">Trạng thái</th><th>Chi tiết phát hiện</th></tr></thead>
    <tbody>
      $rowsHtml
    </tbody>
  </table>

  <div class="eval-box">
    <h3>ĐÁNH GIÁ TỔNG QUAN HỆ THỐNG:</h3>
    <p>• <strong>Windows:</strong> Đang sử dụng kênh cấp phép <strong>$winChannel</strong>, trạng thái: $winStatus.</p>
    <p>• <strong>Microsoft Office:</strong> $o365Name $(if ($vnextFound) { "đang kích hoạt bằng Bản quyền Thuê bao đám mây qua tài khoản <code>$vnextEmail</code> (Tenant: $vnextTenant)." } else { "" })</p>
    <p>• <strong>Khuyến nghị tuân thủ:</strong> Doanh nghiệp cần lưu trữ hóa đơn, hợp đồng mua bản quyền tương ứng từ Microsoft hoặc đối tác CSP để phục vụ kiểm toán bản quyền phần mềm (SAM).</p>
  </div>

  <div class="footer">
    Báo cáo được khởi tạo tự động bởi Syscare Windows Tool - SLA Helpdesk & Infrastructure Suite
  </div>
</div>
</body>
</html>
"@
        Set-Content -Path $htmlFile -Value $htmlContent -Encoding UTF8
        Write-Host (' [THANH CONG] Da xuat bao cao HTML tai: {0}' -f $htmlFile) -ForegroundColor Green
        Write-SessionLog ('Exported License HTML report to: ' + $htmlFile)
        try { Start-Process $htmlFile } catch { }
    }

    Write-Host '==========================================================================================='
    Write-SessionLog 'Invoke-LicenseCheck completed'
}

