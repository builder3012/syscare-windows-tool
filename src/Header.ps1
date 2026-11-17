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

    [string] $OutputRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Syscare_Support'),
    [string] $SessionLog
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Script:ToolVersion = '2.4.0'

