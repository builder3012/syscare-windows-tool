#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('QuickTriage', 'Network', 'Domain', 'Performance', 'Printer', 'WindowsUpdate', 'Connectivity', 'CaseNote', 'IncidentBundle', 'HealthScan')]
    [string] $Action,

    [string] $OutputRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Syscare_Support'),
    [string] $SessionLog
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Script:ToolVersion = '2.1.0'

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

try {
    Write-SessionLog ('Started action: {0}' -f $Action)
    switch ($Action) {
        'QuickTriage'    { Invoke-QuickTriage }
        'Network'        { Invoke-FocusedReport 'Network' { param($d) Save-NetworkDetails $d } }
        'Domain'         { Invoke-FocusedReport 'Domain' { param($d) Save-DomainDetails $d } }
        'Performance'    { Invoke-FocusedReport 'Performance' { param($d) Save-SystemDetails $d } }
        'Printer'        { Invoke-FocusedReport 'Printer' { param($d) Save-PrinterDetails $d } }
        'WindowsUpdate'  { Invoke-FocusedReport 'WindowsUpdate' { param($d) Save-SecurityUpdateDetails $d } }
        'Connectivity'   { Invoke-ConnectivityTest }
        'CaseNote'       { New-CaseNote }
        'IncidentBundle' { Invoke-IncidentBundle }
        'HealthScan'     { Invoke-HealthScan }
    }
    exit 0
}
catch {
    Write-SessionLog ('Action failed: {0} - {1}' -f $Action, $_.Exception.Message) 'ERROR'
    Write-Error $_.Exception.Message
    exit 1
}
