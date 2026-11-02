#include <amxmodx>
#include <fakemeta>
#include <reapi>

new const PLUGIN_NAME[] = "Torbeshi Weapon Tuning"
new const PLUGIN_VERSION[] = "1.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new const MM_CONFIG[] = "addons/amxmodx/configs/mm_weapon_tuning.cfg"

// Rifles, pistols, SMGs and M249 only. Shotguns and sniper rifles stay native.
const MM_TUNED_WEAPONS = (1<<CSW_P228) | (1<<CSW_MAC10) | (1<<CSW_AUG)
    | (1<<CSW_ELITE) | (1<<CSW_FIVESEVEN) | (1<<CSW_UMP45) | (1<<CSW_GALIL)
    | (1<<CSW_FAMAS) | (1<<CSW_USP) | (1<<CSW_GLOCK18) | (1<<CSW_MP5NAVY)
    | (1<<CSW_M249) | (1<<CSW_M4A1) | (1<<CSW_TMP) | (1<<CSW_DEAGLE)
    | (1<<CSW_SG552) | (1<<CSW_AK47) | (1<<CSW_P90)

new g_enabled, g_spread_scale, g_recoil_scale, g_spread_changes, g_recoil_changes

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    if (!is_regamedll())
    {
        set_fail_state("ReGameDLL is required for weapon tuning")
        return
    }
    g_enabled = register_cvar("mm_weapon_tuning", "1")
    g_spread_scale = register_cvar("mm_weapon_spread_scale", "0.80")
    g_recoil_scale = register_cvar("mm_weapon_recoil_scale", "0.85")
    RegisterHookChain(RG_CBaseEntity_FireBullets3, "mm_fire_bullets_pre", false)
    RegisterHookChain(RG_CBasePlayerWeapon_KickBack, "mm_kickback_pre", false)
    register_srvcmd("mm_weapon_tuning_status", "mm_tuning_status")
    log_amx("%s v%s initialized; modest stationary accuracy and recoil preset.", PLUGIN_NAME, PLUGIN_VERSION)
}

public plugin_cfg()
{
    if (file_exists(MM_CONFIG))
    {
        server_cmd("exec %s", MM_CONFIG)
        server_exec()
    }
}

bool:mm_stationary_weapon(id)
{
    if (!get_pcvar_num(g_enabled) || id < 1 || id > MaxClients || !is_user_alive(id)) return false
    new weapon = get_user_weapon(id)
    if (weapon < 1 || weapon > 30 || !(MM_TUNED_WEAPONS & (1<<weapon))) return false
    if (!(pev(id, pev_flags) & FL_ONGROUND)) return false
    new Float:velocity[3]
    pev(id, pev_velocity, velocity)
    return velocity[0]*velocity[0] + velocity[1]*velocity[1] <= 100.0
}

public mm_fire_bullets_pre(id, Float:source[3], Float:direction[3], Float:spread,
    Float:distance, penetration, bullet_type, damage, Float:range_modifier, attacker,
    bool:pistol, random_seed)
{
    if (!mm_stationary_weapon(id)) return HC_CONTINUE
    new Float:scale = floatclamp(get_pcvar_float(g_spread_scale), 0.50, 1.0)
    if (scale < 1.0)
    {
        SetHookChainArg(4, ATYPE_FLOAT, spread * scale)
        g_spread_changes++
    }
    return HC_CONTINUE
}

public mm_kickback_pre(weapon, Float:up_base, Float:lateral_base, Float:up_modifier,
    Float:lateral_modifier, Float:up_max, Float:lateral_max, direction_change)
{
    if (!pev_valid(weapon)) return HC_CONTINUE
    new id = get_member(weapon, m_pPlayer)
    if (!mm_stationary_weapon(id)) return HC_CONTINUE
    new Float:scale = floatclamp(get_pcvar_float(g_recoil_scale), 0.50, 1.0)
    if (scale < 1.0)
    {
        SetHookChainArg(2, ATYPE_FLOAT, up_base * scale)
        SetHookChainArg(3, ATYPE_FLOAT, lateral_base * scale)
        SetHookChainArg(4, ATYPE_FLOAT, up_modifier * scale)
        SetHookChainArg(5, ATYPE_FLOAT, lateral_modifier * scale)
        SetHookChainArg(6, ATYPE_FLOAT, up_max * scale)
        SetHookChainArg(7, ATYPE_FLOAT, lateral_max * scale)
        g_recoil_changes++
    }
    return HC_CONTINUE
}

public mm_tuning_status()
{
    server_print("[Tuning] enabled=%d spread_scale=%.2f recoil_scale=%.2f spread_shots=%d recoil_shots=%d", get_pcvar_num(g_enabled), get_pcvar_float(g_spread_scale), get_pcvar_float(g_recoil_scale), g_spread_changes, g_recoil_changes)
}
