function Test-AssistTcp {
    param([string] $HostName, [int] $Port)
    $client = New-Object Net.Sockets.TcpClient
    try {
        $pending = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(2500)) { return 'TIMEOUT' }
        try { $client.EndConnect($pending); return 'OPEN' }
        catch { return 'CLOSED/UNREACHABLE' }
    }
    catch { return 'DNS/NETWORK ERROR: ' + $_.Exception.Message }
    finally { $client.Close() }
}

function Read-AssistHost {
    param([string] $Prompt)
    $hostInput = (Read-Host $Prompt).Trim()
    if ($hostInput -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$' -or $hostInput -match '\.\.') {
        throw 'Invalid IP or hostname. Enter a plain hostname or IPv4 address.'
    }
    return $hostInput
}

function Get-AssistPrinter {
    param([switch] $AllowNone)
    try { $printers = @(Get-Printer -ErrorAction Stop | Sort-Object Name) }
    catch {
        if ($AllowNone) {
            Write-Warning 'Cannot enumerate print queues (check Print Spooler). USB/PnP devices will still be checked.'
            return $null
        }
        throw
    }
    if ($printers.Count -eq 0) {
        if ($AllowNone) { Write-Host 'No printer queue installed; checking USB/PnP enumeration.'; return $null }
        throw 'No local printer connection was found.'
    }
    for ($i = 0; $i -lt $printers.Count; $i++) {
        Write-Host ('[{0}] {1} | port: {2}' -f ($i + 1), $printers[$i].Name, $printers[$i].PortName)
    }
    $inputNumber = Read-Host 'Enter the printer number (Enter checks devices only)'
    if ($AllowNone -and [string]::IsNullOrWhiteSpace($inputNumber)) { return $null }
    $selection = 0
    if (-not [int]::TryParse($inputNumber, [ref]$selection) -or $selection -lt 1 -or $selection -gt $printers.Count) {
        throw 'Cancelled or invalid printer number.'
    }
    return $printers[$selection - 1]
}

function Save-AssistReport {
    param([string] $Kind, [scriptblock] $Body)
    $directory = New-OutputDirectory $Kind
    Save-Text (Join-Path $directory 'PRINTER_SCAN_DIAGNOSTIC.txt') $Body
    $report = Join-Path $directory 'PRINTER_SCAN_DIAGNOSTIC.txt'
    Write-Host ('Report: {0}' -f $report) -ForegroundColor Cyan
    Get-Content -LiteralPath $report | Select-Object -First 70 | ForEach-Object { Write-Host $_ }
    Complete-Output -Directory $directory -Open $false
}

function Get-AssistPrinterState {
    param($Printer)
    'Computer: ' + $env:COMPUTERNAME
    'Current identity: ' + [Security.Principal.WindowsIdentity]::GetCurrent().Name
    Get-Service Spooler | Format-List Name,Status,StartType
    ''
    $Printer | Format-List Name,Type,DriverName,PortName,PrinterStatus,WorkOffline,Shared,Published
    'Jobs for selected printer:'
    @(Get-PrintJob -PrinterName $Printer.Name -ErrorAction SilentlyContinue) |
        Select-Object ID,JobStatus,SubmittedTime,Size | Format-Table -AutoSize
    'Port configuration:'
    Get-PrinterPort -Name $Printer.PortName -ErrorAction SilentlyContinue |
        Format-List Name,PrinterHostAddress,PortNumber,Protocol,SNMPEnabled
    if ($Printer.WorkOffline) { 'CHECK: printer queue is set to Work Offline.' }
    if ($Printer.PrinterStatus -notin @('Normal', 'Idle', 0, 3)) {
        'CHECK: printer reports a non-normal status; compare with its panel and queue.'
    }
}

function Invoke-PrinterUsbAssist {
    Write-Host 'USB printer: connect power and USB cable, then select its local queue.'
    $printer = Get-AssistPrinter -AllowNone
    Save-AssistReport 'PrinterUSB' {
        Get-Service Spooler | Format-List Name,Status,StartType
        if ($printer) { Get-AssistPrinterState $printer }
        else { 'No queue selected; inspecting device enumeration only.' }
        'USB/PnP printer devices (may include scanners and disconnected devices):'
        Get-PnpDevice -Class Printer,PrintQueue -ErrorAction SilentlyContinue |
            Select-Object FriendlyName,Class,Status,InstanceId | Format-Table -AutoSize
        'USB printer enumerations:'
        Get-CimInstance Win32_PnPEntity -Filter "PNPClass = 'Printer'" -ErrorAction SilentlyContinue |
            Select-Object Name,Status,PNPDeviceID | Format-Table -AutoSize
        'Interpretation: USB00x port with missing PnP device suggests cable/power/USB/driver checks.'
        'Do not reinstall drivers automatically; compare device model and approved vendor driver first.'
    }
}

function Invoke-PrinterSharedAssist {
    $server = Read-AssistHost 'Print server or PC sharing the printer (hostname/IP)'
    $share = (Read-Host 'Shared printer name (optional)').Trim()
    if ($share -and $share -notmatch '^[^\\/:*?"<>|]{1,80}$') { throw 'Invalid share name.' }
    $unc = if ($share) { '\\' + $server + '\' + $share } else { '(not supplied)' }
    Save-AssistReport 'PrinterShared' {
        'Print host: ' + $server
        'Printer UNC: ' + $unc
        'DNS lookup:'
        Resolve-DnsName $server -ErrorAction SilentlyContinue | Select-Object Name,Type,IPAddress | Format-Table -AutoSize
        'TCP 445 (SMB): ' + (Test-AssistTcp $server 445)
        'TCP 135 (RPC endpoint): ' + (Test-AssistTcp $server 135)
        'Local installed queues referencing host:'
        Get-Printer -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like ('*' + $server + '*')
        } | Format-List Name,Type,DriverName,PortName,PrinterStatus,WorkOffline
        'If TCP works but connect/print fails: check share name, approved driver, user print permission, print server logs and firewall RPC dynamic ports.'
        'No connection or Point-and-Print policy is changed automatically.'
    }
}

function Invoke-PrinterIpAssist {
    $target = Read-AssistHost 'Printer IP or DNS name (e.g. Toshiba MFP)'
    Save-AssistReport 'PrinterIP' {
        'Target: ' + $target
        'DNS lookup:'
        Resolve-DnsName $target -ErrorAction SilentlyContinue | Select-Object Name,Type,IPAddress | Format-Table -AutoSize
        foreach ($port in @(9100,515,631,80,443)) {
            ('TCP {0}: {1}' -f $port, (Test-AssistTcp $target $port))
        }
        'Installed queues with matching port host address:'
        $ports = @(Get-PrinterPort -ErrorAction SilentlyContinue | Where-Object {
            $hostProperty = $_.PSObject.Properties['PrinterHostAddress']
            ($hostProperty -and $hostProperty.Value -eq $target) -or $_.Name -eq $target
        })
        foreach ($p in $ports) {
            $p | Format-List Name,PrinterHostAddress,PortNumber,Protocol,SNMPEnabled
            Get-Printer -ErrorAction SilentlyContinue | Where-Object PortName -eq $p.Name |
                Format-List Name,DriverName,PortName,PrinterStatus,WorkOffline
        }
        'A closed port is meaningful only if that protocol is configured for this printer.'
        'A failed ping/status can reflect ICMP or SNMP policy; inspect the port and device web UI before changing anything.'
    }
}

