#include <amxmodx>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <mm_voting_api>
#include <reapi>
#include <mm_mode_api>
#include <mm_presentation_api>

new const PLUGIN_NAME[] = "Multi-Mode Knife 35HP"
new const PLUGIN_VERSION[] = "1.1.1"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new Float:g_next_notice[33]
new g_pickups, g_purchases
#define MM_KNIFE_LOADOUT 894100
#define MM_KNIFE_SUPPLY 894000
#define MM_KNIFE_ROUTE 894200
#define MM_KNIFE_HUD 894300
#define MM_KNIFE_RESET 894301
new bool:g_enabled
new g_added_spawns
new const MAP_POOLS[][] = {
    "addons/amxmodx/configs/mm_voting/maps_classic.ini",
    "addons/amxmodx/configs/mm_voting/maps_deathmatch.ini",
    "addons/amxmodx/configs/mm_voting/maps_armsrace.ini",
    "addons/amxmodx/configs/mm_voting/maps_awponly.ini",
    "addons/amxmodx/configs/mm_voting/maps_hebattle.ini",
    "addons/amxmodx/configs/mm_voting/maps_knife.ini"
}
new g_map_grants
new g_round_target, g_rounds[2], g_kills[33], g_deaths[33], g_hud
new bool:g_finished

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    RegisterHam(Ham_Use, "game_player_hurt", "mm_map_health_use")
    RegisterHam(Ham_Spawn, "player", "mm_spawn_post", 1)
    RegisterHam(Ham_TakeDamage, "player", "mm_damage_pre")
    RegisterHam(Ham_Killed, "player", "mm_killed_post", 1)
    register_event("SendAudio", "mm_t_win", "a", "2=%!MRAD_terwin")
    register_event("SendAudio", "mm_ct_win", "a", "2=%!MRAD_ctwin")
    register_clcmd("say /ktop", "mm_top")
    register_clcmd("say_team /ktop", "mm_top")
    register_clcmd("say /knifescore", "mm_score")
    register_clcmd("say_team /knifescore", "mm_score")
    g_round_target = register_cvar("mm_knife_round_target", "5")
    g_hud = CreateHudSyncObj()
    register_clcmd("drop", "mm_buy_command")
    // World equipment must not overwrite the knife loadout.
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
    register_srvcmd("mm_knife_status", "mm_status")
    log_amx("Knife 35HP initialized: team rounds, knife-only, no armor or buying.")
}

public client_disconnected(id)
{
    g_next_notice[id] = 0.0
    g_kills[id] = 0; g_deaths[id] = 0
    remove_task(MM_KNIFE_LOADOUT + id)
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
    return mm_get_active_mode() == MM_MODE_KNIFE
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
    client_print_color(id, print_team_red, "^4[Knife 35HP]^3 NOTICE^1 | Knives only. Buying and weapon dropping are disabled.")
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
    server_print("[MM Knife] extra_spawns=%d rounds=%d:%d target=%d finished=%d", g_added_spawns, g_rounds[0], g_rounds[1], get_pcvar_num(g_round_target), g_finished)
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id)) continue
        new item = get_member(id, m_pActiveItem)
        server_print("[MM Knife] player=%d team=%d health=%d hud_weapon=%d actual_weapon=%d", id, cs_get_user_team(id), get_user_health(id), get_user_weapon(id), is_nullent(item) ? 0 : get_member(item, m_iId))
    }
    server_print("[MM Knife] version=%s active=%d pickups_blocked=%d purchases_blocked=%d map_equipment_blocked=%d", PLUGIN_VERSION, mm_restricted(), g_pickups, g_purchases, g_map_grants)
}

// Blocks engine CT USP / T Glock spawn grants; progression supplies its own loadout.
public mm_default_items(id)
{
    return mm_restricted() ? HC_SUPERCEDE : HC_CONTINUE
}

public plugin_cfg()
{
    new map[32]
    get_mapname(map, charsmax(map))
    if (mm_pool_contains(_:MM_MODE_KNIFE, map))
    {
        mm_expand_spawns("info_player_start")
        mm_expand_spawns("info_player_deathmatch")
    }
    if (mm_restricted()) mm_activate()
}

public mm_mode_transition_started(old_mode, requested_mode)
{
    if (MmMode:old_mode == MM_MODE_KNIFE) mm_shutdown()
}

public mm_mode_changed(old_mode, new_mode)
{
    if (MmMode:new_mode == MM_MODE_KNIFE) mm_activate()
    else if (MmMode:old_mode == MM_MODE_KNIFE)
    {
        mm_shutdown()
        }
}

mm_activate()
{
    mm_shutdown()
    g_enabled = true
    g_finished = false
    arrayset(g_rounds, 0, sizeof g_rounds); arrayset(g_kills, 0, sizeof g_kills); arrayset(g_deaths, 0, sizeof g_deaths)
    set_task(1.0, "mm_hud", MM_KNIFE_HUD, _, _, "b")
    set_task(0.25, "mm_enforce", MM_KNIFE_SUPPLY, "", 0, "b")
    for (new id = 1; id <= MaxClients; id++) if (is_user_alive(id)) mm_loadout(id)
    client_print_color(0, print_team_grey, "^4[Knife 35HP]^3 First team to ^4%d rounds^3 wins. ^435 HP^3, no armor. ^1/knifescore^3 and ^1/ktop^3.", get_pcvar_num(g_round_target))
}

