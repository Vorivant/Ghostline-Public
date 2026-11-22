# Dot-sourced by install.ps1, uninstall.ps1 and join.ps1: reads brand.json next to the scripts (the unzipped download).
function Get-Brand {
  $c = Join-Path $PSScriptRoot 'brand.json'
  if (-not (Test-Path -LiteralPath $c)) { throw "brand.json not found next to the scripts ($c). Unzip the whole download." }
  $b = Get-Content -Raw -LiteralPath $c | ConvertFrom-Json
  foreach ($k in 'ProductName', 'DataDirName', 'ServiceName', 'CliName') {
    $prop = $b.PSObject.Properties[$k]
    $value = if ($prop) { [string]$prop.Value } else { '' }
    # uninstall.ps1 deletes folders named after these values: an empty or odd value must never reach it.
    if ($value -notmatch '^[A-Za-z][A-Za-z0-9_-]{0,63}$' -or $value -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
      throw "brand.json has an unsafe value for $k"
    }
  }
  foreach ($k in 'ServiceName', 'CliName') {
    if ([string]$b.PSObject.Properties[$k].Value -notmatch '^[A-Za-z][A-Za-z0-9]*$') { throw "brand.json $k must be letters and digits" }
  }
  return $b
}
