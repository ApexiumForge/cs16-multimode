#include <amxmodx>
#include <amxmisc>
#include <mm_mode_api>
#include <mm_classic_api>
#include <mm_voting_api>

#define PLUGIN_NAME "Multi-Mode Network Voting"
#define PLUGIN_VERSION "0.5.0"
#define PLUGIN_AUTHOR "Multi-Mode Network"
#define PROJECT_NAME "Multi-Mode Network"

#define SUPPORTED_MODE_COUNT 4
#define MAX_MAPS_PER_MODE 64
#define MAX_MAP_NAME 32
#define MAX_VOTE_CHOICES 8
#define TASK_END_VOTE 51001
#define TASK_APPLY_DECISION 51002
#define TASK_AUTO_VOTE 51003
#define TASK_RESTORE_MODE 51004
#define COMMAND_SPAM_SECONDS 5
#define APPLY_DELAY_SECONDS 10.0
#define APPLY_DELAY_DISPLAY 10
#define DEFER_RETRY_SECONDS 5.0
#define PENDING_FILE_NAME "mm_vote_pending.dat"

enum VotePhase
{
    VOTE_NONE = 0,
    VOTE_MODE,
    VOTE_MAP
}

new const MODE_NAMES[SUPPORTED_MODE_COUNT][] =
{
    "Classic",
    "Deathmatch",
    "Arms Race",
    "AWP Only"
}

new const MODE_KEYS[SUPPORTED_MODE_COUNT][] =
{
    "classic",
    "deathmatch",
    "armsrace",
    "awponly"
}

new const MAP_POOL_FILES[SUPPORTED_MODE_COUNT][] =
{
    "addons/amxmodx/configs/mm_voting/maps_classic.ini",
    "addons/amxmodx/configs/mm_voting/maps_deathmatch.ini",
    "addons/amxmodx/configs/mm_voting/maps_armsrace.ini",
    "addons/amxmodx/configs/mm_voting/maps_awponly.ini"
}

new g_map_pool[SUPPORTED_MODE_COUNT][MAX_MAPS_PER_MODE][MAX_MAP_NAME]
new g_map_count[SUPPORTED_MODE_COUNT]

new VotePhase:g_vote_phase = VOTE_NONE
new g_vote_candidates[MAX_VOTE_CHOICES]
new g_vote_candidate_count
new g_vote_counts[MAX_VOTE_CHOICES]
new g_player_vote[33]
new bool:g_rtv_requested[33]
new g_rtv_count
new g_last_command[33]
new g_last_vote_finished

new MmMode:g_planned_mode = MM_MODE_CLASSIC
new g_planned_map[MAX_MAP_NAME]
new bool:g_has_decision
new bool:g_change_queued
new bool:g_defer_announced
new bool:g_admin_override_classic

new MmMode:g_restore_mode = MM_MODE_CLASSIC
new g_restore_attempts

new g_enabled_cvar
new g_duration_cvar
new g_rtv_percent_cvar
new g_min_players_cvar
new g_cooldown_cvar
new g_automatic_cvar
new g_auto_delay_cvar
new g_map_choices_cvar
new g_mode_enabled_cvar[SUPPORTED_MODE_COUNT]

public plugin_natives()
{
    register_library("mm_voting")
    register_native("mm_voting_is_active", "native_voting_is_active")
    register_native("mm_voting_has_decision", "native_voting_has_decision")
    register_native("mm_voting_admin_cancel", "native_voting_admin_cancel")
    register_native("mm_voting_admin_change", "native_voting_admin_change")
}

public native_voting_is_active() { return g_vote_phase != VOTE_NONE; }
public native_voting_has_decision() { return g_has_decision; }

public native_voting_admin_cancel(plugin_id, parameter_count)
{
    new requester = get_param(1)
    if (!voting_admin_authorized(requester)) return _:MM_VOTING_ADMIN_UNAUTHORIZED

    if (g_vote_phase != VOTE_NONE) cancel_active_vote("Active vote cancelled by an administrator.")
    clear_decision()
    clear_rtv_requests()
    return _:MM_VOTING_ADMIN_OK
}

