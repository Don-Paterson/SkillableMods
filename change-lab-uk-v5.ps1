<#
.SYNOPSIS
    Patches changes.ps1 and changes.cmd so that:
        changes.cmd uk
    runs non-interactively with UK/London/GMT presets.

.DESCRIPTION
    v5 - Uses regex matching throughout so whitespace/spacing variations
    in the Skillable script do not cause anchor failures.

.PARAMETER Path
    Folder containing changes.ps1 and changes.cmd.
    Defaults to the current directory when run via irm | iex.

.PARAMETER CreateLauncher
    Also creates run-uk.cmd (double-click shortcut for changes.cmd uk).

.EXAMPLE
    .\change-lab-uk-v5.ps1
    .\change-lab-uk-v5.ps1 -Path "C:\scripts" -CreateLauncher
#>

[CmdletBinding()]
param(
    [string]$Path,
    [switch]$CreateLauncher
)

$ErrorActionPreference = 'Stop'

# Resolve Path in script body so irm | iex works (param defaults eval too early)
if (-not $Path) {
    $Path = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step { param($msg) Write-Host "  [*] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [+] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [w] $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  [!] $msg" -ForegroundColor Red; exit 1 }

function Backup-File {
    param([string]$FilePath)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dest  = "$FilePath.bak-$stamp"
    Copy-Item -LiteralPath $FilePath -Destination $dest
    Write-OK "Backed up to $(Split-Path $dest -Leaf)"
}

function Assert-Pattern {
    param([string]$Content, [string]$Pattern, [string]$Label)
    if ($Content -notmatch $Pattern) {
        Write-Fail "Could not find anchor for '$Label'. The Skillable script may have changed - check for a newer patcher."
    }
}

# ---------------------------------------------------------------------------
# Locate files
# ---------------------------------------------------------------------------
$ps1Path = Join-Path $Path 'changes.ps1'
$cmdPath = Join-Path $Path 'changes.cmd'

Write-Host ""
Write-Host "  SkillableMods change-lab-uk-v5 patcher" -ForegroundColor White
Write-Host "  ---------------------------------------"
Write-Host ""
Write-Host "  Working directory: $Path"
Write-Host ""

foreach ($f in $ps1Path, $cmdPath) {
    if (-not (Test-Path $f)) { Write-Fail "File not found: $f" }
}

# ---------------------------------------------------------------------------
# Read originals
# ---------------------------------------------------------------------------
$ps1 = [System.IO.File]::ReadAllText($ps1Path, [System.Text.Encoding]::UTF8)
$cmd = [System.IO.File]::ReadAllText($cmdPath,  [System.Text.Encoding]::UTF8)

if ($ps1 -match 'SkillableMods-v5') {
    Write-Warn "changes.ps1 is already patched by v5. Nothing to do."
    exit 0
}

# ---------------------------------------------------------------------------
# Verify anchors
# ---------------------------------------------------------------------------
Write-Step "Verifying anchors in changes.ps1 ..."

Assert-Pattern $ps1 '\$ComputerName\s*=\s*\$args\[0\]'                              '$ComputerName = $args[0]'
Assert-Pattern $ps1 '\$Result\s*=\s*\$Menu\s*\|\s*Out-GridView[^\n]*keyboard layout' 'keyboard Out-GridView'
Assert-Pattern $ps1 '\$Result\s*=\s*\$Menu\s*\|\s*Out-GridView[^\n]*time zone'       'timezone Out-GridView'
Assert-Pattern $ps1 '\$Result\s*=\s*\$Menu\s*\|\s*Out-GridView[^\n]*region in order' 'GAIA region Out-GridView'
Assert-Pattern $ps1 'if\s*\(\s*\$WindowsLanguageTag\s*-eq\s*\$NULL\s*\)'             'WindowsLanguageTag null check'
Assert-Pattern $ps1 'if\s*\(\s*\$GAIALanguageTag\s*-eq\s*\$NULL\s*\)'               'GAIALanguageTag null check'
Assert-Pattern $ps1 'if\s*\(\s*\$WindowsTimezone\s*-eq\s*\$NULL\s*\)'               'WindowsTimezone null check'

Write-OK "All anchors found."

# ---------------------------------------------------------------------------
# Verify changes.cmd anchor
# ---------------------------------------------------------------------------
Write-Step "Verifying anchors in changes.cmd ..."

$p_cmd = "PowerShell\.exe\s+-Command\s+`"&\s+'%~dpn0\.ps1'`"\s+'%COMPUTERNAME%'"
$cmdCount = ([regex]::Matches($cmd, $p_cmd)).Count
if ($cmdCount -lt 2) {
    Write-Fail "Expected 2 PowerShell invocation lines in changes.cmd, found $cmdCount."
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

# Build preset block as concatenated string - no here-strings, no smart quotes
$nl = "`r`n"
$presetBlock  = $nl + $nl
$presetBlock += "# --- SkillableMods-v5 preset block (begin) ---" + $nl
$presetBlock += "`$Preset = if (`$args[1]) { `$args[1].ToString().ToLower() } else { '' }" + $nl
$presetBlock += "switch (`$Preset) {" + $nl
$presetBlock += "    'uk' {" + $nl
$presetBlock += "        `$WindowsLanguageTag = 'en-GB'" + $nl
$presetBlock += "        `$GAIALanguageTag    = 'uk'" + $nl
$presetBlock += "        `$WindowsTimezone    = 'GMT Standard Time'" + $nl
$presetBlock += "        `$GAIAregion         = 'Europe'" + $nl
$presetBlock += "        `$GAIAzone           = 'London'" + $nl
$presetBlock += "        Write-Host ''" + $nl
$presetBlock += "        Write-Host '      [SkillableMods] UK preset active - skipping interactive menus.' -ForegroundColor Green" + $nl
$presetBlock += "        Write-Host ''" + $nl
$presetBlock += "    }" + $nl
$presetBlock += "    default { `$Preset = '' }" + $nl
$presetBlock += "}" + $nl
$presetBlock += "# --- SkillableMods-v5 preset block (end) ---" + $nl

# 1. Inject preset block after the $args[0] line
$ps1 = [regex]::Replace($ps1,
    '(\$ComputerName\s*=\s*\$args\[0\][^\r\n]*)',
    { param($m) $m.Value + $presetBlock })

if ($ps1 -notmatch 'SkillableMods-v5') { Write-Fail "Preset block injection failed." }
Write-OK "Preset block injected."

# 2. Wrap keyboard Out-GridView in if ($Preset -eq '') / }
#    Close brace goes before the WindowsLanguageTag null check
$ps1 = [regex]::Replace($ps1,
    '(?m)^\s*\$Result\s*=\s*\$Menu\s*\|\s*Out-GridView[^\r\n]*keyboard layout[^\r\n]*',
    { param($m) "  if (`$Preset -eq '') {" + "`r`n  " + $m.Value.TrimStart() })
$ps1 = [regex]::Replace($ps1,
    '(if\s*\(\s*\$WindowsLanguageTag\s*-eq\s*\$NULL\s*\))',
    "}" + "`r`n`r`n" + '$1')
Write-OK "Keyboard OGV wrapped."

# 3. Wrap timezone Out-GridView in if ($Preset -eq '') / }
#    Close brace goes before the WindowsTimezone null check
$ps1 = [regex]::Replace($ps1,
    '(?m)^\s*\$Result\s*=\s*\$Menu\s*\|\s*Out-GridView[^\r\n]*time zone[^\r\n]*',
    { param($m) "  if (`$Preset -eq '') {" + "`r`n  " + $m.Value.TrimStart() })
$ps1 = [regex]::Replace($ps1,
    '(if\s*\(\s*\$WindowsTimezone\s*-eq\s*\$NULL\s*\))',
    "}" + "`r`n`r`n" + '$1')
Write-OK "Timezone OGV wrapped."

# 4. Wrap the GAIA region OGV AND the entire GAIAregion if-chain in one block.
#    Open:  before the region Out-GridView line
#    Close: before the line that begins the actual GAIA processing:
#           $GAIAtimezone=$GAIAregion, $GAIAzone -join ' / '
#    This avoids touching the 16 zone OGV blocks individually.
$ps1 = [regex]::Replace($ps1,
    '(?m)^\s*\$Result\s*=\s*\$Menu\s*\|\s*Out-GridView[^\r\n]*region in order[^\r\n]*',
    { param($m) "  if (`$Preset -eq '') {" + "`r`n  " + $m.Value.TrimStart() })

# Close wrapper before the Windows processing block
# Anchor: $IPsCollection = {$WindowsIPs}.Invoke() which immediately precedes it
$ps1 = [regex]::Replace($ps1,
    '(\$IPsCollection\s*=\s*\{\$WindowsIPs\}\.Invoke\(\))',
    "  }" + "`r`n`r`n" + '$1')
Write-OK "GAIA region/zone OGV section wrapped."

Write-OK "changes.ps1 patched."

# ---------------------------------------------------------------------------
# Patch changes.cmd - pass %1 through to PowerShell script
# ---------------------------------------------------------------------------
Write-Step "Patching changes.cmd ..."

$cmd = [regex]::Replace($cmd,
    "(PowerShell\.exe\s+-Command\s+`"&\s+'%~dpn0\.ps1'`"\s+'%COMPUTERNAME%')",
    '$1  ' + "'" + '%1' + "'")

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
    $launcherPath    = Join-Path $Path 'run-uk.cmd'
    $launcherContent = "@ECHO OFF" + "`r`n" + 'call "%~dp0changes.cmd" uk' + "`r`n"
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
Write-Host "    .\changes.cmd uk      <- runs with UK/London/GMT preset, no menus"
Write-Host "    .\changes.cmd         <- runs interactively as before"
Write-Host ""
