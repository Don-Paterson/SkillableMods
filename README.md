# SkillableMods

Helpers for patching the Skillable lab `changes.ps1` / `changes.cmd` workflow so a UK preset can be applied without manually clicking through the menus.

## What this does

The patcher modifies the local lab files:

- `changes.ps1`
- `changes.cmd`

After patching, running:

```
.\changes.cmd uk
```

automatically applies these settings across all lab VMs with no interactive menus:

| Setting | Value |
|---|---|
| Keyboard | English (United Kingdom) |
| Windows time zone | GMT Standard Time |
| GAIA region | Europe |
| GAIA zone | London |

The original logic in `changes.ps1` is fully preserved. Running `.\changes.cmd` without an argument still works interactively as before.

## Current version

**`change-lab-uk-v5.ps1`** — use this. Earlier versions (v3, v4) are kept for reference only.

v5 improvements over earlier versions:
- Uses regex matching throughout so minor whitespace variations in the Skillable script do not cause anchor failures
- Adds `-NoProfile -NonInteractive` to the PowerShell invocation in `changes.cmd` so it works correctly when launched from a PowerShell 7 (pwsh) prompt
- Detects if already patched and exits cleanly on re-run
- Fails loudly with a clear message rather than silently patching the wrong location

## Usage

### Step 1 — Patch the lab files (once per lab instance)

Run from RDP-HOST in PowerShell. This downloads the patcher, verifies it is the correct version, saves it to a temp file, and runs it against the scripts in `C:\scripts`:

```powershell
$url = "https://raw.githubusercontent.com/Don-Paterson/SkillableMods/main/change-lab-uk-v5.ps1?$(Get-Date -Format 'yyyyMMddHHmmss')"
$script = irm $url
if ($script -notmatch 'IPsCollection') { Write-Error "Wrong version - do not run" } else { $script | Out-File "$env:TEMP\v5.ps1" -Encoding utf8 }
powershell -ExecutionPolicy Bypass -File "$env:TEMP\v5.ps1" -Path C:\scripts
```

If your lab scripts are in a different folder, change `-Path C:\scripts` accordingly.

### Step 2 — Apply UK settings

```powershell
cd C:\scripts
.\changes.cmd uk
```

That's it. No menus. The script pushes keyboard and timezone changes to all reachable Windows VMs and GAIA hosts, then reboots them.

### Subsequent runs on the same lab instance

The patcher only needs to run once per lab instance. After that, just:

```powershell
cd C:\scripts
.\changes.cmd uk
```

Re-running the patcher on an already-patched instance is safe — it detects the existing patch and exits without making changes.

## What gets skipped

The script will report any hosts it could not reach, for example:

```
... skipped GAIA hosts
    10.1.1.4
    10.1.1.111
Please refer to the lab topology if the skipped hosts are used during this course!
```

Skipped hosts are simply not reachable via WinRM or SSH at the time the script runs — typically because they are not part of the current lab topology, are powered off, or are still booting. This is normal and expected.

## Backups

Before patching, the script creates timestamped backups of both files:

```
changes.ps1.bak-20260330-093021
changes.cmd.bak-20260330-093021
```

To restore:

```cmd
copy changes.ps1.bak-20260330-093021 changes.ps1
copy changes.cmd.bak-20260330-093021 changes.cmd
```

## Optional: double-click launcher

Pass `-CreateLauncher` to also create `run-uk.cmd` in the scripts folder:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:TEMP\v5.ps1" -Path C:\scripts -CreateLauncher
```

`run-uk.cmd` simply calls `changes.cmd uk` and can be double-clicked from Explorer.

## Notes

- The patcher targets the Skillable script layout as of mid-2025. If Skillable significantly revises `changes.ps1` in a future lab version, the patcher will stop and report which anchor it could not find rather than patching silently.
- The patcher uses regex matching so minor formatting differences (extra spaces, different line endings) are handled gracefully.

## Disclaimer

Review scripts before running them, especially when downloading from the internet.

Provided as-is, with no warranty.
