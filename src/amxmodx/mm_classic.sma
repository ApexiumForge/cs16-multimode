#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <mm_mode_api>
#include <mm_classic_api>

#define PLUGIN_NAME    "Multi-Mode Network Classic"
#define PLUGIN_VERSION "0.4.4"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"
#define TASK_WARMUP    30001
#define TASK_LIVE      30002
#define TASK_HUD       30003
#define TASK_FINISH    30004

enum MatchState
{
    MATCH_WAITING = 0,
    MATCH_WARMUP,
    MATCH_READY,
    MATCH_LIVE,
    MATCH_HALFTIME,
    MATCH_PAUSED,
    MATCH_FINISHED
}

enum MatchRules
{
    RULE_MR3 = 3,
    RULE_MR5 = 5,
    RULE_MR12 = 12
}

new const MATCH_STATE_NAMES[][] =
{
    "Waiting", "Warmup", "Ready", "Live", "Halftime", "Paused", "Finished"
}

new const FORMAT_T_SLOTS[MM_FORMAT_COUNT] = {1, 2, 3, 4, 5, 1, 2, 3, 4}
new const FORMAT_CT_SLOTS[MM_FORMAT_COUNT] = {1, 2, 3, 4, 5, 2, 3, 4, 5}

new MatchState:g_match_state = MATCH_WAITING
new MatchRules:g_match_rules = RULE_MR12
new bool:g_ready[33]
new g_roster[33]
new g_team_a_score
new g_team_b_score
new g_rounds_played
new g_warmup_remaining
new bool:g_second_half
new bool:g_overtime
new g_overtime_rounds
new bool:g_match_committed
new g_hud_sync
new g_warmup_cvar
new g_overtime_cvar

public plugin_natives()
{
    register_library("mm_classic")
    register_native("mm_classic_change_blocked", "native_classic_change_blocked")
    register_native("mm_classic_get_state", "native_classic_get_state")
    register_native("mm_classic_get_status", "native_classic_get_status")
    register_native("mm_classic_get_ready_count", "native_classic_get_ready_count")
    register_native("mm_classic_get_required_count", "native_classic_get_required_count")
    register_native("mm_classic_team_has_capacity", "native_classic_team_has_capacity")
    register_native("mm_classic_force_ready_humans", "native_classic_force_ready_humans")
    register_native("mm_classic_force_unready_humans", "native_classic_force_unready_humans")
    register_native("mm_classic_admin_warmup", "native_classic_admin_warmup")
    register_native("mm_classic_admin_restart", "native_classic_admin_restart")
    register_native("mm_classic_admin_stop", "native_classic_admin_stop")
}

public native_classic_change_blocked()
{
    return g_match_committed
}

public native_classic_get_state() { return _:g_match_state; }
public native_classic_get_ready_count() { return ready_count(); }
public native_classic_get_required_count() { return required_players(); }

public native_classic_get_status(plugin_id, parameter_count)
{
    new status[128], format_name[16]
    mm_get_classic_format_name(mm_get_classic_format(), format_name, charsmax(format_name))
    formatex(status, charsmax(status), "%s | %s | MR%d | Ready %d/%d | Score %d-%d", format_name,
        MATCH_STATE_NAMES[_:g_match_state], _:g_match_rules, ready_count(), required_players(),
        g_team_a_score, g_team_b_score)
    set_string(1, status, get_param(2))
}

public native_classic_team_has_capacity(plugin_id, parameter_count)
{
    new CsTeams:team = CsTeams:get_param(1)
    if (team == CS_TEAM_T) return team_count(team) < t_capacity()
    if (team == CS_TEAM_CT) return team_count(team) < ct_capacity()
    return false
}

public native_classic_force_ready_humans(plugin_id, parameter_count)
{
    new requester = get_param(1)
    if (!classic_admin_authorized(requester)) return _:MM_CLASSIC_ADMIN_UNAUTHORIZED
    if (!classic_active()) return _:MM_CLASSIC_ADMIN_INACTIVE
    if (g_match_state != MATCH_WARMUP && g_match_state != MATCH_READY) return _:MM_CLASSIC_ADMIN_INVALID_STATE

    for (new id = 1; id <= MaxClients; id++)
    {
        if (is_match_player(id) && !is_user_bot(id) && !is_user_hltv(id)) g_ready[id] = true
    }
    try_start_match()
    return _:MM_CLASSIC_ADMIN_OK
}

