function Invoke-LocalUserAdmin {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-LocalUserAdmin started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  QUAN LY TAI KHOAN CUC BO VA BUILT-IN ADMINISTRATOR' -ForegroundColor Cyan
    Write-Host '==========================================================================================='

    Write-Host ' Danh sach tai khoan cuc bo tren may:' -ForegroundColor Yellow
    try {
        & net.exe user
    } catch { }

    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' [1] Bat tai khoan Built-in Administrator (net user administrator /active:yes)'
    Write-Host ' [2] Tat tai khoan Built-in Administrator (net user administrator /active:no)'
    Write-Host ' [3] Dat lai mat khau cho mot tai khoan (net user <ten> *)'
    Write-Host ' [4] Mo bang quan ly Local Users and Groups (lusrmgr.msc)'
    Write-Host ' [0] Quay lai'
    Write-Host '-------------------------------------------------------------------------------------------'

    $choice = Read-Host 'Chon thao tac [0-4]'
    switch ($choice) {
        '1' {
            $c = Read-Host 'Ban co chac chan muon BAT tai khoan Built-in Administrator? (Y/N)'
            if ($c -match '^[Yy]') {
                try {
                    & net.exe user administrator /active:yes
                    Write-Host ' [THANH CONG] Da bat tai khoan Administrator tich hop.' -ForegroundColor Green
                    $setPw = Read-Host 'Ban co muon dat mat khau cho tai khoan Administrator ngay bay gio khong? (Y/N)'
                    if ($setPw -match '^[Yy]') {
                        & net.exe user administrator *
                    }
                } catch {
                    Write-Host (' Loi: {0}' -f $_.Exception.Message) -ForegroundColor Red
                }
            }
        }
        '2' {
            $c = Read-Host 'Ban co chac chan muon TAT tai khoan Built-in Administrator? (Y/N)'
            if ($c -match '^[Yy]') {
                try {
                    & net.exe user administrator /active:no
                    Write-Host ' [THANH CONG] Da tat tai khoan Administrator tich hop.' -ForegroundColor Green
                } catch {
                    Write-Host (' Loi: {0}' -f $_.Exception.Message) -ForegroundColor Red
                }
            }
        }
        '3' {
            $u = Read-Host 'Nhap ten tai khoan muon doi mat khau'
            if (-not [string]::IsNullOrWhiteSpace($u)) {
                try {
                    & net.exe user $u.Trim() *
                } catch {
                    Write-Host (' Loi: {0}' -f $_.Exception.Message) -ForegroundColor Red
                }
            }
        }
        '4' {
            Write-Host ' Dang mo lusrmgr.msc...' -ForegroundColor Gray
            try {
                Start-Process 'lusrmgr.msc'
            } catch {
                Write-Host ' Ban Windows Home khong ho tro giao dien lusrmgr.msc. Hay dung lenh net user.' -ForegroundColor Yellow
            }
        }
        default {
            Write-Host 'Quay lai menu.'
        }
    }
    Write-Host '==========================================================================================='
    Write-SessionLog 'Invoke-LocalUserAdmin completed'
}

function Invoke-RenamePC {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-RenamePC started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  DOI TEN MAY TINH (RENAME COMPUTER - CHUAN HOA THIET BI IT)' -ForegroundColor Cyan
    Write-Host '==========================================================================================='
    Write-Host (' Ten may hien tai: {0}' -f $env:COMPUTERNAME) -ForegroundColor Yellow
    Write-Host ' Quy chuan ten: Toi da 15 ky tu, chi gom chu cai A-Z, chu so 0-9 va dau gach ngang (-).' -ForegroundColor Gray
    Write-Host '-------------------------------------------------------------------------------------------'

    $newName = Read-Host 'Nhap ten may tinh moi (hoac de trong de huy)'
    if ([string]::IsNullOrWhiteSpace($newName)) {
        Write-Host 'Da huy thao tac doi ten.' -ForegroundColor Yellow
        return
    }

    $newName = $newName.Trim()
    if ($newName.Length -gt 15 -or $newName -match '[^A-Za-z0-9-]') {
        Write-Host ' Ten khong hop le (qua 15 ky tu hoac co ky tu dac biet). Da huy!' -ForegroundColor Red
        return
    }

    $confirm = Read-Host ("Ban co chac muon doi ten may tu '$env:COMPUTERNAME' thanh '$newName'? (Y/N)")
    if ($confirm -notmatch '^[Yy]') {
        Write-Host 'Da huy thao tac.' -ForegroundColor Yellow
        return
    }

    try {
        Rename-Computer -NewName $newName -Force -ErrorAction Stop
        Write-Host (' [THANH CONG] May tinh da duoc doi ten thanh: {0}' -f $newName) -ForegroundColor Green
        Write-Host ' Luu y: Ten moi se co hieu luc sau khi may duoc khoi dong lai.' -ForegroundColor Cyan
        $reboot = Read-Host 'Ban co muon khoi dong lai may tinh ngay bay gio khong? (Y/N)'
        if ($reboot -match '^[Yy]') {
            Write-Host ' May se khoi dong lai trong 10 giay...' -ForegroundColor Yellow
            & shutdown.exe /r /t 10 /c "Doi ten may tinh thanh cong - Khoi dong lai he thong."
        }
    } catch {
        Write-Host (' Loi khi doi ten may: {0}' -f $_.Exception.Message) -ForegroundColor Red
    }
    Write-Host '==========================================================================================='
    Write-SessionLog ('Invoke-RenamePC completed. NewName: ' + $newName)
}

