#include <amxmodx>
#include <cstrike>
#include <fun>
#include <hamsandwich>
#include <mm_mode_api>

#define PLUGIN_NAME    "Multi-Mode Network Arms Race"
#define PLUGIN_VERSION "0.4.3"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"

#define AR_LEVEL_COUNT 15
#define TASK_RESPAWN_BASE 51000
#define TASK_LOADOUT_BASE 52000
#define TASK_HUD 53000
#define TASK_MATCH_RESET 53001
#define MATCH_RESET_DELAY 5.0

enum WeaponCatalog
{
    WEAPON_GLOCK = 0,
    WEAPON_USP,
    WEAPON_DEAGLE,
    WEAPON_TMP,
    WEAPON_MP5,
    WEAPON_P90,
    WEAPON_GALIL,
    WEAPON_FAMAS,
    WEAPON_AK47,
    WEAPON_M4A1,
    WEAPON_AUG,
    WEAPON_SCOUT,
    WEAPON_AWP,
    WEAPON_M249,
    WEAPON_KNIFE,
    WEAPON_CATALOG_COUNT
}

new const WEAPON_NAMES[WEAPON_CATALOG_COUNT][] =
{
    "glock18", "usp", "deagle", "tmp", "mp5navy", "p90", "galil", "famas",
    "ak47", "m4a1", "aug", "scout", "awp", "m249", "knife"
}

new const WEAPON_DISPLAY_NAMES[WEAPON_CATALOG_COUNT][] =
{
    "Glock 18", "USP", "Desert Eagle", "TMP", "MP5 Navy", "P90", "Galil", "Famas",
    "AK-47", "M4A1", "AUG", "Scout", "AWP", "M249", "Knife"
}

new const WEAPON_ENTITIES[WEAPON_CATALOG_COUNT][] =
{
    "weapon_glock18", "weapon_usp", "weapon_deagle", "weapon_tmp", "weapon_mp5navy",
    "weapon_p90", "weapon_galil", "weapon_famas", "weapon_ak47", "weapon_m4a1",
    "weapon_aug", "weapon_scout", "weapon_awp", "weapon_m249", "weapon_knife"
}

new const WEAPON_IDS[WEAPON_CATALOG_COUNT] =
{
    CSW_GLOCK18, CSW_USP, CSW_DEAGLE, CSW_TMP, CSW_MP5NAVY, CSW_P90, CSW_GALIL,
    CSW_FAMAS, CSW_AK47, CSW_M4A1, CSW_AUG, CSW_SCOUT, CSW_AWP, CSW_M249, CSW_KNIFE
}

new const WEAPON_AMMO[WEAPON_CATALOG_COUNT] =
{
    120, 100, 35, 120, 120, 100, 90, 90, 90, 90, 90, 90, 30, 200, 0
}

new const WeaponCatalog:DEFAULT_PROGRESSION[AR_LEVEL_COUNT] =
{
    WEAPON_GLOCK, WEAPON_USP, WEAPON_DEAGLE, WEAPON_TMP, WEAPON_MP5,
    WEAPON_P90, WEAPON_GALIL, WEAPON_FAMAS, WEAPON_AK47, WEAPON_M4A1,
    WEAPON_AUG, WEAPON_SCOUT, WEAPON_AWP, WEAPON_M249, WEAPON_KNIFE
}

new g_level_cvars[AR_LEVEL_COUNT]
new WeaponCatalog:g_progression[AR_LEVEL_COUNT]
new g_level[33]
new g_kills[33]
new g_deaths[33]
new bool:g_match_finished
new bool:g_gameplay_enabled
new g_respawn_delay_cvar
new g_hud_sync

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /ar", "command_progression")
    register_clcmd("say_team /ar", "command_progression")
    register_clcmd("say /artop", "command_leaderboard")
    register_clcmd("say_team /artop", "command_leaderboard")

    register_clcmd("buy", "command_block_purchase")
    register_clcmd("buyequip", "command_block_purchase")
    register_clcmd("cl_autobuy", "command_block_purchase")
    register_clcmd("cl_rebuy", "command_block_purchase")
    register_clcmd("autobuy", "command_block_purchase")
    register_clcmd("rebuy", "command_block_purchase")
    register_clcmd("buyammo1", "command_block_purchase")
    register_clcmd("buyammo2", "command_block_purchase")
    register_clcmd("drop", "command_block_drop")

    RegisterHam(Ham_Killed, "player", "player_killed_post", 1)
    RegisterHam(Ham_Spawn, "player", "player_spawned_post", 1)

    register_progression_cvars()
    g_respawn_delay_cvar = register_cvar("mm_ar_respawn_delay", "1.0")
    g_hud_sync = CreateHudSyncObj()

    for (new id = 1; id <= MaxClients; id++) reset_player(id)
    if (mm_get_active_mode() == MM_MODE_ARMS_RACE) activate_armsrace()
    log_amx("%s Arms Race v%s initialized.", PROJECT_NAME, PLUGIN_VERSION)
}

