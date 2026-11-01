[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Assert-Match([string]$Text, [string]$Pattern, [string]$Message) {
    if ($Text -notmatch $Pattern) { throw "Solo-bot check failed: $Message" }
}

$installer = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\install-test-bots.ps1') -Raw
$enable = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\enable-test-bots.ps1') -Raw
$disable = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\disable-test-bots.ps1') -Raw
$bridge = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_classic_test.sma') -Raw
$devConfig = Get-Content -LiteralPath (Join-Path $repoRoot 'config\dev\mm_solo_test.cfg') -Raw

Assert-Match $installer '4\.4\.957' 'YaPB must be version-pinned.'
Assert-Match $installer 'C32A5B4D77C08C3C59C417568C5719F9227238C6D627D478CFB1D9F7D9C113F4' 'The official archive checksum must be pinned.'
Assert-Match $installer 'Refusing to merge or overwrite' 'An existing YaPB tree must not be overwritten.'
Assert-Match $devConfig 'yb_quota\s+"0"' 'Bots must be disabled by default.'
Assert-Match $devConfig 'yb_rotate_bots\s+"0"' 'Automatic bot rotation must be disabled.'
Assert-Match $devConfig 'mm_test_autorun_1v1\s+"0"' 'The automated smoke scenario must be disabled by default.'
Assert-Match $enable 'DEVELOPMENT ONLY' 'Enable mutations must be visibly development-only.'
Assert-Match $disable 'mm_classic_test' 'Disable must remove the test bridge registration.'
Assert-Match $disable 'yapb' 'Disable must remove the YaPB registration.'
Assert-Match $bridge 'is_user_bot' 'The ready bridge must affect bots only.'
Assert-Match $bridge 'callfunc_begin\("command_ready", "mm_classic\.amxx"\)' 'Bots must use the production /ready handler.'
if ($bridge -match 'g_ready\s*\[') {
    throw 'Solo-bot check failed: the test bridge must not access Classic private ready state.'
}
Assert-Match $bridge 'register_cvar\("mm_test_autorun_1v1", "0"\)' 'Runtime autorun must default to disabled.'
if ((Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\build-plugins.ps1') -Raw) -match 'mm_classic_test') {
    throw 'Solo-bot check failed: the production build must not compile or enable the test bridge.'
}

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("mm-solo-bots-" + [guid]::NewGuid().ToString('N'))
try {
    $fixtureCstrike = Join-Path $fixtureRoot 'cstrike'
    $fixtureMeta = Join-Path $fixtureCstrike 'addons\metamod\plugins.ini'
    $fixtureAmxx = Join-Path $fixtureCstrike 'addons\amxmodx'
    New-Item -ItemType Directory -Path (Split-Path $fixtureMeta), (Join-Path $fixtureAmxx 'configs'), (Join-Path $fixtureAmxx 'plugins'), (Join-Path $fixtureCstrike 'addons\yapb\bin') -Force | Out-Null
    Set-Content -LiteralPath $fixtureMeta -Encoding ASCII -Value 'win32 addons\amxmodx\dlls\amxmodx_mm.dll'
    Set-Content -LiteralPath (Join-Path $fixtureAmxx 'configs\plugins.ini') -Encoding ASCII -Value 'mm_core.amxx'
    Set-Content -LiteralPath (Join-Path $fixtureCstrike 'server.cfg') -Encoding ASCII -Value 'sv_lan 1'
    Set-Content -LiteralPath (Join-Path $fixtureCstrike 'addons\yapb\bin\yapb.dll') -Encoding ASCII -Value 'fixture'
    Set-Content -LiteralPath (Join-Path $fixtureAmxx 'plugins\mm_classic_test.amxx') -Encoding ASCII -Value 'fixture'
    Set-Content -LiteralPath (Join-Path $fixtureAmxx 'configs\mm_solo_test.cfg') -Encoding ASCII -Value 'yb_quota "0"'

    & (Join-Path $repoRoot 'scripts\enable-test-bots.ps1') -ServerDir $fixtureRoot
    & (Join-Path $repoRoot 'scripts\enable-test-bots.ps1') -ServerDir $fixtureRoot
    $enabledMeta = @(Get-Content -LiteralPath $fixtureMeta | Where-Object { $_ -eq 'win32 addons\yapb\bin\yapb.dll' })
    $enabledAmxx = @(Get-Content -LiteralPath (Join-Path $fixtureAmxx 'configs\plugins.ini') | Where-Object { $_ -eq 'mm_classic_test.amxx ; DEVELOPMENT ONLY' })
    if ($enabledMeta.Count -ne 1 -or $enabledAmxx.Count -ne 1) { throw 'Solo-bot check failed: enable must be idempotent.' }

    & (Join-Path $repoRoot 'scripts\disable-test-bots.ps1') -ServerDir $fixtureRoot
    & (Join-Path $repoRoot 'scripts\disable-test-bots.ps1') -ServerDir $fixtureRoot
    $disabledText = (Get-Content -LiteralPath $fixtureMeta -Raw) + (Get-Content -LiteralPath (Join-Path $fixtureAmxx 'configs\plugins.ini') -Raw) + (Get-Content -LiteralPath (Join-Path $fixtureCstrike 'server.cfg') -Raw)
    if ($disabledText -match 'yapb|mm_classic_test|mm_solo_test') { throw 'Solo-bot check failed: disable must remove every development registration.' }
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) { [IO.Directory]::Delete($fixtureRoot, $true) }
}

Write-Host 'All optional solo-bot isolation checks passed.'