public native_classic_force_unready_humans(plugin_id, parameter_count)
{
    new requester = get_param(1)
    if (!classic_admin_authorized(requester)) return _:MM_CLASSIC_ADMIN_UNAUTHORIZED
    if (!classic_active()) return _:MM_CLASSIC_ADMIN_INACTIVE
    if (g_match_state != MATCH_WARMUP && g_match_state != MATCH_READY) return _:MM_CLASSIC_ADMIN_INVALID_STATE

    for (new id = 1; id <= MaxClients; id++)
    {
        if (is_match_player(id) && !is_user_bot(id) && !is_user_hltv(id)) g_ready[id] = false
    }
    return _:MM_CLASSIC_ADMIN_OK
}

public native_classic_admin_warmup(plugin_id, parameter_count)
{
    new requester = get_param(1)
    if (!classic_admin_authorized(requester)) return _:MM_CLASSIC_ADMIN_UNAUTHORIZED
    if (!classic_active()) return _:MM_CLASSIC_ADMIN_INACTIVE
    if (!teams_full()) return _:MM_CLASSIC_ADMIN_TEAMS_INCOMPLETE
    if (g_match_state == MATCH_LIVE || g_match_state == MATCH_HALFTIME || g_match_state == MATCH_PAUSED) return _:MM_CLASSIC_ADMIN_INVALID_STATE
    start_warmup()
    return _:MM_CLASSIC_ADMIN_OK
}

public native_classic_admin_restart(plugin_id, parameter_count)
{
    new requester = get_param(1)
    if (!classic_admin_authorized(requester)) return _:MM_CLASSIC_ADMIN_UNAUTHORIZED
    if (!classic_active()) return _:MM_CLASSIC_ADMIN_INACTIVE
    if (!teams_full()) return _:MM_CLASSIC_ADMIN_TEAMS_INCOMPLETE
    start_live_match()
    return _:MM_CLASSIC_ADMIN_OK
}

public native_classic_admin_stop(plugin_id, parameter_count)
{
    new requester = get_param(1)
    if (!classic_admin_authorized(requester)) return _:MM_CLASSIC_ADMIN_UNAUTHORIZED
    if (!classic_active()) return _:MM_CLASSIC_ADMIN_INACTIVE
    enter_waiting_state()
    return _:MM_CLASSIC_ADMIN_OK
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /match", "command_match")
    register_clcmd("say_team /match", "command_match")
    register_clcmd("say /ready", "command_ready")
    register_clcmd("say_team /ready", "command_ready")
    register_clcmd("say /unready", "command_unready")
    register_clcmd("say_team /unready", "command_unready")
    register_clcmd("say /matchscore", "command_score")
    register_clcmd("say_team /matchscore", "command_score")
    register_clcmd("say /score", "command_score")
    register_clcmd("say_team /score", "command_score")
    register_clcmd("say /teams", "command_teams")
    register_clcmd("say_team /teams", "command_teams")
    register_clcmd("say /pause", "command_pause")
    register_clcmd("say_team /pause", "command_pause")
    register_clcmd("jointeam", "command_join_team")

    register_concmd("mm_match_start", "admin_match_start", ADMIN_CFG)
    register_concmd("mm_match_stop", "admin_match_stop", ADMIN_CFG)
    register_concmd("mm_match_restart", "admin_match_restart", ADMIN_CFG)
    register_concmd("mm_match_format", "admin_match_format", ADMIN_CFG, "<1v1|2v2|3v3|4v4|5v5|1v2|2v3|3v4|4v5>")
    register_concmd("mm_match_rules", "admin_match_rules", ADMIN_CFG, "<mr3|mr5|mr12>")

    register_event("SendAudio", "event_t_win", "a", "2=%!MRAD_terwin")
    register_event("SendAudio", "event_ct_win", "a", "2=%!MRAD_ctwin")
    register_event("TeamInfo", "event_team_info", "a")

    g_warmup_cvar = register_cvar("mm_classic_warmup", "30")
    g_overtime_cvar = register_cvar("mm_classic_overtime", "1")
    g_hud_sync = CreateHudSyncObj()
    set_task(1.0, "task_update_hud", TASK_HUD, _, _, "b")

    if (classic_active())
    {
        enter_waiting_state()
    }
    log_amx("%s Classic match system v%s initialized.", PROJECT_NAME, PLUGIN_VERSION)
}

