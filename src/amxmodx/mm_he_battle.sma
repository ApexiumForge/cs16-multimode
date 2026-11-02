#include <amxmodx>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <reapi>
#include <mm_mode_api>

new const PLUGIN_NAME[] = "Multi-Mode HE Battle"
new const PLUGIN_VERSION[] = "1.0.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new Float:g_next_notice[33]
new g_pickups, g_purchases
#define MM_HE_TICK 891000
#define MM_HE_RESPAWN 891100
#define MM_HE_LOADOUT 891200
new bool:g_enabled
new g_map_grants

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    RegisterHam(Ham_Spawn, "player", "mm_spawn_post", 1)
    RegisterHam(Ham_Killed, "player", "mm_killed_post", 1)
    register_clcmd("drop", "mm_buy_command")
    // Block map weapon containers; our explicit grenade grants are preserved.
    RegisterHam(Ham_Touch, "armoury_entity", "mm_world_touch")
    RegisterHam(Ham_Touch, "weaponbox", "mm_world_touch")
    RegisterHam(Ham_Touch, "weapon_shield", "mm_world_touch")
    // Spawn-triggered map equipment bypasses world pickup touches.
    RegisterHam(Ham_Use, "game_player_equip", "mm_map_equipment_use")
    RegisterHam(Ham_Touch, "game_player_equip", "mm_map_equipment_touch")
    RegisterHam(Ham_Use, "player_weaponstrip", "mm_map_equipment_use")
    RegisterHookChain(RG_CBasePlayer_GiveDefaultItems, "mm_default_items", false)
    RegisterHookChain(RG_BuyWeaponByWeaponID, "mm_buy_weapon", false)
    RegisterHookChain(RG_BuyGunAmmo, "mm_buy_ammo", false)
    RegisterHookChain(RG_BuyItem, "mm_buy_item", false)
    new const commands[][] = {"buy", "buyequip", "autobuy", "rebuy", "cl_autobuy", "cl_rebuy", "buyammo1", "buyammo2"}
    for (new i = 0; i < sizeof commands; i++) register_clcmd(commands[i], "mm_buy_command")
    register_srvcmd("mm_he_battle_status", "mm_status")
    log_amx("HE Battle initialized: HE-only loadout, unlimited grenades and respawning.")
}

public client_disconnected(id)
{
    g_next_notice[id] = 0.0
    remove_task(MM_HE_RESPAWN + id)
    remove_task(MM_HE_LOADOUT + id)
}

public mm_map_equipment_use(entity, caller, activator, use_type, Float:value)
{
    if (!mm_restricted()) return HAM_IGNORED
    g_map_grants++
    return HAM_SUPERCEDE
}

public mm_map_equipment_touch(entity, id)
{
    if (!mm_restricted()) return HAM_IGNORED
    g_map_grants++
    return HAM_SUPERCEDE
}

bool:mm_restricted()
{
    return mm_get_active_mode() == MM_MODE_HE_BATTLE
}

public mm_world_touch(entity, id)
{
    if (!mm_restricted() || id < 1 || id > MaxClients || !is_user_alive(id)) return HAM_IGNORED
    g_pickups++
    return HAM_SUPERCEDE
}

mm_notice(id)
{
    if (id < 1 || id > MaxClients || !is_user_connected(id)) return
    new Float:now = get_gametime()
    if (now < g_next_notice[id]) return
    g_next_notice[id] = now + 2.0
    client_print_color(id, print_team_default, "^4[HE Battle]^1 Buying is disabled. HE grenades replenish automatically.")
}

public mm_buy_command(id)
{
    if (!mm_restricted()) return PLUGIN_CONTINUE
    mm_notice(id)
    return PLUGIN_HANDLED
}

public mm_buy_weapon(id, WeaponIdType:weapon)
{
    if (!mm_restricted()) return HC_CONTINUE
    g_purchases++
    mm_notice(id)
    SetHookChainReturn(ATYPE_INTEGER, 0)
    return HC_SUPERCEDE
}

public mm_buy_ammo(id, weapon, bool:blink)
{
    if (!mm_restricted()) return HC_CONTINUE
    g_purchases++
    mm_notice(id)
    SetHookChainReturn(ATYPE_BOOL, false)
    return HC_SUPERCEDE
}

