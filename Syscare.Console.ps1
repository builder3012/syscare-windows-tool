#requires -Version 5.1
<#
.SYNOPSIS
    Giao diện điều khiển Modern TUI Tiếng Việt cho Syscare / JoIT Windows Tool.
.DESCRIPTION
    Khởi chạy trực tiếp trên PowerShell Console hỗ trợ UTF-8, ANSI colors và phản hồi tức thì (<10ms).
#>
[CmdletBinding()]
param()

$coreScript = Join-Path $PSScriptRoot 'Syscare.WindowsTool.ps1'
if (-not (Test-Path -LiteralPath $coreScript)) {
    Write-Error "Không tìm thấy tệp mã nguồn cốt lõi: $coreScript"
    exit 1
}

# Tự động xin quyền Administrator nếu chưa có
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Đang yêu cầu nâng quyền Administrator (UAC)..." -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path) -Verb RunAs
        exit 0
    } catch {
        Write-Host "Cần cấp quyền Administrator để chạy công cụ." -ForegroundColor Red
        exit 1
    }
}

& $coreScript -Action 'Console'