public client_putinserver(id)
{
    reset_player(id)
}

public client_disconnected(id)
{
    clear_player_tasks(id)
    reset_player(id)
}

public mm_mode_transition_started(old_mode, requested_mode)
{
    if (MmMode:old_mode == MM_MODE_ARMS_RACE && MmMode:requested_mode != MM_MODE_ARMS_RACE)
    {
        disable_armsrace()
    }
}

public mm_mode_changed(old_mode, new_mode)
{
    if (MmMode:new_mode == MM_MODE_ARMS_RACE) activate_armsrace()
}

public player_killed_post(victim, attacker, should_gib)
{
    if (!armsrace_active() || !is_user_connected(victim)) return HAM_IGNORED

    g_deaths[victim]++
    if (!g_match_finished && is_valid_enemy_kill(victim, attacker))
    {
        process_progression_kill(attacker)
    }

    if (!g_match_finished)
    {
        remove_task(TASK_RESPAWN_BASE + victim)
        set_task(get_pcvar_float(g_respawn_delay_cvar), "task_respawn_player", TASK_RESPAWN_BASE + victim)
    }
    return HAM_IGNORED
}

public task_respawn_player(task_id)
{
    new id = task_id - TASK_RESPAWN_BASE
    if (!armsrace_active() || g_match_finished || !is_user_connected(id) || is_user_alive(id) || !is_playing_team(id)) return
    ExecuteHamB(Ham_CS_RoundRespawn, id)
}

public player_spawned_post(id)
{
    if (!armsrace_active() || g_match_finished || !is_user_alive(id) || !is_playing_team(id)) return HAM_IGNORED
    remove_task(TASK_LOADOUT_BASE + id)
    set_task(0.1, "task_apply_loadout", TASK_LOADOUT_BASE + id)
    return HAM_IGNORED
}

public task_apply_loadout(task_id)
{
    new id = task_id - TASK_LOADOUT_BASE
    if (!armsrace_active() || g_match_finished || !is_user_alive(id)) return
    apply_current_weapon(id)
}

public command_block_purchase(id)
{
    if (!armsrace_active()) return PLUGIN_CONTINUE
    client_print(id, print_center, "Purchasing is disabled in Arms Race")
    return PLUGIN_HANDLED
}

public command_block_drop(id)
{
    if (!armsrace_active()) return PLUGIN_CONTINUE
    client_print(id, print_center, "Weapon dropping is disabled in Arms Race")
    return PLUGIN_HANDLED
}

public command_progression(id)
{
    if (!armsrace_active()) return armsrace_inactive_message(id)
    if (!is_user_connected(id)) return PLUGIN_HANDLED

    new WeaponCatalog:weapon = g_progression[g_level[id]]
    client_print(id, print_chat, "[%s] Arms Race level %d/%d: %s | Kills %d | Deaths %d", PROJECT_NAME, g_level[id] + 1, AR_LEVEL_COUNT, WEAPON_DISPLAY_NAMES[weapon], g_kills[id], g_deaths[id])
    return PLUGIN_HANDLED
}

public command_leaderboard(id)
{
    if (!armsrace_active()) return armsrace_inactive_message(id)

    new leaders[32], count
    collect_sorted_players(leaders, count)
    client_print(id, print_chat, "[%s] Arms Race leaderboard:", PROJECT_NAME)

    new limit = min(count, 5)
    for (new rank = 0; rank < limit; rank++)
    {
        new player = leaders[rank]
        client_print(id, print_chat, "#%d %n - Level %d/%d, %d kills", rank + 1, player, g_level[player] + 1, AR_LEVEL_COUNT, g_kills[player])
    }
    return PLUGIN_HANDLED
}

