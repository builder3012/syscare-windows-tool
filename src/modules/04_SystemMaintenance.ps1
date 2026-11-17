function Invoke-ClearOfficeCache {
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '        XOA CACHE MICROSOFT 365 / TEAMS / OUTLOOK (SUA LOI TREO, LOGIN LOOP)' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host ' Tac vu nay se giai quyet cac loi pho bien:' -ForegroundColor Yellow
    Write-Host '  1. Teams bi treo man hinh trang, khong tai tin nhan, vong lap dang nhap (login loop).'
    Write-Host '  2. Outlook loi RoamCache, danh ba autocomplete bi hong, khong mo duoc profile.'
    Write-Host '  3. Office OneAuth / IdentityCache xung dot tai khoan co quan va ca nhan.'
    Write-Host ' LUU Y: Khong anh huong den hop thu email (OST/PST) hay tai lieu OneDrive/SharePoint.' -ForegroundColor Cyan
    Write-Host '-------------------------------------------------------------------------------------------'

    $confirm = Read-Host ' Ban co muon DONG Teams/Outlook va tien hanh xoa cache khong? (Go Y de dong y)'
    if ($confirm -cne 'Y' -and $confirm -cne 'y') {
        Write-Host ' Da huy thao tac xoa cache.' -ForegroundColor Yellow
        return
    }

    Write-Host ' [1/3] Dang dong cac tien trinh Teams va Outlook...' -ForegroundColor Yellow
    $appsToKill = @('teams', 'ms-teams', 'outlook', 'olk', 'winword', 'excel', 'powerpnt')
    foreach ($app in $appsToKill) {
        try {
            $procs = Get-Process -Name $app -ErrorAction SilentlyContinue
            if ($procs) {
                $procs | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-Host ('  - Da dong tien trinh: {0}' -f $app) -ForegroundColor Gray
            }
        } catch { }
    }
    Start-Sleep -Seconds 2

    Write-Host ' [2/3] Dang dọn dẹp các thư mục cache ứng dụng...' -ForegroundColor Yellow
    $deletedCount = 0

    $newTeamsCache = Join-Path $env:LOCALAPPDATA 'Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams'
    if (Test-Path -LiteralPath $newTeamsCache) {
        try {
            Remove-Item -LiteralPath $newTeamsCache -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host '  [OK] Da xoa bo nho dem New Teams (MSTeams LocalCache)' -ForegroundColor Green
            $deletedCount++
        } catch { Write-Warning ('Loi khi xoa New Teams cache: ' + $_.Exception.Message) }
    }

    $classicTeams = Join-Path $env:APPDATA 'Microsoft\Teams'
    if (Test-Path -LiteralPath $classicTeams) {
        $subDirs = @('blob_storage', 'Cache', 'databases', 'GPUCache', 'IndexedDB', 'Local Storage', 'tmp')
        foreach ($sd in $subDirs) {
            $target = Join-Path $classicTeams $sd
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host '  [OK] Da xoa bo nho dem Classic Teams' -ForegroundColor Green
        $deletedCount++
    }

    $roamCache = Join-Path $env:LOCALAPPDATA 'Microsoft\Outlook\RoamCache'
    if (Test-Path -LiteralPath $roamCache) {
        try {
            Get-ChildItem -LiteralPath $roamCache -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host '  [OK] Da xoa Outlook RoamCache' -ForegroundColor Green
            $deletedCount++
        } catch { Write-Warning ('Loi khi xoa Outlook RoamCache: ' + $_.Exception.Message) }
    }

    $authPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\OneAuth'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\IdentityCache'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\TokenBroker\Cache')
    )
    foreach ($ap in $authPaths) {
        if (Test-Path -LiteralPath $ap) {
            try {
                Get-ChildItem -LiteralPath $ap -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host ('  [OK] Da xoa Office Identity Cache: {0}' -f (Split-Path -Leaf $ap)) -ForegroundColor Green
                $deletedCount++
            } catch { }
        }
    }

    $officeCache = Join-Path $env:LOCALAPPDATA 'Microsoft\Office\16.0\OfficeFileCache'
    if (Test-Path -LiteralPath $officeCache) {
        try {
            Get-ChildItem -LiteralPath $officeCache -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host '  [OK] Da xoa Office 16.0 OfficeFileCache' -ForegroundColor Green
            $deletedCount++
        } catch { }
    }

    Write-Host ' [3/3] Hoan tat dọn dẹp!' -ForegroundColor Yellow
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host (' [THANH CONG] Da dọn dẹp xong cac bo nho dem Office/Teams/Outlook ({0} muc da duoc xu ly).' -f $deletedCount) -ForegroundColor Green
    Write-Host ' Nguoi dung co the mo lai Teams va Outlook de dang nhap lai binh thuong.' -ForegroundColor Cyan
    Write-Host '==========================================================================================='
    Write-SessionLog ('ClearOfficeCache completed. Cleaned items: ' + $deletedCount)
}