public client_putinserver(id)
{
    g_ready[id] = false
    g_roster[id] = 0
    set_task(1.0, "task_evaluate_teams")
}

public client_disconnected(id)
{
    new bool:was_match_player = g_roster[id] != 0
    g_ready[id] = false
    g_roster[id] = 0
    if (was_match_player && classic_active() && (g_match_state == MATCH_LIVE || g_match_state == MATCH_HALFTIME))
    {
        set_mm_match_phase(MATCH_PAUSED)
        client_print(0, print_chat, "[%s] Match paused: a required player disconnected.", PROJECT_NAME)
    }
}

public mm_mode_changed(old_mode, new_mode)
{
    if (MmMode:new_mode == MM_MODE_CLASSIC)
    {
        enter_waiting_state()
    }
    else if (MmMode:old_mode == MM_MODE_CLASSIC)
    {
        disable_classic_match()
    }
}

public mm_mode_transition_started(old_mode, new_mode)
{
    if (MmMode:old_mode == MM_MODE_CLASSIC && MmMode:new_mode != MM_MODE_CLASSIC)
    {
        disable_classic_match()
    }
}

public mm_classic_format_changed(old_format, new_format)
{
    if (classic_active())
    {
        client_print(0, print_chat, "[%s] Classic format changed; current match setup was reset.", PROJECT_NAME)
        enter_waiting_state()
    }
}