public native_voting_admin_change(plugin_id, parameter_count)
{
    new MmMode:mode = MmMode:get_param(1)
    new map_name[MAX_MAP_NAME]
    get_string(2, map_name, charsmax(map_name))
    new requester = get_param(3)

    if (!voting_admin_authorized(requester)) return _:MM_VOTING_ADMIN_UNAUTHORIZED
    if (!is_supported_mode(mode)) return _:MM_VOTING_ADMIN_INVALID_MODE
    if (!is_map_name_safe(map_name) || !map_matches_mode(mode, map_name) || !is_map_valid(map_name)) return _:MM_VOTING_ADMIN_INVALID_MAP

    if (g_vote_phase != VOTE_NONE) cancel_active_vote("Active vote cancelled by an administrator.")
    clear_decision()
    clear_rtv_requests()

    g_planned_mode = mode
    copy(g_planned_map, charsmax(g_planned_map), map_name)
    g_has_decision = true
    g_change_queued = true
    g_admin_override_classic = true
    log_amx("Administrator #%d selected %s (%s); applying through the voting controller.", requester, map_name, MODE_NAMES[_:mode])
    task_apply_decision()
    return _:MM_VOTING_ADMIN_OK
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

    register_clcmd("say /rtv", "command_rtv")
    register_clcmd("say_team /rtv", "command_rtv")
    register_clcmd("say /votemode", "command_vote_mode")
    register_clcmd("say_team /votemode", "command_vote_mode")
    register_clcmd("say /votemap", "command_vote_map")
    register_clcmd("say_team /votemap", "command_vote_map")
    register_clcmd("say /nextmap", "command_next_map")
    register_clcmd("say_team /nextmap", "command_next_map")

    g_enabled_cvar = register_cvar("mm_vote_enabled", "1")
    g_duration_cvar = register_cvar("mm_vote_duration", "15")
    g_rtv_percent_cvar = register_cvar("mm_vote_rtv_percent", "60")
    g_min_players_cvar = register_cvar("mm_vote_min_players", "2")
    g_cooldown_cvar = register_cvar("mm_vote_cooldown", "60")
    g_automatic_cvar = register_cvar("mm_vote_automatic", "1")
    g_auto_delay_cvar = register_cvar("mm_vote_auto_delay", "900")
    g_map_choices_cvar = register_cvar("mm_vote_map_choices", "5")
    g_mode_enabled_cvar[MM_MODE_CLASSIC] = register_cvar("mm_vote_mode_classic", "1")
    g_mode_enabled_cvar[MM_MODE_DEATHMATCH] = register_cvar("mm_vote_mode_deathmatch", "1")
    g_mode_enabled_cvar[MM_MODE_ARMS_RACE] = register_cvar("mm_vote_mode_armsrace", "1")
    g_mode_enabled_cvar[MM_MODE_AWP_ONLY] = register_cvar("mm_vote_mode_awponly", "1")

    reset_player_ballots()
    log_amx("%s voting system v%s initialized.", PROJECT_NAME, PLUGIN_VERSION)
}

public plugin_cfg()
{
    server_cmd("exec addons/amxmodx/configs/mm_voting.cfg")
    server_exec()
    load_all_map_pools()
    restore_pending_mode()
    schedule_automatic_vote()
}

public client_putinserver(id)
{
    g_player_vote[id] = -1
    g_rtv_requested[id] = false
    g_last_command[id] = 0
}

public client_disconnected(id)
{
    remove_player_ballot(id)

    if (g_rtv_requested[id])
    {
        g_rtv_requested[id] = false
        if (g_rtv_count > 0)
        {
            g_rtv_count--
        }
    }

    if (eligible_player_count() == 0 && g_vote_phase != VOTE_NONE)
    {
        cancel_active_vote("Vote cancelled because the server is empty.")
        clear_rtv_requests()
    }
}

