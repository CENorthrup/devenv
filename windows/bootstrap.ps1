[CmdletBinding()]
param(
    [ValidateSet('PrepareWindows', 'InstallWsl', 'Check', 'All')]
    [string]$Action = 'All',
    [string]$Distribution = 'Ubuntu'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$WezTermVersion = '20240203-110809-5046fc22'
$WezTermInstaller = "WezTerm-$WezTermVersion-setup.exe"
$WezTermBaseUrl = "https://github.com/wezterm/wezterm/releases/download/$WezTermVersion"
$NerdFontVersion = '3.5.1'
$NerdFontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v$NerdFontVersion/FiraCode.zip"
$NerdFontSha256 = '239395baf60c89b2eaf4862b6b09db0ef95605cd3e8eef51c00345822a81a665'
$WezTermConfigSource = Join-Path $PSScriptRoot 'wezterm.lua'

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-WezTerm {
    $Existing = Get-Command wezterm.exe -ErrorAction SilentlyContinue
    if (-not $Existing) {
        $ProgramCopy = 'C:\Program Files\WezTerm\wezterm.exe'
        if (Test-Path -LiteralPath $ProgramCopy) {
            $Existing = Get-Item -LiteralPath $ProgramCopy
        }
    }
    if ($Existing) {
        $ExistingPath = if ($Existing.Source) { $Existing.Source } else { $Existing.FullName }
        $InstalledVersion = (& $ExistingPath --version 2>$null) -replace '^wezterm\s+', ''
        if ($InstalledVersion -eq $WezTermVersion) {
            Write-Host "WezTerm $InstalledVersion is already installed."
            return
        }
        throw "Existing WezTerm version is $InstalledVersion; review it before replacing it."
    }

    $Temp = Join-Path ([IO.Path]::GetTempPath()) "devenv-wezterm-$WezTermVersion"
    New-Item -ItemType Directory -Force -Path $Temp | Out-Null
    $InstallerPath = Join-Path $Temp $WezTermInstaller
    $ChecksumPath = "$InstallerPath.sha256"
    Invoke-WebRequest "$WezTermBaseUrl/$WezTermInstaller" -OutFile $InstallerPath
    Invoke-WebRequest "$WezTermBaseUrl/$WezTermInstaller.sha256" -OutFile $ChecksumPath
    $Expected = ((Get-Content -Raw $ChecksumPath).Trim() -split '\s+')[0].ToUpperInvariant()
    $Actual = (Get-FileHash -Algorithm SHA256 $InstallerPath).Hash
    if ($Actual -ne $Expected) { throw 'WezTerm installer checksum verification failed.' }
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList '/S' -Wait -PassThru -WindowStyle Hidden
    if ($Process.ExitCode -ne 0) { throw "WezTerm installer exited with code $($Process.ExitCode)." }
}

function Install-FiraCodeNerdFont {
    $FontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $Existing = Get-ChildItem -LiteralPath $FontDir -Filter 'FiraCodeNerdFont*.ttf' -Force -ErrorAction SilentlyContinue
    if ($Existing) {
        Write-Host 'FiraCode Nerd Font is already installed for this user.'
        return
    }

    $Temp = Join-Path ([IO.Path]::GetTempPath()) "devenv-font-$NerdFontVersion"
    $Archive = Join-Path $Temp 'FiraCode.zip'
    $Expanded = Join-Path $Temp 'expanded'
    New-Item -ItemType Directory -Force -Path $Temp | Out-Null
    Invoke-WebRequest $NerdFontUrl -OutFile $Archive
    $Actual = (Get-FileHash -Algorithm SHA256 $Archive).Hash.ToLowerInvariant()
    if ($Actual -ne $NerdFontSha256) { throw 'FiraCode Nerd Font checksum verification failed.' }
    if (Test-Path -LiteralPath $Expanded) { Remove-Item -LiteralPath $Expanded -Recurse -Force }
    Expand-Archive -LiteralPath $Archive -DestinationPath $Expanded
    New-Item -ItemType Directory -Force -Path $FontDir | Out-Null
    $RegistryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -Path $RegistryPath -Force | Out-Null
    Get-ChildItem -LiteralPath $Expanded -Filter 'FiraCodeNerdFont*.ttf' | ForEach-Object {
        $Destination = Join-Path $FontDir $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Force
        New-ItemProperty -Path $RegistryPath -Name "$($_.BaseName) (TrueType)" -Value $_.Name -PropertyType String -Force | Out-Null
    }
}

function Set-WezTermConfig {
    $Destination = Join-Path $HOME '.wezterm.lua'
    if (Test-Path -LiteralPath $Destination) {
        $Current = (Get-FileHash -Algorithm SHA256 $Destination).Hash
        $Desired = (Get-FileHash -Algorithm SHA256 $WezTermConfigSource).Hash
        if ($Current -eq $Desired) { return }
        $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -LiteralPath $Destination -Destination "$Destination.devenv-backup.$Stamp"
    }
    Copy-Item -LiteralPath $WezTermConfigSource -Destination $Destination -Force
}

function Install-UbuntuWsl {
    if (-not (Test-Command 'wsl.exe')) { throw 'WSL is unavailable. Run this step from an elevated PowerShell window.' }
    $Names = @(wsl.exe --list --quiet | ForEach-Object { $_.Trim("`0", ' ') } | Where-Object { $_ })
    if ($Names -contains $Distribution) {
        Write-Host "$Distribution is already installed."
        return
    }
    wsl.exe --install --distribution $Distribution --no-launch
    if ($LASTEXITCODE -ne 0) { throw 'WSL installation did not complete. Restart Windows if prompted, then rerun this script.' }
    Write-Host "Launch $Distribution once to create its Linux user, then run wsl/bootstrap.sh from the repository."
}

function Test-Setup {
    $WezTerm = 'C:\Program Files\WezTerm\wezterm.exe'
    if (-not (Test-Path -LiteralPath $WezTerm)) { throw 'WezTerm was not found.' }
    $Fonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    if (-not (Get-ChildItem -LiteralPath $Fonts -Filter 'FiraCodeNerdFont*.ttf' -Force -ErrorAction SilentlyContinue)) {
        throw 'FiraCode Nerd Font was not found.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $HOME '.wezterm.lua'))) { throw 'WezTerm configuration was not found.' }
    wsl.exe --status
    if ($LASTEXITCODE -ne 0) { throw 'WSL status check failed.' }
    Write-Host 'Windows terminal prerequisites are ready.'
}

if ($Action -in @('PrepareWindows', 'All')) {
    Install-WezTerm
    Install-FiraCodeNerdFont
    Set-WezTermConfig
}
if ($Action -in @('InstallWsl', 'All')) { Install-UbuntuWsl }
if ($Action -in @('Check', 'All')) { Test-Setup }
