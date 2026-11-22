# Shared helpers of install.ps1, uninstall.ps1 and join.ps1: lock the Ghostline data folder to SYSTEM
# and Administrators, verify the whole tree (no links, no other accounts), delete it without following
# links, and check that an enrollment-key file can be read only by the right accounts. Dot-source it.

$script:GlSidSystem = 'S-1-5-18'
$script:GlSidAdministrators = 'S-1-5-32-544'
$script:GlSidTrustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
# Protected: SYSTEM and Administrators full control, inherited by every subfolder and file.
$script:GlProtectedDirSddl = 'D:PAI(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)'
$script:GlProtectedOwnedDirSddl = 'O:BA' + $script:GlProtectedDirSddl
# Children: no explicit entries, unprotected, so only the parent's inheritable entries apply.
$script:GlInheritOnlySddl = 'D:AI'

function Get-GlCurrentUserSid {
  $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  try { if ($id.User) { return $id.User.Value } else { return $null } } finally { $id.Dispose() }
}

function Get-GlTrustedOwnerSids {
  return @($script:GlSidSystem, $script:GlSidAdministrators, $script:GlSidTrustedInstaller)
}

function Test-GlReparsePoint([System.IO.FileSystemInfo]$Item) {
  return [bool]($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}

function Get-GlItemNoFollow([string]$Path) {
  # Returns the FileSystemInfo for the path itself (a link is returned as the link), or $null.
  # FileInfo/DirectoryInfo.Exists read the attributes of the link, not of its target.
  $file = New-Object System.IO.FileInfo($Path)
  if ($file.Exists) { return $file }
  $dir = New-Object System.IO.DirectoryInfo($Path)
  if ($dir.Exists) { return $dir }
  # .NET Framework throws for a missing path; .NET reports attributes -1.
  try { $attributes = [int]$dir.Attributes } catch { return $null }
  if ($attributes -ne -1) { return $dir }
  return $null
}

function Get-GlTreeNoFollow([string]$Root) {
  # Every file and directory below $Root, children before the walk descends; never enters reparse points.
  $items = New-Object System.Collections.ArrayList
  $stack = New-Object System.Collections.Stack
  $stack.Push((New-Object System.IO.DirectoryInfo($Root)))
  while ($stack.Count -gt 0) {
    $dir = $stack.Pop()
    foreach ($child in $dir.GetFileSystemInfos()) {
      [void]$items.Add($child)
      if (($child -is [System.IO.DirectoryInfo]) -and -not (Test-GlReparsePoint $child)) { $stack.Push($child) }
    }
  }
  return ,$items
}

function Get-GlOwnerSid([string]$Path) {
  try {
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
  } catch {
    throw "Cannot read the owner of $Path ($($_.Exception.Message)). Inspect it as an administrator before retrying."
  }
  $owner = $acl.GetOwner([System.Security.Principal.SecurityIdentifier])
  if (-not $owner) { return $null }
  return $owner.Value
}

function Test-GlRuleAppliesToObject($Rule) {
  return -not ([int]$Rule.PropagationFlags -band [int][System.Security.AccessControl.PropagationFlags]::InheritOnly)
}

function Get-GlForeignAllowRules($Acl, [string[]]$AllowedSids) {
  # Allow entries for anybody outside $AllowedSids that apply to the object itself.
  $foreign = @()
  foreach ($rule in $Acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
    if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) { continue }
    if (-not (Test-GlRuleAppliesToObject $rule)) { continue }
    if ($AllowedSids -notcontains $rule.IdentityReference.Value) { $foreign += $rule }
  }
  return ,$foreign
}

function Test-GlFullControl($Acl, [string]$Sid) {
  $full = [int][System.Security.AccessControl.FileSystemRights]::FullControl
  foreach ($rule in $Acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
    if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and
        $rule.IdentityReference.Value -eq $Sid -and (Test-GlRuleAppliesToObject $rule) -and
        ((([int]$rule.FileSystemRights -band $full) -eq $full) -or ([int]$rule.FileSystemRights -band 0x10000000))) { return $true }   # or GENERIC_ALL
  }
  return $false
}

