[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = (Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_modes.sma') -Raw) +
    (Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_mode_manager.sma') -Raw)

function Assert-Contains {
    param([string]$Pattern, [string]$Description)
    if ($source -notmatch $Pattern) { throw "Phase 2.1 check failed: $Description" }
}

Assert-Contains 'register_clcmd\("say /menu"' '/menu must be registered.'
Assert-Contains 'register_clcmd\("say /modes"' '/modes must be registered.'
foreach ($mode in @('Classic', 'Deathmatch', 'Arms Race', 'AWP Only', 'HE Battle')) {
    Assert-Contains ([regex]::Escape('"' + $mode + '"')) "Mode is missing: $mode"
}
foreach ($format in @('1v1', '2v2', '3v3', '4v4', '5v5', '1v2', '2v3', '3v4', '4v5')) {
    Assert-Contains ([regex]::Escape($format)) "Classic format is missing: $format"
}
Assert-Contains 'An administrator must confirm activation' 'Normal-player selections must remain informational.'

Write-Host 'All Phase 2.1 menu checks passed.'
