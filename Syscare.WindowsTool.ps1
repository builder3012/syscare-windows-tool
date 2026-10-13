#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'QuickTriage', 'Network', 'Domain', 'Performance', 'Printer', 'WindowsUpdate',
        'Connectivity', 'CaseNote', 'IncidentBundle', 'HealthScan',
        'PrinterUsb', 'PrinterShared', 'PrinterIp', 'ScanFolder', 'PrinterClearQueue', 'PrinterRestartSpooler',
        'DriverBackup', 'DriverRestore', 'DriverUninstall', 'DriverAutoScan',
        'AssetSpecs', 'BitLockerStatus', 'BitLockerBackupKey',
        'ClearOfficeCache', 'WiFiProfileBackup', 'WiFiProfileRestore', 'DomainRepair'
    )]
    [string] $Action,

    [string] $DriverFolder,
    [string] $DriverName,
    [switch] $Force,
    [string] $WiFiFolder,

    [string] $OutputRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Syscare_Support'),
    [string] $SessionLog
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Script:ToolVersion = '2.3.0'

function Write-SessionLog {
    param([string] $Message, [string] $Level = 'INFO')
    if ([string]::IsNullOrWhiteSpace($SessionLog)) { return }
    try {
        $parent = Split-Path -Parent $SessionLog
        if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
        Add-Content -LiteralPath $SessionLog -Encoding UTF8 -Value ('{0} [{1}] [PowerShell] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message)
    }
    catch { }
}

function Get-SafeName {
    param([string] $Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return 'NA' }
    return (($Value -replace '[^A-Za-z0-9_.-]', '_').Trim('_'))
}

function New-OutputDirectory {
    param([string] $Prefix)
    [IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
    $name = '{0}_{1}_{2}' -f (Get-SafeName $env:COMPUTERNAME), (Get-Date -Format 'yyyyMMdd_HHmmss'), (Get-SafeName $Prefix)
    $path = Join-Path $OutputRoot $name
    [IO.Directory]::CreateDirectory($path) | Out-Null
    @(
        'SYSCARE WINDOWS TOOL - DATA HANDLING NOTICE'
        ('Tool version: {0}' -f $Script:ToolVersion)
        ('Created: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
        ''
        'This folder can contain computer name, user name, IP addresses, domain information, event data and software inventory.'
        'Review and redact sensitive data before sharing outside the organization.'
        'No saved Wi-Fi password is collected by this tool.'
    ) | Set-Content -LiteralPath (Join-Path $path '00_PRIVACY_NOTICE.txt') -Encoding UTF8
    return $path
}

function Save-Text {
    param([string] $Path, [scriptblock] $ScriptBlock)
    try {
        $content = & $ScriptBlock 2>&1 | Out-String -Width 240
        if ([string]::IsNullOrWhiteSpace($content)) { $content = '(No data returned)' }
        Set-Content -LiteralPath $Path -Value $content.TrimEnd() -Encoding UTF8
    }
    catch {
        Set-Content -LiteralPath $Path -Value ('ERROR: {0}' -f $_.Exception.Message) -Encoding UTF8
    }
}

function Test-RebootPending {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) { return $true }
    }
    try {
        $value = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop
        if ($null -ne $value.PendingFileRenameOperations) { return $true }
    }
    catch { }
    return $false
}

function Get-DomainState {
    $computer = Get-CimInstance Win32_ComputerSystem
    $state = [ordered]@{
        PartOfDomain  = [bool]$computer.PartOfDomain
        Domain        = [string]$computer.Domain
        SecureChannel = 'Not applicable'
    }
    if ($computer.PartOfDomain) {
        try { $state.SecureChannel = [string](Test-ComputerSecureChannel -ErrorAction Stop) }
        catch { $state.SecureChannel = 'ERROR: ' + $_.Exception.Message }
    }
    return [pscustomobject]$state
}

function Get-DefaultGateway {
    try {
        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop |
            Sort-Object RouteMetric, InterfaceMetric |
            Select-Object -First 1
        return [string]$route.NextHop
    }
    catch { return '' }
}

function Get-TriageSummary {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $domain = Get-DomainState
    $systemDrive = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $env:SystemDrive)
    $gateway = Get-DefaultGateway
    $internet = $false
    $dns = $false
    $gatewayReachable = $null
    try { $internet = [bool](Test-NetConnection -ComputerName '1.1.1.1' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue) } catch { }
    try { Resolve-DnsName 'www.microsoft.com' -Type A -ErrorAction Stop | Out-Null; $dns = $true } catch { }
    if ($gateway) {
        try { $gatewayReachable = [bool](Test-Connection -ComputerName $gateway -Count 1 -Quiet -ErrorAction Stop) } catch { $gatewayReachable = $false }
    }
    $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    $freeGb = if ($systemDrive) { [math]::Round($systemDrive.FreeSpace / 1GB, 1) } else { $null }
    $totalGb = if ($systemDrive) { [math]::Round($systemDrive.Size / 1GB, 1) } else { $null }
    $freeMemoryGb = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $totalMemoryGb = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
    $lastBoot = [datetime]$os.LastBootUpTime
    $uptimeHours = [math]::Round(((Get-Date) - $lastBoot).TotalHours, 1)
    $critical24h = 0
    $errors24h = 0
    try { $critical24h = @(Get-WinEvent -FilterHashtable @{ LogName='System'; Level=1; StartTime=(Get-Date).AddHours(-24) } -ErrorAction SilentlyContinue).Count } catch { }
    try { $errors24h = @(Get-WinEvent -FilterHashtable @{ LogName='System'; Level=2; StartTime=(Get-Date).AddHours(-24) } -ErrorAction SilentlyContinue).Count } catch { }
    $timeSource = (& w32tm.exe /query /source 2>$null | Out-String).Trim()
    $rebootPending = Test-RebootPending
    $spoolerStatus = if ($spooler) { [string]$spooler.Status } else { 'Not found' }
    $status = 'PASS'
    $attention = New-Object System.Collections.Generic.List[string]
    if (-not $internet) { $status = 'ATTENTION'; $attention.Add('HTTPS Internet test failed') }
    if (-not $dns) { $status = 'ATTENTION'; $attention.Add('DNS resolution test failed') }
    if ($null -ne $freeGb -and $freeGb -lt 10) { $status = 'ATTENTION'; $attention.Add('System drive has less than 10 GB free') }
    if ($freeMemoryGb -lt 1) { $status = 'ATTENTION'; $attention.Add('Less than 1 GB physical memory is currently free') }
    if ($domain.PartOfDomain -and $domain.SecureChannel -ne 'True') { $status = 'ATTENTION'; $attention.Add('Domain secure channel is not healthy') }
    if ($domain.PartOfDomain -and $timeSource -match 'Local CMOS|Free-running') { $status = 'ATTENTION'; $attention.Add('Domain computer is not using a domain time source') }
    if ($rebootPending) { $status = 'ATTENTION'; $attention.Add('Windows reports a pending reboot') }
    if ($spoolerStatus -ne 'Running') { $status = 'ATTENTION'; $attention.Add('Print Spooler is not running') }
    if ($critical24h -gt 0) { $status = 'ATTENTION'; $attention.Add('Critical System events found in last 24 hours') }
    return [pscustomobject][ordered]@{
        OverallStatus        = $status
        Attention            = @($attention)
        ComputerName         = $env:COMPUTERNAME
        CurrentUser          = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        Manufacturer         = $computer.Manufacturer
        Model                = $computer.Model
        Windows              = $os.Caption
        WindowsVersion       = $os.Version
        WindowsBuild         = $os.BuildNumber
        LastBoot             = $lastBoot
        UptimeHours          = $uptimeHours
        MemoryFreeGB         = $freeMemoryGb
        MemoryTotalGB        = $totalMemoryGb
        SystemDriveFreeGB    = $freeGb
        SystemDriveTotalGB   = $totalGb
        DefaultGateway       = $gateway
        GatewayReachable     = $gatewayReachable
        InternetHttps443     = $internet
        DnsResolution        = $dns
        DomainJoined         = $domain.PartOfDomain
        Domain               = $domain.Domain
        DomainSecureChannel  = $domain.SecureChannel
        TimeSource           = $timeSource
        PrintSpooler         = $spoolerStatus
        RebootPending        = $rebootPending
        SystemCritical24h    = $critical24h
        SystemErrors24h      = $errors24h
    }
}

