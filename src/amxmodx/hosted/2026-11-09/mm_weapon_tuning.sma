#include <amxmodx>
#include <fakemeta>
#include <reapi>

new const PLUGIN_NAME[] = "Torbeshi Weapon Tuning"
new const PLUGIN_VERSION[] = "1.5"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new const MM_CONFIG[] = "addons/amxmodx/configs/mm_weapon_tuning.cfg"

// Rifles, pistols, SMGs and M249 only. Shotguns and sniper rifles stay native.
const MM_TUNED_WEAPONS = (1<<CSW_P228) | (1<<CSW_MAC10) | (1<<CSW_AUG)
    | (1<<CSW_ELITE) | (1<<CSW_FIVESEVEN) | (1<<CSW_UMP45) | (1<<CSW_GALIL)
    | (1<<CSW_FAMAS) | (1<<CSW_USP) | (1<<CSW_GLOCK18) | (1<<CSW_MP5NAVY)
    | (1<<CSW_M249) | (1<<CSW_M4A1) | (1<<CSW_TMP) | (1<<CSW_DEAGLE)
    | (1<<CSW_SG552) | (1<<CSW_AK47) | (1<<CSW_P90)
const MM_SMG_WEAPONS = (1<<CSW_MAC10) | (1<<CSW_UMP45) | (1<<CSW_MP5NAVY) | (1<<CSW_TMP) | (1<<CSW_P90)

new g_move_scale, g_moving_changes, g_moving_recoil_changes
new g_enabled, g_spread_scale, g_recoil_scale, g_spread_changes, g_recoil_changes
new g_smg_spread, g_smg_moving_spread, g_smg_recoil, g_smg_shots, g_smg_recoil_shots
new g_burst_enabled, g_burst_size, g_burst_gap, g_burst_spread, g_burst_move_spread, g_burst_recoil
new g_burst_count[33], g_burst_weapon[33], g_burst_shots, g_burst_recoil_shots
new Float:g_last_shot[33]
new bool:g_burst_shot[33]
new g_settled_speed

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    if (!is_regamedll())
    {
        set_fail_state("ReGameDLL is required for weapon tuning")
        return
    }
    g_enabled = register_cvar("mm_weapon_tuning", "1")
    g_move_scale = register_cvar("mm_weapon_moving_spread_scale", "0.60")
    g_spread_scale = register_cvar("mm_weapon_spread_scale", "0.80")
    g_recoil_scale = register_cvar("mm_weapon_recoil_scale", "0.60")
    g_smg_spread = register_cvar("mm_weapon_smg_spread_scale", "0.50")
    g_smg_moving_spread = register_cvar("mm_weapon_smg_moving_spread_scale", "0.50")
    g_smg_recoil = register_cvar("mm_weapon_smg_recoil_scale", "0.50")
    g_burst_enabled = register_cvar("mm_weapon_burst_tuning", "1")
    g_burst_size = register_cvar("mm_weapon_burst_shots", "3")
    g_burst_gap = register_cvar("mm_weapon_burst_reset", "0.25")
    g_burst_spread = register_cvar("mm_weapon_burst_spread_scale", "0.35")
    g_burst_move_spread = register_cvar("mm_weapon_burst_moving_spread_scale", "0.40")
    g_burst_recoil = register_cvar("mm_weapon_burst_recoil_scale", "0.40")
    g_settled_speed = register_cvar("mm_weapon_settled_speed", "20.0")
    RegisterHookChain(RG_CBaseEntity_FireBullets3, "mm_fire_bullets_pre", false)
    RegisterHookChain(RG_CBasePlayerWeapon_KickBack, "mm_kickback_pre", false)
    register_srvcmd("mm_weapon_tuning_status", "mm_tuning_status")
    register_srvcmd("mm_weapon_burst_selftest", "mm_burst_selftest")
    log_amx("%s v%s initialized; stationary accuracy/recoil and grounded movement spread tuning.", PLUGIN_NAME, PLUGIN_VERSION)
}

