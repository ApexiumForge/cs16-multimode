#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <mm_mode_api>

#define PLUGIN_NAME    "Multi-Mode Network AWP Only"
#define PLUGIN_VERSION "0.4.4"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"

#define TASK_RESPAWN_BASE    61000
#define TASK_PROTECTION_BASE 62000
#define TASK_LOADOUT_BASE    63000
#define TASK_HUD             64000
#define TASK_RESTORE_MODE    64001

new g_kills[33]
new g_deaths[33]
new bool:g_protected[33]
new bool:g_gameplay_enabled
new g_respawn_delay_cvar
new g_spawn_protection_cvar
new g_awp_ammo_cvar
new g_change_map_cvar
new g_preferred_map_cvar
new g_fallback_map_cvar
new g_pending_restore_cvar
new g_hud_sync

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /awp", "command_status")
    register_clcmd("say_team /awp", "command_status")
    register_clcmd("say /awptop", "command_leaderboard")
    register_clcmd("say_team /awptop", "command_leaderboard")

    register_clcmd("buy", "command_block_inventory")
    register_clcmd("buyequip", "command_block_inventory")
    register_clcmd("cl_autobuy", "command_block_inventory")
    register_clcmd("cl_rebuy", "command_block_inventory")
    register_clcmd("autobuy", "command_block_inventory")
    register_clcmd("rebuy", "command_block_inventory")
    register_clcmd("buyammo1", "command_block_inventory")
    register_clcmd("buyammo2", "command_block_inventory")
    register_clcmd("drop", "command_block_inventory")

    RegisterHam(Ham_Killed, "player", "player_killed_post", 1)
    RegisterHam(Ham_Spawn, "player", "player_spawned_post", 1)
    RegisterHam(Ham_Touch, "weaponbox", "block_weapon_pickup")
    RegisterHam(Ham_Touch, "armoury_entity", "block_weapon_pickup")
    register_forward(FM_CmdStart, "forward_command_start")

    g_respawn_delay_cvar = register_cvar("mm_awp_respawn_delay", "1.0")
    g_spawn_protection_cvar = register_cvar("mm_awp_spawn_protection", "2.0")
    g_awp_ammo_cvar = register_cvar("mm_awp_reserve_ammo", "30")
    g_change_map_cvar = register_cvar("mm_awp_change_map", "1")
    g_preferred_map_cvar = register_cvar("mm_awp_preferred_map", "awp_india")
    g_fallback_map_cvar = register_cvar("mm_awp_fallback_map", "awp_map")
    g_pending_restore_cvar = register_cvar("mm_awp_pending_restore", "0")
    g_hud_sync = CreateHudSyncObj()

    for (new id = 1; id <= MaxClients; id++) reset_player(id)

    if (get_pcvar_num(g_pending_restore_cvar) == 1)
    {
        set_task(1.0, "task_restore_mode_after_map", TASK_RESTORE_MODE)
    }
    else if (mm_get_active_mode() == MM_MODE_AWP_ONLY)
    {
        activate_awponly()
    }

    log_amx("%s AWP Only v%s initialized.", PROJECT_NAME, PLUGIN_VERSION)
}

public client_putinserver(id)
{
    reset_player(id)
}

public client_disconnected(id)
{
    clear_player_tasks(id)
    g_protected[id] = false
    reset_player(id)
}

public mm_mode_transition_started(old_mode, requested_mode)
{
    if (MmMode:old_mode == MM_MODE_AWP_ONLY && MmMode:requested_mode != MM_MODE_AWP_ONLY)
    {
        disable_awponly()
    }
}

public mm_mode_changed(old_mode, new_mode)
{
    if (MmMode:new_mode == MM_MODE_AWP_ONLY) activate_awponly()
}

public task_restore_mode_after_map()
{
    set_pcvar_num(g_pending_restore_cvar, 0)

    if (mm_get_active_mode() == MM_MODE_AWP_ONLY)
    {
        activate_awponly()
        return
    }

    new MmRequestResult:result = mm_request_mode(MM_MODE_AWP_ONLY, 0)
    if (result != MM_REQUEST_ACCEPTED && result != MM_REQUEST_DUPLICATE)
    {
        log_amx("AWP Only could not be restored after map change (request result %d).", _:result)
    }
}