function Write-SummaryFiles {
    param([string] $Directory, [pscustomobject] $Summary)
    $summaryPath = Join-Path $Directory '01_TRIAGE_SUMMARY.txt'
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('SYSCARE QUICK TRIAGE SUMMARY')
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')))
    $lines.Add(('Overall status: {0}' -f $Summary.OverallStatus))
    $lines.Add('')
    if ($Summary.Attention.Count -gt 0) {
        $lines.Add('ATTENTION ITEMS:')
        foreach ($item in $Summary.Attention) { $lines.Add(' - ' + $item) }
        $lines.Add('')
    }
    foreach ($property in $Summary.PSObject.Properties) {
        if ($property.Name -in @('OverallStatus', 'Attention')) { continue }
        $lines.Add(('{0,-24}: {1}' -f $property.Name, $property.Value))
    }
    $lines | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    $Summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Directory '01_TRIAGE_SUMMARY.json') -Encoding UTF8
    $encoded = [Net.WebUtility]::HtmlEncode(($lines -join [Environment]::NewLine))
    $color = if ($Summary.OverallStatus -eq 'PASS') { '#14804a' } else { '#b54708' }
    $html = @"
<!doctype html><html><head><meta charset="utf-8"><title>Syscare Quick Triage</title>
<style>body{font-family:Segoe UI,Arial;margin:32px;color:#182230}h1{margin-bottom:4px}.status{display:inline-block;padding:6px 12px;border-radius:16px;background:$color;color:white;font-weight:700}pre{background:#f5f7fa;border:1px solid #d5d9e0;padding:18px;white-space:pre-wrap}</style></head>
<body><h1>Syscare Quick Triage</h1><p class="status">$($Summary.OverallStatus)</p><pre>$encoded</pre></body></html>
"@
    Set-Content -LiteralPath (Join-Path $Directory '01_TRIAGE_SUMMARY.html') -Value $html -Encoding UTF8
}

