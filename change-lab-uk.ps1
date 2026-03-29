[CmdletBinding()]
param(
    [string]$Path,
    [switch]$CreateLauncher
)

$ErrorActionPreference = 'Stop'

function Write-Info($m) { Write-Host "[+] $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Write-WarnMsg($m) { Write-Host "[!] $m" -ForegroundColor Yellow }

function Get-TargetDirectory {
    param([string]$PreferredPath)

    if ($PreferredPath) {
        if (-not (Test-Path -LiteralPath $PreferredPath)) {
            throw "Specified path does not exist: $PreferredPath"
        }
        $item = Get-Item -LiteralPath $PreferredPath
        if ($item.PSIsContainer) { return $item.FullName }
        return $item.DirectoryName
    }

    $candidates = @(
        (Get-Location).Path,
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Downloads",
        "C:\scripts"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($dir in $candidates) {
        if ((Test-Path -LiteralPath (Join-Path $dir 'changes.ps1')) -and
            (Test-Path -LiteralPath (Join-Path $dir 'changes.cmd'))) {
            return $dir
        }
    }

    foreach ($dir in $candidates) {
        try {
            $matches = Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -in @('changes.ps1','changes.cmd') } |
                Group-Object DirectoryName
            foreach ($group in $matches) {
                $names = $group.Group.Name
                if ($names -contains 'changes.ps1' -and $names -contains 'changes.cmd') {
                    return $group.Name
                }
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
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

function Replace-Once {
    param(
        [string]$Content,
        [string]$Old,
        [string]$New,
        [string]$Label
    )

    if ($Content.Contains($New)) {
        return $Content
    }

    if (-not $Content.Contains($Old)) {
        throw "Could not find expected text for: $Label"
    }

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

# 1) Add preset argument support
$ps1Patched = Replace-Once -Content $ps1Patched -Label 'preset argument support' -Old @"
$ComputerName = $args[0]
"@ -New @"
$ComputerName = $args[0]
$UsePresetUK = ($args -contains 'uk') -or ($args -contains '-UsePresetUK')
"@

# 2) Keyboard picker
$ps1Patched = Replace-Once -Content $ps1Patched -Label 'keyboard picker' -Old @"
  $Result = $Menu | Out-GridView -PassThru  -Title 'To change the keyboard layout for all VMs make a selection'

  Switch ($Result)  {

{$Result.Name -eq 1} {$WindowsLanguageTag ='da' ; $GAIALanguageTag='dk'}

{$Result.Name -eq 2} {$WindowsLanguageTag ='en-GB' ; $GAIALanguageTag='uk'}

{$Result.Name -eq 3} {$WindowsLanguageTag ='en-US' ; $GAIALanguageTag='us'}

{$Result.Name -eq 4} {$WindowsLanguageTag ='fi' ; $GAIALanguageTag='fi'}

{$Result.Name -eq 5} {$WindowsLanguageTag ='fr-FR' ; $GAIALanguageTag='fr'}

{$Result.Name -eq 6} {$WindowsLanguageTag ='fr-CH' ; $GAIALanguageTag='fr_CH'}

{$Result.Name -eq 7} {$WindowsLanguageTag ='de-DE' ; $GAIALanguageTag='de'}

{$Result.Name -eq 8} {$WindowsLanguageTag ='de-CH' ; $GAIALanguageTag='sg'}

{$Result.Name -eq 9} {$WindowsLanguageTag ='it-IT' ; $GAIALanguageTag='it'}

{$Result.Name -eq 10} {$WindowsLanguageTag ='nb' ; $GAIALanguageTag='no'}

{$Result.Name -eq 11} {$WindowsLanguageTag ='pl' ; $GAIALanguageTag='pl'}

{$Result.Name -eq 12} {$WindowsLanguageTag ='pt-PT' ; $GAIALanguageTag='pt-latin1'}

{$Result.Name -eq 13} {$WindowsLanguageTag ='ru' ; $GAIALanguageTag='ru'}

{$Result.Name -eq 14} {$WindowsLanguageTag ='es-ES' ; $GAIALanguageTag='es'}

{$Result.Name -eq 15} {$WindowsLanguageTag ='sv-SE' ; $GAIALanguageTag='se-latin1'}

{$Result.Name -eq 16} {$WindowsLanguageTag ='tr' ; $GAIALanguageTag='trq'}






} 
"@ -New @"
if($UsePresetUK){
  $WindowsLanguageTag ='en-GB'
  $GAIALanguageTag='uk'
}
else {
  $Result = $Menu | Out-GridView -PassThru  -Title 'To change the keyboard layout for all VMs make a selection'

  Switch ($Result)  {

{$Result.Name -eq 1} {$WindowsLanguageTag ='da' ; $GAIALanguageTag='dk'}

{$Result.Name -eq 2} {$WindowsLanguageTag ='en-GB' ; $GAIALanguageTag='uk'}

{$Result.Name -eq 3} {$WindowsLanguageTag ='en-US' ; $GAIALanguageTag='us'}

{$Result.Name -eq 4} {$WindowsLanguageTag ='fi' ; $GAIALanguageTag='fi'}

{$Result.Name -eq 5} {$WindowsLanguageTag ='fr-FR' ; $GAIALanguageTag='fr'}

{$Result.Name -eq 6} {$WindowsLanguageTag ='fr-CH' ; $GAIALanguageTag='fr_CH'}

{$Result.Name -eq 7} {$WindowsLanguageTag ='de-DE' ; $GAIALanguageTag='de'}

{$Result.Name -eq 8} {$WindowsLanguageTag ='de-CH' ; $GAIALanguageTag='sg'}

{$Result.Name -eq 9} {$WindowsLanguageTag ='it-IT' ; $GAIALanguageTag='it'}

{$Result.Name -eq 10} {$WindowsLanguageTag ='nb' ; $GAIALanguageTag='no'}

{$Result.Name -eq 11} {$WindowsLanguageTag ='pl' ; $GAIALanguageTag='pl'}

{$Result.Name -eq 12} {$WindowsLanguageTag ='pt-PT' ; $GAIALanguageTag='pt-latin1'}

{$Result.Name -eq 13} {$WindowsLanguageTag ='ru' ; $GAIALanguageTag='ru'}

{$Result.Name -eq 14} {$WindowsLanguageTag ='es-ES' ; $GAIALanguageTag='es'}

{$Result.Name -eq 15} {$WindowsLanguageTag ='sv-SE' ; $GAIALanguageTag='se-latin1'}

{$Result.Name -eq 16} {$WindowsLanguageTag ='tr' ; $GAIALanguageTag='trq'}






} 
}
"@

# 3) Windows timezone picker
$ps1Patched = Replace-Once -Content $ps1Patched -Label 'Windows timezone picker start' -Old @"
  $Result = $Menu | Out-GridView -PassThru  -Title 'To change the time zone for all Windows-VMs make a selection'

  Switch ($Result)  {
"@ -New @"
if($UsePresetUK){
  $WindowsTimezone ='GMT Standard Time'
}
else {
  $Result = $Menu | Out-GridView -PassThru  -Title 'To change the time zone for all Windows-VMs make a selection'

  Switch ($Result)  {
"@

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'Windows timezone picker end' -Old @"
}

if($WindowsTimezone -eq $NULL){
"@ -New @"
}
}

if($WindowsTimezone -eq $NULL){
"@

# 4) GAIA region picker
$ps1Patched = Replace-Once -Content $ps1Patched -Label 'GAIA region picker' -Old @"
  $Result = $Menu | Out-GridView -PassThru  -Title 'Please select a region in order to change the timezone on all GAIA-VMs' 

  Switch ($Result)  {


{$Result.Name -eq 1} {$GAIAregion ='Africa'}
{$Result.Name -eq 2} {$GAIAregion ='America'}
{$Result.Name -eq 3} {$GAIAregion ='Antarctica'}
{$Result.Name -eq 4} {$GAIAregion ='Arctic'}
{$Result.Name -eq 5} {$GAIAregion ='Asia'}
{$Result.Name -eq 6} {$GAIAregion ='Atlantic'}
{$Result.Name -eq 7} {$GAIAregion ='Australia'}
{$Result.Name -eq 8} {$GAIAregion ='Brazil'}
{$Result.Name -eq 9} {$GAIAregion ='Canada'}
{$Result.Name -eq 10} {$GAIAregion ='Chile'}
{$Result.Name -eq 11} {$GAIAregion ='Etc'}
{$Result.Name -eq 12} {$GAIAregion ='Europe'}
{$Result.Name -eq 13} {$GAIAregion ='Indian'}
{$Result.Name -eq 14} {$GAIAregion ='Mexico'}
{$Result.Name -eq 15} {$GAIAregion ='Pacific'}
{$Result.Name -eq 16} {$GAIAregion ='US'}  

}
"@ -New @"
if($UsePresetUK){
  $GAIAregion ='Europe'
}
else {
  $Result = $Menu | Out-GridView -PassThru  -Title 'Please select a region in order to change the timezone on all GAIA-VMs' 

  Switch ($Result)  {


{$Result.Name -eq 1} {$GAIAregion ='Africa'}
{$Result.Name -eq 2} {$GAIAregion ='America'}
{$Result.Name -eq 3} {$GAIAregion ='Antarctica'}
{$Result.Name -eq 4} {$GAIAregion ='Arctic'}
{$Result.Name -eq 5} {$GAIAregion ='Asia'}
{$Result.Name -eq 6} {$GAIAregion ='Atlantic'}
{$Result.Name -eq 7} {$GAIAregion ='Australia'}
{$Result.Name -eq 8} {$GAIAregion ='Brazil'}
{$Result.Name -eq 9} {$GAIAregion ='Canada'}
{$Result.Name -eq 10} {$GAIAregion ='Chile'}
{$Result.Name -eq 11} {$GAIAregion ='Etc'}
{$Result.Name -eq 12} {$GAIAregion ='Europe'}
{$Result.Name -eq 13} {$GAIAregion ='Indian'}
{$Result.Name -eq 14} {$GAIAregion ='Mexico'}
{$Result.Name -eq 15} {$GAIAregion ='Pacific'}
{$Result.Name -eq 16} {$GAIAregion ='US'}  

}
}
"@

# 5) Europe zone picker
$ps1Patched = Replace-Once -Content $ps1Patched -Label 'Europe zone picker start' -Old @"
  $Result = $Menu | Out-GridView -PassThru  -Title 'Please select a zone in order to change the timezone on GAIA-VMs' 

  Switch ($Result)  {


{$Result.Name -eq 1} {$GAIAzone ='Amsterdam'}
{$Result.Name -eq 2} {$GAIAzone ='Andorra'}
{$Result.Name -eq 3} {$GAIAzone ='Astrakhan'}
{$Result.Name -eq 4} {$GAIAzone ='Athens'}
{$Result.Name -eq 5} {$GAIAzone ='Belfast'}
{$Result.Name -eq 6} {$GAIAzone ='Belgrade'}
{$Result.Name -eq 7} {$GAIAzone ='Berlin'}
{$Result.Name -eq 8} {$GAIAzone ='Bratislava'}
{$Result.Name -eq 9} {$GAIAzone ='Brussels'}
{$Result.Name -eq 10} {$GAIAzone ='Bucharest'}
{$Result.Name -eq 11} {$GAIAzone ='Budapest'}
{$Result.Name -eq 12} {$GAIAzone ='Chisinau'}
{$Result.Name -eq 13} {$GAIAzone ='Copenhagen'}
{$Result.Name -eq 14} {$GAIAzone ='Dublin'}
{$Result.Name -eq 15} {$GAIAzone ='Gibraltar'}
{$Result.Name -eq 16} {$GAIAzone ='Guernsey'}
{$Result.Name -eq 17} {$GAIAzone ='Helsinki'}
{$Result.Name -eq 18} {$GAIAzone ='Isle_of_Man'}
{$Result.Name -eq 19} {$GAIAzone ='Istanbul'}
{$Result.Name -eq 20} {$GAIAzone ='Jersey'}
{$Result.Name -eq 21} {$GAIAzone ='Kaliningrad'}
{$Result.Name -eq 22} {$GAIAzone ='Kiev'}
{$Result.Name -eq 23} {$GAIAzone ='Kirov'}
{$Result.Name -eq 24} {$GAIAzone ='Lisbon'}
{$Result.Name -eq 25} {$GAIAzone ='Ljubljana'}
{$Result.Name -eq 26} {$GAIAzone ='London'}
{$Result.Name -eq 27} {$GAIAzone ='Luxembourg'}
"@ -New @"
if($UsePresetUK){
  $GAIAzone ='London'
}
else {
  $Result = $Menu | Out-GridView -PassThru  -Title 'Please select a zone in order to change the timezone on GAIA-VMs' 

  Switch ($Result)  {


{$Result.Name -eq 1} {$GAIAzone ='Amsterdam'}
{$Result.Name -eq 2} {$GAIAzone ='Andorra'}
{$Result.Name -eq 3} {$GAIAzone ='Astrakhan'}
{$Result.Name -eq 4} {$GAIAzone ='Athens'}
{$Result.Name -eq 5} {$GAIAzone ='Belfast'}
{$Result.Name -eq 6} {$GAIAzone ='Belgrade'}
{$Result.Name -eq 7} {$GAIAzone ='Berlin'}
{$Result.Name -eq 8} {$GAIAzone ='Bratislava'}
{$Result.Name -eq 9} {$GAIAzone ='Brussels'}
{$Result.Name -eq 10} {$GAIAzone ='Bucharest'}
{$Result.Name -eq 11} {$GAIAzone ='Budapest'}
{$Result.Name -eq 12} {$GAIAzone ='Chisinau'}
{$Result.Name -eq 13} {$GAIAzone ='Copenhagen'}
{$Result.Name -eq 14} {$GAIAzone ='Dublin'}
{$Result.Name -eq 15} {$GAIAzone ='Gibraltar'}
{$Result.Name -eq 16} {$GAIAzone ='Guernsey'}
{$Result.Name -eq 17} {$GAIAzone ='Helsinki'}
{$Result.Name -eq 18} {$GAIAzone ='Isle_of_Man'}
{$Result.Name -eq 19} {$GAIAzone ='Istanbul'}
{$Result.Name -eq 20} {$GAIAzone ='Jersey'}
{$Result.Name -eq 21} {$GAIAzone ='Kaliningrad'}
{$Result.Name -eq 22} {$GAIAzone ='Kiev'}
{$Result.Name -eq 23} {$GAIAzone ='Kirov'}
{$Result.Name -eq 24} {$GAIAzone ='Lisbon'}
{$Result.Name -eq 25} {$GAIAzone ='Ljubljana'}
{$Result.Name -eq 26} {$GAIAzone ='London'}
{$Result.Name -eq 27} {$GAIAzone ='Luxembourg'}
"@

$ps1Patched = Replace-Once -Content $ps1Patched -Label 'Europe zone picker end' -Old @"
{$Result.Name -eq 61} {$GAIAzone ='Zurich'}

}


}
"@ -New @"
{$Result.Name -eq 61} {$GAIAzone ='Zurich'}

}
}
}
"@

# 6) Pass arguments through from changes.cmd
$cmdPatched = Replace-Once -Content $cmdPatched -Label 'changes.cmd remote call' -Old @"
PowerShell.exe -Command "& '%~dpn0.ps1'"  '%COMPUTERNAME%'
"@ -New @"
PowerShell.exe -ExecutionPolicy Bypass -File "%~dpn0.ps1" "%COMPUTERNAME%" %*
"@

if ($ps1Patched -eq $ps1Original -and $cmdPatched -eq $cmdOriginal) {
    Write-WarnMsg "No changes were needed. The files may already be patched."
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
Write-Ok "Patched changes.ps1 and changes.cmd"
Write-Host ""
Write-Host "This keeps the original remote lab logic intact." -ForegroundColor Cyan
Write-Host "It only preselects the UK options when you pass 'uk'." -ForegroundColor Cyan
Write-Host ""
Write-Host "Run this on RDP-HOST:" -ForegroundColor Cyan
Write-Host "  changes.cmd uk" -ForegroundColor White

if ($CreateLauncher) {
    $launcherPath = Join-Path $targetDir 'run-uk.cmd'
    @"
@echo off
call "%~dp0changes.cmd" uk
"@ | Set-Content -LiteralPath $launcherPath -Encoding ASCII
    Write-Ok "Created launcher: $launcherPath"
}