function Invoke-ToggleRDP {
    [CmdletBinding()]
    param()
    Write-SessionLog 'Invoke-ToggleRDP started'
    Write-Host '===========================================================================================' -ForegroundColor Cyan
    Write-Host '  BAT / TAT REMOTE DESKTOP (RDP) VA MO CONG FIREWALL 3389' -ForegroundColor Cyan
    Write-Host '==========================================================================================='

    $rdpKey = 'HKLM:\System\CurrentControlSet\Control\Terminal Server'
    $currentVal = 1
    try {
        $currentVal = (Get-ItemProperty -Path $rdpKey -Name 'fDenyTSConnections' -ErrorAction SilentlyContinue).fDenyTSConnections
    } catch { }

    if ($currentVal -eq 0) {
        Write-Host ' Trang thai RDP hien tai: ' -NoNewline; Write-Host 'DANG BAT (Enabled)' -ForegroundColor Green
    } else {
        Write-Host ' Trang thai RDP hien tai: ' -NoNewline; Write-Host 'DANG TAT (Disabled)' -ForegroundColor Yellow
    }

    Write-Host '-------------------------------------------------------------------------------------------'
    Write-Host ' [1] BAT Remote Desktop va MO cong Firewall 3389' -ForegroundColor Green
    Write-Host ' [2] TAT Remote Desktop va DONG cong Firewall' -ForegroundColor Yellow
    Write-Host ' [0] Quay lai'
    Write-Host '-------------------------------------------------------------------------------------------'

    $choice = Read-Host 'Chon thao tac [0-2]'
    switch ($choice) {
        '1' {
            Write-Host ' Dang bat Remote Desktop qua Registry...' -ForegroundColor Gray
            try {
                Set-ItemProperty -Path $rdpKey -Name 'fDenyTSConnections' -Value 0 -Force
                Set-ItemProperty -Path "$rdpKey\WinStations\RDP-Tcp" -Name 'UserAuthentication' -Value 1 -Force -ErrorAction SilentlyContinue
                Write-Host ' Dang mo cong Remote Desktop tren Windows Firewall...' -ForegroundColor Gray
                & netsh.exe advfirewall firewall set rule group="remote desktop" new enable=Yes 2>&1 | Out-Null
                Write-Host ' [THANH CONG] Da BAT Remote Desktop va mo cong tuong lua.' -ForegroundColor Green
                Write-Host (' IT co the ket noi toi IP cua may nay bang mstsc qua cong 3389.') -ForegroundColor Cyan
            } catch {
                Write-Host (' Loi: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }
        }
        '2' {
            Write-Host ' Dang tat Remote Desktop...' -ForegroundColor Gray
            try {
                Set-ItemProperty -Path $rdpKey -Name 'fDenyTSConnections' -Value 1 -Force
                & netsh.exe advfirewall firewall set rule group="remote desktop" new enable=No 2>&1 | Out-Null
                Write-Host ' [THANH CONG] Da TAT Remote Desktop va khoa cong tuong lua.' -ForegroundColor Green
            } catch {
                Write-Host (' Loi: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }
        }
        default {
            Write-Host 'Quay lai menu.'
        }
    }
    Write-Host '==========================================================================================='
    Write-SessionLog 'Invoke-ToggleRDP completed'
}