public player_killed_post(victim, attacker, should_gib)
{
    if (!awponly_active() || !is_user_connected(victim)) return HAM_IGNORED

    remove_spawn_protection(victim)
    g_deaths[victim]++

    if (is_valid_ffa_kill(victim, attacker))
    {
        g_kills[attacker]++
        replenish_awp_ammunition(attacker)
    }

    remove_task(TASK_RESPAWN_BASE + victim)
    set_task(get_pcvar_float(g_respawn_delay_cvar), "task_respawn_player", TASK_RESPAWN_BASE + victim)
    return HAM_IGNORED
}

public task_respawn_player(task_id)
{
    new id = task_id - TASK_RESPAWN_BASE
    if (!awponly_active() || !is_user_connected(id) || is_user_alive(id) || !is_playing_team(id)) return
    ExecuteHamB(Ham_CS_RoundRespawn, id)
}

public player_spawned_post(id)
{
    if (!awponly_active() || !is_user_alive(id) || !is_playing_team(id)) return HAM_IGNORED

    enable_spawn_protection(id)
    remove_task(TASK_LOADOUT_BASE + id)
    set_task(0.1, "task_apply_loadout", TASK_LOADOUT_BASE + id)
    return HAM_IGNORED
}

public task_apply_loadout(task_id)
{
    new id = task_id - TASK_LOADOUT_BASE
    if (!awponly_active() || !is_user_alive(id)) return
    apply_awp_loadout(id)
}

public forward_command_start(id, command_handle, random_seed)
{
    if (!awponly_active() || !g_protected[id] || !is_user_alive(id)) return FMRES_IGNORED

    new buttons = get_uc(command_handle, UC_Buttons)
    new weapon = get_user_weapon(id)
    if ((buttons & IN_ATTACK) || (weapon == CSW_KNIFE && (buttons & IN_ATTACK2))) remove_spawn_protection(id)
    return FMRES_IGNORED
}

public task_remove_spawn_protection(task_id)
{
    remove_spawn_protection(task_id - TASK_PROTECTION_BASE)
}

public block_weapon_pickup(entity, id)
{
    if (!awponly_active() || id < 1 || id > MaxClients || !is_user_connected(id)) return HAM_IGNORED
    return HAM_SUPERCEDE
}

public command_block_inventory(id)
{
    if (!awponly_active()) return PLUGIN_CONTINUE
    client_print(id, print_center, "Only AWP and Knife are available in AWP Only")
    return PLUGIN_HANDLED
}

public command_status(id)
{
    if (!awponly_active()) return awponly_inactive_message(id)
    client_print(id, print_chat, "[%s] AWP Only | %d kills / %d deaths", PROJECT_NAME, g_kills[id], g_deaths[id])
    return PLUGIN_HANDLED
}

public command_leaderboard(id)
{
    if (!awponly_active()) return awponly_inactive_message(id)

    new leaders[32], count
    collect_sorted_players(leaders, count)
    client_print(id, print_chat, "[%s] AWP Only leaderboard:", PROJECT_NAME)

    new limit = min(count, 5)
    for (new rank = 0; rank < limit; rank++)
    {
        new player = leaders[rank]
        client_print(id, print_chat, "#%d %n - %d kills / %d deaths", rank + 1, player, g_kills[player], g_deaths[player])
    }
    return PLUGIN_HANDLED
}

public task_update_hud()
{
    if (!awponly_active()) return

    new leader = find_leader()
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || is_user_bot(id)) continue

        set_hudmessage(80, 180, 255, 0.02, 0.18, 0, 0.0, 1.1, 0.0, 0.0)
        if (leader)
        {
            ShowSyncHudMsg(id, g_hud_sync, "AWP Only | Kills: %d | Deaths: %d^nLeader: %n (%d kills)", g_kills[id], g_deaths[id], leader, g_kills[leader])
        }
        else
        {
            ShowSyncHudMsg(id, g_hud_sync, "AWP Only | Kills: %d | Deaths: %d^nWaiting for players", g_kills[id], g_deaths[id])
        }
    }
}