public task_update_hud()
{
    if (!armsrace_active() || g_match_finished) return

    new leader = find_leader()
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || is_user_bot(id)) continue

        new WeaponCatalog:weapon = g_progression[g_level[id]]
        set_hudmessage(255, 190, 40, 0.02, 0.18, 0, 0.0, 1.1, 0.0, 0.0)
        if (leader)
        {
            ShowSyncHudMsg(id, g_hud_sync, "Arms Race | Level %d/%d: %s^nKills: %d | Leader: %n (Level %d)", g_level[id] + 1, AR_LEVEL_COUNT, WEAPON_DISPLAY_NAMES[weapon], g_kills[id], leader, g_level[leader] + 1)
        }
        else
        {
            ShowSyncHudMsg(id, g_hud_sync, "Arms Race | Level %d/%d: %s^nKills: %d | Waiting for players", g_level[id] + 1, AR_LEVEL_COUNT, WEAPON_DISPLAY_NAMES[weapon], g_kills[id])
        }
    }
}

public task_reset_match()
{
    if (!armsrace_active()) return
    begin_next_match()
}

activate_armsrace()
{
    g_gameplay_enabled = true
    load_progression()
    begin_next_match()
    remove_task(TASK_HUD)
    set_task(1.0, "task_update_hud", TASK_HUD, _, _, "b")
    client_print(0, print_chat, "[%s] Team Arms Race active. Reach level 15 and win with a knife kill.", PROJECT_NAME)
    log_amx("Arms Race activated with a validated %d-level progression.", AR_LEVEL_COUNT)
}

disable_armsrace()
{
    g_gameplay_enabled = false
    remove_task(TASK_HUD)
    remove_task(TASK_MATCH_RESET)
    for (new id = 1; id <= MaxClients; id++) clear_player_tasks(id)
    g_match_finished = false
    reset_all_progression()
    server_cmd("exec server.cfg")
    server_exec()
    log_amx("Arms Race disabled; tasks, progression, and baseline cvars restored.")
}

begin_next_match()
{
    remove_task(TASK_MATCH_RESET)
    g_match_finished = false
    reset_all_progression()

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || !is_playing_team(id)) continue
        if (is_user_alive(id)) apply_current_weapon(id)
        else
        {
            remove_task(TASK_RESPAWN_BASE + id)
            set_task(0.2, "task_respawn_player", TASK_RESPAWN_BASE + id)
        }
    }
    client_print(0, print_chat, "[%s] A new Arms Race match has started.", PROJECT_NAME)
}

process_progression_kill(attacker)
{
    new WeaponCatalog:required_weapon = g_progression[g_level[attacker]]
    if (get_user_weapon(attacker) != WEAPON_IDS[required_weapon])
    {
        replenish_current_ammunition(attacker)
        return
    }

    g_kills[attacker]++
    if (g_level[attacker] == AR_LEVEL_COUNT - 1)
    {
        finish_match(attacker)
        return
    }

    g_level[attacker]++
    apply_current_weapon(attacker)
    client_print(0, print_chat, "[%s] %n advanced to level %d: %s.", PROJECT_NAME, attacker, g_level[attacker] + 1, WEAPON_DISPLAY_NAMES[g_progression[g_level[attacker]]])
}

finish_match(winner)
{
    g_match_finished = true
    for (new id = 1; id <= MaxClients; id++) clear_player_tasks(id)
    client_print(0, print_chat, "[%s] %n wins Arms Race with the final knife kill!", PROJECT_NAME, winner)
    set_hudmessage(0, 255, 80, -1.0, 0.30, 0, 1.0, 5.0)
    ShowSyncHudMsg(0, g_hud_sync, "%n WINS ARMS RACE!^nFinal knife kill completed", winner)
    log_amx("%n won Arms Race with %d valid progression kills.", winner, g_kills[winner])
    set_task(MATCH_RESET_DELAY, "task_reset_match", TASK_MATCH_RESET)
}

