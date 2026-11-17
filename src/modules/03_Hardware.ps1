function Invoke-AssetSpecs {
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '           THONG TIN PHAN CUNG & TAI SAN MAY TINH (ASSET TAG & SPECS)' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan

    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

    $compName = $env:COMPUTERNAME
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $manufacturer = if ($cs.Manufacturer) { $cs.Manufacturer.Trim() } else { 'Unknown OEM' }
    $model = if ($cs.Model) { $cs.Model.Trim() } else { 'Unknown Model' }
    $serial = if ($bios.SerialNumber) { $bios.SerialNumber.Trim() } else { 'Unknown SN' }
    $biosVer = if ($bios.SMBIOSBIOSVersion) { $bios.SMBIOSBIOSVersion.Trim() } else { 'Unknown' }
    $boardInfo = if ($board) { ('{0} {1}' -f $board.Manufacturer, $board.Product).Trim() } else { 'Unknown' }
    $osCaption = if ($os.Caption) { $os.Caption.Trim() } else { 'Windows' }
    $osBuild = if ($os.BuildNumber) { $os.BuildNumber.Trim() } else { 'Unknown' }
    $osArch = if ($os.OSArchitecture) { $os.OSArchitecture.Trim() } else { '64-bit' }

    $cpuName = if ($cpu.Name) { ($cpu.Name -replace '\s+', ' ').Trim() } else { 'Unknown CPU' }
    $cpuCores = if ($cpu.NumberOfCores) { $cpu.NumberOfCores } else { 0 }
    $cpuThreads = if ($cpu.NumberOfLogicalProcessors) { $cpu.NumberOfLogicalProcessors } else { 0 }

    $memSticks = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $memArray = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Select-Object -First 1
    $totalRamBytes = ($memSticks | Measure-Object -Property Capacity -Sum).Sum
    $totalRamGB = if ($totalRamBytes) { [math]::Round($totalRamBytes / 1GB, 1) } else { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) }
    $totalSlots = if ($memArray -and $memArray.MemoryDevices) { $memArray.MemoryDevices } else { $memSticks.Count }
    $usedSlots = $memSticks.Count
    $speedList = ($memSticks | Where-Object { $_.Speed } | Select-Object -ExpandProperty Speed -Unique) -join '/'
    $ramSpeedStr = if ($speedList) { "$speedList MHz" } else { 'Standard' }

    $disks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    $diskSummaryList = @()
    if ($disks.Count -gt 0) {
        foreach ($d in $disks) {
            $szGB = [math]::Round($d.Size / 1GB, 0)
            $type = if ($d.MediaType) { $d.MediaType } else { 'Disk' }
            $bus = if ($d.BusType) { $d.BusType } else { '' }
            $diskSummaryList += ('{0}GB {1} {2}' -f $szGB, $bus, $type).Trim()
        }
    } else {
        $logDisks = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue
        foreach ($ld in $logDisks) {
            $szGB = [math]::Round($ld.Size / 1GB, 0)
            $diskSummaryList += ('{0}GB Disk ({1})' -f $szGB, $ld.Model)
        }
    }
    $diskSummary = ($diskSummaryList -join ', ')

    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -Unique)
    $gpuSummary = ($gpus -join ' / ')

    $activeNet = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' -ErrorAction SilentlyContinue | Select-Object -First 1
    $ipAddr = if ($activeNet.IPAddress) { $activeNet.IPAddress[0] } else { 'No IP' }
    $macAddr = if ($activeNet.MACAddress) { $activeNet.MACAddress } else { 'No MAC' }

    $oneLine = ('[ASSET] Name: {0} | Tag/SN: {1} | OEM: {2} ({3}) | CPU: {4} ({5}C/{6}T) | RAM: {7}GB ({8}/{9} Slots, {10}) | Disk: {11} | OS: {12} (Build {13}) | IP: {14} | User: {15}' -f `
        $compName, $serial, $manufacturer, $model, $cpuName, $cpuCores, $cpuThreads, $totalRamGB, $usedSlots, $totalSlots, $ramSpeedStr, $diskSummary, $osCaption, $osBuild, $ipAddr, $currentUser)

    Write-Host ('  May tinh / Hostname  : {0}' -f $compName) -ForegroundColor Cyan
    Write-Host ('  Nguoi dung hien tai  : {0}' -f $currentUser)
    Write-Host ('  Hang san xuat (OEM)  : {0}' -f $manufacturer) -ForegroundColor Yellow
    Write-Host ('  Model thiet bi       : {0}' -f $model) -ForegroundColor Yellow
    Write-Host ('  Serial / Service Tag : {0}' -f $serial) -ForegroundColor Green
    Write-Host ('  Bo mach chu (Board)  : {0}' -f $boardInfo)
    Write-Host ('  Phien ban BIOS       : {0}' -f $biosVer)
    Write-Host ('  Bo xu ly (CPU)       : {0} ({1} Cores / {2} Threads)' -f $cpuName, $cpuCores, $cpuThreads)
    Write-Host ('  Bo nho RAM           : {0} GB tong cong ({1}/{2} khe cam duoc dung, toc do: {3})' -f $totalRamGB, $usedSlots, $totalSlots, $ramSpeedStr) -ForegroundColor Cyan
    foreach ($m in $memSticks) {
        Write-Host ('     - Khe {0}: {1} GB, {2} MHz, {3} ({4})' -f $m.DeviceLocator, [math]::Round($m.Capacity / 1GB, 1), $m.Speed, $m.Manufacturer, $m.PartNumber) -ForegroundColor Gray
    }
    Write-Host ('  O dia luu tru        : {0}' -f $diskSummary)
    Write-Host ('  Card do hoa (GPU)    : {0}' -f $gpuSummary)
    Write-Host ('  He dieu hanh         : {0} ({1}) - Build {2}' -f $osCaption, $osArch, $osBuild)
    Write-Host ('  Mang dang dung       : IP={0} | MAC={1}' -f $ipAddr, $macAddr)
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' TOM TAT 1 DONG CHUAN DE DAN VAO TICKET SLA / ITSM:' -ForegroundColor Yellow
    Write-Host $oneLine -ForegroundColor Green
    Write-Host '-------------------------------------------------------------------------------------------'

    $copied = $false
    try {
        Set-Clipboard -Value $oneLine -ErrorAction Stop
        $copied = $true
    }
    catch {
        try {
            $oneLine | clip.exe
            $copied = $true
        } catch { }
    }
    if ($copied) {
        Write-Host ' [OK] Da tu dong COPY dong thong tin tren vao Clipboard! Ban co the bam Ctrl+V de dan vao Ticket.' -ForegroundColor Cyan
    }

    try {
        [IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
        $reportPath = Join-Path $OutputRoot ('Asset_Specs_{0}_{1}.txt' -f (Get-SafeName $compName), (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $reportContent = @(
            '===========================================================================================',
            '                    BAO CAO THONG TIN PHAN CUNG & TAI SAN MAY TINH',
            '===========================================================================================',
            ('Created: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
            '',
            'TOM TAT 1 DONG CHO TICKET SLA:',
            $oneLine,
            '',
            'CHI TIET PHAN CUNG:',
            ('Computer Name        : ' + $compName),
            ('Current User         : ' + $currentUser),
            ('Manufacturer         : ' + $manufacturer),
            ('Model                : ' + $model),
            ('Serial Number/Tag    : ' + $serial),
            ('Baseboard            : ' + $boardInfo),
            ('BIOS Version         : ' + $biosVer),
            ('CPU                  : ' + $cpuName),
            ('Cores / Threads      : ' + $cpuCores + ' Cores / ' + $cpuThreads + ' Threads'),
            ('Total RAM            : ' + $totalRamGB + ' GB'),
            ('RAM Slots Used       : ' + $usedSlots + '/' + $totalSlots + ' Slots (' + $ramSpeedStr + ')'),
            'RAM Modules Details  :'
        )
        foreach ($m in $memSticks) {
            $reportContent += ('  * Slot ' + $m.DeviceLocator + ': ' + [math]::Round($m.Capacity / 1GB, 1) + ' GB, ' + $m.Speed + ' MHz, ' + $m.Manufacturer + ' (' + $m.PartNumber + ')')
        }
        $reportContent += @(
            ('Storage Disks        : ' + $diskSummary),
            ('Video Controllers    : ' + $gpuSummary),
            ('Operating System     : ' + $osCaption + ' ' + $osArch + ' (Build ' + $osBuild + ')'),
            ('Network IP / MAC     : IP=' + $ipAddr + ' | MAC=' + $macAddr),
            '==========================================================================================='
        )
        $reportContent | Set-Content -LiteralPath $reportPath -Encoding UTF8
        Write-Host (' Da xuat file chi tiet: {0}' -f $reportPath) -ForegroundColor Gray
    } catch { }

    Write-SessionLog ('AssetSpecs completed: ' + $oneLine)
}

function Invoke-BitLockerStatus {
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '               KIEM TRA TRANG THAI MA HOA BITLOCKER & CHIP TPM' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan

    Write-Host ' [1] KIEM TRA TRANG THAI CHIP TPM (TRUSTED PLATFORM MODULE):' -ForegroundColor Yellow
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        if ($tpm -and $tpm.PSObject.Properties.Match('TpmPresent').Count -gt 0) {
            Write-Host ('  TPM Present   : {0}' -f $tpm.TpmPresent)
            Write-Host ('  TPM Ready     : {0}' -f $tpm.TpmReady)
            Write-Host ('  TPM Enabled   : {0}' -f $tpm.TpmEnabled)
            Write-Host ('  TPM Activated : {0}' -f $tpm.TpmActivated)
            if ($tpm.PSObject.Properties.Match('ManufacturerVersion').Count -gt 0) {
                Write-Host ('  TPM Version   : {0}' -f $tpm.ManufacturerVersion)
            }
        } else {
            & tpmtool.exe getdeviceinformation
        }
    }
    catch {
        Write-Host '  Tra cuu qua tpmtool getdeviceinformation:' -ForegroundColor Gray
        try { & tpmtool.exe getdeviceinformation } catch { }
    }

    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' [2] KIEM TRA TRANG THAI MA HOA BITLOCKER TREN CAC PHAN VUNG:' -ForegroundColor Yellow

    try {
        $blVolumes = Get-BitLockerVolume -ErrorAction Stop
        foreach ($v in $blVolumes) {
            $statusColor = if ($v.ProtectionStatus -eq 'On') { 'Green' } else { 'Yellow' }
            Write-Host ('  Phan vung : {0} [{1}]' -f $v.MountPoint, $v.VolumeType) -ForegroundColor Cyan
            Write-Host ('  - Tinh trang bao ve : {0}' -f $v.ProtectionStatus) -ForegroundColor $statusColor
            Write-Host ('  - Trang thai ma hoa : {0}' -f $v.VolumeStatus)
            Write-Host ('  - Phuong thuc       : {0}' -f $v.EncryptionMethod)
            Write-Host ('  - Trang thai khoa   : {0}' -f $v.LockStatus)
            if ($v.KeyProtector) {
                $protectorTypes = ($v.KeyProtector | Select-Object -ExpandProperty KeyProtectorType) -join ', '
                Write-Host ('  - Key Protectors    : {0}' -f $protectorTypes) -ForegroundColor Gray
            }
            Write-Host ''
        }
    }
    catch {
        Write-Host '  Khong the dung Get-BitLockerVolume, chuyen sang manage-bde.exe:' -ForegroundColor Yellow
        & manage-bde.exe -status
    }

    Write-Host '==========================================================================================='
    Write-SessionLog 'BitLockerStatus check completed'
}

function Invoke-BitLockerBackupKey {
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '             TRICH XUAT VA SAO LUU BITLOCKER RECOVERY KEY (48 CHU SO)' -ForegroundColor Cyan
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host ' LUU Y BAO MAT: Key nay dung de mo khoa o dia khi doi bo mach, nang cap BIOS hoac loi boot.' -ForegroundColor Yellow
    Write-Host ' Hay luu tru vao vi tri an toan (AD, KeePass, he thong quan ly tai san IT cua cong ty).' -ForegroundColor Yellow
    Write-Host '-------------------------------------------------------------------------------------------'

    $safeComp = Get-SafeName $env:COMPUTERNAME
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $exportFile = Join-Path $OutputRoot ("BitLocker_RecoveryKey_{0}_{1}.txt" -f $safeComp, $stamp)

    $keysFound = 0
    $outputLines = @(
        '===========================================================================================',
        '              SYSCARE WINDOWS TOOL - BITLOCKER RECOVERY KEY BACKUP',
        '===========================================================================================',
        ('Computer Name : ' + $env:COMPUTERNAME),
        ('User Extracted: ' + [Security.Principal.WindowsIdentity]::GetCurrent().Name),
        ('Date & Time   : ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
        ('Serial Number : ' + ((Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue).SerialNumber)),
        '-------------------------------------------------------------------------------------------',
        'CHU Y: Giu file nay tuyet mat. Khong chia se qua email khong ma hoa hoac chat cong khai.',
        '-------------------------------------------------------------------------------------------',
        ''
    )

    try {
        $volumes = Get-BitLockerVolume -ErrorAction Stop
        foreach ($v in $volumes) {
            $driveLetter = $v.MountPoint
            $recProtectors = $v.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
            foreach ($rp in $recProtectors) {
                $keysFound++
                $id = $rp.KeyProtectorId
                $pass = $rp.RecoveryPassword
                Write-Host ('  PHAN VUNG [{0}]' -f $driveLetter) -ForegroundColor Cyan
                Write-Host ('  Key Identifier : {0}' -f $id) -ForegroundColor Yellow
                Write-Host ('  RECOVERY KEY   : {0}' -f $pass) -ForegroundColor Green
                Write-Host ''

                $outputLines += @(
                    ('Drive          : ' + $driveLetter + ' (' + $v.VolumeType + ')'),
                    ('Key Identifier : ' + $id),
                    ('Recovery Key   : ' + $pass),
                    ''
                )
            }
        }
    }
    catch {
        Write-Host '  Dang lay khoa bang manage-bde -protectors -get C: ...' -ForegroundColor Yellow
        $bdeOut = & manage-bde.exe -protectors -get C: 2>&1 | Out-String
        $outputLines += @(
            'MANAGE-BDE OUTPUT (Drive C:):',
            $bdeOut
        )
        if ($bdeOut -match '(\d{6}-\d{6}-\d{6}-\d{6}-\d{6}-\d{6}-\d{6}-\d{6})') {
            $keysFound++
            Write-Host ('  RECOVERY KEY TIM THAY: {0}' -f $matches[1]) -ForegroundColor Green
        }
        Write-Host $bdeOut
    }

    if ($keysFound -gt 0) {
        [IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
        $outputLines | Set-Content -LiteralPath $exportFile -Encoding UTF8
        Write-Host '-------------------------------------------------------------------------------------------'
        Write-Host ' [THANH CONG] Da trich xuat va luu Recovery Key vao file:' -ForegroundColor Green
        Write-Host (' -> {0}' -f $exportFile) -ForegroundColor Green
        Write-Host '==========================================================================================='
        Write-SessionLog ('BitLockerBackupKey extracted: ' + $exportFile)
        try { Start-Process explorer.exe -ArgumentList ('/select,"{0}"' -f $exportFile) | Out-Null } catch { }
    } else {
        Write-Host ' [THONG BAO] Khong tim thay khoa Numerical Password (Recovery Key) nao hoac o dia chua bat BitLocker.' -ForegroundColor Yellow
        Write-SessionLog 'BitLockerBackupKey: No keys found'
    }
}