public command_join_team(id)
{
    if (!classic_active()) return PLUGIN_CONTINUE

    new argument[4]
    read_argv(1, argument, charsmax(argument))
    new requested = str_to_num(argument)
    if (requested == 6) return PLUGIN_CONTINUE

    if (g_match_state == MATCH_LIVE || g_match_state == MATCH_HALFTIME)
    {
        client_print(id, print_chat, "[%s] Team changes are locked during a live match. Spectating is allowed.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    if (requested == 1 && team_count(CS_TEAM_T, id) >= t_capacity())
    {
        client_print(id, print_chat, "[%s] Terrorists are full (%d/%d).", PROJECT_NAME, t_capacity(), t_capacity())
        return PLUGIN_HANDLED
    }
    if (requested == 2 && team_count(CS_TEAM_CT, id) >= ct_capacity())
    {
        client_print(id, print_chat, "[%s] Counter-Terrorists are full (%d/%d).", PROJECT_NAME, ct_capacity(), ct_capacity())
        return PLUGIN_HANDLED
    }
    return PLUGIN_CONTINUE
}

public event_team_info()
{
    if (!classic_active()) return
    new id = read_data(1)
    if (!is_user_connected(id)) return
    set_task(0.1, "task_enforce_team", id)
}

public task_enforce_team(id)
{
    if (!is_user_connected(id) || !classic_active()) return
    new CsTeams:team = cs_get_user_team(id)
    if ((team == CS_TEAM_T && team_count(CS_TEAM_T) > t_capacity()) ||
        (team == CS_TEAM_CT && team_count(CS_TEAM_CT) > ct_capacity()))
    {
        cs_set_user_team(id, CS_TEAM_SPECTATOR)
        g_ready[id] = false
        client_print(id, print_chat, "[%s] That team was full; you were moved to Spectators.", PROJECT_NAME)
    }
    task_evaluate_teams()
}

public task_evaluate_teams()
{
    if (!classic_active()) return
    if (teams_full())
    {
        if (g_match_state == MATCH_WAITING) start_warmup()
        else if (g_match_state == MATCH_PAUSED) resume_live_match()
    }
    else if (g_match_state == MATCH_WARMUP || g_match_state == MATCH_READY)
    {
        enter_waiting_state()
    }
}

public command_ready(id)
{
    if (!classic_active()) return PLUGIN_HANDLED
    if (g_match_state != MATCH_WARMUP && g_match_state != MATCH_READY)
    {
        client_print(id, print_chat, "[%s] Ready-up is not available in the %s state.", PROJECT_NAME, MATCH_STATE_NAMES[_:g_match_state])
        return PLUGIN_HANDLED
    }
    if (!is_match_player(id))
    {
        client_print(id, print_chat, "[%s] Join T or CT before readying up.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    g_ready[id] = true
    client_print(0, print_chat, "[%s] %n is ready (%d/%d).", PROJECT_NAME, id, ready_count(), required_players())
    try_start_match()
    return PLUGIN_HANDLED
}

public command_unready(id)
{
    if (!classic_active()) return PLUGIN_HANDLED
    if (g_match_state != MATCH_WARMUP && g_match_state != MATCH_READY) return PLUGIN_HANDLED
    g_ready[id] = false
    client_print(0, print_chat, "[%s] %n is no longer ready.", PROJECT_NAME, id)
    return PLUGIN_HANDLED
}

public command_match(id)
{
    if (!classic_active()) return classic_inactive_message(id)
    new format_name[16]
    mm_get_classic_format_name(mm_get_classic_format(), format_name, charsmax(format_name))
    client_print(id, print_chat, "[%s] Classic %s | %s | MR%d | Ready %d/%d", PROJECT_NAME, format_name, MATCH_STATE_NAMES[_:g_match_state], _:g_match_rules, ready_count(), required_players())
    return PLUGIN_HANDLED
}

public command_score(id)
{
    if (!classic_active()) return classic_inactive_message(id)
    client_print(id, print_chat, "[%s] Team A %d - %d Team B | Round %d", PROJECT_NAME, g_team_a_score, g_team_b_score, g_rounds_played)
    return PLUGIN_HANDLED
}

public command_teams(id)
{
    if (!classic_active()) return classic_inactive_message(id)
    client_print(id, print_chat, "[%s] T %d/%d | CT %d/%d | Spectators allowed", PROJECT_NAME, team_count(CS_TEAM_T), t_capacity(), team_count(CS_TEAM_CT), ct_capacity())
    return PLUGIN_HANDLED
}

public command_pause(id)
{
    if (!classic_active()) return classic_inactive_message(id)
    if (!(get_user_flags(id) & ADMIN_CFG))
    {
        client_print(id, print_chat, "[%s] Only match administrators can pause.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    if (g_match_state == MATCH_LIVE)
    {
        set_mm_match_phase(MATCH_PAUSED)
        client_print(0, print_chat, "[%s] Match paused by %n.", PROJECT_NAME, id)
    }
    else if (g_match_state == MATCH_PAUSED && teams_full())
    {
        resume_live_match()
    }
    return PLUGIN_HANDLED
}

public admin_match_start(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    if (!classic_active() || !teams_full()) console_print(id, "[MM] Classic must be active and both teams must be full.")
    else start_live_match()
    return PLUGIN_HANDLED
}

public admin_match_stop(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    if (!classic_active())
    {
        console_print(id, "[MM] Classic mode is not active.")
        return PLUGIN_HANDLED
    }
    enter_waiting_state()
    client_print(0, print_chat, "[%s] Match stopped by an administrator.", PROJECT_NAME)
    return PLUGIN_HANDLED
}

public admin_match_restart(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    if (!classic_active() || !teams_full()) console_print(id, "[MM] Classic must be active and both teams must be full.")
    else start_live_match()
    return PLUGIN_HANDLED
}

public admin_match_format(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new value[16]
    read_argv(1, value, charsmax(value))
    new MmClassicFormat:format = parse_format(value)
    if (_:format < 0)
    {
        console_print(id, "[MM] Invalid format.")
        return PLUGIN_HANDLED
    }
    new MmRequestResult:result = mm_request_classic_format(format, id)
    console_print(id, "[MM] Format request result: %d", _:result)
    return PLUGIN_HANDLED
}

public admin_match_rules(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    if (!classic_active())
    {
        console_print(id, "[MM] Classic mode is not active.")
        return PLUGIN_HANDLED
    }
    new value[8]
    read_argv(1, value, charsmax(value))
    if (equali(value, "mr3")) g_match_rules = RULE_MR3
    else if (equali(value, "mr5")) g_match_rules = RULE_MR5
    else if (equali(value, "mr12")) g_match_rules = RULE_MR12
    else
    {
        console_print(id, "[MM] Invalid rules. Use mr3, mr5, or mr12.")
        return PLUGIN_HANDLED
    }
    enter_waiting_state()
    client_print(0, print_chat, "[%s] Match rules set to MR%d; setup reset.", PROJECT_NAME, _:g_match_rules)
    return PLUGIN_HANDLED
}

start_warmup()
{
    apply_warmup_rules()
    clear_ready_state()
    g_warmup_remaining = get_pcvar_num(g_warmup_cvar)
    set_mm_match_phase(MATCH_WARMUP)
    remove_task(TASK_WARMUP)
    set_task(1.0, "task_warmup_tick", TASK_WARMUP, _, _, "b")
    client_print(0, print_chat, "[%s] Teams are full. Warmup started; use /ready.", PROJECT_NAME)
}

public task_warmup_tick()
{
    if (g_match_state != MATCH_WARMUP)
    {
        remove_task(TASK_WARMUP)
        return
    }
    if (!teams_full())
    {
        enter_waiting_state()
        return
    }
    if (g_warmup_remaining > 0) g_warmup_remaining--
    if (g_warmup_remaining <= 0)
    {
        remove_task(TASK_WARMUP)
        set_mm_match_phase(MATCH_READY)
        client_print(0, print_chat, "[%s] Warmup complete. Waiting for all players to /ready.", PROJECT_NAME)
        try_start_match()
    }
}

try_start_match()
{
    if (teams_full() && ready_count() == required_players()) start_live_match()
}

start_live_match()
{
    remove_task(TASK_WARMUP)
    reset_match_scores()
    capture_rosters()
    apply_live_rules()
    g_match_committed = true
    set_mm_match_phase(MATCH_READY)
    server_cmd("sv_restart 3")
    remove_task(TASK_LIVE)
    set_task(3.2, "task_go_live", TASK_LIVE)
    client_print(0, print_chat, "[%s] Match restart: going LIVE in 3 seconds.", PROJECT_NAME)
}

public task_go_live()
{
    if (!classic_active() || !teams_full())
    {
        set_mm_match_phase(MATCH_PAUSED)
        return
    }
    set_mm_match_phase(MATCH_LIVE)
    client_print(0, print_chat, "[%s] LIVE! Team A starts T; Team B starts CT.", PROJECT_NAME)
}

public event_t_win() { record_round_win(CS_TEAM_T); }
public event_ct_win() { record_round_win(CS_TEAM_CT); }

record_round_win(CsTeams:winning_side)
{
    if (!classic_active() || g_match_state != MATCH_LIVE) return
    if ((!g_second_half && winning_side == CS_TEAM_T) || (g_second_half && winning_side == CS_TEAM_CT)) g_team_a_score++
    else g_team_b_score++
    g_rounds_played++
    if (g_overtime) g_overtime_rounds++

    if (match_has_winner())
    {
        finish_match(g_team_a_score > g_team_b_score ? 1 : 2)
        return
    }

    if (!g_overtime && g_match_rules == RULE_MR12 && g_rounds_played == 24 && g_team_a_score == 12 && g_team_b_score == 12)
    {
        if (get_pcvar_num(g_overtime_cvar))
        {
            g_overtime = true
            g_overtime_rounds = 0
            client_print(0, print_chat, "[%s] Regulation tied 12-12. MR3 overtime begins.", PROJECT_NAME)
            start_halftime()
        }
        else finish_match(0)
        return
    }

    if ((!g_overtime && g_rounds_played == _:g_match_rules) || (g_overtime && g_overtime_rounds > 0 && g_overtime_rounds % 3 == 0))
    {
        start_halftime()
    }
}

bool:match_has_winner()
{
    if (g_overtime)
    {
        new high_score = max(g_team_a_score, g_team_b_score)
        return high_score >= 16 && abs(g_team_a_score - g_team_b_score) >= 2
    }
    return g_team_a_score >= _:g_match_rules + 1 || g_team_b_score >= _:g_match_rules + 1
}

start_halftime()
{
    set_mm_match_phase(MATCH_HALFTIME)
    g_second_half = !g_second_half
    switch_player_sides()
    server_cmd("sv_restart 3")
    remove_task(TASK_LIVE)
    set_task(3.2, "task_resume_after_halftime", TASK_LIVE)
    client_print(0, print_chat, "[%s] Halftime: teams are switching sides.", PROJECT_NAME)
}

public task_resume_after_halftime()
{
    if (teams_full())
    {
        set_mm_match_phase(MATCH_LIVE)
        client_print(0, print_chat, "[%s] Match is live after halftime.", PROJECT_NAME)
    }
    else set_mm_match_phase(MATCH_PAUSED)
}

switch_player_sides()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id)) continue
        new CsTeams:team = cs_get_user_team(id)
        if (team == CS_TEAM_T) cs_set_user_team(id, CS_TEAM_CT)
        else if (team == CS_TEAM_CT) cs_set_user_team(id, CS_TEAM_T)
    }
}

finish_match(winner)
{
    g_match_committed = false
    set_mm_match_phase(MATCH_FINISHED)
    if (winner == 0) client_print(0, print_chat, "[%s] Match finished as a draw: %d-%d.", PROJECT_NAME, g_team_a_score, g_team_b_score)
    else client_print(0, print_chat, "[%s] Team %s wins %d-%d!", PROJECT_NAME, winner == 1 ? "A" : "B", g_team_a_score, g_team_b_score)
    set_hudmessage(0, 255, 0, -1.0, 0.30, 0, 1.0, 8.0)
    ShowSyncHudMsg(0, g_hud_sync, "MATCH FINISHED^nTeam A %d - %d Team B", g_team_a_score, g_team_b_score)
    remove_task(TASK_FINISH)
    set_task(10.0, "task_return_to_waiting", TASK_FINISH)
}

public task_return_to_waiting() { enter_waiting_state(); }

resume_live_match()
{
    capture_rosters()
    apply_live_rules()
    server_cmd("sv_restart 3")
    set_mm_match_phase(MATCH_HALFTIME)
    remove_task(TASK_LIVE)
    set_task(3.2, "task_resume_after_halftime", TASK_LIVE)
    client_print(0, print_chat, "[%s] Teams restored; match resumes in 3 seconds.", PROJECT_NAME)
}

enter_waiting_state()
{
    remove_task(TASK_WARMUP)
    remove_task(TASK_LIVE)
    remove_task(TASK_FINISH)
    clear_ready_state()
    reset_match_scores()
    g_match_committed = false
    apply_waiting_rules()
    set_mm_match_phase(MATCH_WAITING)
}

disable_classic_match()
{
    remove_task(TASK_WARMUP)
    remove_task(TASK_LIVE)
    remove_task(TASK_FINISH)
    clear_ready_state()
    reset_match_scores()
    g_match_committed = false
    set_mm_match_phase(MATCH_WAITING)
}

reset_match_scores()
{
    g_team_a_score = 0
    g_team_b_score = 0
    g_rounds_played = 0
    g_second_half = false
    g_overtime = false
    g_overtime_rounds = 0
}

clear_ready_state()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        g_ready[id] = false
        g_roster[id] = 0
    }
}