function Invoke-ScanFolderAssist {
    $server = Read-AssistHost 'Scan destination server hostname or IP'
    $share = (Read-Host 'Scan share name (single share segment)').Trim()
    if ($share -notmatch '^[A-Za-z0-9_$.-]{1,80}$' -or $share -in @('.', '..')) { throw 'Invalid share name.' }
    $folder = (Read-Host 'Relative subfolder below share (optional)').Trim()
    if ($folder -and ($folder -match '(^[\\/]|[<>:"|?*]|\.\.|[\\/]$)' -or $folder.Length -gt 200)) { throw 'Invalid relative folder.' }
    $unc = '\\' + $server + '\' + $share
    if ($folder) { $unc += '\' + ($folder -replace '/', '\') }
    Save-AssistReport 'ScanFolder' {
        'Target UNC: ' + $unc
        'Current PC identity: ' + [Security.Principal.WindowsIdentity]::GetCurrent().Name
        'DNS lookup:'
        Resolve-DnsName $server -ErrorAction SilentlyContinue | Select-Object Name,Type,IPAddress | Format-Table -AutoSize
        'TCP 445 (PC to server only): ' + (Test-AssistTcp $server 445)
        'UNC reachable as current PC identity (not copier identity): ' + (Test-Path -LiteralPath $unc -PathType Container)
        if ($server -in @($env:COMPUTERNAME, 'localhost', '127.0.0.1')) {
            'Share ACL (hosted on this PC):'
            Get-SmbShareAccess -Name $share -ErrorAction SilentlyContinue | Format-Table -AutoSize
            $localShare = Get-SmbShare -Name $share -ErrorAction SilentlyContinue
            if ($localShare) {
                'Local share path: ' + $localShare.Path
                'NTFS ACL (root only):'
                $acl = Get-Acl -LiteralPath $localShare.Path -ErrorAction SilentlyContinue
                if ($acl) {
                    $acl.Access | Select-Object IdentityReference,FileSystemRights,AccessControlType | Format-Table -AutoSize
                }
            }
        }
        'Important: this PC test cannot verify copier-to-server routing or its saved SMB credential.'
        'On Toshiba: check SMB destination server/share/subfolder, DNS/IP, domain account, password expiry/lockout, and device event/job log.'
        'On file server: check share AND NTFS write permission for the dedicated scan account, audit event, SMB version/signing policy, and firewall TCP 445.'
        'Avoid guest/anonymous access, SMB1 enablement, broad Everyone write permissions, and storing a password in this report.'
        'No test file is written and no credentials are requested.'
    }
}

function Invoke-PrinterClearSelectedQueue {
    $printer = Get-AssistPrinter
    $jobs = @(Get-PrintJob -PrinterName $printer.Name -ErrorAction Stop)
    if ($jobs.Count -eq 0) { Write-Host 'Selected printer has no queued jobs.'; return }
    Write-Host ('WARNING: {0} jobs in queue {1} will be cancelled for all users of this queue.' -f $jobs.Count, $printer.Name) -ForegroundColor Yellow
    $answer = Read-Host ('Type CLEAR to cancel jobs for this printer only')
    if ($answer -cne 'CLEAR') { Write-Host 'Cancelled.'; return }
    $failed = 0
    foreach ($job in $jobs) {
        try { Remove-PrintJob -PrinterName $printer.Name -ID $job.ID -ErrorAction Stop }
        catch { $failed++; Write-Warning ('Job {0}: {1}' -f $job.ID, $_.Exception.Message) }
    }
    Write-SessionLog ('Queue clear: printer={0}, requested={1}, failed={2}' -f $printer.Name, $jobs.Count, $failed)
    Write-Host ('Cancelled: {0}; failed: {1}. Remaining: {2}' -f ($jobs.Count - $failed), $failed, @(Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue).Count)
}

function Invoke-PrinterRestartSpooler {
    Write-Host 'WARNING: restarting the LOCAL Spooler temporarily affects ALL print queues on this computer.' -ForegroundColor Yellow
    $answer = Read-Host 'Type RESTART to continue'
    if ($answer -cne 'RESTART') { Write-Host 'Cancelled.'; return }
    Restart-Service -Name Spooler -ErrorAction Stop
    Write-SessionLog 'Local Print Spooler restarted by operator'
    Write-Host ('Local Print Spooler: {0}' -f (Get-Service Spooler).Status)
}

function Invoke-ToshibaScanSuite {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-ToshibaScanSuite started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '   CHUYEN DE SCAN-TO-FOLDER SMB: TOSHIBA e-STUDIO 2508A & 3515AC' -ForegroundColor Cyan
    Write-Host '==========================================================================================='
    Write-Host ' Thong tin thiet bi cong ty:' -ForegroundColor Yellow
    Write-Host '  - [May Mau]       : Toshiba e-STUDIO 3515AC  | IP: 10.6.0.25 | Thu muc: \\10.6.0.25\file_share'
    Write-Host '  - [May Trang Den] : Toshiba e-STUDIO 2508A   | IP: 10.6.0.26 | Thu muc: \\10.6.0.26\file_share'
    Write-Host '  - Tai khoan SMB   : User: scan  |  Password: @@6868'
    Write-Host '-------------------------------------------------------------------------------------------'

    # 1. Kiem tra TCP 445 (SMB Port)
    Write-Host ' [1/6] Kiem tra ket noi mang va cong SMB TCP 445...' -ForegroundColor Gray
    $res25 = Test-AssistTcp '10.6.0.25' 445
    $res26 = Test-AssistTcp '10.6.0.26' 445

    Write-Host '  - May Mau (10.6.0.25)       : ' -NoNewline
    if ($res25 -eq 'OPEN') { Write-Host 'KET NOI TOT (TCP 445 Open)' -ForegroundColor Green }
    else { Write-Host ("KHONG KET NOI DUOC ({0})" -f $res25) -ForegroundColor Red }

    Write-Host '  - May Trang Den (10.6.0.26) : ' -NoNewline
    if ($res26 -eq 'OPEN') { Write-Host 'KET NOI TOT (TCP 445 Open)' -ForegroundColor Green }
    else { Write-Host ("KHONG KET NOI DUOC ({0})" -f $res26) -ForegroundColor Red }

    # 2. Kiem tra chinh sach SMB Client cua may tinh & SMB1
    Write-Host ' [2/6] Kiem tra chinh sach bao mat SMB Client tren may tinh...' -ForegroundColor Gray
    $smbConf = Get-SmbClientConfiguration -ErrorAction SilentlyContinue
    $reqSign = if ($smbConf) { [bool]$smbConf.RequireSecuritySignature } else { $false }
    $guestLogon = if ($smbConf) { [bool]$smbConf.EnableInsecureGuestLogons } else { $true }

    $smb1State = 'Khong ro'
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -ErrorAction SilentlyContinue
        if ($f) { $smb1State = [string]$f.State }
    } catch { }

    Write-Host '  BANG DOI CHIEU CAU HINH AN TOAN VS TUONG THICH (MICROSOFT SECURITY BASELINE):' -ForegroundColor Cyan
    Write-Host '  +-----------------------------+---------------+-------------------+-------------------+' -ForegroundColor Gray
    Write-Host '  | Thanh phan kiem tra         | Hien tai may  | Muc tieu An toan  | Che do Tuong thich|' -ForegroundColor Gray
    Write-Host '  |                             | tinh (Client) | (Khuyen nghi MS)  | (May in 2508A cu) |' -ForegroundColor Gray
    Write-Host '  +-----------------------------+---------------+-------------------+-------------------+' -ForegroundColor Gray
    Write-Host ('  | SMB Signing (Client)        | {0,-13} | True (Bat buoc)   | False (Khong bat) |' -f $(if ($reqSign) { 'True' } else { 'False' }))
    Write-Host ('  | Insecure Guest Logon        | {0,-13} | False (Chan Guest)| True (Cho phep)   |' -f $(if ($guestLogon) { 'True' } else { 'False' }))
    Write-Host ('  | Giao thuc SMB 1.0 Client    | {0,-13} | Disabled (Tat)    | Enabled (Khi can) |' -f $smb1State)
    Write-Host '  +-----------------------------+---------------+-------------------+-------------------+' -ForegroundColor Gray

    # 3. Tu dong nap Credential vao Windows Credential Manager
    Write-Host ' [3/6] Tu dong dong bo thong tin chung thuc (Credential) cho 2 may in...' -ForegroundColor Gray
    try {
        & cmdkey.exe /add:10.6.0.25 /user:scan /pass:@@6868 2>&1 | Out-Null
        & cmdkey.exe /add:10.6.0.26 /user:scan /pass:@@6868 2>&1 | Out-Null
        Write-Host "  [OK] Da nap tai khoan 'scan' va pass '@@6868' cho 10.6.0.25 va 10.6.0.26 vao Windows Credential Manager." -ForegroundColor Green
    } catch {
        Write-Host ('  [CANH BAO] Khong the nap cmdkey: ' + $_.Exception.Message) -ForegroundColor Yellow
    }

    # 4. Kiem tra duong dan UNC
    Write-Host ' [4/6] Kiem tra truy cap folder scan thuc te...' -ForegroundColor Gray
    $unc25 = '\\10.6.0.25\file_share'
    $unc26 = '\\10.6.0.26\file_share'
    $ok25 = Test-Path -LiteralPath $unc25 -ErrorAction SilentlyContinue
    $ok26 = Test-Path -LiteralPath $unc26 -ErrorAction SilentlyContinue

    Write-Host ('  - Truc tiep \\10.6.0.25\file_share : {0}' -f $(if ($ok25) { 'TRUY CAP THANH CONG' } else { 'THAT BAI (Loi phan quyen / SMB)' })) -ForegroundColor $(if ($ok25) { 'Green' } else { 'Red' })
    Write-Host ('  - Truc tiep \\10.6.0.26\file_share : {0}' -f $(if ($ok26) { 'TRUY CAP THANH CONG' } else { 'THAT BAI (Loi phan quyen / SMB)' })) -ForegroundColor $(if ($ok26) { 'Green' } else { 'Red' })

    # 5. Kiem tra phien SMB dang ket noi (thu kich hoat phien neu can)
    Write-Host ' [5/6] Trang thai phien SMB hien hanh (Dialect & Signed)...' -ForegroundColor Gray
    try { [IO.Directory]::GetFiles('\\10.6.0.25\file_share') | Out-Null } catch { }
    try { [IO.Directory]::GetFiles('\\10.6.0.26\file_share') | Out-Null } catch { }

    $sessions = @(Get-SmbConnection -ErrorAction SilentlyContinue | Where-Object { $_.ServerName -in @('10.6.0.25', '10.6.0.26', 'filesvr') -or $_.ShareName -match 'file_share' })
    if ($sessions.Count -gt 0) {
        $sessions | Select-Object ServerName, ShareName, Dialect, Signed | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_.TrimEnd() -ForegroundColor Cyan }
    } else {
        Write-Host '  (Chua co phien SMB live nao. Neu vua khoi dong hoac chua vao thu muc, hay chon muc [1] hoac [2] de mo)' -ForegroundColor Gray
    }

    # 6. Phan tich Event Log SMB Client gan day (30 phut qua)
    Write-Host ' [6/6] Phan tich log loi SMB Client Security (30 phut gan nhat)...' -ForegroundColor Gray
    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-SmbClient/Security'; StartTime = (Get-Date).AddMinutes(-30) } -ErrorAction SilentlyContinue | Select-Object -First 15
        $foundSignError = $false
        $foundGuestError = $false
        if ($events -and $events.Count -gt 0) {
            Write-Host ('  Phat hien {0} su kien SMB Security trong 30 phut qua:' -f $events.Count) -ForegroundColor Yellow
            foreach ($ev in $events) {
                if ($ev.Id -eq 31017 -or "$($ev.Message)" -match 'signing') { $foundSignError = $true }
                if ($ev.Id -eq 31001 -or "$($ev.Message)" -match 'guest') { $foundGuestError = $true }
                Write-Host ('  - [{0}] Event ID: {1} | {2}' -f $ev.TimeCreated.ToString('HH:mm:ss'), $ev.Id, ($ev.Message -split "`r?`n")[0]) -ForegroundColor $(if ($ev.Id -in 31017, 31001) { 'Red' } else { 'Gray' })
            }
        } else {
            Write-Host '  (Khong co su kien chan bao mat SMB nao trong 30 phut qua)' -ForegroundColor Green
        }

        if ($foundSignError) {
            Write-Host '  [NGUYEN NHAN] Phat hien Event 31017: May in tu choi ket noi vi CHUA BAT KY SO (SMB Signing) tren may in trong khi Windows bat buoc ky so!' -ForegroundColor Red
        }
        if ($foundGuestError) {
            Write-Host '  [NGUYEN NHAN] Phat hien Event 31001: Ket noi bi chan vi may in gui yeu cau dang nhap Guest khong an toan!' -ForegroundColor Red
        }
    } catch { }

    # GIAI THICH CHUYEN SAU VA NGUYEN NHAN LOI NETWORK NAME IS NO LONGER AVAILABLE
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' GIAI THICH CHUYEN SAU: VI SAO MAY MAU (10.6.0.25) VAO DUOC NHUNG 2508A (10.6.0.26) BI LOI?' -ForegroundColor Yellow
    Write-Host '  1. May Mau (3515AC) da bat "SMB Signing of SMB Server = If client agrees" trong TopAccess'
    Write-Host '     va ho tro SMB 3.1.1, nen khi Windows 11 yeu cau ky so, may mau dong y ky => Ket noi hoan hao!'
    Write-Host '  2. Neu May Trang Den (2508A) bao loi "The specified network name is no longer available":'
    Write-Host '     - Kha nang A: Toshiba da tat Guest Logon nhung chua tao user "scan" / "@@6868" va chua phan quyen folder scan.'
    Write-Host '     - Kha nang B: May 2508A chi ho tro SMB 1.0 (firmware cu) ma Windows 10/11 da tat tinh nang SMB1Protocol-Client.'
    Write-Host '     - Kha nang C: May 2508A chua bat "SMB Signing of SMB Server = If client agrees", khi Windows 11 bat buoc ky'
    Write-Host '       so (RequireSecuritySignature = True), may in se lap tuc chu dong dong ket noi (TCP Reset).'
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' HUONG DAN IT CAU HINH TREN TOPACCESS CUA MAY TRANG DEN 2508A (CHI CAN LAM 1 LAN):' -ForegroundColor Cyan
    Write-Host '  Buoc 1: Mo trinh duyet vao: http://10.6.0.26 (Dang nhap Admin, pass thuong la 123456)'
    Write-Host '  Buoc 2: Vao Administration > Setup > Network > SMB Session:'
    Write-Host '          - Dat "SMB Server" = Enable'
    Write-Host '          - Dat "SMB Signing of SMB Server" = If client agrees (hoac Always)  <-- QUAN TRONG NHAT'
    Write-Host '          - Dat "Guest Logon" = Disable'
    Write-Host '  Buoc 3: Vao User Management > Tao user: "scan" va mat khau: "@@6868"'
    Write-Host '  Buoc 4: Vao Shared Folder (file_share) > Cap quyen Read/Write cho user "scan".'
    Write-Host '  Buoc 5: Luu lai (Save) va khoi dong lai dich vu mang cua may in.'
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' CAC THAO TAC XU LY TAI CHO:' -ForegroundColor Yellow
    Write-Host ' [1] Mo thu muc scan May Mau (\\10.6.0.25\file_share) tren File Explorer'
    Write-Host ' [2] Mo thu muc scan May Trang Den (\\10.6.0.26\file_share) tren File Explorer'
    Write-Host ' [3] Mo trang quan tri TopAccess May Trang Den 2508A (http://10.6.0.26)'
    Write-Host ' [4] Mo trang quan tri TopAccess May Mau 3515AC (http://10.6.0.25)'
    Write-Host ' [5] [MUC TIEU AN TOAN] Bat Ky so ($true) & Chan Guest ($false) - Chuan bao mat Microsoft' -ForegroundColor Green
    Write-Host ' [6] [CHE DO TUONG THICH] Tat Ky so ($false) & Cho phep Guest ($true) - De vao gap may 2508A' -ForegroundColor Yellow
    Write-Host ' [7] [KICH HOAT SMB1] Bat SMB 1.0 Client (Sua loi Network name is no longer available)' -ForegroundColor Magenta
    Write-Host ' [8] [TAT SMB1] Tat SMB 1.0 Client (Khuyen nghi bao mat chong Ransomware)' -ForegroundColor Green
    Write-Host ' [9] Kiem tra lai phien SMB (Get-SmbConnection: Dialect & Trinh ky Signed)' -ForegroundColor Cyan
    Write-Host ' [A] Xem chi tiet 15 log loi SMB Client Security (Format-List)' -ForegroundColor Gray
    Write-Host ' [B] Reset toan bo ket noi SMB va nap lai Credential (net use * /delete & cmdkey)' -ForegroundColor Cyan
    Write-Host ' [0] Quay lai'
    Write-Host '-------------------------------------------------------------------------------------------'

    $subChoice = Read-Host 'Chon thao tac [0-9, A, B]'
    switch ($subChoice) {
        '1' {
            Write-Host ' Dang mo thu muc scan may mau...' -ForegroundColor Gray
            try { Start-Process 'explorer.exe' '\\10.6.0.25\file_share' } catch { }
        }
        '2' {
            Write-Host ' Dang mo thu muc scan may trang den...' -ForegroundColor Gray
            try { Start-Process 'explorer.exe' '\\10.6.0.26\file_share' } catch { }
        }
        '3' {
            Write-Host ' Dang mo TopAccess may 2508A...' -ForegroundColor Gray
            try { Start-Process 'http://10.6.0.26' } catch { }
        }
        '4' {
            Write-Host ' Dang mo TopAccess may 3515AC...' -ForegroundColor Gray
            try { Start-Process 'http://10.6.0.25' } catch { }
        }
        '5' {
            Write-Host ' Dang khoi phuc chuan bao mat cao Microsoft (Signing = True, InsecureGuest = False)...' -ForegroundColor Gray
            try {
                Set-SmbClientConfiguration -RequireSecuritySignature $true -Force -ErrorAction Stop
                Set-SmbClientConfiguration -EnableInsecureGuestLogons $false -Force -ErrorAction Stop
                Write-Host ' [THANH CONG] Da bat bat buoc ky so va chan Guest khong an toan!' -ForegroundColor Green
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '6' {
            Write-Host ' Dang ha cau hinh che do tuong thich (Signing = False, InsecureGuest = True)...' -ForegroundColor Gray
            try {
                Set-SmbClientConfiguration -RequireSecuritySignature $false -Force -ErrorAction Stop
                Set-SmbClientConfiguration -EnableInsecureGuestLogons $true -Force -ErrorAction Stop
                Write-Host ' [THANH CONG] Da chuyen sang che do tuong thich de ket noi may 2508A.' -ForegroundColor Green
                Write-Host ' Luu y: Sau khi IT cau hinh xong TopAccess tren may in, hay chon [5] de bat lai bao mat!' -ForegroundColor Yellow
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '7' {
            Write-Host ' Dang kich hoat tinh nang SMB1Protocol-Client (co the mat vai chuc giay)...' -ForegroundColor Gray
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -NoRestart -ErrorAction Stop | Out-Null
                Write-Host ' [THANH CONG] Da bat tinh nang SMB 1.0 Client. Luu y can khoi dong lai may de co hieu luc.' -ForegroundColor Green
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '8' {
            Write-Host ' Dang tat tinh nang SMB1Protocol-Client...' -ForegroundColor Gray
            try {
                Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -NoRestart -ErrorAction Stop | Out-Null
                Write-Host ' [THANH CONG] Da tat tinh nang SMB 1.0 Client de bao ve may tinh.' -ForegroundColor Green
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '9' {
            Write-Host ' Dang kiem tra lai phien ket noi SMB...' -ForegroundColor Gray
            try {
                $chk = Get-SmbConnection -ErrorAction SilentlyContinue | Where-Object { $_.ServerName -in @('10.6.0.25', '10.6.0.26', 'filesvr') -or $_.ShareName -match 'file_share' }
                if ($chk) {
                    $chk | Select-Object ServerName, ShareName, Dialect, Signed | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_.TrimEnd() -ForegroundColor Cyan }
                } else {
                    Write-Host ' Khong tim thay phien SMB nao. Hay mo thu muc \\10.6.0.25\file_share tren Explorer truoc.' -ForegroundColor Yellow
                }
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        'A' {
            Write-Host ' Dang truy van 15 log loi SMB Client Security gan day...' -ForegroundColor Gray
            try {
                $evDetail = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-SmbClient/Security'; StartTime = (Get-Date).AddMinutes(-30) } -ErrorAction SilentlyContinue | Select-Object -First 15
                if ($evDetail) {
                    $evDetail | Select-Object TimeCreated, Id, Message | Format-List | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
                } else {
                    Write-Host ' Khong co log loi SMB nao trong 30 phut qua.' -ForegroundColor Green
                }
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        'B' {
            Write-Host ' Dang reset ket noi SMB va dong bo lai Credential...' -ForegroundColor Gray
            try {
                & net.exe use * /delete /y 2>&1 | Out-Null
                & cmdkey.exe /add:10.6.0.25 /user:scan /pass:@@6868 2>&1 | Out-Null
                & cmdkey.exe /add:10.6.0.26 /user:scan /pass:@@6868 2>&1 | Out-Null
                Write-Host ' [THANH CONG] Da ngat ket noi cu va nap lai thong tin xac thuc cho 10.6.0.25 & 10.6.0.26.' -ForegroundColor Green
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        default {
            Write-Host 'Quay lai menu.'
        }
    }
    Write-Host '==========================================================================================='
    Write-SessionLog 'Invoke-ToshibaScanSuite completed'
}

function Invoke-SmbSecurityConfig {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-SmbSecurityConfig started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  QUAN LY CAU HINH SMB CLIENT, KY SO VA SMB 1.0 / SMB 2.0 (WINDOWS 10/11)' -ForegroundColor Cyan
    Write-Host '==========================================================================================='

    $c = Get-SmbClientConfiguration -ErrorAction SilentlyContinue
    $smb1State = 'Khong ro'
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -ErrorAction SilentlyContinue
        if ($f) { $smb1State = [string]$f.State }
    } catch { }

    Write-Host ' Trang thai SMB Client hien tai:' -ForegroundColor Yellow
    if ($c) {
        Write-Host ('  1. Bat buoc Ky so (RequireSecuritySignature)  : {0}' -f $(if ($c.RequireSecuritySignature) { 'BAT (True - Chi ket noi may chu co ky so)' } else { 'TAT (False - Cho phep ket noi ca may chu khong ky)' }))
        Write-Host ('  2. Dang nhap Guest (EnableInsecureGuestLogons) : {0}' -f $(if ($c.EnableInsecureGuestLogons) { 'CHO PHEP (True - Ho tro thiet bi scan doi cu)' } else { 'CHAN (False - Chuan bao mat chong relay)' }))
    }
    Write-Host ('  3. Giao thuc SMB 1.0 Client (SMB1Protocol)     : {0}' -f $smb1State)
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' [1] [MUC TIEU AN TOAN] Bat Ky so ($true) & Chan Guest ($false) - Chuan bao mat Microsoft' -ForegroundColor Green
    Write-Host ' [2] [CHE DO TUONG THICH] Tat Ky so ($false) & Cho phep Guest ($true) - Cho thiet bi cu/scan' -ForegroundColor Yellow
    Write-Host ' [3] Bat/Tat rieng le Bat buoc Ky so (RequireSecuritySignature)'
    Write-Host ' [4] Bat/Tat rieng le Dang nhap Guest khong an toan (EnableInsecureGuestLogons)'
    Write-Host ' [5] BAT tinh nang SMB 1.0 Client (Can cho may scan/NAS rat cu, can khoi dong lai)' -ForegroundColor Magenta
    Write-Host ' [6] TAT tinh nang SMB 1.0 Client (Khuyen nghi bao mat chong Ransomware)' -ForegroundColor Green
    Write-Host ' [7] Kiem tra phien SMB dang mo (Get-SmbConnection: Dialect, Signed)' -ForegroundColor Cyan
    Write-Host ' [8] Xem 15 log loi SMB Client Security gan day (30 phut qua)' -ForegroundColor Gray
    Write-Host ' [9] Xoa sach cac ket noi SMB/IPC$ dang treo (net use * /delete /y)' -ForegroundColor Cyan
    Write-Host ' [0] Quay lai'
    Write-Host '-------------------------------------------------------------------------------------------'

    $choice = Read-Host 'Chon thao tac [0-9]'
    switch ($choice) {
        '1' {
            try {
                Set-SmbClientConfiguration -RequireSecuritySignature $true -Force -ErrorAction Stop
                Set-SmbClientConfiguration -EnableInsecureGuestLogons $false -Force -ErrorAction Stop
                Write-Host ' [THANH CONG] Da ap dung chuan bao mat: Bat ky so SMB va Chan Guest khong an toan.' -ForegroundColor Green
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '2' {
            try {
                Set-SmbClientConfiguration -RequireSecuritySignature $false -Force -ErrorAction Stop
                Set-SmbClientConfiguration -EnableInsecureGuestLogons $true -Force -ErrorAction Stop
                Write-Host ' [THANH CONG] Da ap dung che do tuong thich: Tat ky so va Cho phep Guest.' -ForegroundColor Green
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '3' {
            if ($c -and $c.RequireSecuritySignature) {
                try {
                    Set-SmbClientConfiguration -RequireSecuritySignature $false -Force -ErrorAction Stop
                    Write-Host ' [THANH CONG] Da TAT bat buoc ky so SMB.' -ForegroundColor Green
                } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
            } else {
                try {
                    Set-SmbClientConfiguration -RequireSecuritySignature $true -Force -ErrorAction Stop
                    Write-Host ' [THANH CONG] Da BAT bat buoc ky so SMB.' -ForegroundColor Green
                } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
            }
        }
        '4' {
            if ($c -and $c.EnableInsecureGuestLogons) {
                try {
                    Set-SmbClientConfiguration -EnableInsecureGuestLogons $false -Force -ErrorAction Stop
                    Write-Host ' [THANH CONG] Da CHAN dang nhap Guest khong an toan.' -ForegroundColor Green
                } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
            } else {
                try {
                    Set-SmbClientConfiguration -EnableInsecureGuestLogons $true -Force -ErrorAction Stop
                    Write-Host ' [THANH CONG] Da CHO PHEP dang nhap Guest khong an toan.' -ForegroundColor Green
                } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
            }
        }
        '5' {
            Write-Host ' Dang kich hoat tinh nang SMB1Protocol-Client (co the mat vai chuc giay)...' -ForegroundColor Gray
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -NoRestart -ErrorAction Stop | Out-Null
                Write-Host ' [THANH CONG] Da bat SMB1Protocol-Client. Luu y can khoi dong lai may de co hieu luc day du.' -ForegroundColor Green
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '6' {
            Write-Host ' Dang tat tinh nang SMB1Protocol-Client...' -ForegroundColor Gray
            try {
                Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol-Client -NoRestart -ErrorAction Stop | Out-Null
                Write-Host ' [THANH CONG] Da tat SMB1Protocol-Client de bao ve he thong.' -ForegroundColor Green
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '7' {
            try {
                $conns = Get-SmbConnection -ErrorAction SilentlyContinue
                if ($conns) {
                    $conns | Select-Object ServerName, ShareName, Dialect, Signed | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_.TrimEnd() -ForegroundColor Cyan }
                } else {
                    Write-Host ' Khong co phien SMB nao dang mo tren he thong.' -ForegroundColor Yellow
                }
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '8' {
            Write-Host ' Dang truy van 15 log loi SMB Client Security gan day...' -ForegroundColor Gray
            try {
                $evDetail = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-SmbClient/Security'; StartTime = (Get-Date).AddMinutes(-30) } -ErrorAction SilentlyContinue | Select-Object -First 15
                if ($evDetail) {
                    $evDetail | Select-Object TimeCreated, Id, Message | Format-List | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
                } else {
                    Write-Host ' Khong co log loi SMB nao trong 30 phut qua.' -ForegroundColor Green
                }
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        '9' {
            try {
                & net.exe use * /delete /y 2>&1 | Out-Null
                Write-Host ' [THANH CONG] Da xoa sach toan bo session SMB/IPC$ dang ton tai tren may.' -ForegroundColor Green
            } catch { Write-Host (' Loi: ' + $_.Exception.Message) -ForegroundColor Red }
        }
        default { Write-Host 'Quay lai menu.' }
    }
    Write-Host '==========================================================================================='
    Write-SessionLog 'Invoke-SmbSecurityConfig completed'
}

function Invoke-RpcPrintFix {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-RpcPrintFix started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  SUA LOI CHIA SE MAY IN MANG 0x0000011b, 0x00000709, 0x0000007c (RPC PRINT FIX)' -ForegroundColor Cyan
    Write-Host '==========================================================================================='
    Write-Host ' Cac loi khac phuc:'
    Write-Host '  1. Loi 0x0000011b : Do ban va bao mat Print Spooler yeu cau ma hoa RPC cao cap.'
    Write-Host '  2. Loi 0x00000709, 0x0000007c : Do gioi han Point and Print Restrict tren Windows 10/11.'
    Write-Host '  3. Loi ket noi RPC qua Named Pipes tren Windows 11 22H2 / 24H2.'
    Write-Host '-------------------------------------------------------------------------------------------'

    $confirm = Read-Host 'Ban co chac chan muon cau hinh Registry va khoi dong lai Print Spooler? (Y/N)'
    if ($confirm -notmatch '^[Yy]') {
        Write-Host 'Da huy thao tac.' -ForegroundColor Yellow
        return
    }

    try {
        Write-Host ' [1/3] Cau hinh RpcAuthnLevelPrivacyEnabled tren Print Server/Client...' -ForegroundColor Gray
        $printKey = 'HKLM:\System\CurrentControlSet\Control\Print'
        if (-not (Test-Path -LiteralPath $printKey)) { New-Item -Path $printKey -Force | Out-Null }
        Set-ItemProperty -Path $printKey -Name 'RpcAuthnLevelPrivacyEnabled' -Value 0 -Type DWord -Force

        Write-Host ' [2/3] Cau hinh RPC over Named Pipe va Point and Print Policy...' -ForegroundColor Gray
        $rpcKey = 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers\RPC'
        if (-not (Test-Path -LiteralPath $rpcKey)) { New-Item -Path $rpcKey -Force | Out-Null }
        Set-ItemProperty -Path $rpcKey -Name 'RpcOverNamedPipe' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $rpcKey -Name 'RpcOverTcp' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $rpcKey -Name 'RpcProtocols' -Value 7 -Type DWord -Force

        $pnpKey = 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
        if (-not (Test-Path -LiteralPath $pnpKey)) { New-Item -Path $pnpKey -Force | Out-Null }
        Set-ItemProperty -Path $pnpKey -Name 'Restricted' -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $pnpKey -Name 'NoWarningNoElevationOnInstall' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $pnpKey -Name 'UpdatePromptSettings' -Value 2 -Type DWord -Force

        Write-Host ' [3/3] Khoi dong lai dich vu Print Spooler...' -ForegroundColor Gray
        Restart-Service -Name Spooler -Force -ErrorAction Stop
        Start-Sleep -Seconds 2

        Write-Host '-------------------------------------------------------------------------------------------'
        Write-Host ' [THANH CONG] Da ap dung ban sua loi RPC Print va khoi dong lai Spooler!' -ForegroundColor Green
        Write-Host ' Ban co the vao "Printers & Scanners" hoac go "\\<ten_may_chu>" de them lai may in mang.' -ForegroundColor Cyan
    }
    catch {
        Write-Host (' [LOI] ' + $_.Exception.Message) -ForegroundColor Red
    }
    Write-Host '==========================================================================================='
    Write-SessionLog 'Invoke-RpcPrintFix completed'
}

function Invoke-DriverBackup {
    param([string] $Destination)
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '          SAO LUU TOAN BO DRIVER OEM DANG DUNG (BACKUP / EXPORT DRIVERS)' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan

    $safeComp = Get-SafeName $env:COMPUTERNAME
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

    if ([string]::IsNullOrWhiteSpace($Destination)) {
        $targetDrive = 'D:'
        if (-not (Test-Path -LiteralPath 'D:\' -PathType Container)) {
            $otherDrives = @(Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 -and $_.DeviceID -ne 'C:' })
            if ($otherDrives.Count -gt 0) {
                $targetDrive = $otherDrives[0].DeviceID
            } else {
                $targetDrive = Join-Path $OutputRoot 'Driver_Backups'
            }
        }
        $defaultFolder = Join-Path $targetDrive ("Driver_Backup_{0}_{1}" -f $safeComp, $stamp)

        Write-Host (' Thu muc sao luu goi y: {0}' -f $defaultFolder) -ForegroundColor Yellow
        $customPath = Read-Host ' Nhan [Enter] de dung thu muc goi y, hoac nhap duong dan khac'
        $Destination = if ([string]::IsNullOrWhiteSpace($customPath)) { $defaultFolder } else { $customPath.Trim('"').Trim() }
    }

    try {
        if (-not (Test-Path -LiteralPath $Destination)) {
            [IO.Directory]::CreateDirectory($Destination) | Out-Null
        }
    }
    catch {
        Write-Host (' [LOI] Khong the tao thu muc {0}: {1}' -f $Destination, $_.Exception.Message) -ForegroundColor Red
        Write-SessionLog ('DriverBackup create folder failed: ' + $_.Exception.Message) 'ERROR'
        return
    }

    Write-Host (' Dang xuat toan bo driver OEM he thong vao: {0}...' -f $Destination) -ForegroundColor Yellow
    Write-SessionLog ('Starting DriverBackup to: ' + $Destination)

    $success = $false
    try {
        Export-WindowsDriver -Online -Destination $Destination -ErrorAction Stop | Out-Null
        $success = $true
    }
    catch {
        Write-Host (' Export-WindowsDriver gap loi ({0}), dang thu voi DISM.exe...' -f $_.Exception.Message) -ForegroundColor Yellow
        try {
            $dismProc = Start-Process -FilePath 'dism.exe' -ArgumentList ('/online /export-driver /destination:"{0}"' -f $Destination) -Wait -PassThru -NoNewWindow
            if ($dismProc.ExitCode -eq 0) {
                $success = $true
            } else {
                Write-Host (' DISM xuat driver that bai voi ma loi {0}.' -f $dismProc.ExitCode) -ForegroundColor Red
            }
        }
        catch {
            Write-Host (' DISM gap loi: {0}' -f $_.Exception.Message) -ForegroundColor Red
        }
    }

    if ($success) {
        $infFiles = @(Get-ChildItem -LiteralPath $Destination -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue)
        $totalBytes = ($infFiles | Measure-Object -Property Length -Sum).Sum
        $sizeMB = if ($totalBytes) { [math]::Round($totalBytes / 1MB, 2) } else { 0 }

        Write-Host '-------------------------------------------------------------------------------------------'
        Write-Host (' [THANH CONG] Da sao luu {0} goi driver OEM vao thu muc:' -f $infFiles.Count) -ForegroundColor Green
        Write-Host (' -> {0}' -f $Destination) -ForegroundColor Green
        Write-Host (' Tong dung luong uoc tinh: {0} MB' -f $sizeMB) -ForegroundColor Cyan
        Write-Host ' Ban co the sao chep thu muc nay sang USB de cai dat lai khi cai Windows.' -ForegroundColor Yellow
        Write-Host '==========================================================================================='
        Write-SessionLog ('DriverBackup success: count=' + $infFiles.Count + ', dest=' + $Destination)
    } else {
        Write-Host ' [THAT BAI] Khong the xuat driver. Vui long kiem tra quyen Administrator hoac dung luong o dia.' -ForegroundColor Red
        Write-SessionLog 'DriverBackup failed' 'ERROR'
    }
}

function Invoke-DriverRestore {
    param([string] $SourceFolder)
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '       KHOI PHUC / CAI DAT DRIVER HANG LOAT TU THU MUC (.INF) BANG PNPUTIL' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan

    if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
        $inputPath = Read-Host ' Nhap duong dan den thu muc chua file driver (.inf)'
        $SourceFolder = $inputPath.Trim('"').Trim()
    }

    if ([string]::IsNullOrWhiteSpace($SourceFolder) -or -not (Test-Path -LiteralPath $SourceFolder)) {
        Write-Host (' [LOI] Thu muc khong ton tai hoac duong dan khong hop le: {0}' -f $SourceFolder) -ForegroundColor Red
        return
    }

    $infFiles = @(Get-ChildItem -LiteralPath $SourceFolder -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue)
    if ($infFiles.Count -eq 0) {
        Write-Host (' [CANH BAO] Khong tim thay file .inf nao trong thu muc: {0}' -f $SourceFolder) -ForegroundColor Yellow
        return
    }

    Write-Host (' Tim thay {0} file driver .inf trong thu muc.' -f $infFiles.Count) -ForegroundColor Cyan
    Write-Host ' CANH BAO: Cai dat hang loat driver co the lam thay doi hoat dong thiet bi hoac yeu cau khoi dong lai.' -ForegroundColor Yellow
    $confirm = Read-Host ' Ban co muon tien hanh cai dat tat ca driver nay? (Go Y de dong y)'
    if ($confirm -cne 'Y' -and $confirm -cne 'y') {
        Write-Host ' Da huy tac vu cai dat driver.' -ForegroundColor Yellow
        return
    }

    Write-Host (' Dang nap driver tu: {0}...' -f $SourceFolder) -ForegroundColor Yellow
    Write-SessionLog ('Starting DriverRestore from: ' + $SourceFolder)
    & pnputil.exe /add-driver (Join-Path $SourceFolder '*.inf') /subdirs /install
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' Hoan tat lenh nap driver. Neu co thiet bi moi hoac cap nhat, hay khoi dong lai may de co hieu luc.' -ForegroundColor Green
    Write-Host '==========================================================================================='
    Write-SessionLog 'DriverRestore completed'
}

function Invoke-DriverUninstall {
    param([string] $Name, [switch] $ForceUninstall)
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '             GO BO DRIVER LOI / XUNG DOT BEN THU BA (OEM DRIVER)' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan

    Write-Host ' Danh sach cac goi driver OEM ben thu ba hien co tren may:' -ForegroundColor Yellow
    & pnputil.exe /enum-drivers | more /E
    Write-Host '-------------------------------------------------------------------------------------------'

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $inputName = Read-Host ' Nhap ten Published Name cua driver can go bo (vi du: oem12.inf)'
        $Name = $inputName.Trim().ToLowerInvariant()
    }

    if ($Name -notmatch '^oem\d+\.inf$') {
        Write-Host (' [LOI] Ten driver phai co dinh dang oemX.inf (vi du: oem5.inf). Nhap vao: {0}' -f $Name) -ForegroundColor Red
        return
    }

    $isForce = $ForceUninstall.IsPresent
    if (-not $isForce) {
        $askForce = Read-Host ' Ban co muon dung co /force (go bo ke ca khi dang duoc thiet bi dung)? (Y/N)'
        if ($askForce -in @('Y', 'y')) { $isForce = $true }
    }

    Write-Host ' CANH BAO NGHIEP VU: Go bo driver co the lam thiet bi lien quan ngung hoat dong.' -ForegroundColor Red
    $confirm = Read-Host (' Go chinh xac tu DELETE de xac nhan go bo ' + $Name)
    if ($confirm -cne 'DELETE') {
        Write-Host ' Da huy thao tac go bo driver.' -ForegroundColor Yellow
        return
    }

    Write-Host (' Dang go bo driver {0}...' -f $Name) -ForegroundColor Yellow
    Write-SessionLog ('Starting DriverUninstall for: ' + $Name + ' (Force=' + $isForce + ')')

    if ($isForce) {
        & pnputil.exe /delete-driver $Name /uninstall /force
    } else {
        & pnputil.exe /delete-driver $Name /uninstall
    }
    Write-Host ' Hoan tat thao tac pnputil /delete-driver.' -ForegroundColor Green
    Write-SessionLog ('DriverUninstall completed for: ' + $Name)
}

function Get-LaptopHardwareProfile {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

    $manufacturer = if ($cs.Manufacturer) { $cs.Manufacturer.Trim() } else { 'Unknown' }
    $model = if ($cs.Model) { $cs.Model.Trim() } else { 'Unknown' }
    $serial = if ($bios.SerialNumber) { $bios.SerialNumber.Trim() } else { 'Unknown' }
    $biosVersion = if ($bios.SMBIOSBIOSVersion) { $bios.SMBIOSBIOSVersion.Trim() } else { 'Unknown' }
    $osName = if ($os.Caption) { $os.Caption.Trim() } else { 'Windows' }
    $osArch = if ($os.OSArchitecture) { $os.OSArchitecture.Trim() } else { 'x64' }

    $chassis = Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue
    $chassisTypes = @($chassis.ChassisTypes)
    $isLaptop = [bool]($chassisTypes | Where-Object { $_ -in @(8, 9, 10, 11, 12, 14, 30, 31, 32) })

    $oemName = 'Unknown'
    $supportUrl = ''
    if ($manufacturer -like '*Dell*') {
        $oemName = 'Dell'
        if ($serial -and $serial -ne 'Unknown') {
            $supportUrl = "https://www.dell.com/support/home/vi-vn/product-support/servicetag/$serial/drivers"
        } else {
            $supportUrl = "https://www.dell.com/support/home/vi-vn?app=drivers"
        }
    }
    elseif ($manufacturer -like '*HP*' -or $manufacturer -like '*Hewlett-Packard*') {
        $oemName = 'HP'
        $supportUrl = "https://support.hp.com/vn-vi/drivers"
    }
    elseif ($manufacturer -like '*Lenovo*') {
        $oemName = 'Lenovo'
        if ($serial -and $serial -ne 'Unknown') {
            $supportUrl = "https://pcsupport.lenovo.com/vn/en/productssearch?q=$serial"
        } else {
            $supportUrl = "https://pcsupport.lenovo.com/vn/en/"
        }
    }
    elseif ($manufacturer -like '*ASUSTeK*' -or $manufacturer -like '*ASUS*') {
        $oemName = 'ASUS'
        $supportUrl = "https://www.asus.com/support/Download-Center/"
    }
    elseif ($manufacturer -like '*Acer*') {
        $oemName = 'Acer'
        if ($serial -and $serial -ne 'Unknown') {
            $supportUrl = "https://www.acer.com/ac/vi/VN/content/support-product/$serial"
        } else {
            $supportUrl = "https://www.acer.com/ac/vi/VN/content/drivers"
        }
    }
    elseif ($manufacturer -like '*MSI*' -or $manufacturer -like '*Micro-Star*') {
        $oemName = 'MSI'
        $supportUrl = "https://www.msi.com/support/download"
    }
    elseif ($manufacturer -like '*Gigabyte*') {
        $oemName = 'Gigabyte'
        $supportUrl = "https://www.gigabyte.com/Support"
    }
    elseif ($manufacturer -like '*Microsoft*') {
        $oemName = 'Microsoft Surface'
        $supportUrl = "https://support.microsoft.com/en-us/surface/download-drivers-and-firmware-for-surface-09bb2e09-2a4b-cb69-0951-078a7739e120"
    }

    $problemDevices = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'OK' })

    return [pscustomobject]@{
        Manufacturer   = $manufacturer
        Model          = $model
        Serial         = $serial
        BIOSVersion    = $biosVersion
        OS             = "$osName $osArch"
        IsLaptop       = [bool]$isLaptop
        OEMName        = $oemName
        SupportUrl     = $supportUrl
        ProblemDevices = $problemDevices
    }
}

function Invoke-DriverAutoScan {
    $profile = Get-LaptopHardwareProfile
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '          NHAN DIEN THIET BI & QUET DRIVER THIEU (WHQL WINDOWS UPDATE)' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host ('  Hang san xuat   : {0} ({1})' -f $profile.Manufacturer, $profile.OEMName) -ForegroundColor Yellow
    Write-Host ('  Model thiet bi  : {0}' -f $profile.Model) -ForegroundColor Yellow
    Write-Host ('  Serial / Tag    : {0}' -f $profile.Serial) -ForegroundColor Green
    Write-Host ('  Phien ban BIOS  : {0}' -f $profile.BIOSVersion)
    Write-Host ('  He dieu hanh    : {0}' -f $profile.OS)
    $devType = if ($profile.IsLaptop) { 'Laptop / Portable' } else { 'Desktop / PC' }
    Write-Host ('  Loai thiet bi   : {0}' -f $devType)
    if ($profile.SupportUrl) {
        Write-Host ('  Link ho tro OEM : {0}' -f $profile.SupportUrl) -ForegroundColor Cyan
    }
    Write-Host '-------------------------------------------------------------------------------------------'
    if ($profile.ProblemDevices -and $profile.ProblemDevices.Count -gt 0) {
        Write-Host ('  PHAT HIEN {0} THIET BI CHUA NHAN DRIVER HOAC CO LOI (Code 28 / Missing):' -f $profile.ProblemDevices.Count) -ForegroundColor Red
        foreach ($dev in $profile.ProblemDevices) {
            Write-Host ('   - [{0}] {1} (Status: {2}, Class: {3})' -f $dev.InstanceId, $dev.FriendlyName, $dev.Status, $dev.PNPClass) -ForegroundColor Red
        }
    } else {
        Write-Host '  TRANG THAI DRIVER: Tat ca thiet bi dang hoat dong binh thuong (No missing drivers).' -ForegroundColor Green
    }
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' Tuy chon:'
    Write-Host '  [1] Mo trang ho tro driver chinh hang cua OEM (Dell, HP, Lenovo, Asus, Acer...)'
    Write-Host '  [2] Quet va cai dat driver con thieu qua Windows Update (WHQL Microsoft Catalog)'
    Write-Host '  [0] Bo qua'
    $act = Read-Host ' Chon [0-2]'
    if ($act -eq '1') {
        if ($profile.SupportUrl) {
            Write-Host (' Dang mo: {0}' -f $profile.SupportUrl) -ForegroundColor Cyan
            try { Start-Process $profile.SupportUrl | Out-Null } catch { }
        } else {
            Write-Host ' Khong co link tu dong cho hang nay. Hay tra cuu thu cong tren Google.' -ForegroundColor Yellow
        }
    }
    elseif ($act -eq '2') {
        try {
            Write-Host ' Dang ket noi Microsoft Update Catalog de tim Driver phu hop...' -ForegroundColor Yellow
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            $updateSearcher.ServerSelection = 2
            $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Driver'")
            if ($searchResult.Updates.Count -eq 0) {
                Write-Host ' Khong tim thay driver moi tren Windows Update Catalog.' -ForegroundColor Green
            } else {
                Write-Host (' Tim thay {0} driver kha dung tren Windows Update:' -f $searchResult.Updates.Count) -ForegroundColor Yellow
                $updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
                for ($i = 0; $i -lt $searchResult.Updates.Count; $i++) {
                    $u = $searchResult.Updates.Item($i)
                    Write-Host ('  [{0}] {1}' -f ($i + 1), $u.Title) -ForegroundColor Cyan
                    $updatesToDownload.Add($u) | Out-Null
                }
                $confirmWU = Read-Host ' Ban co muon tai ve va cai dat cac driver tren? (Go Y de dong y)'
                if ($confirmWU -in @('Y', 'y')) {
                    $downloader = $updateSession.CreateUpdateDownloader()
                    $downloader.Updates = $updatesToDownload
                    $downloader.Download() | Out-Null
                    $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
                    for ($i = 0; $i -lt $searchResult.Updates.Count; $i++) {
                        $u = $searchResult.Updates.Item($i)
                        if ($u.IsDownloaded) { $updatesToInstall.Add($u) | Out-Null }
                    }
                    if ($updatesToInstall.Count -gt 0) {
                        $installer = $updateSession.CreateUpdateInstaller()
                        $installer.Updates = $updatesToInstall
                        $instRes = $installer.Install()
                        Write-Host (' Hoan tat cai dat driver via WU (ResultCode: {0}).' -f $instRes.ResultCode) -ForegroundColor Green
                    }
                }
            }
        }
        catch {
            Write-Host (' Loi khi goi Windows Update Agent: ' + $_.Exception.Message) -ForegroundColor Red
        }
    }
    Write-Host '==========================================================================================='
    Write-SessionLog 'DriverAutoScan completed'
}

