#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <mm_mode_api>

#define PLUGIN_NAME    "Multi-Mode Network Deathmatch"
#define PLUGIN_VERSION "0.4.3"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"

#define TASK_RESPAWN_BASE    41000
#define TASK_PROTECTION_BASE 42000
#define TASK_LOADOUT_BASE    43000

enum PrimaryWeapon
{
    PRIMARY_AK47 = 0,
    PRIMARY_M4A1,
    PRIMARY_AWP,
    PRIMARY_MP5,
    PRIMARY_M249,
    PRIMARY_COUNT
}

enum SecondaryWeapon
{
    SECONDARY_DEAGLE = 0,
    SECONDARY_USP,
    SECONDARY_GLOCK,
    SECONDARY_COUNT
}

new const PRIMARY_NAMES[PRIMARY_COUNT][] = { "AK-47", "M4A1", "AWP", "MP5 Navy", "M249" }
new const PRIMARY_ENTITIES[PRIMARY_COUNT][] = { "weapon_ak47", "weapon_m4a1", "weapon_awp", "weapon_mp5navy", "weapon_m249" }
new const PRIMARY_IDS[PRIMARY_COUNT] = { CSW_AK47, CSW_M4A1, CSW_AWP, CSW_MP5NAVY, CSW_M249 }
new const PRIMARY_AMMO[PRIMARY_COUNT] = { 90, 90, 30, 120, 200 }

new const SECONDARY_NAMES[SECONDARY_COUNT][] = { "Desert Eagle", "USP", "Glock 18" }
new const SECONDARY_ENTITIES[SECONDARY_COUNT][] = { "weapon_deagle", "weapon_usp", "weapon_glock18" }
new const SECONDARY_IDS[SECONDARY_COUNT] = { CSW_DEAGLE, CSW_USP, CSW_GLOCK18 }
new const SECONDARY_AMMO[SECONDARY_COUNT] = { 35, 100, 120 }

new PrimaryWeapon:g_primary[33]
new SecondaryWeapon:g_secondary[33]
new g_kills[33]
new g_deaths[33]
new bool:g_protected[33]
new g_spawn_protection_cvar
new g_respawn_delay_cvar

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /dm", "command_weapon_menu")
    register_clcmd("say_team /dm", "command_weapon_menu")
    register_clcmd("say /top", "command_top")
    register_clcmd("say_team /top", "command_top")

    RegisterHam(Ham_Killed, "player", "player_killed_post", 1)
    RegisterHam(Ham_Spawn, "player", "player_spawned_post", 1)
    register_forward(FM_CmdStart, "forward_command_start")

    g_spawn_protection_cvar = register_cvar("mm_dm_spawn_protection", "2.0")
    g_respawn_delay_cvar = register_cvar("mm_dm_respawn_delay", "1.0")

    for (new id = 1; id <= MaxClients; id++) reset_player(id)
    if (deathmatch_active()) activate_deathmatch()
    log_amx("%s Deathmatch v%s initialized.", PROJECT_NAME, PLUGIN_VERSION)
}

public client_putinserver(id)
{
    reset_player(id)
}

public client_disconnected(id)
{
    clear_player_tasks(id)
    g_protected[id] = false
}

public mm_mode_transition_started(old_mode, requested_mode)
{
    if (MmMode:old_mode == MM_MODE_DEATHMATCH && MmMode:requested_mode != MM_MODE_DEATHMATCH)
    {
        disable_deathmatch()
    }
}

public mm_mode_changed(old_mode, new_mode)
{
    if (MmMode:new_mode == MM_MODE_DEATHMATCH)
    {
        activate_deathmatch()
    }
}

public player_killed_post(victim, attacker, should_gib)
{
    if (!deathmatch_active() || !is_user_connected(victim)) return HAM_IGNORED

    remove_spawn_protection(victim)
    g_deaths[victim]++

    if (attacker >= 1 && attacker <= MaxClients && attacker != victim && is_user_connected(attacker))
    {
        g_kills[attacker]++
        replenish_ammunition(attacker)
    }

    remove_task(TASK_RESPAWN_BASE + victim)
    set_task(get_pcvar_float(g_respawn_delay_cvar), "task_respawn_player", TASK_RESPAWN_BASE + victim)
    return HAM_IGNORED
}

