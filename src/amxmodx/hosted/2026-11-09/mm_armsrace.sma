#include <amxmodx>
#include <cstrike>
#include <fun>
#include <hamsandwich>
#include <reapi>
#include <mm_mode_api>
#include <mm_voting_api>
#include <mm_presentation_api>

#define PLUGIN_NAME    "Multi-Mode Network Arms Race"
#define PLUGIN_VERSION "0.7.1"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Arms Race"

#define AR_LEVEL_COUNT 17
#define TASK_RESPAWN_BASE 51000
#define TASK_LOADOUT_BASE 52000
#define TASK_HUD 53000
#define TASK_MATCH_RESET 53001
#define TASK_REMATCH_VOTE 53002
#define MATCH_RESET_DELAY 6.0

enum WeaponCatalog
{
    ARCAT_GLOCK = 0,
    ARCAT_USP,
    ARCAT_DEAGLE,
    ARCAT_TMP,
    ARCAT_MP5,
    ARCAT_P90,
    ARCAT_M3,
    ARCAT_XM1014,
    ARCAT_GALIL,
    ARCAT_FAMAS,
    ARCAT_AK47,
    ARCAT_M4A1,
    ARCAT_AUG,
    ARCAT_SCOUT,
    ARCAT_AWP,
    ARCAT_M249,
    ARCAT_KNIFE,
    ARCAT_CATALOG_COUNT
}

new const ARCAT_NAMES[ARCAT_CATALOG_COUNT][] =
{
    "glock18", "usp", "deagle", "tmp", "mp5navy", "p90", "m3", "xm1014", "galil", "famas",
    "ak47", "m4a1", "aug", "scout", "awp", "m249", "knife"
}

new const ARCAT_DISPLAY_NAMES[ARCAT_CATALOG_COUNT][] =
{
    "Glock 18", "USP", "Desert Eagle", "TMP", "MP5 Navy", "P90", "M3", "XM1014", "Galil", "Famas",
    "AK-47", "M4A1", "AUG", "Scout", "AWP", "M249", "Knife"
}

new const ARCAT_ENTITIES[ARCAT_CATALOG_COUNT][] =
{
    "weapon_glock18", "weapon_usp", "weapon_deagle", "weapon_tmp", "weapon_mp5navy",
    "weapon_p90", "weapon_m3", "weapon_xm1014", "weapon_galil", "weapon_famas", "weapon_ak47", "weapon_m4a1",
    "weapon_aug", "weapon_scout", "weapon_awp", "weapon_m249", "weapon_knife"
}

new const ARCAT_IDS[ARCAT_CATALOG_COUNT] =
{
    CSW_GLOCK18, CSW_USP, CSW_DEAGLE, CSW_TMP, CSW_MP5NAVY, CSW_P90, CSW_M3, CSW_XM1014, CSW_GALIL,
    CSW_FAMAS, CSW_AK47, CSW_M4A1, CSW_AUG, CSW_SCOUT, CSW_AWP, CSW_M249, CSW_KNIFE
}

new const ARCAT_AMMO[ARCAT_CATALOG_COUNT] =
{
    120, 100, 35, 120, 120, 100, 32, 32, 90, 90, 90, 90, 90, 90, 30, 200, 0
}

new const WeaponCatalog:DEFAULT_PROGRESSION[AR_LEVEL_COUNT] =
{
    ARCAT_GLOCK, ARCAT_USP, ARCAT_DEAGLE, ARCAT_TMP, ARCAT_MP5,
    ARCAT_P90, ARCAT_M3, ARCAT_XM1014, ARCAT_GALIL, ARCAT_FAMAS, ARCAT_AK47, ARCAT_M4A1,
    ARCAT_AUG, ARCAT_SCOUT, ARCAT_AWP, ARCAT_M249, ARCAT_KNIFE
}

new g_level_cvars[AR_LEVEL_COUNT]
new WeaponCatalog:g_progression[AR_LEVEL_COUNT]
new g_level[33]
new g_kills[33]
new g_level_kills[33]
new Float:g_next_action_notice[33]
new g_deaths[33]
new bool:g_match_finished
new bool:g_gameplay_enabled
new g_respawn_delay_cvar
new g_hud_sync
new g_announced_leader
new g_rematch_attempts
new bool:g_offer_rematch

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    RegisterHam(Ham_TakeDamage, "player", "mm_finished_damage")
    register_clcmd("say /ar", "command_progression")
    register_clcmd("say_team /ar", "command_progression")
    register_clcmd("say /artop", "command_leaderboard")
    register_clcmd("say_team /artop", "command_leaderboard")
    register_srvcmd("mm_armsrace_status", "mm_status")

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

