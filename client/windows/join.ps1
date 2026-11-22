<#
.SYNOPSIS
  Ghostline: join this PC to YOUR OWN Ghostline server (Headscale).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\join.ps1 -LoginServer https://mesh.example.org
  powershell -ExecutionPolicy Bypass -File .\join.ps1 -LoginServer https://mesh.example.org -AuthKeyFile C:\private\key.txt

.NOTES
  Ghostline has no server built in, so -LoginServer is required. Without -AuthKeyFile the command prints a
  sign-in link: open it and approve this device on your server (headscale auth register ...). The key file must be
  readable only by SYSTEM, Administrators and you (join.ps1 refuses anything wider); delete it after joining.
  Run install.ps1 first. -NoAcceptDns ignores the DNS settings your server pushes. -ForceReauth signs in again, for
  example to move this PC to another server.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$LoginServer,
  [string]$AuthKeyFile = '',
  [string]$Hostname = '',
  [switch]$NoAcceptDns,
  [switch]$ForceReauth
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_acl.ps1')
if ($AuthKeyFile) { $null = Assert-GlPrivateKeyFile $AuthKeyFile }
. (Join-Path $PSScriptRoot '_brand.ps1')
$brand = Get-Brand
$cli = Join-Path (Join-Path $env:ProgramFiles $brand.ProductName) ($brand.CliName + '.exe')
if (-not (Test-Path -LiteralPath $cli)) { throw 'Ghostline is not installed. Run install.ps1 as Administrator first.' }

$uri = $null
if (-not [Uri]::TryCreate($LoginServer, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or -not $uri.Host -or
    $uri.UserInfo -or $uri.Query -or $uri.Fragment -or ($uri.AbsolutePath -ne '/') -or $uri.Host.EndsWith('.invalid')) {
  throw 'LoginServer must be the https address of your server, like https://mesh.example.org (no path, query or credentials).'
}
$server = $uri.GetLeftPart([UriPartial]::Authority)
$cliArgs = @('up', "--login-server=$server", ('--accept-dns=' + $(if ($NoAcceptDns) { 'false' } else { 'true' })))
if ($AuthKeyFile) { $cliArgs += "--auth-key=file:$AuthKeyFile" }
if ($Hostname) { $cliArgs += "--hostname=$Hostname" }
if ($ForceReauth) { $cliArgs += '--force-reauth' }
Write-Host ("$cli " + (($cliArgs -join ' ') -replace '--auth-key=file:\S+', '--auth-key=file:***'))
& $cli @cliArgs
if ($LASTEXITCODE -ne 0) { throw "$($brand.CliName) up failed with exit code $LASTEXITCODE" }
& $cli status
