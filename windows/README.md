# Windows bootstrap

Run from PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
./windows/bootstrap.ps1 -Action All
```

The script is rerunnable and does not require winget. It preserves the recorded
WezTerm release when already installed, verifies downloaded installers and fonts,
installs FiraCode Nerd Font for the current Windows user, backs up a differing
`~/.wezterm.lua`, and configures WezTerm to open Ubuntu WSL with the Nerd Font and
Tokyo Night colors.

`-Action InstallWsl` calls the supported Windows WSL installer only when the named
distribution is absent. That operation may require an elevated PowerShell window,
a Windows restart, and one interactive Ubuntu launch to create the Linux user.
Afterward, obtain this public repository and run `bash wsl/bootstrap.sh` inside
Ubuntu. GitHub authentication and the private dotfiles checkout are separate steps.

Use `-Action PrepareWindows` for the terminal and font only, or `-Action Check` for
read-only verification.
