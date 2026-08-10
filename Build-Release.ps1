#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$batPath = Join-Path $projectRoot 'Tool_Windows.bat'
$corePath = Join-Path $projectRoot 'Syscare.WindowsTool.ps1'
$launcherPath = Join-Path $projectRoot 'Invoke-JoITWindowsTool.ps1'
$indexPath = Join-Path $projectRoot 'index.html'
$checksumPath = Join-Path $projectRoot 'checksums.sha256'
$manifestPath = Join-Path $projectRoot 'release-manifest.json'

foreach ($required in @($batPath, $corePath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing required source file: $required"
    }
}

$versionMatch = Select-String -LiteralPath $batPath -Pattern '^set "TOOL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)"$' | Select-Object -First 1
if (-not $versionMatch) { throw 'TOOL_VERSION was not found in Tool_Windows.bat.' }
$toolVersion = $versionMatch.Matches[0].Groups[1].Value

function ConvertTo-GzipBase64 {
    param([Parameter(Mandatory = $true)][byte[]] $Bytes)
    $output = New-Object IO.MemoryStream
    $gzip = New-Object IO.Compression.GZipStream($output, [IO.Compression.CompressionMode]::Compress, $true)
    try { $gzip.Write($Bytes, 0, $Bytes.Length) }
    finally { $gzip.Dispose() }
    try { return [Convert]::ToBase64String($output.ToArray()) }
    finally { $output.Dispose() }
}

$batBytes = [IO.File]::ReadAllBytes($batPath)
$coreBytes = [IO.File]::ReadAllBytes($corePath)
$batHash = (Get-FileHash -LiteralPath $batPath -Algorithm SHA256).Hash.ToUpperInvariant()
$coreHash = (Get-FileHash -LiteralPath $corePath -Algorithm SHA256).Hash.ToUpperInvariant()
$batPayload = ConvertTo-GzipBase64 -Bytes $batBytes
$corePayload = ConvertTo-GzipBase64 -Bytes $coreBytes
$generatedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$launcherTemplate = @'
#requires -Version 5.1
<#
.SYNOPSIS
    Secure self-contained launcher for Syscare Windows Tool.
.DESCRIPTION
    Extracts the signed-release BAT and PowerShell diagnostics module, verifies
    SHA-256 for both payloads, requests Administrator rights and starts the menu.
    Official URL: https://win.syscare.site
    Generated UTC: __GENERATED_UTC__
#>
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$ToolName = 'Syscare Windows Tool'
$ToolVersion = '__TOOL_VERSION__'
$ExpectedBatSha256 = '__BAT_SHA256__'
$ExpectedCoreSha256 = '__CORE_SHA256__'
$EmbeddedBatGzipBase64 = '__BAT_PAYLOAD__'
$EmbeddedCoreGzipBase64 = '__CORE_PAYLOAD__'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Expand-Payload {
    param(
        [Parameter(Mandatory = $true)][string] $Payload,
        [Parameter(Mandatory = $true)][string] $Destination
    )
    $compressedBytes = [Convert]::FromBase64String($Payload)
    $inputStream = New-Object IO.MemoryStream
    $inputStream.Write($compressedBytes, 0, $compressedBytes.Length)
    $inputStream.Position = 0
    $gzipStream = New-Object IO.Compression.GZipStream($inputStream, [IO.Compression.CompressionMode]::Decompress)
    $outputStream = [IO.File]::Create($Destination)
    try { $gzipStream.CopyTo($outputStream) }
    finally {
        $outputStream.Dispose()
        $gzipStream.Dispose()
        $inputStream.Dispose()
    }
}

function Assert-FileHash {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Expected
    )
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actual -ne $Expected) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        throw "SHA-256 verification failed for $([IO.Path]::GetFileName($Path)). Execution was cancelled."
    }
}

if ($env:OS -ne 'Windows_NT') {
    throw "$ToolName supports Windows only."
}