function Assert-GlDataDirTree([string]$Root, [switch]$AllowLinks) {
  $item = Get-GlItemNoFollow $Root
  if (-not $item) { return }
  if (Test-GlReparsePoint $item) { throw "$Root is a junction or symbolic link. Remove the link (not its target) and check how it got there before installing." }
  if (-not ($item -is [System.IO.DirectoryInfo])) { throw "$Root exists but is not a directory." }
  $trusted = Get-GlTrustedOwnerSids
  $problems = @()
  $owner = Get-GlOwnerSid $Root
  if ($trusted -notcontains $owner) { $problems += "$Root (owner $owner)" }
  foreach ($child in (Get-GlTreeNoFollow $Root)) {
    if (Test-GlReparsePoint $child) {
      if (-not $AllowLinks) { $problems += "$($child.FullName) (junction or symbolic link)" }
      continue
    }
    $childOwner = Get-GlOwnerSid $child.FullName
    if ($trusted -notcontains $childOwner) { $problems += "$($child.FullName) (owner $childOwner)" }
  }
  if ($problems.Count -gt 0) {
    throw ("Refusing to use $Root because a non-administrator, or an unelevated process, may have planted content in it " +
      "(owner not SYSTEM, Administrators or TrustedInstaller, or a link):`n  " + ($problems -join "`n  ") +
      "`nInspect these items. If they are yours, take ownership as an administrator (icacls `"$Root`" /setowner *S-1-5-32-544 /T /C /L) " +
      "and remove any links, then run this again. Nothing was changed by this check.")
  }
}

function Set-GlSddlAcl([System.IO.FileSystemInfo]$Item, [string]$Sddl) {
  if ($Item -is [System.IO.DirectoryInfo]) { $sec = New-Object System.Security.AccessControl.DirectorySecurity }
  else { $sec = New-Object System.Security.AccessControl.FileSecurity }
  $sec.SetSecurityDescriptorSddlForm($Sddl, [System.Security.AccessControl.AccessControlSections]::Access)
  Set-Acl -LiteralPath $Item.FullName -AclObject $sec -ErrorAction Stop
}

function Set-GlFileOwner([System.IO.FileInfo]$File, [string]$Sid) {
  $sections = [System.Security.AccessControl.AccessControlSections]::Owner
  if ($PSVersionTable.PSEdition -eq 'Core') { $sec = [System.IO.FileSystemAclExtensions]::GetAccessControl($File, $sections) }
  else { $sec = $File.GetAccessControl($sections) }
  $sec.SetOwner((New-Object System.Security.Principal.SecurityIdentifier($Sid)))
  if ($PSVersionTable.PSEdition -eq 'Core') { [System.IO.FileSystemAclExtensions]::SetAccessControl($File, $sec) }
  else { $File.SetAccessControl($sec) }
}

function Set-GlAdministratorsOwner([string]$Path) {
  $item = Get-GlItemNoFollow $Path
  if (-not $item -or (Test-GlReparsePoint $item)) { throw "$Path is missing or is a link; not changing its owner." }
  if (-not ($item -is [System.IO.FileInfo])) { throw "$Path is not a file; not changing its owner." }
  Set-GlFileOwner $item $script:GlSidAdministrators
}

function New-GlProtectedDir([string]$Path) {
  $sec = New-Object System.Security.AccessControl.DirectorySecurity
  $sec.SetSecurityDescriptorSddlForm($script:GlProtectedOwnedDirSddl)
  if ($PSVersionTable.PSEdition -eq 'Core') { $null = [System.IO.FileSystemAclExtensions]::CreateDirectory($sec, $Path) }
  else { $null = [System.IO.Directory]::CreateDirectory($Path, $sec) }
}

function Assert-GlProtectedAcl([string]$Root) {
  # Verifies the result rather than trusting Set-Acl: protected root, only SYSTEM/Administrators anywhere.
  $allowed = @($script:GlSidSystem, $script:GlSidAdministrators)
  $acl = Get-Acl -LiteralPath $Root -ErrorAction Stop
  if (-not $acl.AreAccessRulesProtected) { throw "$Root still inherits permissions from its parent." }
  if (-not (Test-GlFullControl $acl $script:GlSidSystem) -or -not (Test-GlFullControl $acl $script:GlSidAdministrators)) {
    throw "$Root does not grant SYSTEM and Administrators full control."
  }
  $bad = @()
  if ((Get-GlForeignAllowRules $acl $allowed).Count -gt 0) { $bad += $Root }
  foreach ($child in (Get-GlTreeNoFollow $Root)) {
    if (Test-GlReparsePoint $child) { $bad += "$($child.FullName) (link)"; continue }
    $childAcl = Get-Acl -LiteralPath $child.FullName -ErrorAction Stop
    # A NULL DACL shows up as an Everyone entry here; an empty one fails the SYSTEM check.
    if ((Get-GlForeignAllowRules $childAcl $allowed).Count -gt 0) { $bad += $child.FullName }
    elseif (-not (Test-GlFullControl $childAcl $script:GlSidSystem)) { $bad += "$($child.FullName) (SYSTEM has no full control)" }
  }
  if ($bad.Count -gt 0) { throw ("Permissions are still too open on:`n  " + ($bad -join "`n  ")) }
}

function Protect-GlDataDir([string]$Root) {
  # Creates $Root if needed, then locks it to SYSTEM + Administrators and verifies the whole tree.
  # Throws (before any ACL change) if the tree fails Assert-GlDataDirTree.
  Assert-GlDataDirTree $Root
  if (-not (Get-GlItemNoFollow $Root)) { New-GlProtectedDir $Root }
  # Re-check: another account may have created it between the check and New-GlProtectedDir.
  Assert-GlDataDirTree $Root
  $rootItem = New-Object System.IO.DirectoryInfo($Root)
  # From here on only SYSTEM and Administrators can add or replace entries in the directory.
  Set-GlSddlAcl $rootItem $script:GlProtectedDirSddl
  # Anything created between the first walk and the new DACL is caught here.
  Assert-GlDataDirTree $Root
  $allowed = @($script:GlSidSystem, $script:GlSidAdministrators)
  foreach ($child in (Get-GlTreeNoFollow $Root)) {
    $acl = Get-Acl -LiteralPath $child.FullName -ErrorAction Stop
    if ($acl.AreAccessRulesProtected -or (Get-GlForeignAllowRules $acl $allowed).Count -gt 0) {
      Set-GlSddlAcl $child $script:GlInheritOnlySddl
    }
  }
  Assert-GlProtectedAcl $Root
}

function Remove-GlDataDir([string]$Root) {
  # Deletes $Root without following links. A link inside is removed as a link; its target is untouched.
  $item = Get-GlItemNoFollow $Root
  if (-not $item) { return $false }
  if (Test-GlReparsePoint $item) {
    # Removes the junction/symlink itself, never its target.
    if ($item -is [System.IO.DirectoryInfo]) { [System.IO.Directory]::Delete($Root, $false) } else { [System.IO.File]::Delete($Root) }
    return $true
  }
  if (-not ($item -is [System.IO.DirectoryInfo])) { throw "$Root is not a directory; not deleting it." }
  Assert-GlDataDirTree $Root -AllowLinks
  Set-GlSddlAcl $item $script:GlProtectedDirSddl
  Assert-GlDataDirTree $Root -AllowLinks
  # Deepest first: a child's full path is always longer than its parent's.
  $tree = Get-GlTreeNoFollow $Root
  $items = @($tree | Sort-Object -Property @{ Expression = { $_.FullName.Length } } -Descending)
  foreach ($child in $items) {
    if ($child -is [System.IO.DirectoryInfo]) {
      [System.IO.Directory]::Delete($child.FullName, $false)   # empty dir, or the link itself
    } else {
      if (-not (Test-GlReparsePoint $child) -and ($child.Attributes -band [System.IO.FileAttributes]::ReadOnly)) {
        $child.Attributes = $child.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
      }
      [System.IO.File]::Delete($child.FullName)   # a file symlink is deleted as the link
    }
  }
  [System.IO.Directory]::Delete($Root, $false)
  return $true
}

function Assert-GlPrivateKeyFile([string]$Path) {
  # The enrollment-key file and the folder holding it must only be readable and changeable by SYSTEM,
  # Administrators and the account running the join (like client/linux/join.sh's root-owned 0600 rule).
  # FileInfo resolves relative paths against the process directory, not the PowerShell location.
  $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
  $item = Get-GlItemNoFollow $Path
  if (-not $item) { throw "Auth key file not found: $Path" }
  if (($item -is [System.IO.DirectoryInfo]) -or (Test-GlReparsePoint $item)) { throw 'Auth key file must be a regular file, not a directory or reparse point.' }
  $me = Get-GlCurrentUserSid
  $allowed = @($script:GlSidSystem, $script:GlSidAdministrators)
  if ($me) { $allowed += $me }
  $fix = "Keep the key in a private folder that only administrators can open, for example:`n" +
         "  New-Item -ItemType Directory C:\private; icacls C:\private /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F'`n" +
         "then save the key there, and delete it after joining."
  $owner = Get-GlOwnerSid $item.FullName
  if ($allowed -notcontains $owner) { throw "Auth key file $($item.FullName) is owned by $owner, not by SYSTEM, Administrators or you. $fix" }
  $foreign = Get-GlForeignAllowRules (Get-Acl -LiteralPath $item.FullName -ErrorAction Stop) $allowed
  if ($foreign.Count -gt 0) {
    $who = ($foreign | ForEach-Object { $_.IdentityReference.Value } | Select-Object -Unique) -join ', '
    throw "Auth key file $($item.FullName) is readable or changeable by other accounts ($who). $fix"
  }
  # Whoever can delete, rename or re-permission the folder (or a folder above it) can swap the key
  # between this check and the CLI reading it.
  $swap = [int]([System.Security.AccessControl.FileSystemRights]::Delete -bor
                [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
                [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
                [System.Security.AccessControl.FileSystemRights]::TakeOwnership) -bor 0x10000000 -bor 0x40000000  # GENERIC_ALL, GENERIC_WRITE
  $dir = $item.Directory
  while ($dir) {
    if (Test-GlReparsePoint $dir) { throw "The folder $($dir.FullName) holding the auth key is a junction or symbolic link. $fix" }
    foreach ($rule in (Get-GlForeignAllowRules (Get-Acl -LiteralPath $dir.FullName -ErrorAction Stop) $allowed)) {
      if ([int]$rule.FileSystemRights -band $swap) {
        throw "Folder $($dir.FullName) lets $($rule.IdentityReference.Value) delete, rename or re-permission its contents, so the auth key could be swapped. $fix"
      }
    }
    $dir = $dir.Parent
  }
  return $item
}
