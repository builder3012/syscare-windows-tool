@echo off
setlocal EnableExtensions DisableDelayedExpansion
title TOOL WINDOWS - SUA LOI, CHAN DOAN VA BAO TRI
color 0B
mode con cols=92 lines=36 >nul 2>&1

rem ================================================================
rem TOOL WINDOWS - Windows 10/11
rem Tat ca nhan menu dung ky tu ASCII de tuong thich tot voi CMD.
rem ================================================================

fltmc >nul 2>&1
if errorlevel 1 (
    cls
    echo ================================================================
    echo  CAN QUYEN ADMINISTRATOR
    echo ================================================================
    echo  Hay bam chuot phai vao file BAT va chon Run as administrator.
    echo.
    pause
    exit /b 1
)

for /f "usebackq delims=" %%D in (`powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"
if not defined DESKTOP set "DESKTOP=%USERPROFILE%\Desktop"

:main
cls
echo ===========================================================================================
echo  TOOL WINDOWS - SUA LOI, CHAN DOAN VA BAO TRI WINDOWS 10/11
echo ===========================================================================================
echo.
echo  [1] SUA LOI WINDOWS         - SFC, DISM, Component Store, CHKDSK
echo  [2] MANG VA INTERNET        - Flush DNS, IP, Winsock, TCP/IP, Wi-Fi
echo  [3] O DIA, RAM VA NGUON     - Kiem tra dia, bo nho, pin, nang luong
echo  [4] KHOI DONG VA PHUC HOI   - BCD, WinRE, Restore Point, Advanced Startup
echo  [5] DRIVER VA THIET BI      - Driver, Device Manager, Verifier, DirectX
echo  [6] BAO MAT VA CAP NHAT     - Defender, Firewall, Windows Update, ban quyen
echo  [7] CHAN DOAN VA QUAN TRI   - Event, Reliability, Services, Registry, DISM info
echo  [8] MAY IN VA TIEN ICH      - Spooler, Store cache, dong bo gio, cong cu he thong
echo  [9] TAO BAO CAO TONG HOP    - Xuat bo log chan doan ra Desktop
echo  [0] THOAT
echo.
echo  Luu y: Cac muc co anh huong ket noi/khoi dong/xoa du lieu se hoi xac nhan.
echo ===========================================================================================
choice /C 1234567890 /N /M "Chon nhom chuc nang [0-9]: "
if errorlevel 10 goto exit_tool
if errorlevel 9 goto create_report
if errorlevel 8 goto utilities_menu
if errorlevel 7 goto admin_menu
if errorlevel 6 goto security_menu
if errorlevel 5 goto driver_menu
if errorlevel 4 goto boot_menu
if errorlevel 3 goto disk_menu
if errorlevel 2 goto network_menu
if errorlevel 1 goto repair_menu
goto main

rem ----------------------------------------------------------------
rem NHOM 1 - SUA LOI WINDOWS
rem ----------------------------------------------------------------
:repair_menu
cls
echo ===========================================================================================
echo  [1] SUA LOI WINDOWS - THU TU KHUYEN NGHI: DISM RESTOREHEALTH, SAU DO SFC SCANNOW
echo ===========================================================================================
echo  [1] SFC Verify Only              - Kiem tra tep he thong, khong sua
echo  [2] SFC ScanNow                  - Quet va sua tep he thong Windows
echo  [3] DISM CheckHealth             - Kiem tra nhanh Component Store
echo  [4] DISM ScanHealth              - Quet sau Component Store
echo  [5] DISM RestoreHealth           - Sua Component Store, co the can Internet
echo  [6] DISM StartComponentCleanup   - Don dep thanh phan Windows cu
echo  [7] CHKDSK Online Scan           - Quet o he thong khi Windows dang chay
echo  [8] CHKDSK Fix                   - Kiem tra/sua loi, co the hen lich khi khoi dong
echo  [9] SUA LOI TOAN DIEN            - DISM RestoreHealth roi SFC ScanNow
echo  [A] Mo thu muc log CBS va DISM
echo  [0] Quay lai menu chinh
echo ===========================================================================================
choice /C 123456789A0 /N /M "Chon chuc nang: "
if errorlevel 11 goto main
if errorlevel 10 goto repair_logs
if errorlevel 9 goto repair_full
if errorlevel 8 goto repair_chkdsk_fix
if errorlevel 7 goto repair_chkdsk_scan
if errorlevel 6 goto repair_cleanup
if errorlevel 5 goto repair_dism_restore
if errorlevel 4 goto repair_dism_scan
if errorlevel 3 goto repair_dism_check
if errorlevel 2 goto repair_sfc_scan
if errorlevel 1 goto repair_sfc_verify
goto repair_menu

:repair_sfc_verify
cls
echo Dang kiem tra tinh toan ven cua tep he thong...
sfc /verifyonly
echo.
pause
goto repair_menu

:repair_sfc_scan
cls
echo Dang quet va sua tep he thong. Khong tat may trong qua trinh nay...
sfc /scannow
echo.
pause
goto repair_menu

:repair_dism_check
cls
DISM.exe /Online /Cleanup-Image /CheckHealth
echo.
pause
goto repair_menu

:repair_dism_scan
cls
echo Qua trinh quet co the mat nhieu phut...
DISM.exe /Online /Cleanup-Image /ScanHealth
echo.
pause
goto repair_menu

:repair_dism_restore
cls
echo Dang sua Component Store. Lenh co the tai tep tu Windows Update...
DISM.exe /Online /Cleanup-Image /RestoreHealth
echo.
pause
goto repair_menu

:repair_cleanup
cls
echo Dang don dep cac thanh phan Windows da duoc thay the...
DISM.exe /Online /Cleanup-Image /StartComponentCleanup
echo.
pause
goto repair_menu

:repair_chkdsk_scan
cls
chkdsk %SystemDrive% /scan
echo.
pause
goto repair_menu

:repair_chkdsk_fix
cls
echo Lenh CHKDSK /F co the yeu cau hen lich quet o lan khoi dong tiep theo.
echo Hay doc thong bao cua Windows va nhap Y neu muon hen lich.
echo.
choice /C YN /N /M "Tiep tuc? [Y/N]: "
if errorlevel 2 goto repair_menu
chkdsk %SystemDrive% /f
echo.
pause
goto repair_menu

:repair_full
cls
echo ================================================================
echo  SUA LOI TOAN DIEN: DISM RESTOREHEALTH, SAU DO SFC SCANNOW
echo ================================================================
echo Qua trinh co the mat 15-60 phut va co the can Internet.
choice /C YN /N /M "Bat dau? [Y/N]: "
if errorlevel 2 goto repair_menu
DISM.exe /Online /Cleanup-Image /RestoreHealth
if errorlevel 1 (
    echo.
    echo DISM bao loi. Van tiep tuc chay SFC de kiem tra tep he thong.
)
echo.
sfc /scannow
echo.
echo Da hoan tat chuoi sua loi. Nen khoi dong lai may neu co tep duoc sua.
pause
goto repair_menu

:repair_logs
start "" explorer.exe "%SystemRoot%\Logs"
goto repair_menu

rem ----------------------------------------------------------------
rem NHOM 2 - MANG VA INTERNET
rem ----------------------------------------------------------------
:network_menu
cls
echo ===========================================================================================
echo  [2] MANG VA INTERNET
echo ===========================================================================================
echo  [1] Xem cau hinh IP day du       - ipconfig /all
echo  [2] Kiem tra ket noi tong hop    - Gateway, Internet IP, DNS
echo  [3] Xoa bo nho dem DNS           - ipconfig /flushdns
echo  [4] Cap lai dia chi IP DHCP      - release/renew, mat ket noi tam thoi
echo  [5] Reset Winsock                - thuong can khoi dong lai
echo  [6] Reset TCP/IP                 - thuong can khoi dong lai
echo  [7] Reset WinHTTP Proxy          - dua proxy he thong ve Direct Access
echo  [8] Xem bo nho dem DNS hien tai
echo  [9] Tao bao cao Wi-Fi            - xuat HTML va tu dong mo
echo  [A] Xem cac Wi-Fi profile da luu - khong hien mat khau
echo  [B] Mo Network Connections
echo  [0] Quay lai menu chinh
echo ===========================================================================================
choice /C 123456789AB0 /N /M "Chon chuc nang: "
if errorlevel 12 goto main
if errorlevel 11 goto network_connections
if errorlevel 10 goto network_wifi_profiles
if errorlevel 9 goto network_wifi_report
if errorlevel 8 goto network_dns_cache
if errorlevel 7 goto network_proxy_reset
if errorlevel 6 goto network_tcp_reset
if errorlevel 5 goto network_winsock_reset
if errorlevel 4 goto network_dhcp_renew
if errorlevel 3 goto network_flushdns
if errorlevel 2 goto network_test
if errorlevel 1 goto network_ipconfig
goto network_menu

:network_ipconfig
cls
ipconfig /all
echo.
pause
goto network_menu

:network_test
cls
echo === CAU HINH IP TOM TAT ===
ipconfig | findstr /I /C:"IPv4" /C:"Default Gateway" /C:"DNS Servers"
echo.
echo === KIEM TRA INTERNET BANG IP ===
ping -n 4 1.1.1.1
echo.
echo === KIEM TRA PHAN GIAI TEN DNS ===
nslookup microsoft.com
echo.
echo === DUONG DI DEN INTERNET ===
tracert -d -h 12 1.1.1.1
echo.
pause
goto network_menu

:network_flushdns
cls
ipconfig /flushdns
echo.
pause
goto network_menu

:network_dhcp_renew
cls
echo CANH BAO: Ket noi mang se bi ngat tam thoi. Khong dung khi dang dieu khien may tu xa.
choice /C YN /N /M "Tiep tuc release/renew IP? [Y/N]: "
if errorlevel 2 goto network_menu
ipconfig /release
ipconfig /renew
ipconfig /flushdns
echo.
pause
goto network_menu

:network_winsock_reset
cls
echo Lenh nay reset Winsock Catalog. Nen khoi dong lai may sau khi chay.
choice /C YN /N /M "Tiep tuc? [Y/N]: "
if errorlevel 2 goto network_menu
netsh winsock reset
echo.
pause
goto network_menu

:network_tcp_reset
cls
echo Lenh nay reset cau hinh TCP/IP va co the anh huong IP tinh.
echo Neu may dang dung IP tinh, hay ghi lai cau hinh truoc khi tiep tuc.
choice /C YN /N /M "Tiep tuc? [Y/N]: "
if errorlevel 2 goto network_menu
netsh int ip reset "%TEMP%\ToolWindows_TCPIP_Reset.log"
echo.
echo Log: %TEMP%\ToolWindows_TCPIP_Reset.log
pause
goto network_menu

:network_proxy_reset
cls
echo Cau hinh WinHTTP proxy hien tai:
netsh winhttp show proxy
echo.
choice /C YN /N /M "Reset WinHTTP proxy ve Direct Access? [Y/N]: "
if errorlevel 2 goto network_menu
netsh winhttp reset proxy
echo.
pause
goto network_menu

:network_dns_cache
cls
ipconfig /displaydns | more
echo.
pause
goto network_menu

:network_wifi_report
cls
netsh wlan show wlanreport
if exist "%ProgramData%\Microsoft\Windows\WlanReport\wlan-report-latest.html" start "" "%ProgramData%\Microsoft\Windows\WlanReport\wlan-report-latest.html"
echo.
pause
goto network_menu

:network_wifi_profiles
cls
netsh wlan show profiles
echo.
pause
goto network_menu

:network_connections
start "" ncpa.cpl
goto network_menu

rem ----------------------------------------------------------------
rem NHOM 3 - O DIA, RAM VA NGUON
rem ----------------------------------------------------------------
:disk_menu
cls
echo ===========================================================================================
echo  [3] O DIA, RAM VA NGUON
echo ===========================================================================================
echo  [1] Quet loi o he thong online       - CHKDSK /scan
echo  [2] Xem suc khoe va trang thai o dia - PowerShell Get-PhysicalDisk/Get-Disk
echo  [3] Mo Disk Management
echo  [4] Mo Disk Cleanup
echo  [5] Mo Optimize Drives
echo  [6] Kiem tra RAM sau khi khoi dong    - Windows Memory Diagnostic
echo  [7] Tao bao cao pin ra Desktop        - phu hop laptop
echo  [8] Tao bao cao nang luong 60 giay    - xuat HTML ra Desktop
echo  [9] Mo thu muc TEMP nguoi dung
echo  [A] Mo Storage Settings
echo  [0] Quay lai menu chinh
echo ===========================================================================================
choice /C 123456789A0 /N /M "Chon chuc nang: "
if errorlevel 11 goto main
if errorlevel 10 goto disk_storage_settings
if errorlevel 9 goto disk_temp
if errorlevel 8 goto disk_energy
if errorlevel 7 goto disk_battery
if errorlevel 6 goto disk_memory
if errorlevel 5 goto disk_optimize
if errorlevel 4 goto disk_cleanup
if errorlevel 3 goto disk_management
if errorlevel 2 goto disk_health
if errorlevel 1 goto disk_scan
goto disk_menu

:disk_scan
cls
chkdsk %SystemDrive% /scan
echo.
pause
goto disk_menu

:disk_health
cls
powershell.exe -NoProfile -Command "Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize; Get-Disk | Select-Object Number,FriendlyName,PartitionStyle,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize"
echo.
pause
goto disk_menu

:disk_management
start "" diskmgmt.msc
goto disk_menu

:disk_cleanup
start "" cleanmgr.exe
goto disk_menu

:disk_optimize
start "" dfrgui.exe
goto disk_menu

:disk_memory
start "" mdsched.exe
goto disk_menu

:disk_battery
cls
powercfg /batteryreport /output "%DESKTOP%\battery-report.html"
if exist "%DESKTOP%\battery-report.html" start "" "%DESKTOP%\battery-report.html"
echo.
pause
goto disk_menu

:disk_energy
cls
echo Dang thu thap thong tin trong 60 giay. Hay giu may hoat dong binh thuong...
powercfg /energy /duration 60 /output "%DESKTOP%\energy-report.html"
if exist "%DESKTOP%\energy-report.html" start "" "%DESKTOP%\energy-report.html"
echo.
pause
goto disk_menu

:disk_temp
start "" explorer.exe "%TEMP%"
goto disk_menu

:disk_storage_settings
start "" ms-settings:storagesense
goto disk_menu

rem ----------------------------------------------------------------
rem NHOM 4 - KHOI DONG VA PHUC HOI
rem ----------------------------------------------------------------
:boot_menu
cls
echo ===========================================================================================
echo  [4] KHOI DONG VA PHUC HOI
echo ===========================================================================================
echo  [1] Xem trang thai Windows Recovery Environment - reagentc /info
echo  [2] Xem Windows Boot Loader                  - bcdedit /enum osloader
echo  [3] Xem toan bo cau hinh BCD                 - bcdedit /enum all /v
echo  [4] Xem Resume Objects                       - bcdedit /enum resume
echo  [5] Sao luu BCD ra Desktop                   - tep co dong thoi gian
echo  [6] Mo System Restore
echo  [7] Mo System Protection va Restore Point
echo  [8] Mo System Configuration                  - msconfig
echo  [9] Khoi dong vao Advanced Startup           - MAY SE KHOI DONG LAI
echo  [0] Quay lai menu chinh
echo ===========================================================================================
choice /C 1234567890 /N /M "Chon chuc nang: "
if errorlevel 10 goto main
if errorlevel 9 goto boot_advanced_startup
if errorlevel 8 goto boot_msconfig
if errorlevel 7 goto boot_protection
if errorlevel 6 goto boot_restore
if errorlevel 5 goto boot_backup
if errorlevel 4 goto boot_resume
if errorlevel 3 goto boot_bcd_all
if errorlevel 2 goto boot_osloader
if errorlevel 1 goto boot_reagent
goto boot_menu

:boot_reagent
cls
reagentc /info
echo.
pause
goto boot_menu

:boot_osloader
cls
bcdedit /enum osloader
echo.
pause
goto boot_menu

:boot_bcd_all
cls
bcdedit /enum all /v
echo.
pause
goto boot_menu

:boot_resume
cls
bcdedit /enum resume
echo.
pause
goto boot_menu

:boot_backup
cls
for /f %%I in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
bcdedit /export "%DESKTOP%\BCD_Backup_%STAMP%.bcd"
echo.
echo Da xuat ban sao BCD ra Desktop neu lenh khong bao loi.
pause
goto boot_menu

:boot_restore
start "" rstrui.exe
goto boot_menu

:boot_protection
start "" SystemPropertiesProtection.exe
goto boot_menu

:boot_msconfig
start "" msconfig.exe
goto boot_menu

:boot_advanced_startup
cls
echo CANH BAO: May tinh se khoi dong lai ngay va vao Advanced Startup.
echo Hay luu tat ca cong viec dang mo truoc khi tiep tuc.
choice /C YN /N /M "Khoi dong lai ngay? [Y/N]: "
if errorlevel 2 goto boot_menu
shutdown.exe /r /o /t 0
goto boot_menu

rem ----------------------------------------------------------------
rem NHOM 5 - DRIVER VA THIET BI
rem ----------------------------------------------------------------
:driver_menu
cls
echo ===========================================================================================
echo  [5] DRIVER VA THIET BI
echo ===========================================================================================
echo  [1] Mo Device Manager
echo  [2] Liet ke driver ben thu ba            - pnputil /enum-drivers
echo  [3] Liet ke driver dang hoat dong         - driverquery /v
echo  [4] Xem trang thai Driver Verifier        - KHONG tu dong bat Verifier
echo  [5] Liet ke thiet bi dang ket noi          - pnputil /enum-devices /connected
echo  [6] Mo DirectX Diagnostic Tool             - dxdiag
echo  [7] Mo System Information                  - msinfo32
echo  [0] Quay lai menu chinh
echo ===========================================================================================
choice /C 12345670 /N /M "Chon chuc nang: "
if errorlevel 8 goto main
if errorlevel 7 goto driver_msinfo
if errorlevel 6 goto driver_dxdiag
if errorlevel 5 goto driver_devices
if errorlevel 4 goto driver_verifier
if errorlevel 3 goto driver_query
if errorlevel 2 goto driver_pnputil
if errorlevel 1 goto driver_manager
goto driver_menu

:driver_manager
start "" devmgmt.msc
goto driver_menu

:driver_pnputil
cls
pnputil.exe /enum-drivers | more
echo.
pause
goto driver_menu

:driver_query
cls
driverquery.exe /v /fo table | more
echo.
pause
goto driver_menu

:driver_verifier
cls
echo === DRIVER VERIFIER STATUS ===
verifier.exe /query
echo.
echo === DRIVER VERIFIER SETTINGS ===
verifier.exe /querysettings
echo.
pause
goto driver_menu

:driver_devices
cls
pnputil.exe /enum-devices /connected | more
echo.
pause
goto driver_menu

:driver_dxdiag
start "" dxdiag.exe
goto driver_menu

:driver_msinfo
start "" msinfo32.exe
goto driver_menu

rem ----------------------------------------------------------------
rem NHOM 6 - BAO MAT VA CAP NHAT
rem ----------------------------------------------------------------
:security_menu
cls
echo ===========================================================================================
echo  [6] BAO MAT VA CAP NHAT
echo ===========================================================================================
echo  [1] Xem trang thai Microsoft Defender
echo  [2] Cap nhat co so du lieu Defender
echo  [3] Quet nhanh bang Defender
echo  [4] Quet toan bo bang Defender             - co the mat nhieu gio
echo  [5] Xem trang thai Windows Firewall
echo  [6] Mo Windows Security
echo  [7] Mo Windows Update
echo  [8] Xem lich su hotfix/cap nhat da cai
echo  [9] Kiem tra trang thai kich hoat Windows
echo  [A] Mo Malicious Software Removal Tool     - MRT
echo  [0] Quay lai menu chinh
echo ===========================================================================================
choice /C 123456789A0 /N /M "Chon chuc nang: "
if errorlevel 11 goto main
if errorlevel 10 goto security_mrt
if errorlevel 9 goto security_activation
if errorlevel 8 goto security_hotfix
if errorlevel 7 goto security_update_ui
if errorlevel 6 goto security_ui
if errorlevel 5 goto security_firewall
if errorlevel 4 goto security_full_scan
if errorlevel 3 goto security_quick_scan
if errorlevel 2 goto security_update_defs
if errorlevel 1 goto security_status
goto security_menu

:security_status
cls
powershell.exe -NoProfile -Command "Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,AntivirusSignatureLastUpdated,QuickScanEndTime,FullScanEndTime | Format-List"
echo.
pause
goto security_menu

:security_update_defs
cls
powershell.exe -NoProfile -Command "Update-MpSignature"
echo.
pause
goto security_menu

:security_quick_scan
cls
echo Dang khoi dong quet nhanh Microsoft Defender...
powershell.exe -NoProfile -Command "Start-MpScan -ScanType QuickScan"
echo.
pause
goto security_menu

:security_full_scan
cls
echo Quet toan bo co the mat nhieu gio. Khong tat may trong qua trinh quet.
choice /C YN /N /M "Bat dau Full Scan? [Y/N]: "
if errorlevel 2 goto security_menu
powershell.exe -NoProfile -Command "Start-MpScan -ScanType FullScan"
echo.
pause
goto security_menu

:security_firewall
cls
netsh advfirewall show allprofiles
echo.
pause
goto security_menu

:security_ui
start "" windowsdefender:
goto security_menu

:security_update_ui
start "" ms-settings:windowsupdate
goto security_menu

:security_hotfix
cls
powershell.exe -NoProfile -Command "Get-HotFix | Sort-Object InstalledOn -Descending | Format-Table HotFixID,Description,InstalledOn,InstalledBy -AutoSize"
echo.
pause
goto security_menu

:security_activation
cls
cscript.exe //nologo "%SystemRoot%\System32\slmgr.vbs" /xpr
echo.
pause
goto security_menu

:security_mrt
start "" mrt.exe
goto security_menu

rem ----------------------------------------------------------------
rem NHOM 7 - CHAN DOAN VA QUAN TRI
rem ----------------------------------------------------------------
:admin_menu
cls
echo ===========================================================================================
echo  [7] CHAN DOAN VA QUAN TRI
echo ===========================================================================================
echo  [1] Computer Management              [2] Services
echo  [3] Event Viewer                     [4] Reliability Monitor
echo  [5] System Diagnostics Report        [6] Resource Monitor
echo  [7] Task Manager                     [8] Startup Apps
echo  [9] Installed Apps                   [A] Windows Optional Features
echo  [B] Sao luu Registry SYSTEM          [C] So sanh HKLM va HKCU Software
echo  [D] Liet ke tat ca Services          [E] Xem Windows Edition hien tai
echo  [F] Xem cac Target Edition           [G] Xem Reserved Storage Status
echo  [0] Quay lai menu chinh
echo ===========================================================================================
choice /C 123456789ABCDEFG0 /N /M "Chon chuc nang: "
if errorlevel 17 goto main
if errorlevel 16 goto admin_reserved_storage
if errorlevel 15 goto admin_target_editions
if errorlevel 14 goto admin_current_edition
if errorlevel 13 goto admin_services_list
if errorlevel 12 goto admin_registry_compare
if errorlevel 11 goto admin_registry_backup
if errorlevel 10 goto admin_optional_features
if errorlevel 9 goto admin_installed_apps
if errorlevel 8 goto admin_startup
if errorlevel 7 goto admin_taskmgr
if errorlevel 6 goto admin_resmon
if errorlevel 5 goto admin_perf_report
if errorlevel 4 goto admin_reliability
if errorlevel 3 goto admin_eventviewer
if errorlevel 2 goto admin_services
if errorlevel 1 goto admin_computer_management
goto admin_menu

:admin_computer_management
start "" compmgmt.msc
goto admin_menu

:admin_services
start "" services.msc
goto admin_menu

:admin_eventviewer
start "" eventvwr.msc
goto admin_menu

:admin_reliability
start "" perfmon.exe /rel
goto admin_menu

:admin_perf_report
start "" perfmon.exe /report
goto admin_menu

:admin_resmon
start "" resmon.exe
goto admin_menu

:admin_taskmgr
start "" taskmgr.exe
goto admin_menu

:admin_startup
start "" ms-settings:startupapps
goto admin_menu

:admin_installed_apps
start "" appwiz.cpl
goto admin_menu

:admin_optional_features
start "" optionalfeatures.exe
goto admin_menu

:admin_registry_backup
cls
for /f %%I in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
reg.exe save HKLM\SYSTEM "%DESKTOP%\SYSTEM_%STAMP%.hiv"
echo.
echo Da xuat ban sao Registry SYSTEM ra Desktop neu lenh khong bao loi.
pause
goto admin_menu

:admin_registry_compare
cls
echo Lenh nay chi so sanh va khong thay doi Registry.
reg.exe compare HKLM\SOFTWARE HKCU\SOFTWARE
echo.
pause
goto admin_menu

:admin_services_list
cls
sc.exe query type= service state= all | more
echo.
pause
goto admin_menu

:admin_current_edition
cls
DISM.exe /Online /Get-CurrentEdition
echo.
pause
goto admin_menu

:admin_target_editions
cls
DISM.exe /Online /Get-TargetEditions
echo.
pause
goto admin_menu

:admin_reserved_storage
cls
DISM.exe /Online /Get-ReservedStorageState
echo.
pause
goto admin_menu

rem ----------------------------------------------------------------
rem NHOM 8 - MAY IN VA TIEN ICH
rem ----------------------------------------------------------------
:utilities_menu
cls
echo ===========================================================================================
echo  [8] MAY IN VA TIEN ICH THUONG DUNG
echo ===========================================================================================
echo  [1] Mo Printers and Scanners
echo  [2] Khoi dong lai Print Spooler             - khong xoa hang doi
echo  [3] Sua hang doi in bi ket                  - XOA TAT CA LENH IN DANG CHO
echo  [4] Mo trang Troubleshoot
echo  [5] Reset bo nho dem Microsoft Store        - wsreset
echo  [6] Kiem tra va dong bo lai gio Windows
echo  [7] Mo Internet Options
echo  [8] Mo System Properties Advanced
echo  [9] Mo thu muc Startup cua nguoi dung
echo  [A] Khoi dong lai Windows Explorer
echo  [B] Mo Clipboard Settings
echo  [0] Quay lai menu chinh
echo ===========================================================================================
choice /C 123456789AB0 /N /M "Chon chuc nang: "
if errorlevel 12 goto main
if errorlevel 11 goto utility_clipboard
if errorlevel 10 goto utility_restart_explorer
if errorlevel 9 goto utility_startup_folder
if errorlevel 8 goto utility_system_advanced
if errorlevel 7 goto utility_internet_options
if errorlevel 6 goto utility_time_sync
if errorlevel 5 goto utility_store_reset
if errorlevel 4 goto utility_troubleshoot
if errorlevel 3 goto utility_spooler_clear
if errorlevel 2 goto utility_spooler_restart
if errorlevel 1 goto utility_printers
goto utilities_menu

:utility_printers
start "" ms-settings:printers
goto utilities_menu

:utility_spooler_restart
cls
net.exe stop spooler
net.exe start spooler
echo.
pause
goto utilities_menu

:utility_spooler_clear
cls
echo CANH BAO: Chuc nang nay se xoa TOAN BO lenh in dang cho tren may.
choice /C YN /N /M "Tiep tuc xoa hang doi in? [Y/N]: "
if errorlevel 2 goto utilities_menu
net.exe stop spooler
del /F /Q "%SystemRoot%\System32\spool\PRINTERS\*" >nul 2>&1
net.exe start spooler
echo.
echo Da khoi dong lai Spooler va xoa hang doi in.
pause
goto utilities_menu

:utility_troubleshoot
start "" ms-settings:troubleshoot
goto utilities_menu

:utility_store_reset
start "" wsreset.exe
goto utilities_menu

:utility_time_sync
cls
echo === TRANG THAI DONG BO GIO ===
w32tm.exe /query /status
echo.
echo === DONG BO LAI VOI NGUON THOI GIAN DA CAU HINH ===
w32tm.exe /resync /rediscover
echo.
pause
goto utilities_menu

:utility_internet_options
start "" inetcpl.cpl
goto utilities_menu

:utility_system_advanced
start "" SystemPropertiesAdvanced.exe
goto utilities_menu

:utility_startup_folder
start "" explorer.exe shell:startup
goto utilities_menu

:utility_restart_explorer
cls
echo Tac vu nay se dong va mo lai thanh Taskbar/Desktop trong vai giay.
choice /C YN /N /M "Khoi dong lai Windows Explorer? [Y/N]: "
if errorlevel 2 goto utilities_menu
taskkill.exe /F /IM explorer.exe
start "" explorer.exe
goto utilities_menu

:utility_clipboard
start "" ms-settings:clipboard
goto utilities_menu

rem ----------------------------------------------------------------
rem NHOM 9 - TAO BAO CAO TONG HOP
rem ----------------------------------------------------------------
:create_report
cls
echo ===========================================================================================
echo  TAO BAO CAO CHAN DOAN TONG HOP
echo ===========================================================================================
echo Bao cao se duoc luu vao mot thu muc moi tren Desktop.
echo Qua trinh co the mat 5-20 phut vi co SFC VerifyOnly va DISM CheckHealth.
echo Bao cao chi thu thap thong tin, khong tu dong sua he thong.
echo.
choice /C YN /N /M "Bat dau tao bao cao? [Y/N]: "
if errorlevel 2 goto main

for /f %%I in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
set "REPORT_DIR=%DESKTOP%\Windows_Diagnostics_%STAMP%"
md "%REPORT_DIR%" >nul 2>&1

echo [01/17] Dang thu thap thong tin he thong...
systeminfo.exe > "%REPORT_DIR%\01_SystemInfo.txt" 2>&1
echo [02/17] Dang thu thap ComputerInfo...
powershell.exe -NoProfile -Command "Get-ComputerInfo | Format-List *" > "%REPORT_DIR%\02_ComputerInfo.txt" 2>&1
echo [03/17] Dang thu thap cau hinh mang...
ipconfig.exe /all > "%REPORT_DIR%\03_Network_IPConfig.txt" 2>&1
route.exe print > "%REPORT_DIR%\04_Network_Routes.txt" 2>&1
netstat.exe -ano > "%REPORT_DIR%\05_Network_Connections.txt" 2>&1
echo [06/17] Dang thu thap driver...
driverquery.exe /v /fo csv > "%REPORT_DIR%\06_Drivers.csv" 2>&1
pnputil.exe /enum-drivers > "%REPORT_DIR%\07_DriverStore.txt" 2>&1
echo [08/17] Dang thu thap services va startup...
sc.exe query type= service state= all > "%REPORT_DIR%\08_Services.txt" 2>&1
powershell.exe -NoProfile -Command "Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User | Format-List" > "%REPORT_DIR%\09_StartupPrograms.txt" 2>&1
echo [10/17] Dang thu thap thong tin o dia...
powershell.exe -NoProfile -Command "Get-PhysicalDisk | Format-List *; Get-Disk | Format-List *; Get-Volume | Format-Table -AutoSize" > "%REPORT_DIR%\10_Disks.txt" 2>&1
echo [11/17] Dang thu thap Windows Recovery va BCD...
reagentc.exe /info > "%REPORT_DIR%\11_WindowsRE.txt" 2>&1
bcdedit.exe /enum all /v > "%REPORT_DIR%\12_BCD.txt" 2>&1
echo [13/17] Dang thu thap loi System va Application gan nhat...
wevtutil.exe qe System /q:"*[System[(Level=1 or Level=2)]]" /c:100 /rd:true /f:text > "%REPORT_DIR%\13_System_Errors.txt" 2>&1
wevtutil.exe qe Application /q:"*[System[(Level=1 or Level=2)]]" /c:100 /rd:true /f:text > "%REPORT_DIR%\14_Application_Errors.txt" 2>&1
echo [15/17] Dang kiem tra DISM CheckHealth...
DISM.exe /Online /Cleanup-Image /CheckHealth > "%REPORT_DIR%\15_DISM_CheckHealth.txt" 2>&1
echo [16/17] Dang chay SFC VerifyOnly. Vui long cho...
sfc.exe /verifyonly > "%REPORT_DIR%\16_SFC_VerifyOnly.txt" 2>&1
echo [17/18] Dang thu thap trang thai Defender...
powershell.exe -NoProfile -Command "Get-MpComputerStatus | Format-List *" > "%REPORT_DIR%\17_Defender_Status.txt" 2>&1
echo [18/18] Dang thu thap trang thai Firewall...
netsh.exe advfirewall show allprofiles > "%REPORT_DIR%\18_Firewall_Status.txt" 2>&1

echo Tool Windows - Bao cao tao luc %DATE% %TIME% > "%REPORT_DIR%\README.txt"
echo Khong nen chia se bao cao ra ben ngoai khi chua ra soat IP, ten may va ten nguoi dung.>> "%REPORT_DIR%\README.txt"

echo.
echo ================================================================
echo  DA HOAN TAT BAO CAO
echo  Thu muc: %REPORT_DIR%
echo ================================================================
start "" explorer.exe "%REPORT_DIR%"
pause
goto main

:exit_tool
cls
echo Da dong Tool Windows.
endlocal
exit /b 0