apply_current_weapon(id)
{
    if (!is_user_alive(id)) return

    new WeaponCatalog:weapon = g_progression[g_level[id]]
    strip_user_weapons(id)
    give_item(id, "weapon_knife")
    if (weapon != WEAPON_KNIFE) give_item(id, WEAPON_ENTITIES[weapon])
    replenish_current_ammunition(id)
}

replenish_current_ammunition(id)
{
    if (!is_user_connected(id)) return
    new WeaponCatalog:weapon = g_progression[g_level[id]]
    if (weapon != WEAPON_KNIFE) cs_set_user_bpammo(id, WEAPON_IDS[weapon], WEAPON_AMMO[weapon])
}

bool:is_valid_enemy_kill(victim, attacker)
{
    if (attacker < 1 || attacker > MaxClients || attacker == victim || !is_user_connected(attacker)) return false
    if (!is_playing_team(victim) || !is_playing_team(attacker)) return false
    return cs_get_user_team(victim) != cs_get_user_team(attacker)
}

register_progression_cvars()
{
    new cvar_name[32]
    for (new level = 0; level < AR_LEVEL_COUNT; level++)
    {
        formatex(cvar_name, charsmax(cvar_name), "mm_ar_level_%d", level + 1)
        g_level_cvars[level] = register_cvar(cvar_name, WEAPON_NAMES[DEFAULT_PROGRESSION[level]])
    }
}

load_progression()
{
    new configured_name[32]
    for (new level = 0; level < AR_LEVEL_COUNT; level++)
    {
        get_pcvar_string(g_level_cvars[level], configured_name, charsmax(configured_name))
        new WeaponCatalog:weapon = find_catalog_weapon(configured_name)
        if (_:weapon < 0 || (level == AR_LEVEL_COUNT - 1 && weapon != WEAPON_KNIFE))
        {
            weapon = DEFAULT_PROGRESSION[level]
            log_amx("Invalid Arms Race weapon '%s' at level %d; using %s.", configured_name, level + 1, WEAPON_NAMES[weapon])
        }
        g_progression[level] = weapon
    }
}

WeaponCatalog:find_catalog_weapon(const name[])
{
    for (new WeaponCatalog:weapon = WEAPON_GLOCK; weapon < WEAPON_CATALOG_COUNT; weapon++)
    {
        if (equali(name, WEAPON_NAMES[weapon])) return weapon
    }
    return WeaponCatalog:-1
}

collect_sorted_players(output[32], &count)
{
    count = 0
    for (new id = 1; id <= MaxClients; id++)
    {
        if (is_user_connected(id) && !is_user_hltv(id)) output[count++] = id
    }

    for (new left = 0; left < count; left++)
    {
        for (new right = left + 1; right < count; right++)
        {
            if (is_better_score(output[right], output[left]))
            {
                new temporary = output[left]
                output[left] = output[right]
                output[right] = temporary
            }
        }
    }
}

find_leader()
{
    new leader
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || is_user_hltv(id)) continue
        if (!leader || is_better_score(id, leader)) leader = id
    }
    return leader
}

bool:is_better_score(candidate, current)
{
    if (g_level[candidate] != g_level[current]) return g_level[candidate] > g_level[current]
    if (g_kills[candidate] != g_kills[current]) return g_kills[candidate] > g_kills[current]
    return g_deaths[candidate] < g_deaths[current]
}

clear_player_tasks(id)
{
    remove_task(TASK_RESPAWN_BASE + id)
    remove_task(TASK_LOADOUT_BASE + id)
}

reset_player(id)
{
    g_level[id] = 0
    g_kills[id] = 0
    g_deaths[id] = 0
}

reset_all_progression()
{
    for (new id = 1; id <= MaxClients; id++) reset_player(id)
}

armsrace_inactive_message(id)
{
    client_print(id, print_chat, "[%s] Arms Race commands are disabled while another mode is active.", PROJECT_NAME)
    return PLUGIN_HANDLED
}

bool:is_playing_team(id)
{
    if (!is_user_connected(id)) return false
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

bool:armsrace_active()
{
    return g_gameplay_enabled && mm_get_active_mode() == MM_MODE_ARMS_RACE
}