function Invoke-WiFiProfileBackup {
    param([string] $Destination)
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '              SAO LUU PROFILE MANG WI-FI (NETSH WLAN EXPORT PROFILE)' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan

    $svc = Get-Service -Name wlansvc -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host ' [LOI] Dich vu WLAN AutoConfig (wlansvc) khong co tren he thong nay.' -ForegroundColor Red
        return
    }
    if ($svc.Status -ne 'Running') {
        Write-Host ' Dich vu WLAN dang tat. Dang khoi chay wlansvc...' -ForegroundColor Yellow
        try { Start-Service -Name wlansvc -ErrorAction Stop }
        catch { Write-Host (' Khong the khoi chay wlansvc: {0}' -f $_.Exception.Message) -ForegroundColor Red; return }
    }

    $profiles = (& netsh.exe wlan show profiles 2>&1 | Out-String)
    if ($profiles -notmatch ':\s+(.+)$') {
        Write-Host ' [THONG BAO] Khong tim thay profile Wi-Fi nao duoc luu tren may nay.' -ForegroundColor Yellow
        return
    }

    $safeComp = Get-SafeName $env:COMPUTERNAME
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    if ([string]::IsNullOrWhiteSpace($Destination)) {
        $Destination = Join-Path $OutputRoot ("WiFi_Profiles_{0}_{1}" -f $safeComp, $stamp)
    }

    try { [IO.Directory]::CreateDirectory($Destination) | Out-Null }
    catch {
        Write-Host (' [LOI] Khong the tao thu muc {0}: {1}' -f $Destination, $_.Exception.Message) -ForegroundColor Red
        return
    }

    Write-Host (' Dang xuat cac profile Wi-Fi ra thu muc: {0}...' -f $Destination) -ForegroundColor Yellow
    & netsh.exe wlan export profile folder="$Destination" key=clear | Out-Null

    $xmlFiles = @(Get-ChildItem -LiteralPath $Destination -Filter '*.xml' -ErrorAction SilentlyContinue)
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host (' [THANH CONG] Da xuat {0} profile Wi-Fi thanh cong vao:' -f $xmlFiles.Count) -ForegroundColor Green
    Write-Host (' -> {0}' -f $Destination) -ForegroundColor Green
    foreach ($xf in $xmlFiles) {
        Write-Host ('   - {0}' -f $xf.Name) -ForegroundColor Cyan
    }
    Write-Host ''
    Write-Host ' LUU Y BAO MAT: Cac file XML chua mat khau Wi-Fi ro rang (key=clear).' -ForegroundColor Yellow
    Write-Host ' Hay bao ve thu muc nay va xoa sau khi hoan tat khoi phuc.' -ForegroundColor Yellow
    Write-Host '==========================================================================================='
    Write-SessionLog ('WiFiProfileBackup completed. Exported: ' + $xmlFiles.Count + ' files to ' + $Destination)
    try { Start-Process explorer.exe -ArgumentList ('/select,"{0}"' -f $Destination) | Out-Null } catch { }
}

