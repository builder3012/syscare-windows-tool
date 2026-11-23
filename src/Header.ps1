#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet(
        'Console',
        'QuickTriage', 'Network', 'Domain', 'Performance', 'Printer', 'WindowsUpdate',
        'Connectivity', 'CaseNote', 'IncidentBundle', 'HealthScan',
        'PrinterUsb', 'PrinterShared', 'PrinterIp', 'ScanFolder', 'PrinterClearQueue', 'PrinterRestartSpooler',
        'ToshibaScanSuite', 'SmbSecurityConfig', 'RpcPrintFix',
        'DriverBackup', 'DriverRestore', 'DriverUninstall', 'DriverAutoScan',
        'AssetSpecs', 'BitLockerStatus', 'BitLockerBackupKey',
        'ClearOfficeCache', 'WiFiProfileBackup', 'WiFiProfileRestore', 'DomainRepair',
        'SearchFix', 'DeepClean', 'FastStartupToggle', 'LicenseCheck', 'LocalUserAdmin', 'RenamePC', 'ToggleRDP',
        'CloudIdentity'
    )]
    [string] $Action = 'Console',

    [string] $DriverFolder,
    [string] $DriverName,
    [switch] $Force,
    [string] $WiFiFolder,

    [string] $OutputRoot,
    [string] $SessionLog
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Script:ToolVersion = '2.4.0'

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $desktop = $null
    try { $desktop = [Environment]::GetFolderPath('Desktop') } catch { }
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop -ErrorAction SilentlyContinue)) {
        if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
            $candidate = Join-Path $env:USERPROFILE 'Desktop'
            if (Test-Path -LiteralPath $candidate -ErrorAction SilentlyContinue) {
                $desktop = $candidate
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop -ErrorAction SilentlyContinue)) {
        $desktop = if (-not [string]::IsNullOrWhiteSpace($env:TEMP) -and (Test-Path -LiteralPath $env:TEMP -ErrorAction SilentlyContinue)) { $env:TEMP } else { $PWD.Path }
    }
    $OutputRoot = Join-Path $desktop 'Syscare_Support'
}