activate_awponly()
{
    g_gameplay_enabled = true
    reset_all_scores()

    if (queue_preferred_map_change())
    {
        log_amx("AWP Only map change queued; gameplay activation will resume on the target map.")
        return
    }

    remove_task(TASK_HUD)
    set_task(1.0, "task_update_hud", TASK_HUD, _, _, "b")

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

    client_print(0, print_chat, "[%s] Free-for-all AWP Only active. AWP and Knife only.", PROJECT_NAME)
    log_amx("AWP Only activated; transient scores reset.")
}

disable_awponly()
{
    g_gameplay_enabled = false
    set_pcvar_num(g_pending_restore_cvar, 0)
    remove_task(TASK_HUD)
    remove_task(TASK_RESTORE_MODE)

    for (new id = 1; id <= MaxClients; id++)
    {
        clear_player_tasks(id)
        remove_spawn_protection(id)
    }

    reset_all_scores()
    server_cmd("exec server.cfg")
    server_exec()
    log_amx("AWP Only disabled; tasks, protection, scores, and baseline cvars restored.")
}

bool:queue_preferred_map_change()
{
    if (get_pcvar_num(g_change_map_cvar) == 0) return false

    new preferred_map[32], fallback_map[32], target_map[32], current_map[32]
    get_pcvar_string(g_preferred_map_cvar, preferred_map, charsmax(preferred_map))
    get_pcvar_string(g_fallback_map_cvar, fallback_map, charsmax(fallback_map))
    get_mapname(current_map, charsmax(current_map))

    // Respect an installed AWP map selected by the authoritative vote controller.
    if (equali(current_map, "awp_", 4) && is_installed_map(current_map)) return false

    if (is_installed_map(preferred_map)) copy(target_map, charsmax(target_map), preferred_map)
    else if (is_installed_map(fallback_map)) copy(target_map, charsmax(target_map), fallback_map)
    else
    {
        log_amx("AWP Only map selection skipped: neither '%s' nor '%s' has an installed BSP.", preferred_map, fallback_map)
        return false
    }

    if (equali(current_map, target_map)) return false

    set_pcvar_num(g_pending_restore_cvar, 1)
    server_cmd("changelevel %s", target_map)
    log_amx("AWP Only changing map from %s to %s.", current_map, target_map)
    return true
}

bool:is_installed_map(const map_name[])
{
    if (!is_safe_map_name(map_name)) return false

    new map_path[64]
    formatex(map_path, charsmax(map_path), "maps/%s.bsp", map_name)
    return bool:file_exists(map_path)
}

bool:is_safe_map_name(const map_name[])
{
    if (!map_name[0]) return false

    for (new index = 0; map_name[index]; index++)
    {
        new character = map_name[index]
        if ((character >= 'a' && character <= 'z') ||
            (character >= 'A' && character <= 'Z') ||
            (character >= '0' && character <= '9') ||
            character == '_' || character == '-') continue
        return false
    }
    return true
}

apply_awp_loadout(id)
{
    strip_user_weapons(id)
    give_item(id, "weapon_knife")
    give_item(id, "weapon_awp")
    replenish_awp_ammunition(id)
}

replenish_awp_ammunition(id)
{
    if (!is_user_connected(id)) return
    new reserve_ammo = clamp(get_pcvar_num(g_awp_ammo_cvar), 10, 90)
    cs_set_user_bpammo(id, CSW_AWP, reserve_ammo)
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

bool:is_valid_ffa_kill(victim, attacker)
{
    if (attacker < 1 || attacker > MaxClients || attacker == victim || !is_user_connected(attacker)) return false
    if (!is_playing_team(victim) || !is_playing_team(attacker)) return false
    return true
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
    if (g_kills[candidate] != g_kills[current]) return g_kills[candidate] > g_kills[current]
    return g_deaths[candidate] < g_deaths[current]
}

clear_player_tasks(id)
{
    remove_task(TASK_RESPAWN_BASE + id)
    remove_task(TASK_PROTECTION_BASE + id)
    remove_task(TASK_LOADOUT_BASE + id)
}

reset_player(id)
{
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

awponly_inactive_message(id)
{
    client_print(id, print_chat, "[%s] AWP Only commands are disabled while another mode is active.", PROJECT_NAME)
    return PLUGIN_HANDLED
}

bool:is_playing_team(id)
{
    if (!is_user_connected(id)) return false
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

bool:awponly_active()
{
    return g_gameplay_enabled && mm_get_active_mode() == MM_MODE_AWP_ONLY
}