function Invoke-WiFiProfileRestore {
    param([string] $SourceFolder)
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '             KHOI PHUC PROFILE MANG WI-FI (NETSH WLAN ADD PROFILE)' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan

    $svc = Get-Service -Name wlansvc -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host ' [LOI] Dich vu WLAN AutoConfig (wlansvc) khong co tren he thong nay.' -ForegroundColor Red
        return
    }
    if ($svc.Status -ne 'Running') {
        try { Start-Service -Name wlansvc -ErrorAction Stop } catch { }
    }

    if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
        $inputPath = Read-Host ' Nhap duong dan thu muc chua cac file XML profile Wi-Fi da sao luu'
        $SourceFolder = $inputPath.Trim('"').Trim()
    }

    if ([string]::IsNullOrWhiteSpace($SourceFolder) -or -not (Test-Path -LiteralPath $SourceFolder)) {
        Write-Host (' [LOI] Thu muc khong hop le hoac khong ton tai: {0}' -f $SourceFolder) -ForegroundColor Red
        return
    }

    $xmlFiles = @(Get-ChildItem -LiteralPath $SourceFolder -Filter '*.xml' -ErrorAction SilentlyContinue)
    if ($xmlFiles.Count -eq 0) {
        Write-Host (' [CANH BAO] Khong tim thay file XML profile nao trong: {0}' -f $SourceFolder) -ForegroundColor Yellow
        return
    }

    Write-Host (' Tim thay {0} profile Wi-Fi can khoi phuc.' -f $xmlFiles.Count) -ForegroundColor Cyan
    $confirm = Read-Host ' Ban co muon nap cac profile nay vao he thong khong? (Go Y de dong y)'
    if ($confirm -cne 'Y' -and $confirm -cne 'y') {
        Write-Host ' Da huy thao tac.' -ForegroundColor Yellow
        return
    }

    $imported = 0
    foreach ($xf in $xmlFiles) {
        try {
            $out = & netsh.exe wlan add profile filename="$($xf.FullName)" user=all 2>&1 | Out-String
            Write-Host ('  + Nap profile [{0}]: {1}' -f $xf.Name, $out.Trim()) -ForegroundColor Green
            $imported++
        }
        catch {
            Write-Host ('  - Loi khi nap [{0}]: {1}' -f $xf.Name, $_.Exception.Message) -ForegroundColor Red
        }
    }

    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host (' [HOAN TAT] Da nap thanh cong {0}/{1} profile Wi-Fi.' -f $imported, $xmlFiles.Count) -ForegroundColor Green
    Write-Host '==========================================================================================='
    Write-SessionLog ('WiFiProfileRestore completed: imported ' + $imported + ' of ' + $xmlFiles.Count)
}