public command_rtv(id)
{
    if (!can_use_vote_command(id))
    {
        return PLUGIN_HANDLED
    }

    if (g_vote_phase != VOTE_NONE)
    {
        show_active_vote(id)
        return PLUGIN_HANDLED
    }
    if (g_has_decision)
    {
        show_next_decision(id)
        return PLUGIN_HANDLED
    }
    if (!server_meets_minimum(id))
    {
        return PLUGIN_HANDLED
    }

    new remaining = vote_cooldown_remaining()
    if (remaining > 0)
    {
        client_print(id, print_chat, "[%s] Vote cooldown: %d second(s) remaining.", PROJECT_NAME, remaining)
        return PLUGIN_HANDLED
    }
    if (g_rtv_requested[id])
    {
        client_print(id, print_chat, "[%s] Your RTV request is already counted.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }

    g_rtv_requested[id] = true
    g_rtv_count++

    new required = required_rtv_count()
    client_print(0, print_chat, "[%s] %n requested RTV (%d/%d).", PROJECT_NAME, id, g_rtv_count, required)
    if (g_rtv_count >= required)
    {
        start_mode_vote()
    }
    return PLUGIN_HANDLED
}

public command_vote_mode(id)
{
    if (!can_use_vote_command(id))
    {
        return PLUGIN_HANDLED
    }
    if (g_vote_phase == VOTE_MODE)
    {
        show_mode_vote(id)
        return PLUGIN_HANDLED
    }
    if (g_vote_phase == VOTE_MAP)
    {
        client_print(id, print_chat, "[%s] A map vote is already active.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    if (!can_start_new_vote(id))
    {
        return PLUGIN_HANDLED
    }

    start_mode_vote()
    return PLUGIN_HANDLED
}

public command_vote_map(id)
{
    if (!can_use_vote_command(id))
    {
        return PLUGIN_HANDLED
    }
    if (g_vote_phase == VOTE_MAP)
    {
        show_map_vote(id)
        return PLUGIN_HANDLED
    }
    if (g_vote_phase == VOTE_MODE)
    {
        client_print(id, print_chat, "[%s] Finish the active mode vote first.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    if (!can_start_new_vote(id))
    {
        return PLUGIN_HANDLED
    }

    g_planned_mode = mm_get_active_mode()
    if (!is_supported_mode(g_planned_mode))
    {
        g_planned_mode = MM_MODE_CLASSIC
    }
    start_map_vote()
    return PLUGIN_HANDLED
}

public command_next_map(id)
{
    show_next_decision(id)
    return PLUGIN_HANDLED
}

bool:can_use_vote_command(id)
{
    if (!get_pcvar_num(g_enabled_cvar))
    {
        client_print(id, print_chat, "[%s] Player voting is disabled.", PROJECT_NAME)
        return false
    }
    if (!is_eligible_voter(id))
    {
        client_print(id, print_chat, "[%s] Only connected human players may vote.", PROJECT_NAME)
        return false
    }

    new now = get_systime()
    if (now - g_last_command[id] < COMMAND_SPAM_SECONDS)
    {
        client_print(id, print_chat, "[%s] Please wait before using another vote command.", PROJECT_NAME)
        return false
    }
    g_last_command[id] = now
    return true
}

bool:can_start_new_vote(id)
{
    if (g_has_decision)
    {
        show_next_decision(id)
        return false
    }
    if (!server_meets_minimum(id))
    {
        return false
    }

    new remaining = vote_cooldown_remaining()
    if (remaining > 0)
    {
        client_print(id, print_chat, "[%s] Vote cooldown: %d second(s) remaining.", PROJECT_NAME, remaining)
        return false
    }
    return true
}

bool:server_meets_minimum(id)
{
    new players = eligible_player_count()
    new minimum = clamp(get_pcvar_num(g_min_players_cvar), 1, 12)
    if (players < minimum)
    {
        client_print(id, print_chat, "[%s] At least %d human player(s) are required; currently %d.", PROJECT_NAME, minimum, players)
        return false
    }
    return true
}

start_mode_vote()
{
    if (g_vote_phase != VOTE_NONE || g_has_decision)
    {
        return
    }

    reset_vote_state(VOTE_MODE)
    for (new mode = 0; mode < SUPPORTED_MODE_COUNT && g_vote_candidate_count < MAX_VOTE_CHOICES; mode++)
    {
        if (get_pcvar_num(g_mode_enabled_cvar[mode]))
        {
            g_vote_candidates[g_vote_candidate_count++] = mode
        }
    }

    if (g_vote_candidate_count < 1)
    {
        cancel_active_vote("Mode vote cancelled: no eligible modes are enabled.")
        return
    }

    client_print(0, print_chat, "[%s] Mode vote started. Use /votemode to open the menu.", PROJECT_NAME)
    show_vote_to_all()
    schedule_vote_end()
}

start_map_vote()
{
    if (g_vote_phase != VOTE_NONE || !is_supported_mode(g_planned_mode))
    {
        return
    }

    reset_vote_state(VOTE_MAP)
    new available[MAX_MAPS_PER_MODE]
    new available_count
    new current_map[MAX_MAP_NAME]
    get_mapname(current_map, charsmax(current_map))

    for (new index = 0; index < g_map_count[_:g_planned_mode]; index++)
    {
        if (!equali(g_map_pool[_:g_planned_mode][index], current_map))
        {
            available[available_count++] = index
        }
    }

    // A same-map mode transition is allowed only when no alternative is installed.
    if (available_count == 0 && g_map_count[_:g_planned_mode] == 1)
    {
        available[available_count++] = 0
    }

    shuffle_indices(available, available_count)
    new requested_choices = clamp(get_pcvar_num(g_map_choices_cvar), 2, MAX_VOTE_CHOICES)
    g_vote_candidate_count = min(available_count, requested_choices)
    for (new candidate = 0; candidate < g_vote_candidate_count; candidate++)
    {
        g_vote_candidates[candidate] = available[candidate]
    }

    if (g_vote_candidate_count < 1)
    {
        new message[128]
        formatex(message, charsmax(message), "Map vote cancelled: no installed maps exist in the %s pool.", MODE_NAMES[_:g_planned_mode])
        cancel_active_vote(message)
        return
    }

    client_print(0, print_chat, "[%s] %s map vote started. Use /votemap to open the menu.", PROJECT_NAME, MODE_NAMES[_:g_planned_mode])
    show_vote_to_all()
    schedule_vote_end()
}

reset_vote_state(VotePhase:phase)
{
    g_vote_phase = phase
    g_vote_candidate_count = 0
    arrayset(g_vote_candidates, 0, sizeof g_vote_candidates)
    arrayset(g_vote_counts, 0, sizeof g_vote_counts)
    reset_player_ballots()
    remove_task(TASK_END_VOTE)
}

schedule_vote_end()
{
    new duration = clamp(get_pcvar_num(g_duration_cvar), 5, 60)
    set_task(float(duration), "task_finish_vote", TASK_END_VOTE)
}

show_vote_to_all()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        if (is_eligible_voter(id))
        {
            show_active_vote(id)
        }
    }
}

show_active_vote(id)
{
    if (g_vote_phase == VOTE_MODE)
    {
        show_mode_vote(id)
    }
    else if (g_vote_phase == VOTE_MAP)
    {
        show_map_vote(id)
    }
}

show_mode_vote(id)
{
    new menu = menu_create("Choose the next game mode", "handle_mode_vote")
    new info[8]

    for (new candidate = 0; candidate < g_vote_candidate_count; candidate++)
    {
        num_to_str(candidate, info, charsmax(info))
        menu_additem(menu, MODE_NAMES[g_vote_candidates[candidate]], info)
    }
    menu_setprop(menu, MPROP_EXITNAME, "Close")
    menu_display(id, menu)
}

show_map_vote(id)
{
    new title[96]
    formatex(title, charsmax(title), "Choose the next %s map", MODE_NAMES[_:g_planned_mode])
    new menu = menu_create(title, "handle_map_vote")
    new info[8]

    for (new candidate = 0; candidate < g_vote_candidate_count; candidate++)
    {
        num_to_str(candidate, info, charsmax(info))
        new pool_index = g_vote_candidates[candidate]
        menu_additem(menu, g_map_pool[_:g_planned_mode][pool_index], info)
    }
    menu_setprop(menu, MPROP_EXITNAME, "Close")
    menu_display(id, menu)
}

public handle_mode_vote(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new info[8], item_name[64], access, callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), item_name, charsmax(item_name), callback)
    menu_destroy(menu)
    record_vote(id, str_to_num(info), VOTE_MODE)
    return PLUGIN_HANDLED
}

public handle_map_vote(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new info[8], item_name[64], access, callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), item_name, charsmax(item_name), callback)
    menu_destroy(menu)
    record_vote(id, str_to_num(info), VOTE_MAP)
    return PLUGIN_HANDLED
}