function Add-FileManifest {
    param([string] $Directory)
    $manifestPath = Join-Path $Directory '99_SHA256_MANIFEST.csv'
    Get-ChildItem -LiteralPath $Directory -File |
        Where-Object { $_.FullName -ne $manifestPath } |
        Sort-Object Name |
        ForEach-Object {
            [pscustomobject]@{ File = $_.Name; SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash; Bytes = $_.Length }
        } | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
}

function Save-SystemDetails {
    param([string] $Directory)
    Save-Text (Join-Path $Directory '10_SYSTEM.txt') { systeminfo.exe; ''; Get-ComputerInfo | Format-List WindowsProductName,WindowsVersion,OsBuildNumber,CsManufacturer,CsModel,CsProcessors,CsTotalPhysicalMemory,BiosSMBIOSBIOSVersion,BiosReleaseDate }
    Save-Text (Join-Path $Directory '11_STORAGE.txt') { Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize; ''; Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,HealthStatus,SizeRemaining,Size | Format-Table -AutoSize }
    Save-Text (Join-Path $Directory '12_TOP_PROCESSES.txt') { 'TOP CPU'; Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Name,Id,CPU,WorkingSet,StartTime | Format-Table -AutoSize; ''; 'TOP MEMORY'; Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 20 Name,Id,CPU,WorkingSet | Format-Table -AutoSize }
}

function Save-NetworkDetails {
    param([string] $Directory)
    Save-Text (Join-Path $Directory '20_NETWORK_IPCONFIG.txt') { ipconfig.exe /all }
    Save-Text (Join-Path $Directory '21_NETWORK_ADAPTERS.txt') { Get-NetAdapter | Sort-Object Status,Name | Format-Table Name,InterfaceDescription,Status,LinkSpeed,MacAddress,DriverInformation -AutoSize; ''; Get-NetIPConfiguration -Detailed | Format-List * }
    Save-Text (Join-Path $Directory '22_NETWORK_ROUTES.txt') { route.exe print; ''; Get-NetRoute | Sort-Object AddressFamily,RouteMetric | Format-Table -AutoSize }
    Save-Text (Join-Path $Directory '23_NETWORK_DNS_PROXY.txt') { Get-DnsClientServerAddress | Format-Table -AutoSize; ''; netsh.exe winhttp show proxy; ''; ipconfig.exe /displaydns }
    Save-Text (Join-Path $Directory '24_NETWORK_CONNECTIVITY.txt') {
        $gateway = Get-DefaultGateway
        'Default gateway: ' + $gateway
        if ($gateway) { 'Gateway ping: ' + (Test-Connection -ComputerName $gateway -Count 2 -Quiet) }
        'Internet TCP 443 (1.1.1.1): ' + (Test-NetConnection -ComputerName '1.1.1.1' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue)
        'DNS www.microsoft.com:'
        Resolve-DnsName 'www.microsoft.com' -ErrorAction Continue | Format-Table -AutoSize
        'Trace route:'
        tracert.exe -d -h 12 1.1.1.1
    }
}

