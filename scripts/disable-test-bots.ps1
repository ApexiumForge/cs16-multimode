[CmdletBinding()]
param([string]$ServerDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'))

$ErrorActionPreference = 'Stop'
$ServerDir = [IO.Path]::GetFullPath($ServerDir)
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pidFile = Join-Path $repoRoot '.runtime\hlds.pid'
if (Test-Path -LiteralPath $pidFile) { throw 'Stop the project HLDS before disabling test bots.' }

$cstrikeDir = Join-Path $ServerDir 'cstrike'
$targets = @(
    @{ Path=(Join-Path $cstrikeDir 'addons\metamod\plugins.ini'); Pattern='^win32 addons\\yapb\\bin\\yapb\.dll$' },
    @{ Path=(Join-Path $cstrikeDir 'addons\amxmodx\configs\plugins.ini'); Pattern='^mm_classic_test\.amxx ; DEVELOPMENT ONLY$' },
    @{ Path=(Join-Path $cstrikeDir 'server.cfg'); Pattern='^exec addons/amxmodx/configs/mm_solo_test\.cfg // DEVELOPMENT ONLY$' }
)
foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target.Path -PathType Leaf)) { throw "Configuration file is missing: $($target.Path)" }
    $remaining = Get-Content -LiteralPath $target.Path | Where-Object { $_ -notmatch $target.Pattern }
    Set-Content -LiteralPath $target.Path -Encoding ASCII -Value $remaining
}

Write-Host 'Solo bot testing disabled. Installed YaPB/test files remain available for later use.'