public mm_buy_item(id, slot)
{
    if (!mm_restricted()) return HC_CONTINUE
    g_purchases++
    mm_notice(id)
    return HC_SUPERCEDE
}

public mm_status()
{
    server_print("[MM HE Battle] version=%s active=%d pickups_blocked=%d purchases_blocked=%d map_equipment_blocked=%d", PLUGIN_VERSION, mm_restricted(), g_pickups, g_purchases, g_map_grants)
}

// The mode supplies its own grenades instead of engine spawn weapons.
public mm_default_items(id)
{
    return mm_restricted() ? HC_SUPERCEDE : HC_CONTINUE
}

public plugin_cfg()
{
    if (mm_restricted()) mm_activate()
}

public mm_mode_transition_started(old_mode, requested_mode)
{
    if (MmMode:old_mode == MM_MODE_HE_BATTLE) mm_shutdown()
}

public mm_mode_changed(old_mode, new_mode)
{
    if (MmMode:new_mode == MM_MODE_HE_BATTLE) mm_activate()
    else if (g_enabled) mm_shutdown()
}

mm_activate()
{
    mm_shutdown()
    g_enabled = true
    set_task(0.2, "mm_supply", MM_HE_TICK, "", 0, "b")
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!mm_playing(id)) continue
        if (is_user_alive(id)) mm_loadout(id)
        else set_task(1.0, "mm_respawn", MM_HE_RESPAWN + id)
    }
    client_print_color(0, print_team_default, "^4[HE Battle]^1 HE grenades only! Your grenades replenish automatically.")
}

mm_shutdown()
{
    remove_task(MM_HE_TICK)
    for (new id = 1; id <= MaxClients; id++)
    {
        remove_task(MM_HE_RESPAWN + id)
        remove_task(MM_HE_LOADOUT + id)
        if (g_enabled && is_user_alive(id))
        {
            rg_remove_item(id, "weapon_hegrenade", true)
            if (!user_has_weapon(id, CSW_KNIFE)) give_item(id, "weapon_knife")
        }
    }
    g_enabled = false
}

bool:mm_playing(id)
{
    if (!is_user_connected(id)) return false
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

public mm_spawn_post(id)
{
    if (!g_enabled || !mm_restricted() || !is_user_alive(id)) return HAM_IGNORED
    remove_task(MM_HE_RESPAWN + id)
    remove_task(MM_HE_LOADOUT + id)
    set_task(0.1, "mm_spawn_loadout", MM_HE_LOADOUT + id)
    return HAM_IGNORED
}

public mm_spawn_loadout(task)
{
    new id = task - MM_HE_LOADOUT
    if (g_enabled && mm_restricted() && is_user_alive(id) && mm_playing(id)) mm_loadout(id)
}

mm_loadout(id)
{
    strip_user_weapons(id)
    give_item(id, "weapon_hegrenade")
    cs_set_user_bpammo(id, CSW_HEGRENADE, 2)
    engclient_cmd(id, "weapon_hegrenade")
}

public mm_supply()
{
    if (!g_enabled || !mm_restricted() || mm_get_transition_state() != MM_TRANSITION_IDLE) return
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id) || !mm_playing(id)) continue
        new weapons[32], count, bool:extra
        get_user_weapons(id, weapons, count)
        for (new i = 0; i < count; i++)
            if (weapons[i] != CSW_HEGRENADE) extra = true
        if (extra || !user_has_weapon(id, CSW_HEGRENADE)) mm_loadout(id)
        else if (cs_get_user_bpammo(id, CSW_HEGRENADE) < 2) cs_set_user_bpammo(id, CSW_HEGRENADE, 2)
    }
}

public mm_killed_post(victim, attacker, gib)
{
    if (!g_enabled || !mm_restricted() || !mm_playing(victim)) return HAM_IGNORED
    remove_task(MM_HE_LOADOUT + victim)
    remove_task(MM_HE_RESPAWN + victim)
    set_task(1.0, "mm_respawn", MM_HE_RESPAWN + victim)
    return HAM_IGNORED
}

public mm_respawn(task)
{
    new id = task - MM_HE_RESPAWN
    if (g_enabled && mm_restricted() && mm_get_transition_state() == MM_TRANSITION_IDLE && mm_playing(id) && !is_user_alive(id))
        ExecuteHamB(Ham_CS_RoundRespawn, id)
}

public plugin_end() mm_shutdown()
