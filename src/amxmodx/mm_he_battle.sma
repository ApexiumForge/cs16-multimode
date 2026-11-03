#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <reapi>
#include <mm_mode_api>
#include <mm_presentation_api>

new const PLUGIN_NAME[] = "Multi-Mode HE Battle"
new const PLUGIN_VERSION[] = "1.4.1"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new Float:g_next_notice[33]
new g_pickups, g_purchases
#define MM_HE_TICK 891000
#define MM_HE_RESPAWN 891100
#define MM_HE_LOADOUT 891200
#define MM_HE_RESET 891300
#define MM_HE_HUD 891400
new g_ffa
new const MM_HE_SETTINGS[] = "addons/amxmodx/configs/mm_he_settings.cfg"
new g_kills[33], g_deaths[33], g_kill_limit, g_hud
new bool:g_finished
new bool:g_enabled
new g_map_grants
new g_team_kills[2]
new Float:g_refilled[33]

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    RegisterHam(Ham_TakeDamage, "player", "mm_damage_pre")
    RegisterHam(Ham_Spawn, "player", "mm_spawn_post", 1)
    RegisterHam(Ham_Killed, "player", "mm_killed_post", 1)
    register_clcmd("say /top", "mm_top")
    register_clcmd("say_team /top", "mm_top")
    register_clcmd("say /hetop", "mm_top")
    g_ffa = register_cvar("mm_he_freeforall", "0")
    register_clcmd("say /he", "mm_options")
    register_clcmd("say_team /he", "mm_options")
    register_concmd("mm_he_ffa", "mm_ffa_command", ADMIN_CFG, "<0|1> Save HE Battle team/FFA rules")
    g_kill_limit = register_cvar("mm_he_kill_limit", "30")
    g_hud = CreateHudSyncObj()
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
    g_kills[id] = 0
    g_deaths[id] = 0
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
    client_print_color(id, print_team_red, "^4[HE Battle]^3 NOTICE^1 | Buying is disabled. HE grenades replenish automatically.")
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
    server_print("[MM HE Battle] freeforall=%d team_score=%d:%d target=%d finished=%d", get_pcvar_num(g_ffa), g_team_kills[0], g_team_kills[1], get_pcvar_num(g_kill_limit), g_finished)
    server_print("[MM HE Battle] version=%s active=%d pickups_blocked=%d purchases_blocked=%d map_equipment_blocked=%d", PLUGIN_VERSION, mm_restricted(), g_pickups, g_purchases, g_map_grants)
}

// The mode supplies its own grenades instead of engine spawn weapons.
public mm_default_items(id)
{
    return mm_restricted() ? HC_SUPERCEDE : HC_CONTINUE
}

public plugin_cfg()
{
    if (file_exists(MM_HE_SETTINGS))
    {
        server_cmd("exec %s", MM_HE_SETTINGS)
        server_exec()
    }
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
    g_finished = false
    arrayset(g_kills, 0, sizeof g_kills)
    arrayset(g_deaths, 0, sizeof g_deaths)
    arrayset(g_team_kills, 0, sizeof g_team_kills)
    set_task(1.0, "mm_hud", MM_HE_HUD, "", 0, "b")
    set_task(0.2, "mm_supply", MM_HE_TICK, "", 0, "b")
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!mm_playing(id)) continue
        if (is_user_alive(id))
        {
            set_user_health(id, 100)
            cs_set_user_armor(id, 0, CS_ARMOR_NONE)
            mm_loadout(id)
        }
        else set_task(1.0, "mm_respawn", MM_HE_RESPAWN + id)
    }
    client_print_color(0, print_team_grey, "^4[HE Battle]^3 %s combat. Unlimited HE grenades! Use ^1/he^3 for rules and options.", get_pcvar_num(g_ffa) ? "Free-for-all" : "Team")
}

mm_shutdown()
{
    remove_task(MM_HE_TICK)
    remove_task(MM_HE_RESET)
    remove_task(MM_HE_HUD)
    if (g_enabled) mm_clear_grenades()
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
    g_finished = false
}

bool:mm_playing(id)
{
    if (!is_user_connected(id)) return false
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

public mm_spawn_post(id)
{
    if (!g_enabled || g_finished || !mm_restricted() || !is_user_alive(id)) return HAM_IGNORED
    remove_task(MM_HE_RESPAWN + id)
    remove_task(MM_HE_LOADOUT + id)
    set_task(0.1, "mm_spawn_loadout", MM_HE_LOADOUT + id)
    return HAM_IGNORED
}

public mm_spawn_loadout(task)
{
    new id = task - MM_HE_LOADOUT
    if (g_enabled && !g_finished && mm_restricted() && is_user_alive(id) && mm_playing(id)) mm_loadout(id)
}

mm_loadout(id)
{
    rg_remove_all_items(id, false)
    give_item(id, "weapon_hegrenade")
    cs_set_user_bpammo(id, CSW_HEGRENADE, 2)
    engclient_cmd(id, "weapon_hegrenade")
}

public mm_supply()
{
    if (!g_enabled || g_finished || !mm_restricted() || mm_get_transition_state() != MM_TRANSITION_IDLE) return
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id) || !mm_playing(id)) continue
        new weapons[32], count, bool:extra
        get_user_weapons(id, weapons, count)
        for (new i = 0; i < count; i++)
            if (weapons[i] != CSW_HEGRENADE) extra = true
        if (extra || !user_has_weapon(id, CSW_HEGRENADE)) {mm_loadout(id); g_refilled[id] = get_gametime()+1.2;}
        else if (cs_get_user_bpammo(id, CSW_HEGRENADE) < 2) {cs_set_user_bpammo(id, CSW_HEGRENADE, 2); g_refilled[id] = get_gametime()+1.2;}
    }
}