mm_shutdown()
{
    remove_task(MM_KNIFE_HUD); remove_task(MM_KNIFE_RESET)
    g_finished = false
    remove_task(MM_KNIFE_SUPPLY)
    remove_task(MM_KNIFE_ROUTE)
    for (new id = 1; id <= MaxClients; id++) remove_task(MM_KNIFE_LOADOUT + id)
    g_enabled = false
}

public plugin_end() mm_shutdown()

public mm_spawn_post(id)
{
    remove_task(MM_KNIFE_LOADOUT + id)
    if (mm_restricted() && is_user_alive(id)) set_task(0.2, "mm_spawn_loadout", MM_KNIFE_LOADOUT + id)
    return HAM_IGNORED
}

public mm_spawn_loadout(task)
{
    new id = task - MM_KNIFE_LOADOUT
    if (g_enabled && mm_restricted() && is_user_alive(id)) mm_loadout(id)
}

mm_loadout(id)
{
    rg_remove_all_items(id, false)
    give_item(id, "weapon_knife")
    set_user_health(id, 35)
    cs_set_user_armor(id, 0, CS_ARMOR_NONE)
    cs_set_user_defuse(id, 0)
    engclient_cmd(id, "weapon_knife")
}

public mm_enforce()
{
    if (!g_enabled || !mm_restricted() || mm_get_transition_state() != MM_TRANSITION_IDLE) return
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id)) continue
        new weapons[32], count, bool:extra
        get_user_weapons(id, weapons, count)
        for (new i = 0; i < count; i++) if (weapons[i] != CSW_KNIFE) extra = true
        // Preserve damage already taken when removing an unexpected item.
        new health = get_user_health(id)
        if (extra || !user_has_weapon(id, CSW_KNIFE)) {mm_loadout(id); set_user_health(id, min(health, 35));}
        else if (health > 35) set_user_health(id, 35)
        if (get_user_armor(id)) cs_set_user_armor(id, 0, CS_ARMOR_NONE)
    }
}

public mm_damage_pre(victim, inflictor, attacker, Float:damage, bits)
{
    if (!mm_restricted()) return HAM_IGNORED
    if (g_finished) return HAM_SUPERCEDE
    // Original 35hp maps drop players from high spawn platforms. HP is set explicitly here.
    if (bits & DMG_FALL) return HAM_SUPERCEDE
    if (attacker >= 1 && attacker <= MaxClients && attacker != victim && is_user_connected(attacker))
    {
        if (cs_get_user_team(attacker) == cs_get_user_team(victim)) return HAM_SUPERCEDE
        new active_item = get_member(attacker, m_pActiveItem)
        if (is_nullent(active_item) || get_member(active_item, m_iId) != WEAPON_KNIFE) return HAM_SUPERCEDE
    }
    return HAM_IGNORED
}

bool:mm_pool_contains(mode, const map[])
{
    new file = fopen(MAP_POOLS[mode], "rt"), line[64], bool:found
    if (!file) return false
    while (!feof(file))
    {
        fgets(file, line, charsmax(line)); trim(line)
        if (equali(line, map) && is_map_valid(line)) {found = true; break;}
    }
    fclose(file)
    return found
}

mm_expand_spawns(const classname[])
{
    new entities[32], count, entity
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", classname)) > 0)
        if (count < sizeof entities) entities[count++] = entity
    new original = count
    if (!original || count >= 16) return
    new Float:origin[3], Float:point[3], Float:bottom[3], Float:floor[3], Float:angles[3]
    new Float:normal[3]
    new trace = create_tr2()
    for (new i = 0; i < original && count < 16; i++)
    {
        pev(entities[i], pev_origin, origin); pev(entities[i], pev_angles, angles)
        for (new direction = 0; direction < 8 && count < 16; direction++)
        {
            point[0] = origin[0] + floatcos(float(direction) * 45.0, degrees) * 72.0
            point[1] = origin[1] + floatsin(float(direction) * 45.0, degrees) * 72.0
            point[2] = origin[2] + 32.0
            bottom[0] = point[0]; bottom[1] = point[1]; bottom[2] = origin[2] - 4096.0
            engfunc(EngFunc_TraceLine, point, bottom, IGNORE_MONSTERS, 0, trace)
            new Float:fraction; get_tr2(trace, TR_flFraction, fraction)
            if (fraction >= 1.0 || get_tr2(trace, TR_StartSolid)) continue
            get_tr2(trace, TR_vecPlaneNormal, normal)
            if (normal[2] < 0.75) continue
            get_tr2(trace, TR_vecEndPos, floor); floor[2] += 37.0
            if (engfunc(EngFunc_PointContents, floor) != CONTENTS_EMPTY) continue
            engfunc(EngFunc_TraceHull, floor, floor, IGNORE_MONSTERS, HULL_HUMAN, 0, trace)
            if (get_tr2(trace, TR_StartSolid) || get_tr2(trace, TR_AllSolid)) continue
            new bool:near
            for (new j = 0; j < count; j++)
            {
                pev(entities[j], pev_origin, bottom)
                if (get_distance_f(floor, bottom) < 64.0) {near = true; break;}
            }
            if (near) continue
            new added = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, classname))
            if (!pev_valid(added)) continue
            engfunc(EngFunc_SetOrigin, added, floor); set_pev(added, pev_angles, angles)
            dllfunc(DLLFunc_Spawn, added)
            entities[count++] = added; g_added_spawns++
        }
    }
    free_tr2(trace)
    log_amx("Knife spawn capacity %s: %d (original %d).", classname, count, original)
}

