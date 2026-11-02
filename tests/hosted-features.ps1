[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Read-ProjectFile([string]$RelativePath) {
    Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
}
function Assert-Match([string]$Text, [string]$Pattern, [string]$Description) {
    if ($Text -notmatch $Pattern) { throw "Hosted-feature check failed: $Description" }
}

$api = Read-ProjectFile 'src\amxmodx\include\mm_mode_api.inc'
$rounds = Read-ProjectFile 'src\amxmodx\mm_arcade_rounds.sma'
$he = Read-ProjectFile 'src\amxmodx\mm_he_battle.sma'
$protection = Read-ProjectFile 'src\amxmodx\mm_arcade_protection.sma'
$knife = Read-ProjectFile 'src\amxmodx\mm_knife.sma'
$arms = Read-ProjectFile 'src\amxmodx\mm_armsrace.sma'
$restrictions = Read-ProjectFile 'src\amxmodx\mm_armsrace_restrictions.sma'
$spawns = Read-ProjectFile 'src\amxmodx\mm_random_spawns.sma'
$tuning = Read-ProjectFile 'src\amxmodx\mm_weapon_tuning.sma'
$build = Read-ProjectFile 'scripts\build-plugins.ps1'
$installer = Read-ProjectFile 'scripts\install-reapi.ps1'

Assert-Match $api 'MM_MODE_HE_BATTLE' 'The shared mode contract must expose HE Battle.'
Assert-Match $api 'MM_MODE_KNIFE' 'The shared mode contract must expose Knife 35HP.'
Assert-Match $rounds 'mode == MM_MODE_HE_BATTLE' 'The shared continuous-round controller must include HE Battle.'
Assert-Match $he 'mm_get_active_mode\(\) == MM_MODE_HE_BATTLE' 'HE mechanics must remain mode-isolated.'
Assert-Match $he 'mm_mode_transition_started[\s\S]*mm_shutdown\(\)' 'HE Battle must clean up at transition start.'
Assert-Match $he 'remove_task\(MM_HE_TICK\)' 'HE Battle must remove its supply task on shutdown.'
Assert-Match $he 'remove_task\(MM_HE_RESPAWN \+ id\)' 'HE Battle must remove pending respawns.'
Assert-Match $he 'RegisterHookChain\(RG_CBasePlayer_GiveDefaultItems' 'HE Battle must suppress engine default weapons.'
Assert-Match $he 'cs_set_user_bpammo\(id, CSW_HEGRENADE, 2\)' 'HE Battle must replenish grenade ammunition.'
Assert-Match $he 'mm_he_kill_limit", "30"' 'HE Battle must expose its default enemy-kill limit.'
Assert-Match $he 'cs_get_user_team\(attacker\) == cs_get_user_team\(victim\)' 'HE Battle must protect allies under shared FFA policy.'

Assert-Match $protection 'MM_MODE_ARMS_RACE \|\| mode == MM_MODE_HE_BATTLE' 'Shared protection must remain limited to Arms Race and HE Battle.'
Assert-Match $protection 'IN_ATTACK \| IN_ATTACK2' 'Attacking must cancel arcade spawn protection.'
Assert-Match $protection 'mm_mode_transition_started[\s\S]*arrayset' 'Mode transitions must clear protection state.'

Assert-Match $knife 'mm_get_active_mode\(\) == MM_MODE_KNIFE' 'Knife mechanics must remain mode-isolated.'
Assert-Match $knife 'set_user_health\(id, 35\)' 'Knife mode must enforce 35 HP.'
Assert-Match $knife 'RegisterHookChain\(RG_CBasePlayer_GiveDefaultItems' 'Knife mode must suppress default spawn weapons.'
Assert-Match $knife 'mm_voting_admin_change' 'Knife map routing must use the centralized voting API.'
Assert-Match $knife 'remove_task\(MM_KNIFE_SUPPLY\)' 'Knife shutdown must remove its repeating enforcement task.'

Assert-Match $arms 'g_level_kills\[attacker\] < 2' 'Gun progression must require two valid kills.'
Assert-Match $arms 'if \(g_level\[victim\] > 0\) g_level\[victim\]--' 'Knife deaths must remove one victim level without underflow.'
Assert-Match $restrictions 'mm_get_active_mode\(\) == MM_MODE_ARMS_RACE' 'Arms Race restrictions must remain mode-isolated.'
Assert-Match $restrictions 'RegisterHookChain\(RG_BuyWeaponByWeaponID' 'Engine-level purchases must be blocked.'
Assert-Match $restrictions 'RegisterHam\(Ham_Touch, "weaponbox"' 'World weapon boxes must be blocked.'

Assert-Match $spawns 'mode == MM_MODE_DEATHMATCH \|\| mode == MM_MODE_ARMS_RACE \|\| mode == MM_MODE_HE_BATTLE' 'Distributed spawns must remain limited to DM, Arms Race, and HE Battle.'
Assert-Match $spawns 'mm_get_transition_state\(\) != MM_TRANSITION_IDLE' 'Distributed spawns must stop during transitions.'
Assert-Match $spawns 'mm_hazard\(point\)' 'Distributed spawns must reject trigger_hurt areas.'
Assert-Match $spawns 'TraceHull' 'Distributed spawns must perform player-hull clearance checks.'

Assert-Match $tuning '#include <reapi>' 'Weapon tuning must declare its ReAPI dependency.'
Assert-Match $tuning 'RG_CBaseEntity_FireBullets3' 'Weapon tuning must adjust server-side bullet spread.'
Assert-Match $tuning 'RG_CBasePlayerWeapon_KickBack' 'Weapon tuning must adjust server-side recoil.'
Assert-Match $tuning 'FL_ONGROUND' 'Weapon tuning must require a grounded player.'
Assert-Match $installer "5\.29\.0\.358" 'The ReAPI installer must pin an explicit official release.'
Assert-Match $installer 'F33A7435540BEA8706DB3FA948E51A85B511F5B18C383B97402A204DC5419195' 'The official ReAPI archive must be checksum-pinned.'

foreach ($plugin in @('mm_he_battle', 'mm_arcade_protection', 'mm_knife', 'mm_armsrace_restrictions', 'mm_random_spawns', 'mm_weapon_tuning')) {
    Assert-Match $build "Name = '$plugin'" "$plugin must be included in the reproducible build."
    Assert-Match $build "'$plugin\.amxx'" "$plugin must be registered in generated plugins.ini."
}
Assert-Match $build 'mm_weapon_tuning\.cfg' 'The weapon tuning configuration must be deployed.'
Assert-Match $build 'mm_rules\.html' 'The rules MOTD must be deployed.'

Write-Host 'All hosted-feature architecture and lifecycle checks passed.'
