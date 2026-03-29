[CmdletBinding()]
param(
    [string]$Path,
    [switch]$CreateLauncher
)

$ErrorActionPreference = 'Stop'

function Write-Info($m) { Write-Host "[+] $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Write-WarnMsg($m){ Write-Host "[!] $m" -ForegroundColor Yellow }

function Get-TargetDirectory {
    param([string]$PreferredPath)

    $candidates = New-Object System.Collections.Generic.List[string]

    if ($PreferredPath) {
        if (-not (Test-Path -LiteralPath $PreferredPath)) {
            throw "Specified path does not exist: $PreferredPath"
        }
        $item = Get-Item -LiteralPath $PreferredPath
        if ($item.PSIsContainer) { $candidates.Add($item.FullName) } else { $candidates.Add($item.DirectoryName) }
    }

    $common = @(
        (Get-Location).Path,
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Downloads",
        'C:\scripts'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($dir in $common) {
        if (-not $candidates.Contains($dir)) { [void]$candidates.Add($dir) }
    }

    foreach ($dir in $candidates) {
        $ps1 = Join-Path $dir 'changes.ps1'
        $cmd = Join-Path $dir 'changes.cmd'
        if ((Test-Path -LiteralPath $ps1) -and (Test-Path -LiteralPath $cmd)) { return $dir }
    }

    foreach ($dir in $common) {
        try {
            $matches = Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -in @('changes.ps1','changes.cmd') } |
                Group-Object DirectoryName
            foreach ($group in $matches) {
                $names = $group.Group.Name
                if ($names -contains 'changes.ps1' -and $names -contains 'changes.cmd') { return $group.Name }
            }
        } catch {}
    }

    throw "Could not find a folder containing both changes.ps1 and changes.cmd. Re-run with -Path 'C:\path\to\folder'."
}

function Backup-File {
    param([string]$FilePath)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$FilePath.bak-$stamp"
    Copy-Item -LiteralPath $FilePath -Destination $backup -Force
    return $backup
}

function Normalize-Newlines {
    param([string]$Text)
    return ($Text -replace "`r`n", "`n") -replace "`r", "`n"
}

function Replace-Once {
    param(
        [string]$Content,
        [string]$Old,
        [string]$New,
        [string]$Label
    )
    if ($Content.Contains($New)) { return $Content }
    if (-not $Content.Contains($Old)) { throw "Could not find expected text for: $Label" }
    return $Content.Replace($Old, $New)
}

$targetDir = Get-TargetDirectory -PreferredPath $Path
$ps1Path = Join-Path $targetDir 'changes.ps1'
$cmdPath = Join-Path $targetDir 'changes.cmd'

Write-Info "Target folder: $targetDir"

$ps1Original = Normalize-Newlines (Get-Content -LiteralPath $ps1Path -Raw)
$cmdOriginal = Normalize-Newlines (Get-Content -LiteralPath $cmdPath -Raw)

$ps1Patched = $ps1Original
$cmdPatched = $cmdOriginal

# Patch changes.cmd so: changes.cmd uk
if ($cmdPatched -notmatch '(?m)%\*') {
    $oldCmd = "PowerShell.exe -Command \"& '%~dpn0.ps1'\"  '%COMPUTERNAME%'"
    $newCmd = 'PowerShell.exe -ExecutionPolicy Bypass -File "%~dpn0.ps1" "%COMPUTERNAME%" %*'
    if ($cmdPatched.Contains($oldCmd)) {
        $cmdPatched = $cmdPatched.Replace($oldCmd, $newCmd)
    }
}

if ($ps1Patched -notmatch '(?m)^\$UsePresetUK\s*=') {
    $old = '$ComputerName = $args[0]'
    $new = "$old`n`$UsePresetUK = (`$args -contains 'uk') -or (`$args -contains '-UsePresetUK')"
    $ps1Patched = Replace-Once -Content $ps1Patched -Old $old -New $new -Label 'preset argument block'
}

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'keyboard menu start' -Old @"
  `$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the keyboard layout for all VMs make a selection'

  Switch (`$Result)  {
"@ -New @"
if(`$UsePresetUK){
    `$WindowsLanguageTag ='en-GB'
    `$GAIALanguageTag='uk'
}else {
  `$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the keyboard layout for all VMs make a selection'

  Switch (`$Result)  {
"@

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'keyboard menu end' -Old @"
} 



if(`$WindowsLanguageTag -eq `$NULL){
"@ -New @"
} 
}


if(`$WindowsLanguageTag -eq `$NULL){
"@

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'Windows timezone menu start' -Old @"
  `$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the time zone for all Windows-VMs make a selection'

  Switch (`$Result)  {
"@ -New @"
if(`$UsePresetUK){
    `$WindowsTimezone ='GMT Standard Time'
}else {
  `$Result = `$Menu | Out-GridView -PassThru  -Title 'To change the time zone for all Windows-VMs make a selection'

  Switch (`$Result)  {
"@

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'Windows timezone menu end' -Old @"
}

if(`$WindowsTimezone -eq `$NULL){
"@ -New @"
}
}

if(`$WindowsTimezone -eq `$NULL){
"@

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'GAIA region menu start' -Old @"
if(`$ComputerName -eq 'RDP-HOST'){



`$Menu = [ordered]@{
"@ -New @"
if(`$ComputerName -eq 'RDP-HOST'){

if(`$UsePresetUK){
    `$GAIAregion = 'Europe'
}else {
`$Menu = [ordered]@{
"@

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'GAIA region menu end' -Old @"
}



if(`$GAIAregion -eq 'Africa'){
"@ -New @"
}
}


if(`$GAIAregion -eq 'Africa'){
"@

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'GAIA Europe zone menu start' -Old @"
if(`$GAIAregion -eq 'Europe'){
  


`$Menu = [ordered]@{
"@ -New @"
if(`$GAIAregion -eq 'Europe'){
  
if(`$UsePresetUK){
    `$GAIAzone = 'London'
}else {
`$Menu = [ordered]@{
"@

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'GAIA Europe zone menu end' -Old @"

}


}

if(`$GAIAregion -eq 'Indian'){
"@ -New @"

}

}
}

if(`$GAIAregion -eq 'Indian'){
"@

if ($ps1Patched -eq $ps1Original -and $cmdPatched -eq $cmdOriginal) {
    Write-WarnMsg 'No changes were needed. The files may already be patched.'
    return
}

$ps1Backup = Backup-File -FilePath $ps1Path
$cmdBackup = Backup-File -FilePath $cmdPath

$ps1Patched = $ps1Patched -replace "`n", "`r`n"
$cmdPatched = $cmdPatched -replace "`n", "`r`n"

Set-Content -LiteralPath $ps1Path -Value $ps1Patched -Encoding UTF8
Set-Content -LiteralPath $cmdPath -Value $cmdPatched -Encoding ASCII

Write-Ok "Backed up: $ps1Backup"
Write-Ok "Backed up: $cmdBackup"
Write-Ok 'Patched changes.ps1 and changes.cmd'
Write-Host ''
Write-Host 'You can now run:' -ForegroundColor Cyan
Write-Host '  changes.cmd uk' -ForegroundColor White
Write-Host ''
Write-Host 'Or directly:' -ForegroundColor Cyan
Write-Host '  PowerShell.exe -ExecutionPolicy Bypass -File .\changes.ps1 "%COMPUTERNAME%" uk' -ForegroundColor White

if ($CreateLauncher) {
    $launcherPath = Join-Path $targetDir 'run-uk.cmd'
    @"
@echo off
call "%~dp0changes.cmd" uk
"@ | Set-Content -LiteralPath $launcherPath -Encoding ASCII
    Write-Ok "Created launcher: $launcherPath"
}