function Invoke-DomainRepair {
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '           KIEM TRA VA SUA LOI QUAN HE TIN CAY DOMAIN (SECURE CHANNEL)' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan

    $cs = Get-CimInstance Win32_ComputerSystem
    if (-not $cs.PartOfDomain) {
        Write-Host ' [THONG BAO] May tinh nay dang o che do WORKGROUP, khong gia nhap Domain Active Directory.' -ForegroundColor Yellow
        Write-Host ' Chuc nang sua Secure Channel chi ap dung cho may tinh thuoc Domain.' -ForegroundColor Gray
        return
    }

    $domain = $cs.Domain
    Write-Host (' May tinh thuoc Domain: {0}' -f $domain) -ForegroundColor Yellow
    Write-Host ' Dang kiem tra kenh an toan (Test-ComputerSecureChannel)...' -ForegroundColor Cyan

    $scStatus = $false
    try {
        $scStatus = [bool](Test-ComputerSecureChannel -Verbose -ErrorAction Stop)
    }
    catch {
        Write-Host (' [LOI TEST] ' + $_.Exception.Message) -ForegroundColor Red
    }

    if ($scStatus) {
        Write-Host ' -> Trang thai Secure Channel hien tai: TOT (TRUE / OK).' -ForegroundColor Green
        Write-Host ' Quan he tin cay giua may tinh va Domain Controller van hoat dong binh thuong.' -ForegroundColor Green
        $force = Read-Host ' Ban co muon CUONG BUC lam moi lai ket noi (Force Repair) khong? (Y/N)'
        if ($force -notin @('Y', 'y')) {
            Write-Host ' Khong co thay doi nao duoc thuc hien.' -ForegroundColor Yellow
            return
        }
    } else {
        Write-Host ' -> Canh bao: Secure Channel gap van de hoac mat tin cay voi Domain Controller!' -ForegroundColor Red
    }

    Write-Host ' Dang tien hanh sua va thiet lap lai Secure Channel...' -ForegroundColor Yellow
    Write-SessionLog ('Starting DomainRepair for domain: ' + $domain)

    $repairSuccess = $false
    try {
        $repairSuccess = [bool](Test-ComputerSecureChannel -Repair -ErrorAction Stop)
    }
    catch {
        Write-Host (' Test-ComputerSecureChannel -Repair thong bao: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    if (-not $repairSuccess) {
        Write-Host ' Dang thu dat lai bang nltest /sc_reset...' -ForegroundColor Yellow
        try {
            $nlOut = & nltest.exe /sc_reset:$domain 2>&1 | Out-String
            Write-Host $nlOut.Trim()
            if ($nlOut -match 'Success') { $repairSuccess = $true }
        } catch { }
    }

    Write-Host ' Dang xoa ve Kerberos cu (klist purge)...' -ForegroundColor Gray
    try { & klist.exe purge | Out-Null } catch { }

    Write-Host ' Dang dong bo lai thoi gian voi Domain Controller (w32tm)...' -ForegroundColor Gray
    try { & w32tm.exe /resync /rediscover | Out-Null } catch { }

    Write-Host ' Dang cap nhat lai chinh sach nhom (gpupdate /force)...' -ForegroundColor Gray
    try { & gpupdate.exe /force | Out-Null } catch { }

    Write-Host '-------------------------------------------------------------------------------------------'
    $finalStatus = [bool](Test-ComputerSecureChannel -ErrorAction SilentlyContinue)
    if ($finalStatus) {
        Write-Host ' [THANH CONG] Kenh an toan voi Domain da duoc khoi phuc va xac thuc thanh cong!' -ForegroundColor Green
        Write-Host ' Khuyen nghi: Khoi dong lai may tinh neu truoc do user khong dang nhap duoc domain.' -ForegroundColor Cyan
    } else {
        Write-Host ' [CHUA HOAN TAT] May tinh van chua ket noi duoc voi Domain Controller.' -ForegroundColor Red
        Write-Host ' Khuyen nghi: Kiem tra cap mang/IP DNS Domain, hoac nho Domain Admin gia nhap lai Domain.' -ForegroundColor Yellow
    }
    Write-Host '==========================================================================================='
    Write-SessionLog ('DomainRepair completed. Final status: ' + $finalStatus)
}

function Invoke-SearchFix {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-SearchFix started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  SUA LOI WINDOWS SEARCH VA START MENU (TASKBAR SEARCH FIX)' -ForegroundColor Cyan
    Write-Host '==========================================================================================='
    Write-Host ' Tien trinh se dung dich vu Search, ket thuc tien trinh giao dien Tim kiem va khoi dong lai.'

    Write-Host ' [1/4] Dang dung dich vu Windows Search (WSearch)...' -ForegroundColor Gray
    try { & net.exe stop wsearch /y 2>&1 | Out-Null } catch { }

    Write-Host ' [2/4] Dang ket thuc tien trinh SearchHost, SearchIndexer, StartMenu...' -ForegroundColor Gray
    $procs = @('SearchHost', 'SearchIndexer', 'StartMenuExperienceHost', 'ShellExperienceHost')
    foreach ($p in $procs) {
        try { Stop-Process -Name $p -Force -ErrorAction SilentlyContinue } catch { }
    }
    Start-Sleep -Seconds 1

    Write-Host ' [3/4] Dang dat lai trang thai dich vu WSearch ve Automatic...' -ForegroundColor Gray
    try { Set-Service -Name 'wsearch' -StartupType Automatic -ErrorAction SilentlyContinue } catch { }
    try { & net.exe start wsearch 2>&1 | Out-Null } catch { }

    Write-Host ' [4/4] Dang kiem tra lai trang thai dich vu...' -ForegroundColor Gray
    $svc = Get-Service -Name 'wsearch' -ErrorAction SilentlyContinue
    Write-Host '-------------------------------------------------------------------------------------------'
    if ($svc -and $svc.Status -eq 'Running') {
        Write-Host ' [THANH CONG] Dich vu Windows Search dang chay on dinh (Status: Running).' -ForegroundColor Green
        Write-Host ' Hay thu nhan nut Start / Tim kiem tren Taskbar de kiem tra lai.' -ForegroundColor Cyan
    } else {
        Write-Host ' [CANH BAO] Khong the khoi dong lai dich vu wsearch tu dong.' -ForegroundColor Yellow
        Write-Host ' Hay mo services.msc de kiem tra chi tiet.' -ForegroundColor Gray
    }
    Write-Host '==========================================================================================='
    Write-SessionLog 'Invoke-SearchFix completed'
}

function Invoke-DeepClean {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-DeepClean started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  DON DEP HE THONG SAU 1-CLICK (DEEP SYSTEM JUNK CLEAN)' -ForegroundColor Cyan
    Write-Host '==========================================================================================='
    Write-Host ' Cac thu muc se duoc don dep an toan:'
    Write-Host '  1. Thu muc Temp nguoi dung   : ' -NoNewline; Write-Host $env:TEMP -ForegroundColor Yellow
    Write-Host '  2. Thu muc Temp he thong     : ' -NoNewline; Write-Host "$env:SystemRoot\Temp" -ForegroundColor Yellow
    Write-Host '  3. Thu muc Prefetch          : ' -NoNewline; Write-Host "$env:SystemRoot\Prefetch" -ForegroundColor Yellow
    Write-Host '  4. Cache Windows Update      : ' -NoNewline; Write-Host "$env:SystemRoot\SoftwareDistribution\Download" -ForegroundColor Yellow
    Write-Host '  5. Thung rac Recycle Bin     : Tat ca cac o dia' -ForegroundColor Yellow
    Write-Host '-------------------------------------------------------------------------------------------'

    $initFree = 0
    try {
        $cDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
        if ($cDrive) { $initFree = $cDrive.Free }
    } catch { }

    $confirm = Read-Host 'Ban co chac chan muon tien hanh don dep he thong? (Y/N)'
    if ($confirm -notmatch '^[Yy]') {
        Write-Host 'Da huy thao tac don dep.' -ForegroundColor Yellow
        return
    }

    $deletedCount = 0
    $targets = @(
        $env:TEMP,
        (Join-Path $env:SystemRoot 'Temp'),
        (Join-Path $env:SystemRoot 'Prefetch'),
        (Join-Path (Join-Path $env:SystemRoot 'SoftwareDistribution') 'Download')
    )

    foreach ($folder in $targets) {
        if ([IO.Directory]::Exists($folder)) {
            Write-Host (' Dang don dep: {0}...' -f $folder) -ForegroundColor Gray
            try {
                $items = Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    try {
                        Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        $deletedCount++
                    } catch { }
                }
            } catch { }
        }
    }

    Write-Host ' Dang don dep Thung rac (Recycle Bin)...' -ForegroundColor Gray
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null
    } catch { }

    $finalFree = 0
    try {
        $cDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
        if ($cDrive) { $finalFree = $cDrive.Free }
    } catch { }

    $freedBytes = [Math]::Max(0, ($finalFree - $initFree))
    $freedMB = [Math]::Round(($freedBytes / 1MB), 2)

    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' [HOAN TAT] Don dep he thong sau thanh cong!' -ForegroundColor Green
    Write-Host (' Tong so muc da xu ly/xoa : {0} muc' -f $deletedCount)
    if ($freedMB -gt 1024) {
        $freedGB = [Math]::Round(($freedMB / 1024), 2)
        Write-Host (' Dung luong o C: da duoc giai phong: ~{0} GB' -f $freedGB) -ForegroundColor Cyan
    } else {
        Write-Host (' Dung luong o C: da duoc giai phong: ~{0} MB' -f $freedMB) -ForegroundColor Cyan
    }
    Write-Host '==========================================================================================='
    Write-SessionLog ('Invoke-DeepClean completed. Freed MB: ' + $freedMB)
}

