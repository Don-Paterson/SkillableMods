<#
.SYNOPSIS
    One-shot UK setup for Skillable Check Point labs.
    Downloads the v5 patcher, patches the lab scripts, then applies UK settings.

.DESCRIPTION
    Run this on RDP-HOST at the start of a new lab instance.
    It performs two steps automatically:
      1. Downloads and runs change-lab-uk-v5.ps1 to patch changes.ps1 and changes.cmd
      2. Runs changes.ps1 with the UK preset - no interactive menus

    Safe to run on an already-patched instance - the patcher detects this and skips step 1.

.EXAMPLE
    irm "https://raw.githubusercontent.com/Don-Paterson/SkillableMods/main/run-uk-setup.ps1?$(Get-Date -Format 'yyyyMMddHHmmss')" | iex
#>

$ErrorActionPreference = 'Stop'
$ScriptsPath = 'C:\scripts'

Write-Host ''
Write-Host '  SkillableMods - UK Setup' -ForegroundColor White
Write-Host '  ------------------------' -ForegroundColor White
Write-Host ''

# ---------------------------------------------------------------------------
# Step 1: Download and run the patcher
# ---------------------------------------------------------------------------
Write-Host '  [1/2] Patching lab scripts...' -ForegroundColor Cyan
Write-Host ''

$patcherUrl = "https://raw.githubusercontent.com/Don-Paterson/SkillableMods/main/change-lab-uk-v5.ps1?$(Get-Date -Format 'yyyyMMddHHmmss')"

try {
    $patcher = irm $patcherUrl
} catch {
    Write-Host '  [!] Failed to download patcher. Check network connectivity.' -ForegroundColor Red
    exit 1
}

if ($patcher -notmatch 'IPsCollection') {
    Write-Host '  [!] Downloaded file does not look like v5 - aborting.' -ForegroundColor Red
    exit 1
}

$patcherFile = "$env:TEMP\change-lab-uk-v5.ps1"
$patcher | Out-File $patcherFile -Encoding utf8

powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $patcherFile -Path $ScriptsPath

if ($LASTEXITCODE -ne 0) {
    Write-Host '  [!] Patcher exited with an error. Stopping.' -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Step 2: Apply UK settings
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '  [2/2] Applying UK settings...' -ForegroundColor Cyan
Write-Host ''

$changesScript = Join-Path $ScriptsPath 'changes.ps1'

if (-not (Test-Path $changesScript)) {
    Write-Host "  [!] Cannot find $changesScript" -ForegroundColor Red
    exit 1
}

powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& '$changesScript' 'RDP-HOST' 'uk'"

Write-Host ''
Write-Host '  All done.' -ForegroundColor Green
Write-Host ''