public mm_status()
{
    server_print("[Arms Race] version=%s active=%d levels=%d kills_per_gun=2 knife_kills=1", PLUGIN_VERSION, armsrace_active(), AR_LEVEL_COUNT)
    for (new level = 0; level < AR_LEVEL_COUNT; level++)
    {
        new name[32]
        get_pcvar_string(g_level_cvars[level], name, charsmax(name))
        server_print("[Arms Race] level=%d weapon=%s", level+1, name)
    }
}

public client_putinserver(id)
{
    reset_player(id)
}

public client_disconnected(id)
{
    clear_player_tasks(id)
    g_next_action_notice[id] = 0.0
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
        process_progression_kill(attacker, victim)
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
    cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM)
}

public command_block_purchase(id)
{
    if (!armsrace_active()) return PLUGIN_CONTINUE
    mm_action_notice(id, "Buying is disabled. Earn your ^4next weapon^1 with ^4kills^1.")
    return PLUGIN_HANDLED
}

public command_block_drop(id)
{
    if (!armsrace_active()) return PLUGIN_CONTINUE
    mm_action_notice(id, "Weapon dropping is ^4disabled^1.")
    return PLUGIN_HANDLED
}

public command_progression(id)
{
    if (!armsrace_active()) return armsrace_inactive_message(id)
    if (!is_user_connected(id)) return PLUGIN_HANDLED

    new WeaponCatalog:weapon = g_progression[g_level[id]]
    new next[32]
    mm_next_weapon(id, next, charsmax(next))
    client_print_color(id, print_team_grey, "^4[%s]^3 Level ^4%d/%d^3: ^4%s^3 | Progress ^4%d/%d^3 | Next: ^4%s^3", PROJECT_NAME, g_level[id] + 1, AR_LEVEL_COUNT, ARCAT_DISPLAY_NAMES[weapon], g_level_kills[id], g_level[id] == AR_LEVEL_COUNT - 1 ? 1 : 2, next)
    return PLUGIN_HANDLED
}

public command_leaderboard(id)
{
    if (!armsrace_active()) return armsrace_inactive_message(id)

    new leaders[32], count
    collect_sorted_players(leaders, count)
    client_print_color(id, print_team_grey, "^4[%s]^3 Top ^4Arms Race^3 players:", PROJECT_NAME)

    new limit = min(count, 5)
    for (new rank = 0; rank < limit; rank++)
    {
        new player = leaders[rank]
        client_print_color(id, player, "^4[Arms Race]^1 #^4%d ^3%n^1 - Level ^4%d/%d^1, ^4%d^1 kills", rank + 1, player, g_level[player] + 1, AR_LEVEL_COUNT, g_kills[player])
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
        set_hudmessage(0, 220, 80, 0.02, 0.18, 0, 0.0, 1.1, 0.0, 0.0)
        if (leader)
        {
            new next[32]; mm_next_weapon(id, next, charsmax(next))
            ShowSyncHudMsg(id, g_hud_sync, "ARMS RACE | Level %d/%d: %s^nProgress %d/%d | Next: %s^nLeader %n (Level %d)", g_level[id] + 1, AR_LEVEL_COUNT, ARCAT_DISPLAY_NAMES[weapon], g_level_kills[id], g_level[id] == AR_LEVEL_COUNT - 1 ? 1 : 2, next, leader, g_level[leader]+1)
        }
        else
        {
            ShowSyncHudMsg(id, g_hud_sync, "Arms Race | Level %d/%d: %s^nProgress: %d/%d | Kills: %d | Waiting for players", g_level[id] + 1, AR_LEVEL_COUNT, ARCAT_DISPLAY_NAMES[weapon], g_level_kills[id], g_level[id] == AR_LEVEL_COUNT - 1 ? 1 : 2, g_kills[id])
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
    g_offer_rematch = false; g_announced_leader = 0
    g_gameplay_enabled = true
    load_progression()
    begin_next_match()
    remove_task(TASK_HUD)
    set_task(1.0, "task_update_hud", TASK_HUD, _, _, "b")
    client_print_color(0, print_team_grey, "^4[%s]^3 ^4Free-for-all^3: ^4two gun kills^3 or ^4one knife kill^3 to advance. Being knifed loses ^4a level^3.", PROJECT_NAME)
    log_amx("Arms Race activated with a validated %d-level progression.", AR_LEVEL_COUNT)
}

disable_armsrace()
{
    remove_task(TASK_REMATCH_VOTE)
    g_offer_rematch = false; g_announced_leader = 0
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
    g_announced_leader = 0

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || !is_playing_team(id)) continue
        if (is_user_alive(id))
        {
            apply_current_weapon(id)
            cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM)
        }
        else
        {
            remove_task(TASK_RESPAWN_BASE + id)
            set_task(0.2, "task_respawn_player", TASK_RESPAWN_BASE + id)
        }
    }
    client_print_color(0, print_team_grey, "^4[%s]^3 A ^4new match^3 has started. Good luck!", PROJECT_NAME)
    if (g_offer_rematch)
    {
        g_offer_rematch = false
        server_cmd("sv_restart 1")
        g_rematch_attempts = 0
        set_task(1.5, "mm_begin_rematch_vote", TASK_REMATCH_VOTE)
    }
}
public mm_begin_rematch_vote()
{
    if (armsrace_active() && !mm_voting_start_rematch(MM_MODE_ARMS_RACE) && ++g_rematch_attempts < 6) set_task(5.0, "mm_begin_rematch_vote", TASK_REMATCH_VOTE)
}
mm_next_weapon(id, text[], length)
{
    if (g_level[id] < AR_LEVEL_COUNT-1) copy(text, length, ARCAT_DISPLAY_NAMES[g_progression[g_level[id]+1]])
    else copy(text, length, "Final knife kill wins")
}
mm_announce_leader()
{
    new players[32], count
    collect_sorted_players(players, count)
    if (!count || !g_kills[players[0]] || g_announced_leader == players[0]) return
    g_announced_leader = players[0]
    client_print_color(0, g_announced_leader, "^4[Arms Race]^1 ^3%n^1 takes the lead at level ^4%d^1!", g_announced_leader, g_level[g_announced_leader]+1)
}