function Invoke-FastStartupToggle {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-FastStartupToggle started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  BAT / TAT FAST STARTUP VA HIBERNATION (NGUON & KHOI DONG NHANH)' -ForegroundColor Cyan
    Write-Host '==========================================================================================='
    Write-Host ' Giai thich IT:'
    Write-Host '  - Tinh nang Fast Startup tao file hiberfil.sys (ngon 4-16GB RAM tren o C).'
    Write-Host '  - Day la nguyen nhan hang dau khien laptop khong tat han quat khi gap may, nong may,'
    Write-Host '    loi mat card mang/driver Wi-Fi hoac man hinh den khi danh thuc.'
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' Trang thai cac che do Sleep/Hibernate hien tai:' -ForegroundColor Gray
    try { & powercfg.exe /a } catch { }
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' [1] TAT Fast Startup & Hibernation (Khuyen nghi cho Laptop bi nong / loi sleep / tiet kiem o C)' -ForegroundColor Yellow
    Write-Host ' [2] BAT Fast Startup & Hibernation (Cho may can khoi dong nhanh)' -ForegroundColor Green
    Write-Host ' [0] Quay lai'
    Write-Host '-------------------------------------------------------------------------------------------'

    $choice = Read-Host 'Chon thao tac [0-2]'
    switch ($choice) {
        '1' {
            Write-Host ' Dang tat Fast Startup & Hibernation (powercfg /h off)...' -ForegroundColor Gray
            try {
                & powercfg.exe /h off
                Write-Host ' [THANH CONG] Da tat Hibernation va Fast Startup.' -ForegroundColor Green
                Write-Host ' File hiberfil.sys da duoc xoa, giai phong dung luong tren o C.' -ForegroundColor Cyan
            } catch {
                Write-Host (' Loi: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }
        }
        '2' {
            Write-Host ' Dang bat Fast Startup & Hibernation (powercfg /h on)...' -ForegroundColor Gray
            try {
                & powercfg.exe /h on
                Write-Host ' [THANH CONG] Da bat Hibernation va Fast Startup.' -ForegroundColor Green
            } catch {
                Write-Host (' Loi: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }
        }
        default {
            Write-Host 'Quay lai menu.'
        }
    }
    Write-Host '==========================================================================================='
    Write-SessionLog 'Invoke-FastStartupToggle completed'
}