$toolDirectory = Join-Path $env:LOCALAPPDATA ("Syscare\WindowsTool\{0}" -f $ToolVersion)
$batPath = Join-Path $toolDirectory 'Tool_Windows.bat'
$corePath = Join-Path $toolDirectory 'Syscare.WindowsTool.ps1'
[IO.Directory]::CreateDirectory($toolDirectory) | Out-Null

Expand-Payload -Payload $EmbeddedBatGzipBase64 -Destination $batPath
Expand-Payload -Payload $EmbeddedCoreGzipBase64 -Destination $corePath
Assert-FileHash -Path $batPath -Expected $ExpectedBatSha256
Assert-FileHash -Path $corePath -Expected $ExpectedCoreSha256

$argumentList = @('/D', '/C', ('"{0}"' -f $batPath))
if (Test-IsAdministrator) {
    $process = Start-Process -FilePath $env:ComSpec -ArgumentList $argumentList -Wait -PassThru
}
else {
    Write-Host "Requesting Administrator rights for $ToolName v$ToolVersion..." -ForegroundColor Cyan
    try {
        $process = Start-Process -FilePath $env:ComSpec -ArgumentList $argumentList -Verb RunAs -Wait -PassThru
    }
    catch {
        throw 'Unable to start the tool: UAC was declined or the account has no Administrator permission.'
    }
}

if ($null -ne $process -and $process.ExitCode -notin @(0, 1)) {
    Write-Warning "$ToolName ended with exit code $($process.ExitCode)."
}
'@

$launcher = $launcherTemplate.Replace('__GENERATED_UTC__', $generatedUtc).
    Replace('__TOOL_VERSION__', $toolVersion).
    Replace('__BAT_SHA256__', $batHash).
    Replace('__CORE_SHA256__', $coreHash).
    Replace('__BAT_PAYLOAD__', $batPayload).
    Replace('__CORE_PAYLOAD__', $corePayload)

$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($launcherPath, $launcher, $utf8NoBom)
[IO.File]::WriteAllText($indexPath, $launcher, $utf8NoBom)

$releaseFiles = @(
    '.nojekyll',
    'AUDIT_REPORT.md',
    'Build-Release.mjs',
    'Build-Release.ps1',
    'CHANGELOG.md',
    'CNAME',
    'Invoke-JoITWindowsTool.ps1',
    'README.md',
    'Syscare.WindowsTool.ps1',
    'TEST_REPORT.md',
    'Tool_Windows.bat',
    'index.html'
)
$hashRows = foreach ($relative in $releaseFiles) {
    $path = Join-Path $projectRoot $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        [pscustomobject]@{
            File = $relative
            SHA256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant()
            Bytes = (Get-Item -LiteralPath $path).Length
        }
    }
}
$checksumLines = $hashRows | ForEach-Object { '{0}  {1}' -f $_.SHA256, $_.File }
[IO.File]::WriteAllLines($checksumPath, [string[]]$checksumLines, $utf8NoBom)

$manifest = [ordered]@{
    name = 'Syscare Windows Tool'
    version = $toolVersion
    generatedUtc = $generatedUtc
    officialUrl = 'https://win.syscare.site'
    minimumPowerShell = '5.1'
    launcherPayloads = @(
        [ordered]@{ file = 'Tool_Windows.bat'; sha256 = $batHash; bytes = $batBytes.Length },
        [ordered]@{ file = 'Syscare.WindowsTool.ps1'; sha256 = $coreHash; bytes = $coreBytes.Length }
    )
    files = @($hashRows)
}
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), $utf8NoBom)

Write-Host "Release v$toolVersion built successfully." -ForegroundColor Green
Write-Host "BAT SHA-256 : $batHash"
Write-Host "Core SHA-256: $coreHash"
Write-Host "Launcher and index are identical: $((Get-FileHash $launcherPath).Hash -eq (Get-FileHash $indexPath).Hash)"
