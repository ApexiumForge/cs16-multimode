[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$warmup = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_warmup_money.sma') -Raw
$crosshair = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_crosshair.sma') -Raw
$skins = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\optional\mm_skins.sma') -Raw
$announcer = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\optional\mm_announcer.sma') -Raw
$build = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\build-plugins.ps1') -Raw
$spriteDir = Join-Path $repoRoot 'config\cstrike\sprites'

function Assert-Match([string]$Text, [string]$Pattern, [string]$Description) {
    if ($Text -notmatch $Pattern) { throw "Remote-sync check failed: $Description" }
}

Assert-Match $warmup 'mm_get_active_mode\(\) != MM_MODE_CLASSIC' 'Practice money must remain Classic-only.'
Assert-Match $warmup 'mm_get_transition_state\(\) != MM_TRANSITION_IDLE' 'Practice money must stop during mode transitions.'
Assert-Match $warmup 'mm_classic_change_blocked\(\)' 'Practice money must not run during a committed match.'
Assert-Match $warmup 'MM_CLASSIC_WAITING.*MM_CLASSIC_WARMUP.*MM_CLASSIC_READY' 'Only practice lifecycle states may receive money.'
Assert-Match $warmup 'clamp\(get_pcvar_num\(g_money_cvar\), 0, MAX_CS_MONEY\)' 'Configured money must be clamped to the CS limit.'
Assert-Match $warmup 'team != CS_TEAM_T && team != CS_TEAM_CT' 'Spectators must not receive practice money.'

Assert-Match $crosshair 'register_clcmd\("say /crosshair"' 'The crosshair menu command must exist.'
Assert-Match $crosshair 'is_user_bot\(id\)' 'Bots must not receive the crosshair menu.'
Assert-Match $crosshair 'g_fov\[id\] != 90' 'Scoped weapons must preserve their native FOV behavior.'
Assert-Match $crosshair 'CSW_AWP.*CSW_SCOUT.*CSW_G3SG1' 'Sniper weapons must be excluded from custom reticles.'
Assert-Match $crosshair 'nvault_open\("mm_crosshair"\)' 'Preferences must use the isolated nVault keyspace.'
Assert-Match $crosshair 'mm_stable_auth' 'Only stable player identities may persist preferences.'

Assert-Match $skins 'models/player/mm_ct_hd/mm_ct_hd\.mdl' 'Optional CT model path must stay namespaced.'
Assert-Match $skins 'models/player/mm_t_hd/mm_t_hd\.mdl' 'Optional T model path must stay namespaced.'
Assert-Match $skins 'models/multimode/v_butterfly_lore\.mdl' 'Optional knife model path must stay namespaced.'
if ($build -match "Name = 'mm_skins'") { throw 'Remote-sync check failed: resource-dependent skins must not enter the default production build.' }

Assert-Match $announcer 'multimode/doublekill\.wav' 'Optional announcer sound path must stay namespaced.'
Assert-Match $announcer 'mm_mode_transition_started' 'Optional announcer must clear transient sequences during mode transitions.'
Assert-Match $announcer 'victim == attacker' 'Optional announcer must reject suicides.'
Assert-Match $announcer 'MM_MODE_CLASSIC' 'Optional announcer must preserve Classic team-kill rules.'
if ($build -match "Name = 'mm_announcer'") { throw 'Remote-sync check failed: the resource-dependent announcer must not enter the default production build.' }

$expected = @()
foreach ($version in @('v1', 'v3')) {
    $lastShape = if ($version -eq 'v1') { 3 } else { 4 }
    foreach ($shape in 0..$lastShape) {
        foreach ($color in 0..4) {
            $expected += "mm_xh_${version}_${shape}_${color}.spr"
            $expected += "mm_xh_${version}_${shape}_${color}.txt"
        }
    }
}
$actual = @(Get-ChildItem -LiteralPath $spriteDir -Filter 'mm_xh_v*' -File | Select-Object -ExpandProperty Name | Sort-Object)
if (Compare-Object ($expected | Sort-Object) $actual) {
    throw 'Remote-sync check failed: the tracked crosshair resource set is incomplete or contains unexpected files.'
}
if ($actual | Where-Object { $_ -like '*.ztmp' }) {
    throw 'Remote-sync check failed: generated .ztmp cache files must not be tracked.'
}
foreach ($descriptor in Get-ChildItem -LiteralPath $spriteDir -Filter 'mm_xh_v*.txt' -File) {
    $stem = [IO.Path]::GetFileNameWithoutExtension($descriptor.Name)
    $text = Get-Content -LiteralPath $descriptor.FullName -Raw
    if ($text -notmatch [regex]::Escape($stem)) {
        throw "Remote-sync check failed: sprite descriptor does not reference its matching sprite: $($descriptor.Name)"
    }
}

Assert-Match $build "Name = 'mm_warmup_money'" 'The practice-money plugin must be built.'
Assert-Match $build "Name = 'mm_crosshair'" 'The crosshair plugin must be built.'
Assert-Match $build "Get-ChildItem[^\r\n]+mm_xh_v\*" 'Versioned crosshair resources must be copied by the build.'
Assert-Match $build "'mm_arcade_protection\.amxx', 'mm_knife\.amxx', 'mm_football\.amxx', 'mm_mode_maps\.amxx', 'mm_voting\.amxx', 'mm_admin\.amxx'" 'Generated plugin order must include gameplay, shared map routing, voting, and administration.'
Assert-Match $build "'mm_admin\.amxx', 'mm_warmup_money\.amxx', 'mm_random_spawns\.amxx', 'mm_weapon_tuning\.amxx', 'mm_crosshair\.amxx'" 'Generated plugin order must include the synchronized modules.'

Write-Host 'All remote-only module synchronization checks passed.'