record_vote(id, candidate, VotePhase:expected_phase)
{
    if (g_vote_phase != expected_phase || !is_eligible_voter(id) || candidate < 0 || candidate >= g_vote_candidate_count)
    {
        client_print(id, print_chat, "[%s] That vote is no longer active.", PROJECT_NAME)
        return
    }

    remove_player_ballot(id)
    g_player_vote[id] = candidate
    g_vote_counts[candidate]++

    if (expected_phase == VOTE_MODE)
    {
        client_print(id, print_chat, "[%s] Your vote: %s.", PROJECT_NAME, MODE_NAMES[g_vote_candidates[candidate]])
    }
    else
    {
        new pool_index = g_vote_candidates[candidate]
        client_print(id, print_chat, "[%s] Your vote: %s.", PROJECT_NAME, g_map_pool[_:g_planned_mode][pool_index])
    }
}

public task_finish_vote()
{
    if (g_vote_phase == VOTE_NONE)
    {
        return
    }
    if (eligible_player_count() < clamp(get_pcvar_num(g_min_players_cvar), 1, 12))
    {
        cancel_active_vote("Vote cancelled: not enough human players remain.")
        return
    }

    new bool:tie
    new winner = choose_vote_winner(tie)
    if (winner < 0)
    {
        cancel_active_vote("Vote cancelled because no ballots were cast.")
        return
    }

    new VotePhase:finished_phase = g_vote_phase
    g_vote_phase = VOTE_NONE
    reset_player_ballots()

    if (tie)
    {
        client_print(0, print_chat, "[%s] The vote tied; one of the tied choices was selected randomly.", PROJECT_NAME)
    }

    if (finished_phase == VOTE_MODE)
    {
        g_planned_mode = MmMode:g_vote_candidates[winner]
        client_print(0, print_chat, "[%s] Next mode selected: %s.", PROJECT_NAME, MODE_NAMES[_:g_planned_mode])
        start_map_vote()
        return
    }

    new pool_index = g_vote_candidates[winner]
    copy(g_planned_map, charsmax(g_planned_map), g_map_pool[_:g_planned_mode][pool_index])
    g_has_decision = true
    g_change_queued = true
    g_defer_announced = false
    g_last_vote_finished = get_systime()
    clear_rtv_requests()
    client_print(0, print_chat, "[%s] Next: %s on %s. Change begins in %d seconds when safe.", PROJECT_NAME, MODE_NAMES[_:g_planned_mode], g_planned_map, APPLY_DELAY_DISPLAY)
    remove_task(TASK_APPLY_DECISION)
    set_task(APPLY_DELAY_SECONDS, "task_apply_decision", TASK_APPLY_DECISION)
}