public task_respawn_player(task_id)
{
    new id = task_id - TASK_RESPAWN_BASE
    if (!deathmatch_active() || !is_user_connected(id) || is_user_alive(id) || !is_playing_team(id)) return
    ExecuteHamB(Ham_CS_RoundRespawn, id)
}

public player_spawned_post(id)
{
    if (!deathmatch_active() || !is_user_alive(id) || !is_playing_team(id)) return HAM_IGNORED

    enable_spawn_protection(id)
    remove_task(TASK_LOADOUT_BASE + id)
    set_task(0.1, "task_apply_loadout", TASK_LOADOUT_BASE + id)
    return HAM_IGNORED
}

public task_apply_loadout(task_id)
{
    new id = task_id - TASK_LOADOUT_BASE
    if (!deathmatch_active() || !is_user_alive(id)) return
    apply_loadout(id)
}

public forward_command_start(id, command_handle, random_seed)
{
    if (!deathmatch_active() || !g_protected[id] || !is_user_alive(id)) return FMRES_IGNORED

    new buttons = get_uc(command_handle, UC_Buttons)
    if (buttons & (IN_ATTACK | IN_ATTACK2)) remove_spawn_protection(id)
    return FMRES_IGNORED
}

public task_remove_spawn_protection(task_id)
{
    remove_spawn_protection(task_id - TASK_PROTECTION_BASE)
}

public command_weapon_menu(id)
{
    if (!deathmatch_active())
    {
        client_print(id, print_chat, "[%s] /dm is available only in Deathmatch mode.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    if (!is_user_connected(id) || is_user_bot(id)) return PLUGIN_HANDLED

    show_primary_menu(id)
    return PLUGIN_HANDLED
}

show_primary_menu(id)
{
    new menu = menu_create("Deathmatch: Primary Weapon", "primary_menu_handler")
    new item_info[4]
    for (new PrimaryWeapon:weapon = PRIMARY_AK47; weapon < PRIMARY_COUNT; weapon++)
    {
        num_to_str(_:weapon, item_info, charsmax(item_info))
        menu_additem(menu, PRIMARY_NAMES[weapon], item_info)
    }
    menu_display(id, menu)
}

public primary_menu_handler(id, menu, item)
{
    if (item == MENU_EXIT || !deathmatch_active())
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new item_info[4], access, callback
    menu_item_getinfo(menu, item, access, item_info, charsmax(item_info), _, _, callback)
    g_primary[id] = PrimaryWeapon:str_to_num(item_info)
    menu_destroy(menu)
    show_secondary_menu(id)
    return PLUGIN_HANDLED
}

show_secondary_menu(id)
{
    new menu = menu_create("Deathmatch: Secondary Weapon", "secondary_menu_handler")
    new item_info[4]
    for (new SecondaryWeapon:weapon = SECONDARY_DEAGLE; weapon < SECONDARY_COUNT; weapon++)
    {
        num_to_str(_:weapon, item_info, charsmax(item_info))
        menu_additem(menu, SECONDARY_NAMES[weapon], item_info)
    }
    menu_display(id, menu)
}

public secondary_menu_handler(id, menu, item)
{
    if (item == MENU_EXIT || !deathmatch_active())
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new item_info[4], access, callback
    menu_item_getinfo(menu, item, access, item_info, charsmax(item_info), _, _, callback)
    g_secondary[id] = SecondaryWeapon:str_to_num(item_info)
    menu_destroy(menu)

    client_print(id, print_chat, "[%s] Loadout selected: %s + %s.", PROJECT_NAME, PRIMARY_NAMES[g_primary[id]], SECONDARY_NAMES[g_secondary[id]])
    if (is_user_alive(id)) apply_loadout(id)
    return PLUGIN_HANDLED
}

public command_top(id)
{
    if (!deathmatch_active())
    {
        client_print(id, print_chat, "[%s] /top is available only in Deathmatch mode.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }

    new leaders[32], count
    for (new player = 1; player <= MaxClients; player++)
    {
        if (is_user_connected(player) && !is_user_hltv(player)) leaders[count++] = player
    }

    for (new left = 0; left < count; left++)
    {
        for (new right = left + 1; right < count; right++)
        {
            if (is_better_score(leaders[right], leaders[left]))
            {
                new temporary = leaders[left]
                leaders[left] = leaders[right]
                leaders[right] = temporary
            }
        }
    }

    client_print(id, print_chat, "[%s] Deathmatch leaderboard:", PROJECT_NAME)
    new limit = min(count, 5)
    for (new rank = 0; rank < limit; rank++)
    {
        new player = leaders[rank]
        client_print(id, print_chat, "#%d %n - %d kills / %d deaths", rank + 1, player, g_kills[player], g_deaths[player])
    }
    return PLUGIN_HANDLED
}

activate_deathmatch()
{
    reset_all_scores()
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || !is_playing_team(id)) continue
        if (is_user_alive(id)) player_spawned_post(id)
        else
        {
            remove_task(TASK_RESPAWN_BASE + id)
            set_task(0.2, "task_respawn_player", TASK_RESPAWN_BASE + id)
        }
    }
    client_print(0, print_chat, "[%s] Team Deathmatch active. Use /dm for weapons and /top for scores.", PROJECT_NAME)
    log_amx("Deathmatch activated; transient scores reset.")
}

disable_deathmatch()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        clear_player_tasks(id)
        remove_spawn_protection(id)
    }
    reset_all_scores()
    server_cmd("exec server.cfg")
    server_exec()
    log_amx("Deathmatch disabled; tasks, protection, scores, and baseline cvars restored.")
}