public client_putinserver(id) mm_reset_burst(id)
public client_disconnected(id) mm_reset_burst(id)

mm_reset_burst(id)
{
    g_burst_count[id] = 0; g_burst_weapon[id] = 0
    g_last_shot[id] = 0.0; g_burst_shot[id] = false
}

bool:mm_opening_shot(shots, weapon, previous_weapon, Float:elapsed, Float:gap, size, &next_shots)
{
    next_shots = weapon != previous_weapon || elapsed >= gap ? 1 : shots+1
    return next_shots <= size
}

public plugin_cfg()
{
    if (file_exists(MM_CONFIG))
    {
        server_cmd("exec %s", MM_CONFIG)
        server_exec()
    }
}

bool:mm_grounded_weapon(id)
{
    if (!get_pcvar_num(g_enabled) || id < 1 || id > MaxClients || !is_user_alive(id)) return false
    new item = get_member(id, m_pActiveItem)
    if (is_nullent(item)) return false
    new weapon = get_member(item, m_iId)
    if (weapon < 1 || weapon > 30 || !(MM_TUNED_WEAPONS & (1<<weapon))) return false
    if (!(pev(id, pev_flags) & FL_ONGROUND)) return false
    return true
}

public mm_fire_bullets_pre(id, Float:source[3], Float:direction[3], Float:spread,
    Float:distance, penetration, bullet_type, damage, Float:range_modifier, attacker,
    bool:pistol, random_seed)
{
    if (!mm_grounded_weapon(id)) return HC_CONTINUE
    new bool:moving = mm_is_moving(id)
    new item = get_member(id, m_pActiveItem)
    new bool:smg = (MM_SMG_WEAPONS & (1<<get_member(item, m_iId))) != 0
    new scale_cvar = smg ? (moving ? g_smg_moving_spread : g_smg_spread) : (moving ? g_move_scale : g_spread_scale)
    new Float:scale = floatclamp(get_pcvar_float(scale_cvar), 0.50, 1.0)
    new Float:now = get_gametime(), next_shots
    new bool:opening = mm_opening_shot(g_burst_count[id], get_member(item, m_iId), g_burst_weapon[id], now-g_last_shot[id], floatclamp(get_pcvar_float(g_burst_gap), 0.15, 1.0), clamp(get_pcvar_num(g_burst_size), 1, 5), next_shots)
    g_burst_count[id] = next_shots
    g_burst_weapon[id] = get_member(item, m_iId)
    g_last_shot[id] = now
    g_burst_shot[id] = opening && get_pcvar_num(g_burst_enabled) != 0
    if (g_burst_shot[id])
    {
        scale = floatmin(scale, floatclamp(get_pcvar_float(moving ? g_burst_move_spread : g_burst_spread), 0.25, 1.0))
        g_burst_shots++
    }
    if (scale < 1.0)
    {
        SetHookChainArg(4, ATYPE_FLOAT, spread * scale)
        g_spread_changes++
        if (moving) g_moving_changes++
        if (smg) g_smg_shots++
    }
    return HC_CONTINUE
}

public mm_kickback_pre(weapon, Float:up_base, Float:lateral_base, Float:up_modifier,
    Float:lateral_modifier, Float:up_max, Float:lateral_max, direction_change)
{
    if (!pev_valid(weapon)) return HC_CONTINUE
    new id = get_member(weapon, m_pPlayer)
    if (!mm_grounded_weapon(id)) return HC_CONTINUE
    new bool:smg = (MM_SMG_WEAPONS & (1<<get_member(weapon, m_iId))) != 0
    new Float:scale = floatclamp(get_pcvar_float(smg ? g_smg_recoil : g_recoil_scale), 0.50, 1.0)
    if (g_burst_shot[id] && get_pcvar_num(g_burst_enabled) && get_gametime()-g_last_shot[id] < 0.05)
    {
        scale = floatmin(scale, floatclamp(get_pcvar_float(g_burst_recoil), 0.25, 1.0))
        g_burst_recoil_shots++
    }
    if (scale < 1.0)
    {
        SetHookChainArg(2, ATYPE_FLOAT, up_base * scale)
        SetHookChainArg(3, ATYPE_FLOAT, lateral_base * scale)
        SetHookChainArg(4, ATYPE_FLOAT, up_modifier * scale)
        SetHookChainArg(5, ATYPE_FLOAT, lateral_modifier * scale)
        SetHookChainArg(6, ATYPE_FLOAT, up_max * scale)
        SetHookChainArg(7, ATYPE_FLOAT, lateral_max * scale)
        g_recoil_changes++
        if (mm_is_moving(id)) g_moving_recoil_changes++
        if (smg) g_smg_recoil_shots++
    }
    return HC_CONTINUE
}

