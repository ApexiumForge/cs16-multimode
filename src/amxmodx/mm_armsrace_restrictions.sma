#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <mm_mode_api>

new const PLUGIN_NAME[] = "Multi-Mode Arms Race Restrictions"
new const PLUGIN_VERSION[] = "1.2.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new Float:g_next_notice[33]
new g_pickups, g_purchases
new g_map_grants

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    // Block world containers, preserving give_item used by mode progression.
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
    register_srvcmd("mm_armsrace_restrictions_status", "mm_status")
    log_amx("Arms Race world pickups and purchases restricted; progression grants preserved.")
}

public client_disconnected(id) g_next_notice[id] = 0.0

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
    return mm_get_active_mode() == MM_MODE_ARMS_RACE
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
    client_print_color(id, print_team_default, "^4[Arms Race]^1 Buying is disabled. Earn your next weapon with kills.")
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
    server_print("[MM AR Restrictions] version=%s active=%d pickups_blocked=%d purchases_blocked=%d map_equipment_blocked=%d", PLUGIN_VERSION, mm_restricted(), g_pickups, g_purchases, g_map_grants)
}

// Blocks engine CT USP / T Glock spawn grants; progression supplies its own loadout.
public mm_default_items(id)
{
    return mm_restricted() ? HC_SUPERCEDE : HC_CONTINUE
}