function Save-DomainDetails {
    param([string] $Directory)
    Save-Text (Join-Path $Directory '30_DOMAIN_TIME_GPO.txt') {
        $state = Get-DomainState
        $state | Format-List
        ''
        'TIME SOURCE AND STATUS'
        w32tm.exe /query /source
        w32tm.exe /query /status
        ''
        'LOGON SERVER AND SECURE CHANNEL'
        'LOGONSERVER=' + $env:LOGONSERVER
        if ($state.PartOfDomain) {
            nltest.exe /sc_query:$($state.Domain)
            ''
            'DOMAIN CONTROLLER DISCOVERY'
            nltest.exe /dsgetdc:$($state.Domain)
            ''
            'GROUP POLICY RESULT - COMPUTER'
            gpresult.exe /r /scope computer
            ''
            'KERBEROS TICKETS'
            klist.exe
        }
    }
}

function Save-PrinterDetails {
    param([string] $Directory)
    Save-Text (Join-Path $Directory '40_PRINTERS.txt') {
        Get-Service Spooler | Format-List Name,Status,StartType
        ''
        if (Get-Command Get-Printer -ErrorAction SilentlyContinue) {
            Get-Printer | Sort-Object Name | Format-Table Name,DriverName,PortName,Type,PrinterStatus,WorkOffline,Shared,Published -AutoSize
            ''
            'PRINT JOBS'
            Get-Printer | ForEach-Object { Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue } | Format-Table -AutoSize
            ''
            'PRINTER PORTS'
            Get-PrinterPort | Format-Table -AutoSize
        }
        else { 'PrintManagement cmdlets are unavailable.' }
    }
}

function Save-SecurityUpdateDetails {
    param([string] $Directory)
    Save-Text (Join-Path $Directory '50_DEFENDER_FIREWALL.txt') { Get-MpComputerStatus | Format-List AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,IoavProtectionEnabled,NISEnabled,AntivirusSignatureLastUpdated,QuickScanEndTime,FullScanEndTime; ''; netsh.exe advfirewall show allprofiles }
    Save-Text (Join-Path $Directory '51_WINDOWS_UPDATE.txt') { 'REBOOT PENDING: ' + (Test-RebootPending); ''; Get-Service wuauserv,bits,cryptsvc,usosvc -ErrorAction SilentlyContinue | Format-Table Name,Status,StartType -AutoSize; ''; Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 40 HotFixID,Description,InstalledOn,InstalledBy | Format-Table -AutoSize; ''; 'WINDOWS UPDATE POLICY'; Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue | Format-List * }
}

function Save-EventDetails {
    param([string] $Directory)
    $start = (Get-Date).AddDays(-3)
    Save-Text (Join-Path $Directory '60_SYSTEM_ERRORS_3D.txt') { Get-WinEvent -FilterHashtable @{ LogName='System'; Level=1,2,3; StartTime=$start } -MaxEvents 200 -ErrorAction SilentlyContinue | Select-Object TimeCreated,LevelDisplayName,ProviderName,Id,Message | Format-List }
    Save-Text (Join-Path $Directory '61_APPLICATION_ERRORS_3D.txt') { Get-WinEvent -FilterHashtable @{ LogName='Application'; Level=1,2,3; StartTime=$start } -MaxEvents 200 -ErrorAction SilentlyContinue | Select-Object TimeCreated,LevelDisplayName,ProviderName,Id,Message | Format-List }
}

function Complete-Output {
    param([string] $Directory, [bool] $Open = $true)
    Add-FileManifest -Directory $Directory
    Write-Host ''
    Write-Host ('Completed: {0}' -f $Directory) -ForegroundColor Green
    Write-SessionLog ('Completed {0}: {1}' -f $Action, $Directory)
    if ($Open) { Start-Process explorer.exe -ArgumentList ('"{0}"' -f $Directory) | Out-Null }
}

function Invoke-QuickTriage {
    $directory = New-OutputDirectory 'QuickTriage'
    Write-Host '[1/7] System and health summary...'
    $summary = Get-TriageSummary
    Write-SummaryFiles -Directory $directory -Summary $summary
    Write-Host '[2/7] System, storage and processes...'
    Save-SystemDetails -Directory $directory
    Write-Host '[3/7] Network...'
    Save-NetworkDetails -Directory $directory
    Write-Host '[4/7] Domain, Group Policy and time...'
    Save-DomainDetails -Directory $directory
    Write-Host '[5/7] Printers...'
    Save-PrinterDetails -Directory $directory
    Write-Host '[6/7] Security and Windows Update...'
    Save-SecurityUpdateDetails -Directory $directory
    Write-Host '[7/7] Recent errors...'
    Save-EventDetails -Directory $directory
    Complete-Output -Directory $directory
}