choose_vote_winner(&bool:tie)
{
    new highest
    new tied[MAX_VOTE_CHOICES]
    new tied_count

    for (new candidate = 0; candidate < g_vote_candidate_count; candidate++)
    {
        if (g_vote_counts[candidate] > highest)
        {
            highest = g_vote_counts[candidate]
            tied_count = 0
            tied[tied_count++] = candidate
        }
        else if (g_vote_counts[candidate] == highest && highest > 0)
        {
            tied[tied_count++] = candidate
        }
    }

    if (highest == 0 || tied_count == 0)
    {
        return -1
    }
    tie = tied_count > 1
    return tied[random_num(0, tied_count - 1)]
}

public task_apply_decision()
{
    if (!g_has_decision || !g_change_queued)
    {
        return
    }
    if (mm_get_transition_state() != MM_TRANSITION_IDLE)
    {
        set_task(DEFER_RETRY_SECONDS, "task_apply_decision", TASK_APPLY_DECISION)
        return
    }
    if (!g_admin_override_classic && mm_get_active_mode() == MM_MODE_CLASSIC && mm_classic_change_blocked())
    {
        if (!g_defer_announced)
        {
            client_print(0, print_chat, "[%s] Map/mode change queued until the live Classic match is finished.", PROJECT_NAME)
            g_defer_announced = true
        }
        set_task(DEFER_RETRY_SECONDS, "task_apply_decision", TASK_APPLY_DECISION)
        return
    }

    new current_map[MAX_MAP_NAME]
    get_mapname(current_map, charsmax(current_map))
    if (equali(current_map, g_planned_map))
    {
        if (mm_get_active_mode() == g_planned_mode)
        {
            client_print(0, print_chat, "[%s] Selected mode and map are already active; no change was needed.", PROJECT_NAME)
            clear_decision()
            return
        }

        new MmRequestResult:result = mm_request_mode(g_planned_mode, 0)
        if (result == MM_REQUEST_ACCEPTED || result == MM_REQUEST_DUPLICATE)
        {
            clear_decision()
        }
        else
        {
            set_task(DEFER_RETRY_SECONDS, "task_apply_decision", TASK_APPLY_DECISION)
        }
        return
    }

    if (!is_map_valid(g_planned_map))
    {
        log_amx("Refusing map change because the selected BSP is no longer installed: %s", g_planned_map)
        client_print(0, print_chat, "[%s] Planned map is no longer installed; change cancelled.", PROJECT_NAME)
        clear_decision()
        return
    }

    if (!write_pending_decision(g_planned_mode, g_planned_map))
    {
        log_amx("Could not persist pending mode %s for map %s; refusing unsafe changelevel.", MODE_KEYS[_:g_planned_mode], g_planned_map)
        client_print(0, print_chat, "[%s] Could not save the next mode safely; change cancelled.", PROJECT_NAME)
        clear_decision()
        return
    }

    g_change_queued = false
    client_print(0, print_chat, "[%s] Changing to %s (%s).", PROJECT_NAME, g_planned_map, MODE_NAMES[_:g_planned_mode])
    server_cmd("changelevel %s", g_planned_map)
}

