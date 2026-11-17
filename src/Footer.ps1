
try {
    Write-SessionLog ('Started action: {0}' -f $Action)
    switch ($Action) {
        'Console'               { Invoke-SyscareConsole }
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
        'ToshibaScanSuite'      { Invoke-ToshibaScanSuite }
        'SmbSecurityConfig'     { Invoke-SmbSecurityConfig }
        'RpcPrintFix'           { Invoke-RpcPrintFix }
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
        'SearchFix'             { Invoke-SearchFix }
        'DeepClean'             { Invoke-DeepClean }
        'FastStartupToggle'     { Invoke-FastStartupToggle }
        'LicenseCheck'          { Invoke-LicenseCheck }
        'LocalUserAdmin'        { Invoke-LocalUserAdmin }
        'RenamePC'              { Invoke-RenamePC }
        'ToggleRDP'             { Invoke-ToggleRDP }
        'CloudIdentity'         { Invoke-CloudIdentitySuite }
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