// Classic 35hp maps use a named 65-damage entity to lower a fresh 100 HP spawn.
// The mode supplies 35 HP itself, so only this redundant health setter is blocked.
public mm_map_health_use(entity, caller, activator, use_type, Float:value)
{
    if (!mm_restricted() || !pev_valid(entity)) return HAM_IGNORED
    new Float:damage
    pev(entity, pev_dmg, damage)
    if (damage >= 64.9 && damage <= 65.1)
    {
        g_map_grants++
        return HAM_SUPERCEDE
    }
    return HAM_IGNORED
}

public mm_killed_post(victim, attacker, gib)
{
    if (!g_enabled || !mm_restricted() || g_finished) return HAM_IGNORED
    if (victim >= 1 && victim <= MaxClients) g_deaths[victim]++
    if (attacker >= 1 && attacker <= MaxClients && attacker != victim && is_user_connected(attacker) && cs_get_user_team(attacker) != cs_get_user_team(victim)) g_kills[attacker]++
    return HAM_IGNORED
}
public mm_t_win() mm_round_win(0)
public mm_ct_win() mm_round_win(1)
mm_round_win(team)
{
    if (!g_enabled || !mm_restricted() || g_finished) return
    g_rounds[team]++
    client_print_color(0, team ? print_team_blue : print_team_red, "^4[Knife 35HP]^1 ^3%s^1 win the round! T ^4%d^1 : ^4%d^1 CT | First to ^4%d", team ? "CTs" : "Terrorists", g_rounds[0], g_rounds[1], get_pcvar_num(g_round_target))
    if (g_rounds[team] < clamp(get_pcvar_num(g_round_target), 1, 30)) return
    g_finished = true
    new players[32], count, detail[96]
    mm_rank_scores(g_kills, g_deaths, players, count)
    formatex(detail, charsmax(detail), "%s win! T %d : %d CT", team ? "CTs" : "Terrorists", g_rounds[0], g_rounds[1])
    mm_show_results(MM_MODE_KNIFE, count ? players[0] : 0, count > 1 ? players[1] : 0, count > 2 ? players[2] : 0, "KNIFE MATCH RESULTS", detail)
    set_task(6.0, "mm_reset_match", MM_KNIFE_RESET)
}
public mm_reset_match()
{
    if (!g_enabled || !mm_restricted()) return
    g_finished = false
    arrayset(g_rounds, 0, sizeof g_rounds); arrayset(g_kills, 0, sizeof g_kills); arrayset(g_deaths, 0, sizeof g_deaths)
    server_cmd("sv_restart 1")
}
public mm_top(id)
{
    if (!mm_restricted()) return PLUGIN_CONTINUE
    new players[32], count
    mm_rank_scores(g_kills, g_deaths, players, count)
    client_print_color(id, print_team_grey, "^4[Knife 35HP]^3 Match knife leaderboard:")
    for (new rank = 0; rank < min(count, 5); rank++) client_print_color(id, players[rank], "^4[Knife 35HP]^1 #^4%d ^3%n^1 | ^4%d^1 kills / ^4%d^1 deaths", rank+1, players[rank], g_kills[players[rank]], g_deaths[players[rank]])
    return PLUGIN_HANDLED
}
public mm_score(id)
{
    if (!mm_restricted()) return PLUGIN_CONTINUE
    client_print_color(id, print_team_grey, "^4[Knife 35HP]^3 T ^4%d^3 : ^4%d^3 CT | First to ^4%d^3 rounds.", g_rounds[0], g_rounds[1], get_pcvar_num(g_round_target))
    return PLUGIN_HANDLED
}
public mm_hud()
{
    if (!g_enabled || !mm_restricted()) return
    set_hudmessage(240, 190, 80, 0.02, 0.18, 0, 0.0, 1.1, 0.0, 0.0)
    ShowSyncHudMsg(0, g_hud, "KNIFE 35HP | First to %d rounds^nT %d : %d CT | /ktop /knifescore", get_pcvar_num(g_round_target), g_rounds[0], g_rounds[1])
}