capture_rosters()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id)) continue
        new CsTeams:team = cs_get_user_team(id)
        g_roster[id] = team == CS_TEAM_T ? 1 : (team == CS_TEAM_CT ? 2 : 0)
    }
}

apply_waiting_rules()
{
    server_cmd("exec addons/amxmodx/configs/mm_classic.cfg")
    server_exec()
}

apply_warmup_rules()
{
    set_cvar_num("mp_startmoney", 16000)
    set_cvar_num("mp_freezetime", 0)
    set_cvar_float("mp_roundtime", 60.0)
    set_cvar_num("mp_friendlyfire", 0)
}

apply_live_rules()
{
    set_cvar_num("mp_startmoney", 800)
    set_cvar_num("mp_freezetime", 6)
    set_cvar_float("mp_roundtime", 1.75)
    set_cvar_float("mp_buytime", 0.333333)
    set_cvar_num("mp_friendlyfire", 0)
    set_cvar_num("mp_autoteambalance", 0)
    set_cvar_num("mp_limitteams", 0)
    set_cvar_num("mp_maxrounds", 0)
    set_cvar_num("mp_winlimit", 0)
    set_cvar_num("mp_timelimit", 0)
}

public task_update_hud()
{
    if (!classic_active()) return
    new format_name[16]
    mm_get_classic_format_name(mm_get_classic_format(), format_name, charsmax(format_name))
    set_hudmessage(0, 180, 255, 0.02, 0.18, 0, 0.0, 1.1, 0.0, 0.0)
    if (g_match_state == MATCH_WARMUP)
        ShowSyncHudMsg(0, g_hud_sync, "Classic %s | %s %ds^nTeam A %d - %d Team B | Ready %d/%d", format_name, MATCH_STATE_NAMES[_:g_match_state], g_warmup_remaining, g_team_a_score, g_team_b_score, ready_count(), required_players())
    else
        ShowSyncHudMsg(0, g_hud_sync, "Classic %s | %s^nTeam A %d - %d Team B | Ready %d/%d", format_name, MATCH_STATE_NAMES[_:g_match_state], g_team_a_score, g_team_b_score, ready_count(), required_players())
}

