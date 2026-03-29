# SkillableMods

# SkillableMods – UK preset patch for `changes.ps1` / `changes.cmd`

This repository contains a PowerShell bootstrap script that patches the standard Skillable lab language/timezone scripts so they can be run with a **UK preset** and without clicking through the selection menus each time.

After patching, you can run:

```cmd
changes.cmd uk
```

or:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\changes.ps1 "%COMPUTERNAME%" uk
```

## What it changes

The patch adds a preset that automatically uses:

- **Windows keyboard/layout:** `en-GB`
- **GAIA language tag:** `uk`
- **Windows time zone:** `GMT Standard Time`
- **GAIA region:** `Europe`
- **GAIA zone:** `London`

It also updates `changes.cmd` so arguments can be passed through to `changes.ps1`.

## What the bootstrap script does

`change-lab-uk.ps1` will:

- locate `changes.ps1` and `changes.cmd`
- make timestamped backups of both files
- patch both files in place
- optionally create a double-click launcher called `run-uk.cmd`

## Files

- `change-lab-uk.ps1` – bootstrap/patch script
- `changes.ps1` – existing Skillable script to be patched locally
- `changes.cmd` – existing launcher to be patched locally

## Quick start

### Simple one-liner

```powershell
irm https://raw.githubusercontent.com/Don-Paterson/SkillableMods/main/change-lab-uk.ps1 | iex
```

### Safer method

```powershell
iwr https://raw.githubusercontent.com/Don-Paterson/SkillableMods/main/change-lab-uk.ps1 -OutFile .\change-lab-uk.ps1
notepad .\change-lab-uk.ps1
powershell -ExecutionPolicy Bypass -File .\change-lab-uk.ps1
```

## Usage

### Patch files in the current/default locations

```powershell
.\change-lab-uk.ps1
```

The script checks common locations such as:

- current directory
- Desktop
- Documents
- Downloads
- `C:\scripts`

If it finds a folder containing both `changes.ps1` and `changes.cmd`, it patches those files.

### Patch a specific folder

```powershell
.\change-lab-uk.ps1 -Path "C:\scripts"
```

You can also point `-Path` at either the folder or one of the files in that folder.

### Create a double-click launcher

```powershell
.\change-lab-uk.ps1 -CreateLauncher
```

This creates:

```cmd
run-uk.cmd
```

which simply runs:

```cmd
changes.cmd uk
```

## After patching

Run the updated script with:

```cmd
changes.cmd uk
```

That applies the UK preset and skips the relevant language/timezone/GAIA location selection menus.

You can still run the original interactive behaviour by running:

```cmd
changes.cmd
```

without the `uk` argument.

## Backups

Before making changes, the script creates timestamped backups such as:

- `changes.ps1.bak-20260329-190000`
- `changes.cmd.bak-20260329-190000`

This makes it easy to restore the original versions if needed.

## Notes and cautions

- This script is designed around the current known structure of your existing `changes.ps1` and `changes.cmd` files.
- If those source files change significantly in future, the patch may need to be adjusted.
- `irm ... | iex` is convenient, but it executes remote code immediately. Use the download-and-review method if you want a safer workflow.
- Test in a fresh lab instance before relying on it as your normal process.

## Expected result

Once patched, the everyday workflow becomes:

```cmd
changes.cmd uk
```

instead of clicking through the UK / London / Europe selections each time.

## License

Use whatever license you prefer for the repository. If you want, you can add an MIT `LICENSE` file.
