#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Ghostline: remove the service, C:\Program Files\Ghostline and the PATH entry.
  -PurgeData also deletes this PC's mesh identity (C:\ProgramData\Ghostline), so it joins as a new device next
  time; it never follows links inside that folder and refuses content that an ordinary account owns (_acl.ps1).
  Remove the device on your server too: headscale nodes list ; headscale nodes delete -i <ID>
#>
[CmdletBinding()]
param([switch]$PurgeData)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_brand.ps1')
. (Join-Path $PSScriptRoot '_acl.ps1')
$brand = Get-Brand
$svcName = $brand.ServiceName
$installDir = Join-Path $env:ProgramFiles $brand.ProductName
$dataDir = Join-Path $env:ProgramData $brand.DataDirName
$exe = Join-Path $installDir ($svcName + '.exe')
if ($PurgeData) {
  $existing = Get-GlItemNoFollow $dataDir
  if ($existing -and -not (Test-GlReparsePoint $existing)) { Assert-GlDataDirTree $dataDir -AllowLinks }
}
$svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
if ($svc) {
  if ($svc.Status -ne 'Stopped') { Stop-Service -Name $svcName -Force; $svc.WaitForStatus('Stopped', '00:00:30') }
  if (Test-Path $exe) { & $exe uninstall-system-daemon } else { & sc.exe delete $svcName | Out-Null }
  if ($LASTEXITCODE -ne 0) { throw "Removing the service failed (exit $LASTEXITCODE); no files were removed." }
  Write-Host "Removed the $svcName service."
}
if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force; Write-Host "Deleted $installDir" }
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$new = (($machinePath -split ';') | Where-Object { $_ -and $_ -ne $installDir }) -join ';'
if ($new -ne $machinePath) { [Environment]::SetEnvironmentVariable('Path', $new, 'Machine'); Write-Host 'Removed the PATH entry.' }
if ($PurgeData) {
  if (Remove-GlDataDir $dataDir) { Write-Host "Deleted $dataDir" }
} else {
  Write-Host "Kept this PC's mesh identity in $dataDir (use -PurgeData to delete it)."
}