public mm_killed_post(victim, attacker, gib)
{
    if (!g_enabled || !mm_restricted() || !mm_playing(victim)) return HAM_IGNORED
    if (g_finished) return HAM_IGNORED
    g_deaths[victim]++
    if (attacker != victim && attacker >= 1 && attacker <= MaxClients && mm_playing(attacker)
        && (get_pcvar_num(g_ffa) || cs_get_user_team(attacker) != cs_get_user_team(victim)))
    {
        g_kills[attacker]++
        new team = cs_get_user_team(attacker) == CS_TEAM_T ? 0 : 1
        g_team_kills[team]++
        if ((get_pcvar_num(g_ffa) ? g_kills[attacker] : g_team_kills[team]) >= clamp(get_pcvar_num(g_kill_limit), 1, 200))
        {
            g_finished = true
            for (new id = 1; id <= MaxClients; id++)
            {
                remove_task(MM_HE_RESPAWN + id)
                remove_task(MM_HE_LOADOUT + id)
            }
            if (get_pcvar_num(g_ffa)) client_print_color(0, attacker, "^4[HE Battle]^1 ^3%n^1 wins with ^4%d^1 opponent kills! New match in 6 seconds.", attacker, g_kills[attacker])
            else client_print_color(0, team == 0 ? print_team_red : print_team_blue, "^4[HE Battle]^1 ^3%s^1 win! T ^4%d^1 : ^4%d^1 CT. New match in 6 seconds.", team == 0 ? "Terrorists" : "CTs", g_team_kills[0], g_team_kills[1])
            new leaders[32], count, detail[96]
            mm_standings(leaders, count)
            if (get_pcvar_num(g_ffa)) formatex(detail, charsmax(detail), "%n wins with %d kills", attacker, g_kills[attacker])
            else formatex(detail, charsmax(detail), "%s win! T %d : %d CT", team == 0 ? "Terrorists" : "CTs", g_team_kills[0], g_team_kills[1])
            mm_show_results(MM_MODE_HE_BATTLE, count ? leaders[0] : 0, count > 1 ? leaders[1] : 0, count > 2 ? leaders[2] : 0, "HE BATTLE RESULTS", detail)
            set_task(6.0, "mm_reset_match", MM_HE_RESET)
            return HAM_IGNORED
        }
    }
    remove_task(MM_HE_LOADOUT + victim)
    remove_task(MM_HE_RESPAWN + victim)
    set_task(1.0, "mm_respawn", MM_HE_RESPAWN + victim)
    return HAM_IGNORED
}

public mm_respawn(task)
{
    new id = task - MM_HE_RESPAWN
    if (g_enabled && !g_finished && mm_restricted() && mm_get_transition_state() == MM_TRANSITION_IDLE && mm_playing(id) && !is_user_alive(id))
        ExecuteHamB(Ham_CS_RoundRespawn, id)
}

public plugin_end() mm_shutdown()

// Enforce ally protection even when shared arcade policy enables mp_freeforall.
public mm_damage_pre(victim, inflictor, attacker, Float:damage, damage_bits)
{
    if (g_enabled && mm_restricted() && g_finished) return HAM_SUPERCEDE
    if (!g_enabled || !mm_restricted() || attacker == victim) return HAM_IGNORED
    if (attacker < 1 || attacker > MaxClients || !is_user_connected(attacker) || !is_user_connected(victim)) return HAM_IGNORED
    if (!get_pcvar_num(g_ffa) && cs_get_user_team(attacker) == cs_get_user_team(victim)) return HAM_SUPERCEDE
    return HAM_IGNORED
}

public client_putinserver(id)
{
    g_kills[id] = 0
    g_deaths[id] = 0
}

public mm_reset_match()
{
    if (g_enabled && mm_restricted()) mm_activate()
}

mm_standings(players[32], &count)
{
    count = 0
    for (new id = 1; id <= MaxClients; id++)
        if (mm_playing(id)) players[count++] = id
    for (new i = 0; i < count; i++)
        for (new j = i + 1; j < count; j++)
            if (g_kills[players[j]] > g_kills[players[i]] || (g_kills[players[j]] == g_kills[players[i]] && g_deaths[players[j]] < g_deaths[players[i]]))
            {
                new temp = players[i]
                players[i] = players[j]
                players[j] = temp
            }
}

