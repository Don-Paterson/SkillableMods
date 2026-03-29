<#
.SYNOPSIS
    Patches changes.ps1 and changes.cmd so that:
        changes.cmd uk
    runs non-interactively with UK/London/GMT presets.

.DESCRIPTION
    v5 — anchor strings matched against the live Skillable script as of 2026-03-29.
    The patcher fails loudly rather than silently patching the wrong location.

.PARAMETER Path
    Folder containing changes.ps1 and changes.cmd.
    Defaults to the directory this script lives in.

.PARAMETER CreateLauncher
    Also creates run-uk.cmd (double-click shortcut for changes.cmd uk).

.EXAMPLE
    .\change-lab-uk-v5.ps1
    .\change-lab-uk-v5.ps1 -Path "C:\scripts" -CreateLauncher
#>

[CmdletBinding()]
param(
    [string]$Path = $PSScriptRoot,
    [switch]$CreateLauncher
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step  { param($msg) Write-Host "  [*] $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "  [+] $msg" -ForegroundColor Green }
function Write-Fail  { param($msg) Write-Host "  [!] $msg" -ForegroundColor Red ; exit 1 }

function Backup-File {
    param([string]$FilePath)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dest  = "$FilePath.bak-$stamp"
    Copy-Item -LiteralPath $FilePath -Destination $dest
    Write-OK "Backed up to $(Split-Path $dest -Leaf)"
}

function Assert-Contains {
    param([string]$Content, [string]$Anchor, [string]$Label)
    if ($Content -notlike "*$Anchor*") {
        Write-Fail "Could not find anchor for '$Label'. The Skillable script may have changed — check for a newer patcher."
    }
}

function Check-AlreadyPatched {
    param([string]$Content)
    if ($Content -like '*SkillableMods-v5*') {
        Write-Host ""
        Write-Host "  [i] changes.ps1 is already patched by v5. Nothing to do." -ForegroundColor Yellow
        exit 0
    }
}

# ---------------------------------------------------------------------------
# Locate files
# ---------------------------------------------------------------------------
$ps1Path  = Join-Path $Path 'changes.ps1'
$cmdPath  = Join-Path $Path 'changes.cmd'

Write-Host ""
Write-Host "  SkillableMods change-lab-uk-v5 patcher" -ForegroundColor White
Write-Host "  ---------------------------------------"
Write-Host ""

foreach ($f in $ps1Path, $cmdPath) {
    if (-not (Test-Path $f)) { Write-Fail "File not found: $f" }
}

# ---------------------------------------------------------------------------
# Read originals
# ---------------------------------------------------------------------------
# Use UTF-8 without BOM throughout; preserve CRLF from source
$ps1 = [System.IO.File]::ReadAllText($ps1Path, [System.Text.Encoding]::UTF8)
$cmd = [System.IO.File]::ReadAllText($cmdPath, [System.Text.Encoding]::UTF8)

Check-AlreadyPatched $ps1

# ---------------------------------------------------------------------------
# Verify anchors before touching anything
# ---------------------------------------------------------------------------
Write-Step "Verifying anchors in changes.ps1 ..."

# Anchor 1: where we inject the preset block (after $args[0] assignment)
$anchor_args   = '$ComputerName = $args[0]'

# Anchor 2: keyboard Out-GridView line (to wrap with if)
$anchor_kbd    = "`$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the keyboard layout for all VMs make a selection'"

# Anchor 3: timezone Out-GridView line
$anchor_tz     = "`$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the time zone for all Windows-VMs make a selection'"

# Anchor 4: GAIA region Out-GridView line (inside the RDP-HOST block)
$anchor_region = "`$Result = `$Menu | Out-GridView -PassThru  -Title 'Please select a region in order to change the timezone on all GAIA-VMs'"

# The three null-exit guards that must be bypassed by the preset
$anchor_null_kbd  = 'if($WindowsLanguageTag -eq $NULL){'
$anchor_null_gaia = 'if($GAIALanguageTag-eq $NULL){'
$anchor_null_tz   = 'if($WindowsTimezone -eq $NULL){'

Assert-Contains $ps1 $anchor_args   '$ComputerName = $args[0]'
Assert-Contains $ps1 $anchor_kbd    'keyboard Out-GridView'
Assert-Contains $ps1 $anchor_tz     'timezone Out-GridView'
Assert-Contains $ps1 $anchor_region 'GAIA region Out-GridView'
Assert-Contains $ps1 $anchor_null_kbd  'WindowsLanguageTag null check'
Assert-Contains $ps1 $anchor_null_gaia 'GAIALanguageTag null check'
Assert-Contains $ps1 $anchor_null_tz   'WindowsTimezone null check'

Write-OK "All anchors found."

# ---------------------------------------------------------------------------
# Verify changes.cmd anchors
# ---------------------------------------------------------------------------
Write-Step "Verifying anchors in changes.cmd ..."

# Both invocation lines pass only %COMPUTERNAME% — we need to add %1
$anchor_cmd_remote = "PowerShell.exe -Command `"& '%~dpn0.ps1'`"  '%COMPUTERNAME%'"

$cmdCount = ([regex]::Matches($cmd, [regex]::Escape($anchor_cmd_remote))).Count
if ($cmdCount -lt 2) {
    Write-Fail "Expected 2 PowerShell invocation lines in changes.cmd, found $cmdCount. Script may have changed."
}
Write-OK "changes.cmd anchors found ($cmdCount invocation lines)."

# ---------------------------------------------------------------------------
# Back up both files
# ---------------------------------------------------------------------------
Write-Step "Creating backups ..."
Backup-File $ps1Path
Backup-File $cmdPath

# ---------------------------------------------------------------------------
# Patch changes.ps1
# ---------------------------------------------------------------------------
Write-Step "Patching changes.ps1 ..."

# ---- 1. Inject preset block after '$ComputerName = $args[0]' ----
$presetBlock = @'

# --- SkillableMods-v5 preset block (begin) ---
$Preset = if ($args[1]) { $args[1].ToString().ToLower() } else { '' }
switch ($Preset) {
    'uk' {
        $WindowsLanguageTag = 'en-GB'
        $GAIALanguageTag    = 'uk'
        $WindowsTimezone    = 'GMT Standard Time'
        $GAIAregion         = 'Europe'
        $GAIAzone           = 'London'
        Write-Host ""
        Write-Host "      [SkillableMods] UK preset active — skipping interactive menus." -ForegroundColor Green
        Write-Host ""
    }
    default {
        $Preset = ''   # treat anything unrecognised as interactive
    }
}
# --- SkillableMods-v5 preset block (end) ---
'@

$ps1 = $ps1.Replace($anchor_args, $anchor_args + $presetBlock)

# ---- 2. Wrap keyboard Out-GridView block in if ($Preset -eq '') ----
#    The block starts just before $Result = $Menu | Out-GridView (keyboard)
#    and ends at the closing '} ' of the Switch block (line 95 in original).
#    We locate the Switch's closing brace by finding the pattern after the Switch.

# The keyboard section: from the Out-GridView line through the Switch closing brace
# Pattern: Out-GridView line ... Switch ($Result) { ... }  (then the null checks)
# We'll replace the Out-GridView call line itself with a guarded version.

$kbdOGV     = "`$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the keyboard layout for all VMs make a selection'"
$kbdOGV_new = "  if (`$Preset -eq '') {`r`n  `$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the keyboard layout for all VMs make a selection'"

$ps1 = $ps1.Replace($kbdOGV, $kbdOGV_new)

# The Switch block closing brace for the keyboard section is '} ' on its own line
# followed by the null checks. We replace the null-check opener to also close the if.
# Original:
#     }
#     if($WindowsLanguageTag -eq $NULL){
# New (adds closing brace for the if ($Preset -eq '') wrapper):
$kbdNullOld = "} `r`n`r`n`r`n`r`nif(`$WindowsLanguageTag -eq `$NULL){"
$kbdNullNew = "} `r`n  }`r`n`r`n`r`n`r`nif(`$WindowsLanguageTag -eq `$NULL){"
if ($ps1 -like "*$kbdNullOld*") {
    $ps1 = $ps1.Replace($kbdNullOld, $kbdNullNew)
} else {
    # Fallback: simpler single-newline variant
    $kbdNullOld2 = "}`r`n`r`nif(`$WindowsLanguageTag -eq `$NULL){"
    $kbdNullNew2 = "}`r`n  }`r`n`r`nif(`$WindowsLanguageTag -eq `$NULL){"
    if ($ps1 -like "*$kbdNullOld2*") {
        $ps1 = $ps1.Replace($kbdNullOld2, $kbdNullNew2)
    } else {
        Write-Fail "Could not locate keyboard Switch closing brace for if-wrapper."
    }
}

# ---- 3. Wrap timezone Out-GridView block similarly ----
$tzOGV     = "`$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the time zone for all Windows-VMs make a selection'"
$tzOGV_new = "  if (`$Preset -eq '') {`r`n  `$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the time zone for all Windows-VMs make a selection'"

$ps1 = $ps1.Replace($tzOGV, $tzOGV_new)

# Close that if before the WindowsTimezone null check
$tzNullOld = "if(`$WindowsTimezone -eq `$NULL){"
$tzNullNew = "  }`r`n`r`nif(`$WindowsTimezone -eq `$NULL){"
$ps1 = $ps1.Replace($tzNullOld, $tzNullNew)

# ---- 4. Wrap GAIA region Out-GridView block ----
#    It's inside if($ComputerName -eq 'RDP-HOST') so already conditionally gated.
$rgOGV     = "`$Result = `$Menu | Out-GridView -PassThru  -Title 'Please select a region in order to change the timezone on all GAIA-VMs'"
$rgOGV_new = "  if (`$Preset -eq '') {`r`n  `$Result = `$Menu | Out-GridView -PassThru  -Title 'Please select a region in order to change the timezone on all GAIA-VMs'"

$ps1 = $ps1.Replace($rgOGV, $rgOGV_new)

# Close that if before the if($GAIAregion -eq 'Africa') chain
$rgNullOld = "`r`n`r`n`r`nif(`$GAIAregion -eq 'Africa'){"
$rgNullNew = "`r`n  }`r`n`r`n`r`nif(`$GAIAregion -eq 'Africa'){"
if ($ps1 -like "*$rgNullOld*") {
    $ps1 = $ps1.Replace($rgNullOld, $rgNullNew)
} else {
    $rgNullOld2 = "`r`n`r`nif(`$GAIAregion -eq 'Africa'){"
    $rgNullNew2 = "`r`n  }`r`n`r`nif(`$GAIAregion -eq 'Africa'){"
    if ($ps1 -like "*$rgNullOld2*") {
        $ps1 = $ps1.Replace($rgNullOld2, $rgNullNew2)
    } else {
        Write-Fail "Could not locate GAIA region Switch closing for if-wrapper."
    }
}

# ---- 5. Wrap all GAIA zone Out-GridView lines (one per region) ----
#    Each looks like: $Result = $Menu | Out-GridView -PassThru  -Title 'Please select a zone ...'
#    There are many (one per region branch). We guard them all the same way.
$zoneOGV     = "`$Result = `$Menu | Out-GridView -PassThru  -Title 'Please select a zone in order to change the timezone on GAIA-VMs'"
$zoneOGV_new = "  if (`$Preset -eq '') {`r`n  `$Result = `$Menu | Out-GridView -PassThru  -Title 'Please select a zone in order to change the timezone on GAIA-VMs'"

# All zone Out-GridView lines are identical — replace them all
$zoneCount = ([regex]::Matches($ps1, [regex]::Escape($zoneOGV))).Count
if ($zoneCount -eq 0) { Write-Fail "Could not find any GAIA zone Out-GridView lines." }
$ps1 = $ps1.Replace($zoneOGV, $zoneOGV_new)

# Each zone Switch block closes, then immediately has either:
#   }    (closing the if($GAIAregion -eq 'X') branch)
# We need to close our if ($Preset) wrapper before the outer closing brace.
# The pattern after each zone Switch is:  `}`r`n`r`n`r`n}`r`n`r`n  (close Switch, blank, close region-if)
# We insert our close before the Switch-closing brace of each zone block.
# Strategy: each zone block ends with:   `}\r\n\r\n\r\n}\r\n` 
# We replace with:                       `}\r\n  }\r\n\r\n\r\n}\r\n`

$zoneCloseOld = "}`r`n`r`n`r`n}`r`n`r`n"
$zoneCloseNew = "}`r`n  }`r`n`r`n`r`n}`r`n`r`n"
# This pattern appears multiple times (once per region). Replace all.
$zoneCloseCount = ([regex]::Matches($ps1, [regex]::Escape($zoneCloseOld))).Count
if ($zoneCloseCount -gt 0) {
    $ps1 = $ps1.Replace($zoneCloseOld, $zoneCloseNew)
} else {
    # Single-blank-line variant
    $zoneCloseOld2 = "}`r`n`r`n}`r`n"
    if ($ps1 -like "*$zoneCloseOld2*") {
        $ps1 = $ps1.Replace($zoneCloseOld2, "}`r`n  }`r`n`r`n}`r`n")
    } else {
        Write-Host "  [w] Could not auto-close zone if-wrappers. Preset will still work; zone menus will appear but be ignored." -ForegroundColor Yellow
    }
}

Write-OK "changes.ps1 patched ($zoneCount zone Out-GridView blocks guarded)."

# ---------------------------------------------------------------------------
# Patch changes.cmd — pass %1 through to the PowerShell script
# ---------------------------------------------------------------------------
Write-Step "Patching changes.cmd ..."

$cmdOld = "PowerShell.exe -Command `"& '%~dpn0.ps1'`"  '%COMPUTERNAME%'"
$cmdNew = "PowerShell.exe -Command `"& '%~dpn0.ps1'`"  '%COMPUTERNAME%'  '%1'"

$cmd = $cmd.Replace($cmdOld, $cmdNew)

Write-OK "changes.cmd patched."

# ---------------------------------------------------------------------------
# Write patched files
# ---------------------------------------------------------------------------
Write-Step "Writing patched files ..."

[System.IO.File]::WriteAllText($ps1Path, $ps1, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($cmdPath, $cmd, [System.Text.Encoding]::UTF8)

Write-OK "changes.ps1 written."
Write-OK "changes.cmd written."

# ---------------------------------------------------------------------------
# Optional launcher
# ---------------------------------------------------------------------------
if ($CreateLauncher) {
    Write-Step "Creating run-uk.cmd ..."
    $launcherPath = Join-Path $Path 'run-uk.cmd'
    $launcherContent = "@ECHO OFF`r`ncall `"%~dp0changes.cmd`" uk`r`n"
    [System.IO.File]::WriteAllText($launcherPath, $launcherContent, [System.Text.Encoding]::ASCII)
    Write-OK "run-uk.cmd created."
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  Patching complete." -ForegroundColor White
Write-Host ""
Write-Host "  Usage:" -ForegroundColor White
Write-Host "    changes.cmd uk      <- runs with UK/London/GMT preset, no menus"
Write-Host "    changes.cmd         <- runs interactively as before"
Write-Host ""
