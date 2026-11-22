#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Ghostline: install the mesh service and command on Windows 10/11 (x64).

.DESCRIPTION
  Run from the unzipped download, in PowerShell as Administrator:
    powershell -ExecutionPolicy Bypass -File .\install.ps1
  1. Warns about an installed official Tailscale service: both cannot run at once (-Force skips the question).
  2. Locks %ProgramData%\Ghostline (this PC's mesh keys) to SYSTEM and Administrators, and refuses a folder that
     someone else created or that is a link (see _acl.ps1).
  3. Copies ghostlined.exe, ghostline.exe, wintun.dll and the licence files to C:\Program Files\Ghostline.
  4. Registers and starts the service (ghostlined.exe install-system-daemon) and adds the folder to the PATH.
  Then join your server: powershell -ExecutionPolicy Bypass -File .\join.ps1 -LoginServer https://<your server>
#>
[CmdletBinding()]
param([switch]$Force)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_brand.ps1')
. (Join-Path $PSScriptRoot '_acl.ps1')
$brand = Get-Brand
$svcName = $brand.ServiceName
$installDir = Join-Path $env:ProgramFiles $brand.ProductName
$dataDir = Join-Path $env:ProgramData $brand.DataDirName
$files = @(($svcName + '.exe'), ($brand.CliName + '.exe'), 'wintun.dll', 'brand.json')
foreach ($f in $files) {
  if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $f))) { throw "$f is missing next to install.ps1. Unzip the whole download." }
}
Assert-GlDataDirTree $dataDir

$official = Get-Service -Name 'Tailscale' -ErrorAction SilentlyContinue
if ($official) {
  Write-Warning 'The official Tailscale service is installed. Both cannot run at once.'
  Write-Warning 'Continuing stops and removes it (its data in C:\ProgramData\Tailscale is not deleted).'
  if (-not $Force -and (Read-Host 'Type YES to continue') -ne 'YES') { Write-Host 'Stopped, nothing changed.'; exit 1 }
}
Protect-GlDataDir $dataDir
Write-Host "Restricted $dataDir to SYSTEM and Administrators."
if ($official) {
  Get-Process -Name 'tailscale-ipn' -ErrorAction SilentlyContinue | Stop-Process -Force
  if ($official.Status -ne 'Stopped') { Stop-Service -Name 'Tailscale' -Force; $official.WaitForStatus('Stopped', '00:00:30') }
  $offExe = Join-Path $env:ProgramFiles 'Tailscale\tailscaled.exe'
  if (Test-Path $offExe) { & $offExe uninstall-system-daemon } else { & sc.exe delete Tailscale | Out-Null }
  if ($LASTEXITCODE -ne 0) { throw "Removing the Tailscale service failed (exit $LASTEXITCODE)." }
}
$mine = Get-Service -Name $svcName -ErrorAction SilentlyContinue
if ($mine) {
  Write-Host "Updating the existing $svcName service..."
  if ($mine.Status -ne 'Stopped') { Stop-Service -Name $svcName -Force; $mine.WaitForStatus('Stopped', '00:00:30') }
  $oldExe = Join-Path $installDir ($svcName + '.exe')
  if (Test-Path $oldExe) { & $oldExe uninstall-system-daemon } else { & sc.exe delete $svcName | Out-Null }
  if ($LASTEXITCODE -ne 0) { throw "Removing the old service failed (exit $LASTEXITCODE)." }
}

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
$copy = $files + @(Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object { $_.Name -like 'LICENSE*' -or $_.Name -like 'PATENTS*' -or $_.Name -eq 'THIRD-PARTY-NOTICES.md' } | ForEach-Object { $_.Name })
foreach ($f in ($copy | Select-Object -Unique)) {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $f) -Destination (Join-Path $installDir $f) -Force
}
$lic = Join-Path $PSScriptRoot 'licenses'
if (Test-Path -LiteralPath $lic) { Copy-Item -LiteralPath $lic -Destination $installDir -Recurse -Force }
Get-ChildItem -LiteralPath $installDir -Recurse -File | Unblock-File
Write-Host "Copied the files to $installDir"

$exe = Join-Path $installDir ($svcName + '.exe')
& $exe install-system-daemon
if ($LASTEXITCODE -ne 0) { throw 'install-system-daemon failed' }
$envFile = Join-Path $dataDir 'tailscaled-env.txt'
if (-not (Test-Path $envFile) -or -not (Select-String -Path $envFile -Pattern '^TS_NO_LOGS_NO_SUPPORT=' -Quiet)) {
  Add-Content -Path $envFile -Value 'TS_NO_LOGS_NO_SUPPORT=true'
  Set-GlAdministratorsOwner $envFile
}
Assert-GlDataDirTree $dataDir
Assert-GlProtectedAcl $dataDir
Start-Service -Name $svcName
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if (($machinePath -split ';') -notcontains $installDir) {
  [Environment]::SetEnvironmentVariable('Path', ($machinePath.TrimEnd(';') + ';' + $installDir), 'Machine')
  Write-Host "Added $installDir to the PATH (open a new terminal to use the ghostline command)."
}
Write-Host "`nInstalled. The $svcName service is $((Get-Service $svcName).Status)." -ForegroundColor Green
Write-Host 'Next: powershell -ExecutionPolicy Bypass -File .\join.ps1 -LoginServer https://<your server>'