apply_loadout(id)
{
    strip_user_weapons(id)
    give_item(id, "weapon_knife")
    give_item(id, PRIMARY_ENTITIES[g_primary[id]])
    give_item(id, SECONDARY_ENTITIES[g_secondary[id]])
    replenish_ammunition(id)
}

replenish_ammunition(id)
{
    if (!is_user_connected(id)) return
    cs_set_user_bpammo(id, PRIMARY_IDS[g_primary[id]], PRIMARY_AMMO[g_primary[id]])
    cs_set_user_bpammo(id, SECONDARY_IDS[g_secondary[id]], SECONDARY_AMMO[g_secondary[id]])
}

enable_spawn_protection(id)
{
    remove_task(TASK_PROTECTION_BASE + id)
    g_protected[id] = true
    set_user_godmode(id, 1)

    new Float:duration = get_pcvar_float(g_spawn_protection_cvar)
    if (duration <= 0.0) remove_spawn_protection(id)
    else set_task(duration, "task_remove_spawn_protection", TASK_PROTECTION_BASE + id)
}

remove_spawn_protection(id)
{
    if (id < 1 || id > MaxClients) return
    remove_task(TASK_PROTECTION_BASE + id)
    g_protected[id] = false
    if (is_user_connected(id)) set_user_godmode(id, 0)
}

clear_player_tasks(id)
{
    remove_task(TASK_RESPAWN_BASE + id)
    remove_task(TASK_PROTECTION_BASE + id)
    remove_task(TASK_LOADOUT_BASE + id)
}

reset_player(id)
{
    g_primary[id] = PRIMARY_AK47
    g_secondary[id] = SECONDARY_DEAGLE
    g_kills[id] = 0
    g_deaths[id] = 0
    g_protected[id] = false
}

reset_all_scores()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        g_kills[id] = 0
        g_deaths[id] = 0
    }
}

bool:is_better_score(candidate, current)
{
    if (g_kills[candidate] != g_kills[current]) return g_kills[candidate] > g_kills[current]
    return g_deaths[candidate] < g_deaths[current]
}

bool:is_playing_team(id)
{
    if (!is_user_connected(id)) return false
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

bool:deathmatch_active()
{
    return mm_get_active_mode() == MM_MODE_DEATHMATCH
}
