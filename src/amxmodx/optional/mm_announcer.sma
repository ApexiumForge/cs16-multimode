#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <mm_mode_api>

#define PLUGIN_NAME    "Multi-Mode Network Announcer"
#define PLUGIN_VERSION "0.4.4"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"

#define DOUBLE_KILL_SOUND "multimode/doublekill.wav"
#define ANNOUNCER_CONFIG  "addons/amxmodx/configs/mm_announcer.cfg"

new Float:g_last_kill_time[33]
new g_kills_in_window[33]
new g_enabled_cvar
new g_double_kill_window_cvar

public plugin_precache()
{
    precache_sound(DOUBLE_KILL_SOUND)
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    RegisterHam(Ham_Killed, "player", "player_killed_post", 1)

    g_enabled_cvar = register_cvar("mm_announcer_enabled", "1")
    g_double_kill_window_cvar = register_cvar("mm_announcer_doublekill_window", "4.0")

    if (file_exists(ANNOUNCER_CONFIG))
    {
        server_cmd("exec %s", ANNOUNCER_CONFIG)
        server_exec()
    }
    else
    {
        log_amx("Announcer configuration is missing: %s", ANNOUNCER_CONFIG)
    }

    reset_all_sequences()
    log_amx("%s announcer v%s initialized; Double Kill sound precached.", PROJECT_NAME, PLUGIN_VERSION)
}

public client_putinserver(id)
{
    reset_sequence(id)
}

public client_disconnected(id)
{
    reset_sequence(id)
}

public mm_mode_transition_started(old_mode, requested_mode)
{
    reset_all_sequences()
}

public player_killed_post(victim, attacker, should_gib)
{
    if (victim >= 1 && victim <= MaxClients)
    {
        reset_sequence(victim)
    }

    if (get_pcvar_num(g_enabled_cvar) == 0 || !is_valid_announcer_kill(victim, attacker))
    {
        return HAM_IGNORED
    }

    new Float:now = get_gametime()
    new Float:window = get_pcvar_float(g_double_kill_window_cvar)
    if (window < 0.1)
    {
        window = 0.1
    }

    if (g_kills_in_window[attacker] > 0 && now - g_last_kill_time[attacker] <= window)
    {
        g_kills_in_window[attacker]++
    }
    else
    {
        g_kills_in_window[attacker] = 1
    }
    g_last_kill_time[attacker] = now

    if (g_kills_in_window[attacker] == 2)
    {
        client_cmd(0, "spk ^"%s^"", DOUBLE_KILL_SOUND)
        client_print(0, print_chat, "[%s] %n made a DOUBLE KILL!", PROJECT_NAME, attacker)
        reset_sequence(attacker)
    }

    return HAM_IGNORED
}

bool:is_valid_announcer_kill(victim, attacker)
{
    if (victim < 1 || victim > MaxClients || attacker < 1 || attacker > MaxClients) return false
    if (victim == attacker || !is_user_connected(victim) || !is_user_connected(attacker)) return false
    if (!is_playing_team(victim) || !is_playing_team(attacker)) return false

    if (mm_get_active_mode() == MM_MODE_CLASSIC)
    {
        return cs_get_user_team(victim) != cs_get_user_team(attacker)
    }
    return true
}

bool:is_playing_team(id)
{
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

reset_sequence(id)
{
    g_last_kill_time[id] = 0.0
    g_kills_in_window[id] = 0
}

reset_all_sequences()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        reset_sequence(id)
    }
}
