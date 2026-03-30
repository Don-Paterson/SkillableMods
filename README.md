# SkillableMods

Helpers for patching the Skillable lab `changes.ps1` / `changes.cmd` workflow so UK settings can be applied to all lab VMs without manually clicking through menus.

## Quick start

Run this on **RDP-HOST** at the start of every new lab instance:
Run this in a **PowerShell** prompt (not CMD) on **RDP-HOST**:

```powershell
irm "https://raw.githubusercontent.com/Don-Paterson/SkillableMods/main/run-uk-setup.ps1?$(Get-Date -Format 'yyyyMMddHHmmss')" | iex
```

That's it. No menus, no interaction. The script patches the lab files and applies UK settings in one shot.

## What it does

Running the one-liner above performs two steps automatically:

**Step 1 - Patch the lab scripts (once per lab instance)**

Downloads and runs `change-lab-uk-v5.ps1`, which modifies `C:\scripts\changes.ps1` and `C:\scripts\changes.cmd` to support a non-interactive `uk` preset. If the scripts have already been patched (e.g. you are re-running on the same instance), this step is skipped automatically.

**Step 2 - Apply UK settings**

Runs `changes.ps1` with the `uk` preset, pushing the following settings to all reachable VMs and GAIA hosts:

| Setting | Value |
|---|---|
| Keyboard | English (United Kingdom) |
| Windows time zone | GMT Standard Time |
| GAIA region | Europe |
| GAIA zone | London |

Windows VMs are updated via WinRM and rebooted. GAIA hosts are updated via SSH (plink) and rebooted.

## Files

| File | Purpose |
|---|---|
| `run-uk-setup.ps1` | One-shot setup script - download, patch, and apply in a single command |
| `change-lab-uk-v5.ps1` | Patcher - modifies `changes.ps1` and `changes.cmd` |
| `change-lab-uk-v3.ps1` | Older version, kept for reference |
| `change-lab-uk-v4.ps1` | Older version, kept for reference |
| `change-lab-uk.ps1` | Original version, kept for reference |

## After the script runs

You will see output like:

```
  [SkillableMods] UK preset active - skipping interactive menus.
  ... making changes to Windows hosts ...
  ... making changes to GAIA hosts (time zone = 'Europe / London' and keyboard layout = 'uk')
                done!
```

Some hosts may be reported as skipped:

```
  ... skipped GAIA hosts
      10.1.1.4
      10.1.1.111
  Please refer to the lab topology if the skipped hosts are used during this course!
```

Skipped hosts are simply not reachable at the time the script runs - typically because they are not part of the current lab topology, are powered off, or are still booting. This is normal and expected.

Wait for all VMs to finish rebooting before starting the lab exercises.

## Applying UK settings again on the same instance

If you need to re-run the UK settings on an already-patched instance (e.g. after a VM rebuild), just run the same one-liner again - or call the script directly:

```powershell
cd C:\scripts
.\changes.cmd uk
```

## Advanced usage

**Different scripts folder:**

```powershell
powershell -ExecutionPolicy Bypass -File "$env:TEMP\change-lab-uk-v5.ps1" -Path "C:\path\to\folder"
```

**Run patcher only, without applying settings:**

```powershell
$url = "https://raw.githubusercontent.com/Don-Paterson/SkillableMods/main/change-lab-uk-v5.ps1?$(Get-Date -Format 'yyyyMMddHHmmss')"
$script = irm $url
if ($script -notmatch 'IPsCollection') { Write-Error "Wrong version - do not run" } else { $script | Out-File "$env:TEMP\v5.ps1" -Encoding utf8 }
powershell -ExecutionPolicy Bypass -File "$env:TEMP\v5.ps1" -Path C:\scripts
```

**Create a double-click launcher (`run-uk.cmd`):**

```powershell
powershell -ExecutionPolicy Bypass -File "$env:TEMP\v5.ps1" -Path C:\scripts -CreateLauncher
```

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

## Notes

- Tested in the Skillable Check Point lab environment (CPR82_CCSA lab).
- RDP-HOST is used as the orchestration point - it has WinRM access to Windows VMs and plink available for GAIA hosts.
- The patcher uses regex matching so minor formatting differences in the Skillable scripts are handled gracefully.
- If Skillable significantly revises `changes.ps1` in a future lab version, the patcher will stop and report which anchor it could not find rather than patching silently.
- The `-NoProfile -NonInteractive` flags are included in the PowerShell invocation to prevent issues when running from a PowerShell 7 (pwsh) prompt.

## Disclaimer

Review scripts before running them, especially when downloading from the internet.

Provided as-is, with no warranty.