process_progression_kill(attacker, victim)
{
    new WeaponCatalog:required_weapon = g_progression[g_level[attacker]]
    new active_item = get_member(attacker, m_pActiveItem)
    new weapon = is_nullent(active_item) ? 0 : get_member(active_item, m_iId)
    new bool:knife_kill = weapon == CSW_KNIFE
    if (!knife_kill && weapon != ARCAT_IDS[required_weapon])
    {
        replenish_current_ammunition(attacker)
        return
    }

    if (knife_kill)
    {
        if (g_level[victim] > 0) g_level[victim]--
        g_level_kills[victim] = 0
        client_print_color(0, attacker, "^4[%s]^3 %n^1 | ^4KNIFE KILL^1 - skips a level!", PROJECT_NAME, attacker)
        client_print_color(0, victim, "^4[%s]^3 %n^1 | LEVEL DOWN | ^4%d^1 - ^4%s", PROJECT_NAME, victim, g_level[victim]+1, ARCAT_DISPLAY_NAMES[g_progression[g_level[victim]]])
    }
    g_kills[attacker]++
    if (g_level[attacker] == AR_LEVEL_COUNT - 1)
    {
        if (knife_kill) finish_match(attacker)
        return
    }

    g_level_kills[attacker]++
    if (!knife_kill && g_level_kills[attacker] < 2)
    {
        replenish_current_ammunition(attacker)
        client_print_color(attacker, print_team_grey, "^4[%s]^3 Progress: ^41 / 2^3 kills | One more to advance.", PROJECT_NAME)
        mm_announce_leader()
        return
    }
    g_level_kills[attacker] = 0
    g_level[attacker]++
    apply_current_weapon(attacker)
    client_print_color(0, attacker, "^4[%s]^1 ^3%n^1 LEVEL UP | ^4%d^1 - ^4%s^1.", PROJECT_NAME, attacker, g_level[attacker] + 1, ARCAT_DISPLAY_NAMES[g_progression[g_level[attacker]]])
    mm_announce_leader()
    if (g_level[attacker] == AR_LEVEL_COUNT-1)
    {
        client_print_color(0, attacker, "^4[Arms Race]^1 ^3%n^1 reached ^4FINAL KNIFE^1! One knife kill wins.", attacker)
        set_dhudmessage(255, 120, 40, -1.0, 0.30, 0, 0.0, 4.0, 0.1, 0.4)
        show_dhudmessage(0, "FINAL KNIFE LEVEL^n%n needs one knife kill!", attacker)
    }
}