write_pending_decision(MmMode:mode, const map_name[])
{
    new path[192]
    get_pending_file_path(path, charsmax(path))
    delete_file(path)

    new file = fopen(path, "wt")
    if (!file)
    {
        return 0
    }
    fprintf(file, "%s %s^n", MODE_KEYS[_:mode], map_name)
    fclose(file)
    return 1
}

restore_pending_mode()
{
    new path[192]
    get_pending_file_path(path, charsmax(path))
    if (!file_exists(path))
    {
        return
    }

    new file = fopen(path, "rt")
    if (!file)
    {
        log_amx("Could not read pending vote state: %s", path)
        return
    }

    new line[96], mode_key[32], expected_map[MAX_MAP_NAME]
    fgets(file, line, charsmax(line))
    fclose(file)
    delete_file(path) // Consume first to prevent a map-change loop after any later failure.
    parse(line, mode_key, charsmax(mode_key), expected_map, charsmax(expected_map))

    new current_map[MAX_MAP_NAME]
    get_mapname(current_map, charsmax(current_map))
    if (!equali(current_map, expected_map))
    {
        log_amx("Ignored stale pending vote state for map %s; current map is %s.", expected_map, current_map)
        return
    }

    g_restore_mode = find_supported_mode(mode_key)
    if (!is_supported_mode(g_restore_mode) || g_restore_mode == MM_MODE_CLASSIC)
    {
        return
    }

    g_restore_attempts = 0
    task_restore_mode()
}