function Invoke-FocusedReport {
    param([string] $Prefix, [scriptblock] $Collector)
    $directory = New-OutputDirectory $Prefix
    & $Collector $directory
    Complete-Output -Directory $directory
}

function Invoke-ConnectivityTest {
    $directory = New-OutputDirectory 'Connectivity'
    $target = Read-Host 'Server, hostname or IP to test'
    if ([string]::IsNullOrWhiteSpace($target) -or $target.Length -gt 253) { throw 'Invalid or empty target.' }
    $portsText = Read-Host 'TCP ports separated by comma [default: 53,80,443,445,3389]'
    if ([string]::IsNullOrWhiteSpace($portsText)) { $portsText = '53,80,443,445,3389' }
    $ports = @($portsText -split ',' | ForEach-Object { $p = 0; if ([int]::TryParse($_.Trim(), [ref]$p) -and $p -ge 1 -and $p -le 65535) { $p } })
    if ($ports.Count -eq 0) { throw 'No valid TCP ports were supplied.' }
    Save-Text (Join-Path $directory 'TARGET_CONNECTIVITY.txt') {
        'Target: ' + $target
        'DNS:'
        Resolve-DnsName $target -ErrorAction Continue | Format-Table -AutoSize
        ''
        'PING:'
        Test-Connection -ComputerName $target -Count 4 -ErrorAction Continue | Format-Table -AutoSize
        ''
        'TCP PORTS:'
        foreach ($port in $ports) {
            $ok = Test-NetConnection -ComputerName $target -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
            [pscustomobject]@{ Target=$target; Port=$port; TcpSucceeded=$ok }
        }
        ''
        'TRACE ROUTE:'
        tracert.exe -d -h 15 $target
    }
    Complete-Output -Directory $directory
}