finish_match(winner)
{
    g_match_finished = true
    g_offer_rematch = true
    for (new id = 1; id <= MaxClients; id++) clear_player_tasks(id)
    client_print_color(0, winner, "^4[%s]^1 ^3%n^1 wins ^4Arms Race^1 with the ^4final knife kill^1!", PROJECT_NAME, winner)
    set_hudmessage(0, 255, 80, -1.0, 0.30, 0, 1.0, 5.0)
    ShowSyncHudMsg(0, g_hud_sync, "%n WINS ARMS RACE!^nFinal knife kill completed", winner)
    new leaders[32], count, detail[96]
    collect_sorted_players(leaders, count)
    formatex(detail, charsmax(detail), "%n wins! Rematch/map vote follows the round reset.", winner)
    mm_show_results(MM_MODE_ARMS_RACE, winner, count > 1 ? leaders[1] : 0, count > 2 ? leaders[2] : 0, "ARMS RACE CHAMPION", detail)
    log_amx("%n won Arms Race with %d valid progression kills.", winner, g_kills[winner])
    set_task(MATCH_RESET_DELAY, "task_reset_match", TASK_MATCH_RESET)
}

apply_current_weapon(id)
{
    if (!is_user_alive(id)) return

    new WeaponCatalog:weapon = g_progression[g_level[id]]
    new CsArmorType:armor_type
    new armor = cs_get_user_armor(id, armor_type)
    rg_remove_all_items(id, false)
    cs_set_user_armor(id, armor, armor_type)
    give_item(id, "weapon_knife")
    if (weapon != ARCAT_KNIFE) give_item(id, ARCAT_ENTITIES[weapon])
    engclient_cmd(id, ARCAT_ENTITIES[weapon])
    replenish_current_ammunition(id)
}

replenish_current_ammunition(id)
{
    if (!is_user_connected(id)) return
    new WeaponCatalog:weapon = g_progression[g_level[id]]
    if (weapon != ARCAT_KNIFE) cs_set_user_bpammo(id, ARCAT_IDS[weapon], ARCAT_AMMO[weapon])
}

bool:is_valid_enemy_kill(victim, attacker)
{
    if (attacker < 1 || attacker > MaxClients || attacker == victim || !is_user_connected(attacker)) return false
    if (!is_playing_team(victim) || !is_playing_team(attacker)) return false
    return true
}

register_progression_cvars()
{
    new cvar_name[32]
    for (new level = 0; level < AR_LEVEL_COUNT; level++)
    {
        formatex(cvar_name, charsmax(cvar_name), "mm_ar_level_%d", level + 1)
        g_level_cvars[level] = register_cvar(cvar_name, ARCAT_NAMES[DEFAULT_PROGRESSION[level]])
    }
}

load_progression()
{
    new configured_name[32]
    for (new level = 0; level < AR_LEVEL_COUNT; level++)
    {
        get_pcvar_string(g_level_cvars[level], configured_name, charsmax(configured_name))
        new WeaponCatalog:weapon = find_catalog_weapon(configured_name)
        if (_:weapon < 0 || (level == AR_LEVEL_COUNT - 1 && weapon != ARCAT_KNIFE))
        {
            weapon = DEFAULT_PROGRESSION[level]
            log_amx("Invalid Arms Race weapon '%s' at level %d; using %s.", configured_name, level + 1, ARCAT_NAMES[weapon])
        }
        g_progression[level] = weapon
    }
}

WeaponCatalog:find_catalog_weapon(const name[])
{
    for (new WeaponCatalog:weapon = ARCAT_GLOCK; weapon < ARCAT_CATALOG_COUNT; weapon++)
    {
        if (equali(name, ARCAT_NAMES[weapon])) return weapon
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
    if (g_level_kills[candidate] != g_level_kills[current]) return g_level_kills[candidate] > g_level_kills[current]
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
    g_level_kills[id] = 0
    g_kills[id] = 0
    g_deaths[id] = 0
}

reset_all_progression()
{
    for (new id = 1; id <= MaxClients; id++) reset_player(id)
}

armsrace_inactive_message(id)
{
    client_print_color(id, print_team_grey, "^4[%s]^3 These commands are available in ^4Arms Race^3 mode.", PROJECT_NAME)
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

mm_action_notice(id, const text[])
{
    if (!is_user_connected(id)) return
    new Float:now = get_gametime()
    if (now < g_next_action_notice[id]) return
    g_next_action_notice[id] = now + 2.0
    client_print_color(id, print_team_grey, "^4[Arms Race]^3 %s", text)
}

public mm_finished_damage(victim, inflictor, attacker, Float:damage, bits)
{
    return armsrace_active() && g_match_finished ? HAM_SUPERCEDE : HAM_IGNORED
}
public plugin_end()
{
    remove_task(TASK_HUD); remove_task(TASK_MATCH_RESET); remove_task(TASK_REMATCH_VOTE)
    for (new id=1; id<=MaxClients; id++) clear_player_tasks(id)
}