public task_restore_mode()
{
    if (mm_get_transition_state() != MM_TRANSITION_IDLE)
    {
        if (g_restore_attempts++ < 10)
        {
            set_task(0.5, "task_restore_mode", TASK_RESTORE_MODE)
        }
        else
        {
            log_amx("Timed out restoring voted mode %s after map change.", MODE_NAMES[_:g_restore_mode])
        }
        return
    }

    new MmRequestResult:result = mm_request_mode(g_restore_mode, 0)
    if (result != MM_REQUEST_ACCEPTED && result != MM_REQUEST_DUPLICATE)
    {
        log_amx("Failed to restore voted mode %s after map change (result %d).", MODE_NAMES[_:g_restore_mode], _:result)
    }
}

get_pending_file_path(output[], output_length)
{
    new data_dir[160]
    get_localinfo("amxx_datadir", data_dir, charsmax(data_dir))
    formatex(output, output_length, "%s/%s", data_dir, PENDING_FILE_NAME)
}

load_all_map_pools()
{
    for (new mode = 0; mode < SUPPORTED_MODE_COUNT; mode++)
    {
        load_map_pool(mode)
        log_amx("Loaded %d installed map(s) for %s voting.", g_map_count[mode], MODE_NAMES[mode])
    }
}

load_map_pool(mode)
{
    g_map_count[mode] = 0
    new file = fopen(MAP_POOL_FILES[mode], "rt")
    if (!file)
    {
        log_amx("Map pool is missing: %s", MAP_POOL_FILES[mode])
        return
    }

    new line[128]
    while (!feof(file) && g_map_count[mode] < MAX_MAPS_PER_MODE)
    {
        fgets(file, line, charsmax(line))
        trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#')
        {
            continue
        }

        new comment = contain(line, "//")
        if (comment >= 0)
        {
            line[comment] = 0
            trim(line)
        }
        if (!is_map_name_safe(line) || !map_matches_mode(mode, line) || !is_map_valid(line) || map_already_loaded(mode, line))
        {
            log_amx("Skipping invalid, missing, duplicate, or incompatible map '%s' in %s.", line, MAP_POOL_FILES[mode])
            continue
        }

        copy(g_map_pool[mode][g_map_count[mode]], MAX_MAP_NAME - 1, line)
        g_map_count[mode]++
    }
    fclose(file)
}

bool:map_matches_mode(mode, const map_name[])
{
    if (mode == _:MM_MODE_CLASSIC)
    {
        return equali(map_name, "de_", 3) || equali(map_name, "cs_", 3)
    }
    if (mode == _:MM_MODE_AWP_ONLY)
    {
        return equali(map_name, "awp_", 4)
    }
    return true
}

bool:is_map_name_safe(const map_name[])
{
    new length = strlen(map_name)
    if (length < 1 || length >= MAX_MAP_NAME)
    {
        return false
    }

    for (new index = 0; index < length; index++)
    {
        new character = map_name[index]
        if (!isalnum(character) && character != '_' && character != '-')
        {
            return false
        }
    }
    return true
}

bool:map_already_loaded(mode, const map_name[])
{
    for (new index = 0; index < g_map_count[mode]; index++)
    {
        if (equali(g_map_pool[mode][index], map_name))
        {
            return true
        }
    }
    return false
}

shuffle_indices(values[], count)
{
    for (new index = count - 1; index > 0; index--)
    {
        new other = random_num(0, index)
        new temporary = values[index]
        values[index] = values[other]
        values[other] = temporary
    }
}

