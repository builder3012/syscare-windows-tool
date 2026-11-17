function Invoke-CloudIdentitySuite {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-CloudIdentitySuite started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  QUAN LY CLOUD IDENTITY, ENTRA ID, PRT TOKEN & INTUNE (MICROSOFT 365)' -ForegroundColor Cyan
    Write-Host '==========================================================================================='

    # 1. Thu thap thong tin tu dsregcmd /status
    Write-Host ' [1/3] Dang truy van trang thai thiet bi va danh tinh dam may (dsregcmd /status)...' -ForegroundColor Gray
    $dsRaw = ""
    try { $dsRaw = (& dsregcmd.exe /status 2>&1 | Out-String).Trim() } catch { }

    function Get-DsValue([string]$pattern, [string]$default = 'N/A') {
        if ($dsRaw -match $pattern) { return $matches[1].Trim() }
        return $default
    }

    $azureAdJoined    = Get-DsValue '(?i)AzureAdJoined\s*:\s*([A-Za-z]+)' 'NO'
    $enterpriseJoined = Get-DsValue '(?i)EnterpriseJoined\s*:\s*([A-Za-z]+)' 'NO'
    $domainJoined     = Get-DsValue '(?i)DomainJoined\s*:\s*([A-Za-z]+)' 'NO'
    $domainName       = Get-DsValue '(?i)DomainName\s*:\s*([^\r\n]+)' 'N/A'
    $deviceName       = Get-DsValue '(?i)Device Name\s*:\s*([^\r\n]+)' $env:COMPUTERNAME
    $deviceId         = Get-DsValue '(?i)DeviceId\s*:\s*([^\r\n]+)' 'Chua co'
    $tenantId         = Get-DsValue '(?i)TenantId\s*:\s*([^\r\n]+)' 'Chua lien ket'
    $tenantName       = Get-DsValue '(?i)TenantName\s*:\s*([^\r\n]+)' 'N/A'

    $workplaceJoined  = Get-DsValue '(?i)WorkplaceJoined\s*:\s*([A-Za-z]+)' 'NO'
    $wamDefaultSet    = Get-DsValue '(?i)WamDefaultSet\s*:\s*([A-Za-z]+)' 'NO'

    $azureAdPrt       = Get-DsValue '(?i)AzureAdPrt\s*:\s*([A-Za-z]+)' 'NO'
    $azureAdPrtAuth   = Get-DsValue '(?i)AzureAdPrtAuthority\s*:\s*([^\r\n]+)' 'N/A'
    $enterprisePrt    = Get-DsValue '(?i)EnterprisePrt\s*:\s*([A-Za-z]+)' 'NO'

    $diagAdConnect    = Get-DsValue '(?i)AD Connectivity Test\s*:\s*([^\r\n]+)' 'N/A'
    $clientErrorCode  = Get-DsValue '(?i)Client ErrorCode\s*:\s*([^\r\n]+)' 'N/A'
    $executingUser    = Get-DsValue '(?i)Executing Account Name\s*:\s*([^\r\n]+)' $env:USERNAME

    # 2. Thu thap thong tin Intune / MDM
    Write-Host ' [2/3] Kiem tra tinh trang dang ky quan ly thiet bi MDM / Intune...' -ForegroundColor Gray
    $mdmFound = $false
    $mdmProvider = ""
    $mdmUrl = ""
    $mdmUpn = ""
    try {
        $enrollments = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue
        if ($enrollments) {
            foreach ($e in $enrollments) {
                $p = Get-ItemProperty -Path $e.PSPath -ErrorAction SilentlyContinue
                if ($p -and ($p.DiscoveryServiceFullURL -or "$($p.ProviderID)" -match 'MS DM Server|Intune' -or ($p.UPN -and "$($p.UPN)" -match '@'))) {
                    $mdmFound = $true
                    $mdmProvider = "$($p.ProviderID)"
                    $mdmUrl = "$($p.DiscoveryServiceFullURL)"
                    $mdmUpn = "$($p.UPN)"
                    break
                }
            }
        }
    } catch { }

    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' THONG TIN IDENTITY & THIET BI (DEVICE & DOMAIN STATE):' -ForegroundColor Yellow
    Write-Host ("  - Gia nhap On-Premises AD : {0} (Domain: {1})" -f $domainJoined, $domainName) -ForegroundColor $(if ($domainJoined -eq 'YES') { 'Green' } else { 'White' })
    Write-Host ("  - Gia nhap Entra ID (Cloud): {0}" -f $azureAdJoined) -ForegroundColor $(if ($azureAdJoined -eq 'YES') { 'Green' } else { 'White' })
    Write-Host ("  - Lien ket Tai khoan Co quan: {0} (Workplace / Work Account)" -f $workplaceJoined) -ForegroundColor $(if ($workplaceJoined -eq 'YES') { 'Green' } else { 'White' })
    if ($deviceId -ne 'Chua co') { Write-Host ("  - Cloud Device ID         : {0}" -f $deviceId) }
    if ($tenantId -ne 'Chua lien ket') { Write-Host ("  - Tenant ID               : {0}" -f $tenantId) }
    if ($tenantName -ne 'N/A') { Write-Host ("  - Tenant Name             : {0}" -f $tenantName) }

    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' TRANG THAI XAC THUC SSO & PRT TOKEN (OFFICE 365 / OUTLOOK):' -ForegroundColor Yellow
    Write-Host ("  - Primary Refresh Token (AzureAdPrt) : {0}" -f $azureAdPrt) -ForegroundColor $(if ($azureAdPrt -eq 'YES') { 'Green' } else { 'Yellow' })
    Write-Host ("  - Web Account Manager (WamDefaultSet): {0}" -f $wamDefaultSet)
    if ($azureAdPrtAuth -ne 'N/A' -and $azureAdPrtAuth -ne 'NO') {
        Write-Host ("  - Co quan xac thuc PRT              : {0}" -f $azureAdPrtAuth)
    }

    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' TRANG THAI QUAN LY THIET BI MDM / MICROSOFT INTUNE:' -ForegroundColor Yellow
    if ($mdmFound) {
        Write-Host '  - Tinh trang MDM          : DA DANG KY (Enrolled)' -ForegroundColor Green
        if ($mdmUpn) { Write-Host ("  - Tai khoan dang ky       : {0}" -f $mdmUpn) -ForegroundColor Cyan }
        if ($mdmProvider) { Write-Host ("  - MDM Provider            : {0}" -f $mdmProvider) }
        if ($mdmUrl) { Write-Host ("  - Discovery URL           : {0}" -f $mdmUrl) }
    } else {
        Write-Host '  - Tinh trang MDM          : CHUA DANG KY (Khong su dung hoac goi khong co ban quyen Intune Plan 1)' -ForegroundColor Gray
    }

    # 3. Danh gia suc khoe va canh bao
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' DANH GIA SUC KHOE IDENTITY & KHUYEN NGHI IT:' -ForegroundColor Cyan
    if ($azureAdPrt -eq 'YES') {
        Write-Host '  [+] HE THONG SSO HOAT DONG TOT: May tinh da duoc cap PRT Token.' -ForegroundColor Green
        Write-Host '      Cac ung dung Office 365 (Word, Excel, Outlook, OneDrive) xac thuc tu dong on dinh.'
    } else {
        Write-Host '  [!] CANH BAO: May tinh CHUA CO hoac BI MAT PRT Token (AzureAdPrt : NO).' -ForegroundColor Yellow
        Write-Host '      => Day la nguyen nhan khien Outlook hien tam giac vang "Need Password", loop dang nhap'
        Write-Host '         hoac Office bao loi "Account Error". Can reset WAM / TokenBroker cache.'
    }

    if ($clientErrorCode -ne 'N/A' -and $clientErrorCode -ne '0x0') {
        Write-Host ("  [!] Ma loi dang ky Entra ID gan nhat: {0} (Account: {1})" -f $clientErrorCode, $executingUser) -ForegroundColor Gray
    }

    # 4. Menu thao tac
    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' CAC THAO TAC XU LY & DIEU KHIEN:' -ForegroundColor Yellow
    Write-Host ' [1] 1-Click Sua loi Outlook / Office 365 "Need Password", Tam giac vang & Reset WAM Token' -ForegroundColor Green
    Write-Host ' [2] Dong bo tuc thi chinh sach MDM / Intune ve may tinh (DeviceEnroller.exe)' -ForegroundColor Cyan
    Write-Host ' [3] Mo nhanh cai dat "Access work or school" (Lien ket / Ngat lien ket tai khoan)'
    Write-Host ' [4] Dang ky lai WAM BrokerPlugin (Sua loi man hinh dang nhap bi trang tinh / crash)' -ForegroundColor Magenta
    Write-Host ' [5] Xuat toan bo bao cao dsregcmd /status chi tiet ra file text Desktop'
    Write-Host ' [0] Quay lai'
    Write-Host '-------------------------------------------------------------------------------------------'

    $sub = Read-Host 'Chon thao tac [0-5]'
    switch ($sub) {
        '1' {
            Write-Host ' [1/3] Dang dong cac ung dung Office va trinh duyet...' -ForegroundColor Gray
            $apps = @('outlook', 'olk', 'winword', 'excel', 'powerpnt', 'onedrive', 'teams', 'ms-teams')
            foreach ($a in $apps) {
                try { Get-Process -Name $a -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch { }
            }
            Start-Sleep -Seconds 1

            Write-Host ' [2/3] Dang xoa bo nho dem TokenBroker, OneAuth, IdentityCache va WAM Accounts...' -ForegroundColor Gray
            $paths = @(
                (Join-Path $env:LOCALAPPDATA 'Microsoft\OneAuth'),
                (Join-Path $env:LOCALAPPDATA 'Microsoft\IdentityCache'),
                (Join-Path $env:LOCALAPPDATA 'Microsoft\TokenBroker\Cache'),
                (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker\Accounts'),
                (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\AC\TokenBroker\Accounts')
            )
            $cleaned = 0
            foreach ($p in $paths) {
                if (Test-Path -LiteralPath $p) {
                    try {
                        Get-ChildItem -LiteralPath $p -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        $cleaned++
                    } catch { }
                }
            }

            Write-Host ' [3/3] Dang dang ky lai AAD BrokerPlugin de khoi tao moi...' -ForegroundColor Gray
            try {
                $manifest = "$env:SystemRoot\SystemApps\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AppxManifest.xml"
                if (Test-Path -LiteralPath $manifest) {
                    Add-AppxPackage -Register $manifest -DisableDevelopmentMode -ForceApplicationShutdown -ErrorAction SilentlyContinue
                }
            } catch { }

            Write-Host '-------------------------------------------------------------------------------------------'
            Write-Host ' [THANH CONG] Da xoa sach token xac thuc cu bi loi va reset WAM BrokerPlugin!' -ForegroundColor Green
            Write-Host ' Nguoi dung bay gio hay mo lai Outlook / Word de dang nhap lai (Windows se cap PRT moi).' -ForegroundColor Cyan
        }
        '2' {
            Write-Host ' Dang kich hoat dong bo chinh sach thiet bi tu Intune / MDM...' -ForegroundColor Gray
            try {
                Start-Process -FilePath "$env:SystemRoot\system32\DeviceEnroller.exe" -ArgumentList '/c /urmgred' -NoNewWindow -Wait -ErrorAction Stop
                Write-Host ' [THANH CONG] Da gui lenh dong bo chinh sach Intune / MDM thanh cong.' -ForegroundColor Green
                Write-Host ' Windows dang cap nhat cac chinh sach tu server trong nen.' -ForegroundColor Cyan
            } catch {
                Write-Host (' [LOI] ' + $_.Exception.Message) -ForegroundColor Red
            }
        }
        '3' {
            Write-Host ' Dang mo trang Windows Settings: Access work or school...' -ForegroundColor Gray
            try { Start-Process 'ms-settings:workplace' } catch { }
        }
        '4' {
            Write-Host ' Dang dang ky lai goi ung dung AAD BrokerPlugin (Reset WAM)...' -ForegroundColor Gray
            try {
                $manifest = "$env:SystemRoot\SystemApps\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AppxManifest.xml"
                if (Test-Path -LiteralPath $manifest) {
                    Add-AppxPackage -Register $manifest -DisableDevelopmentMode -ForceApplicationShutdown -ErrorAction Stop
                    Write-Host ' [THANH CONG] Da dang ky lai AAD BrokerPlugin thanh cong!' -ForegroundColor Green
                } else {
                    Write-Host ' [LOI] Khong tim thay tep AppxManifest cua AAD BrokerPlugin.' -ForegroundColor Red
                }
            } catch {
                Write-Host (' [LOI] ' + $_.Exception.Message) -ForegroundColor Red
            }
        }
        '5' {
            try {
                [IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
                $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $reportPath = Join-Path $OutputRoot ("EntraID_Status_{0}_{1}.txt" -f (Get-SafeName $env:COMPUTERNAME), $stamp)
                $dsRaw | Set-Content -LiteralPath $reportPath -Encoding UTF8
                Write-Host (' [THANH CONG] Da xuat bao cao dsregcmd ra: {0}' -f $reportPath) -ForegroundColor Green
                try { Start-Process 'notepad.exe' $reportPath } catch { }
            } catch {
                Write-Host (' [LOI] ' + $_.Exception.Message) -ForegroundColor Red
            }
        }
        default {
            Write-Host 'Quay lai menu.'
        }
    }
    Write-Host '==========================================================================================='
    Write-SessionLog 'Invoke-CloudIdentitySuite completed'
}