public mm_top(id)
{
    if (!mm_restricted()) return PLUGIN_CONTINUE
    new players[32], count
    mm_standings(players, count)
    client_print_color(id, print_team_grey, "^4[HE Battle]^3 Kill target ^4%d^3 | Team score in Teams; individual in FFA:", clamp(get_pcvar_num(g_kill_limit), 1, 200))
    for (new i = 0; i < min(count, 5); i++)
        client_print_color(id, players[i], "^4[HE Battle]^1 #%d ^3%n^1 - %d kills / %d deaths", i + 1, players[i], g_kills[players[i]], g_deaths[players[i]])
    return PLUGIN_HANDLED
}

public mm_hud()
{
    if (!g_enabled || !mm_restricted()) return
    new players[32], count, limit = clamp(get_pcvar_num(g_kill_limit), 1, 200)
    mm_standings(players, count)
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || is_user_bot(id)) continue
        set_hudmessage(0, 220, 80, 0.02, 0.18, 0, 0.0, 1.1, 0.0, 0.0)
        if (g_finished) ShowSyncHudMsg(id, g_hud, "HE Battle | Match finished!^nNew match starts shortly")
        else if (count && get_pcvar_num(g_ffa)) ShowSyncHudMsg(id, g_hud, "HE BATTLE | FFA | First to %d^nYour kills %d | Leader %n (%d)^nHE %s", limit, g_kills[id], players[0], g_kills[players[0]], g_refilled[id] > get_gametime() ? "REPLENISHED" : "READY (unlimited)")
        else if (count) ShowSyncHudMsg(id, g_hud, "HE BATTLE | TEAMS | First team to %d^nT %d : %d CT | Allies protected^nLeader %n (%d) | HE %s", limit, g_team_kills[0], g_team_kills[1], players[0], g_kills[players[0]], g_refilled[id] > get_gametime() ? "REPLENISHED" : "READY (unlimited)")
        else ShowSyncHudMsg(id, g_hud, "HE Battle | First to %d opponent kills | /top", limit)
    }
}

mm_clear_grenades()
{
    new entity, model[64]
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "grenade")) > 0)
    {
        pev(entity, pev_model, model, charsmax(model))
        if (equal(model, "models/w_hegrenade.mdl")) engfunc(EngFunc_RemoveEntity, entity)
    }
}

public mm_options(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED
    new title[192], label[96]
    formatex(title, charsmax(title), "HE Battle Options^nCombat: %s^n%s^nKill target %d (team total in Teams)", get_pcvar_num(g_ffa) ? "FREE-FOR-ALL" : "TEAMS", get_pcvar_num(g_ffa) ? "Everyone is an enemy" : "Teammates are protected", clamp(get_pcvar_num(g_kill_limit), 1, 200))
    new menu = menu_create(title, "mm_options_handler")
    formatex(label, charsmax(label), "Switch to %s (admin)", get_pcvar_num(g_ffa) ? "Teams" : "Free-for-all")
    menu_additem(menu, label, "toggle", ADMIN_CFG)
    menu_setprop(menu, MPROP_EXITNAME, "Close")
    menu_display(id, menu)
    return PLUGIN_HANDLED
}

public mm_options_handler(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT || !is_user_connected(id) || !(get_user_flags(id) & ADMIN_CFG)) return PLUGIN_HANDLED
    mm_set_ffa(id, get_pcvar_num(g_ffa) ? 0 : 1)
    return PLUGIN_HANDLED
}

public mm_ffa_command(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new value[8]
    read_argv(1, value, charsmax(value))
    if (!equal(value, "0") && !equal(value, "1"))
    {
        console_print(id, "Usage: mm_he_ffa <0|1>")
        return PLUGIN_HANDLED
    }
    mm_set_ffa(id, str_to_num(value))
    return PLUGIN_HANDLED
}

mm_set_ffa(id, enabled)
{
    if (enabled == (get_pcvar_num(g_ffa) ? 1 : 0)) return
    new file = fopen(MM_HE_SETTINGS, "wt")
    if (!file)
    {
        console_print(id, "[HE Battle] Could not save rules; setting unchanged.")
        return
    }
    fprintf(file, "// Saved through /he or mm_he_ffa^nmm_he_freeforall %d^n", enabled)
    fclose(file)
    set_pcvar_num(g_ffa, enabled)
    if (id) client_print_color(0, id, "^4[HE Battle]^1 ^3%n^1 selected ^4%s^1 combat.", id, enabled ? "Free-for-all" : "Team")
    else client_print_color(0, print_team_grey, "^4[HE Battle]^3 Combat set to ^4%s^3.", enabled ? "Free-for-all" : "Team")
    // A fresh match prevents mixed team and FFA scores.
    if (g_enabled && mm_restricted()) mm_activate()
}
