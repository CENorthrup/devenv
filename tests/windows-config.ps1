$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Bootstrap = Join-Path $Root 'windows/bootstrap.ps1'
$WezTermConfigSource = Join-Path $Root 'windows/wezterm.lua'

# Load only the two configuration functions, never the installer entry point.
$Tokens = $null
$ParseErrors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile($Bootstrap, [ref]$Tokens, [ref]$ParseErrors)
if ($ParseErrors.Count) { throw ($ParseErrors | Out-String) }
foreach ($Name in @('Set-WezTermConfig', 'Test-WezTermConfig')) {
    $Function = $Ast.Find({ param($Node)
        $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq $Name
    }, $true)
    if (-not $Function) { throw "Missing function: $Name" }
    . ([scriptblock]::Create($Function.Extent.Text))
}

$Scratch = Join-Path ([IO.Path]::GetTempPath()) ('devenv-terminal-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $Scratch | Out-Null
$Destination = Join-Path $Scratch '.wezterm.lua'
try {
    $Rejected = $false
    try { Test-WezTermConfig -Destination $Destination } catch { $Rejected = $true }
    if (-not $Rejected) { throw 'Missing configuration was accepted.' }
    Set-WezTermConfig -Destination $Destination
    Test-WezTermConfig -Destination $Destination
    $Before = (Get-Item -LiteralPath $Destination).LastWriteTimeUtc
    Set-WezTermConfig -Destination $Destination
    if ((Get-Item -LiteralPath $Destination).LastWriteTimeUtc -ne $Before) { throw 'Rerun rewrote matching configuration.' }
    if (@(Get-ChildItem -LiteralPath $Scratch -Force).Count -ne 1) { throw 'Rerun created an unnecessary backup.' }
    Add-Content -LiteralPath $Destination -Value '-- deliberate drift'
    $DriftHash = (Get-FileHash -LiteralPath $Destination).Hash
    $Rejected = $false
    try { Test-WezTermConfig -Destination $Destination } catch { $Rejected = $true }
    if (-not $Rejected) { throw 'Configuration drift was accepted.' }
    if ((Get-FileHash -LiteralPath $Destination).Hash -ne $DriftHash) { throw 'Check rewrote configuration.' }
    Set-WezTermConfig -Destination $Destination
    Test-WezTermConfig -Destination $Destination
    $Backups = @(Get-ChildItem -LiteralPath $Scratch -Force -Filter '*.devenv-backup.*')
    if ($Backups.Count -ne 1 -or (Get-FileHash -LiteralPath $Backups[0].FullName).Hash -ne $DriftHash) {
        throw 'Explicit application did not preserve the changed file.'
    }
    Write-Host 'PASS: terminal config application, stable rerun, missing/drift rejection, read-only check, backup.'
} finally {
    Remove-Item -LiteralPath $Scratch -Recurse -Force
}