set_mm_match_phase(MatchState:phase)
{
    g_match_state = phase
    log_amx("Match state: %s", MATCH_STATE_NAMES[_:phase])
}

bool:classic_active() { return mm_get_active_mode() == MM_MODE_CLASSIC; }
bool:classic_admin_authorized(requester)
{
    return requester == 0 || (requester >= 1 && requester <= MaxClients && is_user_connected(requester) && (get_user_flags(requester) & ADMIN_CFG))
}
bool:is_match_player(id)
{
    if (!is_user_connected(id)) return false
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}
bool:teams_full() { return team_count(CS_TEAM_T) == t_capacity() && team_count(CS_TEAM_CT) == ct_capacity(); }
t_capacity()
{
    new MmClassicFormat:format = mm_get_classic_format()
    return g_second_half ? FORMAT_CT_SLOTS[format] : FORMAT_T_SLOTS[format]
}
ct_capacity()
{
    new MmClassicFormat:format = mm_get_classic_format()
    return g_second_half ? FORMAT_T_SLOTS[format] : FORMAT_CT_SLOTS[format]
}
required_players() { return t_capacity() + ct_capacity(); }

team_count(CsTeams:team, excluded = 0)
{
    new count
    for (new id = 1; id <= MaxClients; id++)
    {
        if (id != excluded && is_user_connected(id) && !is_user_hltv(id) && cs_get_user_team(id) == team) count++
    }
    return count
}

ready_count()
{
    new count
    for (new id = 1; id <= MaxClients; id++) if (is_match_player(id) && g_ready[id]) count++
    return count
}

classic_inactive_message(id)
{
    client_print(id, print_chat, "[%s] Classic match commands are disabled while another mode is active.", PROJECT_NAME)
    return PLUGIN_HANDLED
}

MmClassicFormat:parse_format(const value[])
{
    new name[16]
    for (new MmClassicFormat:format = MM_FORMAT_1V1; format < MM_FORMAT_COUNT; format++)
    {
        mm_get_classic_format_name(format, name, charsmax(name))
        if (equali(value, name)) return format
    }
    return MmClassicFormat:-1
}