public task_automatic_vote()
{
    if (!get_pcvar_num(g_enabled_cvar) || !get_pcvar_num(g_automatic_cvar) || g_vote_phase != VOTE_NONE || g_has_decision)
    {
        return
    }
    if (eligible_player_count() < clamp(get_pcvar_num(g_min_players_cvar), 1, 12))
    {
        set_task(60.0, "task_automatic_vote", TASK_AUTO_VOTE)
        return
    }
    start_mode_vote()
}

schedule_automatic_vote()
{
    remove_task(TASK_AUTO_VOTE)
    if (get_pcvar_num(g_enabled_cvar) && get_pcvar_num(g_automatic_cvar))
    {
        new delay = clamp(get_pcvar_num(g_auto_delay_cvar), 60, 7200)
        set_task(float(delay), "task_automatic_vote", TASK_AUTO_VOTE)
    }
}

show_next_decision(id)
{
    if (!g_has_decision)
    {
        client_print(id, print_chat, "[%s] No next mode/map has been decided yet.", PROJECT_NAME)
        return
    }

    new suffix[48]
    if (g_defer_announced)
    {
        copy(suffix, charsmax(suffix), " (queued after Classic)")
    }
    client_print(id, print_chat, "[%s] Next: %s on %s%s.", PROJECT_NAME, MODE_NAMES[_:g_planned_mode], g_planned_map, suffix)
}

remove_player_ballot(id)
{
    new previous = g_player_vote[id]
    if (previous >= 0 && previous < g_vote_candidate_count && g_vote_counts[previous] > 0)
    {
        g_vote_counts[previous]--
    }
    g_player_vote[id] = -1
}

reset_player_ballots()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        g_player_vote[id] = -1
    }
}

clear_rtv_requests()
{
    g_rtv_count = 0
    for (new id = 1; id <= MaxClients; id++)
    {
        g_rtv_requested[id] = false
    }
}

cancel_active_vote(const reason[])
{
    remove_task(TASK_END_VOTE)
    g_vote_phase = VOTE_NONE
    reset_player_ballots()
    clear_rtv_requests()
    g_last_vote_finished = get_systime()
    if (reason[0])
    {
        client_print(0, print_chat, "[%s] %s", PROJECT_NAME, reason)
        log_amx("%s", reason)
    }
}

vote_cooldown_remaining()
{
    if (g_last_vote_finished <= 0)
    {
        return 0
    }
    return max(0, get_pcvar_num(g_cooldown_cvar) - (get_systime() - g_last_vote_finished))
}

clear_decision()
{
    remove_task(TASK_APPLY_DECISION)
    g_has_decision = false
    g_change_queued = false
    g_defer_announced = false
    g_admin_override_classic = false
    g_planned_map[0] = 0
}

eligible_player_count()
{
    new count
    for (new id = 1; id <= MaxClients; id++)
    {
        if (is_eligible_voter(id))
        {
            count++
        }
    }
    return count
}

required_rtv_count()
{
    new players = eligible_player_count()
    new percent = clamp(get_pcvar_num(g_rtv_percent_cvar), 1, 100)
    return max(1, floatround(float(players * percent) / 100.0, floatround_ceil))
}

bool:is_eligible_voter(id)
{
    return id >= 1 && id <= MaxClients && is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id)
}

bool:is_supported_mode(MmMode:mode)
{
    return _:mode >= _:MM_MODE_CLASSIC && _:mode <= _:MM_MODE_AWP_ONLY
}

bool:voting_admin_authorized(requester)
{
    return requester == 0 || (requester >= 1 && requester <= MaxClients && is_user_connected(requester) && (get_user_flags(requester) & ADMIN_CFG))
}

MmMode:find_supported_mode(const key[])
{
    for (new mode = 0; mode < SUPPORTED_MODE_COUNT; mode++)
    {
        if (equali(key, MODE_KEYS[mode]))
        {
            return MmMode:mode
        }
    }
    return MmMode:-1
}