public mm_tuning_status()
{
    server_print("[Tuning] version=%s moving_recoil_shots=%d", PLUGIN_VERSION, g_moving_recoil_changes)
    server_print("[Tuning] moving_spread_scale=%.2f moving_shots=%d", get_pcvar_float(g_move_scale), g_moving_changes)
    server_print("[Tuning] enabled=%d spread_scale=%.2f recoil_scale=%.2f spread_shots=%d recoil_shots=%d", get_pcvar_num(g_enabled), get_pcvar_float(g_spread_scale), get_pcvar_float(g_recoil_scale), g_spread_changes, g_recoil_changes)
    server_print("[Tuning] SMG spread=%.2f moving=%.2f recoil=%.2f shots=%d recoil_shots=%d", get_pcvar_float(g_smg_spread), get_pcvar_float(g_smg_moving_spread), get_pcvar_float(g_smg_recoil), g_smg_shots, g_smg_recoil_shots)
    server_print("[Tuning] burst=%d first_shots=%d reset=%.2fs spread=%.2f moving=%.2f recoil=%.2f shots=%d recoil_shots=%d", get_pcvar_num(g_burst_enabled), get_pcvar_num(g_burst_size), get_pcvar_float(g_burst_gap), get_pcvar_float(g_burst_spread), get_pcvar_float(g_burst_move_spread), get_pcvar_float(g_burst_recoil), g_burst_shots, g_burst_recoil_shots)
    server_print("[Tuning] settled_speed=%.0f units/sec", get_pcvar_float(g_settled_speed))
}

bool:mm_is_moving(id)
{
    new Float:velocity[3]
    pev(id, pev_velocity, velocity)
    new Float:threshold = floatclamp(get_pcvar_float(g_settled_speed), 5.0, 40.0)
    return velocity[0]*velocity[0] + velocity[1]*velocity[1] > threshold*threshold
}

public mm_burst_selftest()
{
    new passed, next_shots
    if (mm_opening_shot(0, CSW_AK47, 0, 0.0, 0.25, 3, next_shots) && next_shots == 1) passed++
    if (mm_opening_shot(1, CSW_AK47, CSW_AK47, 0.1, 0.25, 3, next_shots) && next_shots == 2) passed++
    if (mm_opening_shot(2, CSW_AK47, CSW_AK47, 0.1, 0.25, 3, next_shots) && next_shots == 3) passed++
    if (!mm_opening_shot(3, CSW_AK47, CSW_AK47, 0.1, 0.25, 3, next_shots) && next_shots == 4) passed++
    if (!mm_opening_shot(8, CSW_AK47, CSW_AK47, 0.1, 0.25, 3, next_shots) && next_shots == 9) passed++
    if (mm_opening_shot(8, CSW_AK47, CSW_AK47, 0.25, 0.25, 3, next_shots) && next_shots == 1) passed++
    if (mm_opening_shot(8, CSW_USP, CSW_AK47, 0.1, 0.25, 3, next_shots) && next_shots == 1) passed++
    if (!mm_opening_shot(3, CSW_AK47, CSW_AK47, 0.24, 0.25, 3, next_shots) && next_shots == 4) passed++
    server_print("[Tuning Test] Burst sequencing passed %d/8 (opening shots, sustained spray, pause boundary, weapon switch).", passed)
}
