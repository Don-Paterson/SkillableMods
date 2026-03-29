# SkillableMods

Helpers for patching the Skillable lab `changes.ps1` / `changes.cmd` workflow so a UK preset can be applied without manually clicking through the menus.

## What this does

The bootstrap script patches the local lab files:

- `changes.ps1`
- `changes.cmd`

After patching, you can run:

```powershell
changes.cmd uk
```

and the script will automatically use these selections:

- Keyboard: **English (United Kingdom)**
- Windows time zone: **GMT Standard Time**
- GAIA region: **Europe**
- GAIA zone: **London**

The original remote lab-wide logic in `changes.ps1` is preserved. This only preselects the menu choices.

## Files

- `change-lab-uk.ps1` — bootstrap patcher
- `README.md`
- `LICENSE`

## Usage

Run the bootstrap patcher from PowerShell:

```powershell
irm https://raw.githubusercontent.com/Don-Paterson/SkillableMods/main/change-lab-uk.ps1 | iex
```

Safer method:

```powershell
iwr https://raw.githubusercontent.com/Don-Paterson/SkillableMods/main/change-lab-uk.ps1 -OutFile .\change-lab-uk.ps1
powershell -ExecutionPolicy Bypass -File .\change-lab-uk.ps1
```

If the script files are in a different folder:

```powershell
.\change-lab-uk.ps1 -Path "C:\path\to\folder"
```

To create a double-click launcher as well:

```powershell
.\change-lab-uk.ps1 -CreateLauncher
```

That creates:

```cmd
run-uk.cmd
```

which runs:

```cmd
changes.cmd uk
```

## After patching

Run this on **RDP-HOST**:

```cmd
changes.cmd uk
```

This should skip the manual selections for:

1. English (United Kingdom)
2. (UTC+00:00) Dublin, Edinburgh, Lisbon, London
3. Europe
4. London

## Backups

Before patching, the script creates timestamped backups of both files, for example:

- `changes.ps1.bak-20260329-184500`
- `changes.cmd.bak-20260329-184500`

## Notes

- This depends on the target `changes.ps1` and `changes.cmd` matching the expected Skillable script layout.
- If those files change significantly in a future lab version, the patcher may stop and report which expected block it could not find.
- The patcher is designed to fail clearly rather than silently patch the wrong section.

## Disclaimer

Review scripts before running them, especially when using `irm ... | iex`.

Provided as-is, with no warranty.