function New-CaseNote {
    [IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
    $caseId = Read-Host 'Ticket/incident ID (or press Enter for automatic ID)'
    if ([string]::IsNullOrWhiteSpace($caseId)) { $caseId = Get-Date -Format 'yyyyMMdd-HHmmss' }
    $technician = Read-Host 'Technician'
    $symptom = Read-Host 'User symptom / request'
    $actionTaken = Read-Host 'Action taken'
    $result = Read-Host 'Result / next step'
    $safeId = Get-SafeName $caseId
    $path = Join-Path $OutputRoot ('CASE_{0}_{1}.txt' -f $safeId, (Get-Date -Format 'yyyyMMdd_HHmmss'))
    @(
        'SYSCARE SERVICE CASE NOTE'
        ('Ticket/Incident : {0}' -f $caseId)
        ('Started/Recorded: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
        ('Computer        : {0}' -f $env:COMPUTERNAME)
        ('User            : {0}' -f [Security.Principal.WindowsIdentity]::GetCurrent().Name)
        ('Technician      : {0}' -f $technician)
        ('Symptom         : {0}' -f $symptom)
        ('Action taken    : {0}' -f $actionTaken)
        ('Result/Next step: {0}' -f $result)
        ''
        'Review this file for sensitive information before external sharing.'
    ) | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Host ('Case note saved: {0}' -f $path) -ForegroundColor Green
    Write-SessionLog ('Case note saved: {0}' -f $path)
    Start-Process notepad.exe -ArgumentList ('"{0}"' -f $path) | Out-Null
}

function Invoke-IncidentBundle {
    $directory = New-OutputDirectory 'IncidentBundle'
    Write-Host '[1/9] Summary...'
    Write-SummaryFiles -Directory $directory -Summary (Get-TriageSummary)
    Write-Host '[2/9] System and performance...'
    Save-SystemDetails -Directory $directory
    Write-Host '[3/9] Network...'
    Save-NetworkDetails -Directory $directory
    Write-Host '[4/9] Domain, Group Policy and time...'
    Save-DomainDetails -Directory $directory
    Write-Host '[5/9] Printers...'
    Save-PrinterDetails -Directory $directory
    Write-Host '[6/9] Security and update...'
    Save-SecurityUpdateDetails -Directory $directory
    Write-Host '[7/9] Drivers, services and startup...'
    Save-Text (Join-Path $directory '70_DRIVERS.csv') { driverquery.exe /v /fo csv }
    Save-Text (Join-Path $directory '71_DEVICES_WITH_ERRORS.txt') { Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object Status -ne 'OK' | Format-Table -AutoSize }
    Save-Text (Join-Path $directory '72_SERVICES_STARTUP_TASKS.txt') { Get-Service | Sort-Object Status,Name | Format-Table -AutoSize; ''; Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User | Format-List; ''; schtasks.exe /query /fo LIST /v }
    Write-Host '[8/9] Recent events...'
    Save-EventDetails -Directory $directory
    Write-Host '[9/9] Manifest and ZIP...'
    Add-FileManifest -Directory $directory
    $zip = $directory + '.zip'
    Compress-Archive -Path (Join-Path $directory '*') -DestinationPath $zip -CompressionLevel Optimal -Force
    Write-Host ('Incident bundle: {0}' -f $zip) -ForegroundColor Green
    Write-SessionLog ('Completed IncidentBundle: {0}' -f $zip)
    Start-Process explorer.exe -ArgumentList ('/select,"{0}"' -f $zip) | Out-Null
}

function Invoke-HealthScan {
    $directory = New-OutputDirectory 'HealthScan'
    Write-Host '[1/2] DISM CheckHealth...'
    Save-Text (Join-Path $directory 'DISM_CheckHealth.txt') { DISM.exe /Online /Cleanup-Image /CheckHealth }
    Write-Host '[2/2] SFC VerifyOnly. This can take several minutes...'
    Save-Text (Join-Path $directory 'SFC_VerifyOnly.txt') { sfc.exe /verifyonly }
    Complete-Output -Directory $directory
}

# Printer assistant: local read-only checks, except for two separately confirmed repairs.
# No printer credentials, scan files, or document contents are collected.
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

try {
    Write-SessionLog ('Started action: {0}' -f $Action)
    switch ($Action) {
        'QuickTriage'           { Invoke-QuickTriage }
        'Network'               { Invoke-FocusedReport 'Network' { param($d) Save-NetworkDetails $d } }
        'Domain'                { Invoke-FocusedReport 'Domain' { param($d) Save-DomainDetails $d } }
        'Performance'           { Invoke-FocusedReport 'Performance' { param($d) Save-SystemDetails $d } }
        'Printer'               { Invoke-FocusedReport 'Printer' { param($d) Save-PrinterDetails $d } }
        'PrinterUsb'            { Invoke-PrinterUsbAssist }
        'PrinterShared'         { Invoke-PrinterSharedAssist }
        'PrinterIp'             { Invoke-PrinterIpAssist }
        'ScanFolder'            { Invoke-ScanFolderAssist }
        'PrinterClearQueue'     { Invoke-PrinterClearSelectedQueue }
        'PrinterRestartSpooler' { Invoke-PrinterRestartSpooler }
        'DriverBackup'          { Invoke-DriverBackup -Destination $DriverFolder }
        'DriverRestore'         { Invoke-DriverRestore -SourceFolder $DriverFolder }
        'DriverUninstall'       { Invoke-DriverUninstall -Name $DriverName -ForceUninstall:$Force }
        'DriverAutoScan'        { Invoke-DriverAutoScan }
        'AssetSpecs'            { Invoke-AssetSpecs }
        'BitLockerStatus'       { Invoke-BitLockerStatus }
        'BitLockerBackupKey'    { Invoke-BitLockerBackupKey }
        'ClearOfficeCache'      { Invoke-ClearOfficeCache }
        'WiFiProfileBackup'     { Invoke-WiFiProfileBackup -Destination $WiFiFolder }
        'WiFiProfileRestore'    { Invoke-WiFiProfileRestore -SourceFolder $WiFiFolder }
        'DomainRepair'          { Invoke-DomainRepair }
        'WindowsUpdate'         { Invoke-FocusedReport 'WindowsUpdate' { param($d) Save-SecurityUpdateDetails $d } }
        'Connectivity'          { Invoke-ConnectivityTest }
        'CaseNote'              { New-CaseNote }
        'IncidentBundle'        { Invoke-IncidentBundle }
        'HealthScan'            { Invoke-HealthScan }
    }
    exit 0
}
catch {
    Write-SessionLog ('Action failed: {0} - {1}' -f $Action, $_.Exception.Message) 'ERROR'
    Write-Error $_.Exception.Message
    exit 1
}
