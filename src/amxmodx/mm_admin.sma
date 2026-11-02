#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <mm_mode_api>
#include <mm_classic_api>
#include <mm_voting_api>

#define PLUGIN_NAME "Apexium Forge Admin Panel"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR "ApexiumForge"
#define MAX_MAP_NAME 32
#define SUPPORTED_MODE_COUNT 4

enum PendingAction
{
    ACTION_NONE = 0,
    ACTION_MODE,
    ACTION_MAP,
    ACTION_CLASSIC_WARMUP,
    ACTION_CLASSIC_RESTART,
    ACTION_CLASSIC_STOP,
    ACTION_KICK,
    ACTION_FRIENDLY_FIRE,
    ACTION_AUTOBALANCE,
    ACTION_TEAM_LIMITS,
    ACTION_GRAVITY,
    ACTION_RESTART_ROUND
}

new const MODE_NAMES[SUPPORTED_MODE_COUNT][] = { "Classic", "Deathmatch", "Arms Race", "AWP Only" }
new const CONTROL_LABELS[][] =
{
    "toggle Friendly Fire",
    "toggle Autobalance",
    "cycle Team Limits",
    "cycle Gravity",
    "restart the round"
}
new const MAP_POOL_FILES[SUPPORTED_MODE_COUNT][] =
{
    "addons/amxmodx/configs/mm_voting/maps_classic.ini",
    "addons/amxmodx/configs/mm_voting/maps_deathmatch.ini",
    "addons/amxmodx/configs/mm_voting/maps_armsrace.ini",
    "addons/amxmodx/configs/mm_voting/maps_awponly.ini"
}

new PendingAction:g_pending_action[33]
new MmMode:g_pending_mode[33]
new g_pending_map[33][MAX_MAP_NAME]
new g_target_userid[33]
new g_target_authid[33][35]

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /admin", "command_admin_menu")
    register_clcmd("say_team /admin", "command_admin_menu")
    register_clcmd("say /adminmenu", "command_admin_menu")
    register_clcmd("say_team /adminmenu", "command_admin_menu")
    log_amx("Apexium Forge admin panel v%s initialized.", PLUGIN_VERSION)
}

public client_disconnected(id)
{
    clear_pending(id)
}

public command_admin_menu(id)
{
    if (!authorized_admin(id))
    {
        client_print(id, print_chat, "[Apexium] You are not authorized to use the admin panel.")
        return PLUGIN_HANDLED
    }
    show_main_menu(id)
    return PLUGIN_HANDLED
}

show_main_menu(id)
{
    if (!authorized_admin(id)) return
    new menu = menu_create("APEXIUM FORGE - ADMIN PANEL", "handle_main_menu")
    menu_additem(menu, "Game Mode Management", "0", ADMIN_CFG)
    menu_additem(menu, "Map Management", "1", ADMIN_CFG)
    menu_additem(menu, "Classic Match Management", "2", ADMIN_CFG)
    menu_additem(menu, "Bot Management", "3", ADMIN_CFG)
    menu_additem(menu, "Player Management", "4", ADMIN_KICK)
    menu_additem(menu, "Server Controls", "5", ADMIN_CFG)
    menu_additem(menu, "Server Information", "6")
    menu_setprop(menu, MPROP_EXITNAME, "Exit")
    menu_display(id, menu)
}

public handle_main_menu(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT || !authorized_admin(id)) return PLUGIN_HANDLED
    switch (item)
    {
        case 0: show_mode_menu(id)
        case 1: show_map_menu(id)
        case 2: show_classic_menu(id)
        case 3: show_bot_menu(id)
        case 4: show_player_list(id)
        case 5: show_server_controls(id)
        case 6: show_server_information(id)
    }
    return PLUGIN_HANDLED
}

show_mode_menu(id)
{
    if (!require_flag(id, ADMIN_CFG)) return
    new current[32], title[96], info[4]
    mm_get_mode_name(mm_get_active_mode(), current, charsmax(current))
    formatex(title, charsmax(title), "Game Mode Management^nCurrent: %s", current)
    new menu = menu_create(title, "handle_mode_menu")
    for (new mode = 0; mode < SUPPORTED_MODE_COUNT; mode++)
    {
        num_to_str(mode, info, charsmax(info))
        menu_additem(menu, MODE_NAMES[mode], info)
    }
    set_back(menu)
    menu_display(id, menu)
}

public handle_mode_menu(id, menu, item)
{
    if (item == MENU_EXIT) { menu_destroy(menu); show_main_menu(id); return PLUGIN_HANDLED; }
    new access, info[8], label[32], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)
    if (!require_flag(id, ADMIN_CFG)) return PLUGIN_HANDLED
    new mode = str_to_num(info)
    if (mode < 0 || mode >= SUPPORTED_MODE_COUNT) return PLUGIN_HANDLED
    g_pending_action[id] = ACTION_MODE
    g_pending_mode[id] = MmMode:mode
    show_confirmation(id, MODE_NAMES[mode])
    return PLUGIN_HANDLED
}

show_map_menu(id)
{
    if (!require_flag(id, ADMIN_CFG)) return
    new MmMode:mode = mm_get_active_mode()
    if (_:mode < 0 || _:mode >= SUPPORTED_MODE_COUNT)
    {
        client_print(id, print_chat, "[Apexium] The active mode has no supported map pool.")
        return
    }

    new title[96]
    formatex(title, charsmax(title), "Map Management - %s", MODE_NAMES[_:mode])
    new menu = menu_create(title, "handle_map_menu")
    new file = fopen(MAP_POOL_FILES[_:mode], "rt")
    new count, line[MAX_MAP_NAME]
    if (file)
    {
        while (!feof(file))
        {
            fgets(file, line, charsmax(line))
            trim(line)
            if (!line[0] || line[0] == ';' || line[0] == '#' || !safe_map_name(line) || !is_map_valid(line)) continue
            menu_additem(menu, line, line)
            count++
        }
        fclose(file)
    }
    if (!count) menu_additem(menu, "No installed maps in this pool", "", ADMIN_RCON)
    set_back(menu)
    menu_display(id, menu)
}

public handle_map_menu(id, menu, item)
{
    if (item == MENU_EXIT) { menu_destroy(menu); show_main_menu(id); return PLUGIN_HANDLED; }
    new access, map_name[MAX_MAP_NAME], label[MAX_MAP_NAME], callback
    menu_item_getinfo(menu, item, access, map_name, charsmax(map_name), label, charsmax(label), callback)
    menu_destroy(menu)
    if (!require_flag(id, ADMIN_CFG) || !safe_map_name(map_name) || !is_map_valid(map_name)) return PLUGIN_HANDLED
    g_pending_action[id] = ACTION_MAP
    g_pending_mode[id] = mm_get_active_mode()
    copy(g_pending_map[id], MAX_MAP_NAME - 1, map_name)
    show_confirmation(id, map_name)
    return PLUGIN_HANDLED
}

show_classic_menu(id)
{
    if (!require_flag(id, ADMIN_CFG)) return
    new status[128], title[160]
    mm_classic_get_status(status, charsmax(status))
    formatex(title, charsmax(title), "Classic Match Management^n%s", status)
    new menu = menu_create(title, "handle_classic_menu")
    menu_additem(menu, "Force Ready All Humans", "0")
    menu_additem(menu, "Force Unready All Humans", "1")
    menu_additem(menu, "Start Warmup", "2")
    menu_additem(menu, "Restart Match", "3")
    menu_additem(menu, "Stop/Cancel Match", "4")
    menu_additem(menu, "Show Match Status", "5")
    set_back(menu)
    menu_display(id, menu)
}

public handle_classic_menu(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT) { show_main_menu(id); return PLUGIN_HANDLED; }
    if (!require_flag(id, ADMIN_CFG)) return PLUGIN_HANDLED
    switch (item)
    {
        case 0: print_classic_result(id, mm_classic_force_ready_humans(id))
        case 1: print_classic_result(id, mm_classic_force_unready_humans(id))
        case 2: { g_pending_action[id] = ACTION_CLASSIC_WARMUP; show_confirmation(id, "start/restart warmup"); return PLUGIN_HANDLED; }
        case 3: { g_pending_action[id] = ACTION_CLASSIC_RESTART; show_confirmation(id, "restart the Classic match"); return PLUGIN_HANDLED; }
        case 4: { g_pending_action[id] = ACTION_CLASSIC_STOP; show_confirmation(id, "stop/cancel the Classic match"); return PLUGIN_HANDLED; }
        case 5: show_classic_status(id)
    }
    show_classic_menu(id)
    return PLUGIN_HANDLED
}

show_bot_menu(id)
{
    if (!require_flag(id, ADMIN_CFG)) return
    new menu = menu_create("YaPB Bot Management", "handle_bot_menu")
    menu_additem(menu, "Add T Bot", "0")
    menu_additem(menu, "Add CT Bot", "1")
    menu_additem(menu, "Add Balanced Pair", "2")
    menu_additem(menu, "Remove One Bot", "3")
    menu_additem(menu, "Remove All Bots", "4")
    set_back(menu)
    menu_display(id, menu)
}

public handle_bot_menu(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT) { show_main_menu(id); return PLUGIN_HANDLED; }
    if (!require_flag(id, ADMIN_CFG) || !yapb_available(id)) return PLUGIN_HANDLED
    switch (item)
    {
        case 0: add_bot(id, CS_TEAM_T)
        case 1: add_bot(id, CS_TEAM_CT)
        case 2:
        {
            if (bot_team_has_capacity(CS_TEAM_T) && bot_team_has_capacity(CS_TEAM_CT))
            {
                server_cmd("yb add 2 0 1 0 AF_Admin_T")
                server_cmd("yb add 2 0 2 0 AF_Admin_CT")
                client_print(id, print_chat, "[Apexium] Requested one YaPB bot for each team.")
            }
            else client_print(id, print_chat, "[Apexium] Both teams need an available slot.")
        }
        case 3: show_bot_remove_menu(id)
        case 4:
        {
            server_cmd("yb kickall instant")
            client_print(id, print_chat, "[Apexium] Requested removal of all YaPB bots.")
        }
    }
    return PLUGIN_HANDLED
}

show_bot_remove_menu(id)
{
    new menu = menu_create("Remove One YaPB Bot", "handle_bot_remove")
    new name[32], info[12], count
    for (new player = 1; player <= MaxClients; player++)
    {
        if (!is_user_connected(player) || !is_user_bot(player)) continue
        get_user_name(player, name, charsmax(name))
        num_to_str(get_user_userid(player), info, charsmax(info))
        menu_additem(menu, name, info)
        count++
    }
    if (!count) menu_additem(menu, "No bots connected", "", ADMIN_RCON)
    set_back(menu)
    menu_display(id, menu)
}

public handle_bot_remove(id, menu, item)
{
    if (item == MENU_EXIT) { menu_destroy(menu); show_bot_menu(id); return PLUGIN_HANDLED; }
    new access, info[12], label[32], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)
    if (!require_flag(id, ADMIN_CFG)) return PLUGIN_HANDLED
    new target = find_player("k", str_to_num(info))
    if (target && is_user_connected(target) && is_user_bot(target))
    {
        server_cmd("kick #%d", get_user_userid(target))
        server_exec()
    }
    else client_print(id, print_chat, "[Apexium] That bot is no longer connected.")
    return PLUGIN_HANDLED
}

show_player_list(id)
{
    if (!require_flag(id, ADMIN_KICK)) return
    new menu = menu_create("Player Management", "handle_player_list")
    new name[32], info[12]
    for (new player = 1; player <= MaxClients; player++)
    {
        if (!is_user_connected(player) || is_user_hltv(player)) continue
        get_user_name(player, name, charsmax(name))
        num_to_str(get_user_userid(player), info, charsmax(info))
        menu_additem(menu, name, info)
    }
    set_back(menu)
    menu_display(id, menu)
}

public handle_player_list(id, menu, item)
{
    if (item == MENU_EXIT) { menu_destroy(menu); show_main_menu(id); return PLUGIN_HANDLED; }
    new access, info[12], label[32], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)
    if (!require_flag(id, ADMIN_KICK)) return PLUGIN_HANDLED
    new target = find_player("k", str_to_num(info))
    if (!valid_target(id, target)) return PLUGIN_HANDLED
    remember_target(id, target)
    show_player_actions(id, target)
    return PLUGIN_HANDLED
}

show_player_actions(id, target)
{
    new name[32], title[64]
    get_user_name(target, name, charsmax(name))
    formatex(title, charsmax(title), "Manage: %s", name)
    new menu = menu_create(title, "handle_player_action")
    menu_additem(menu, "Kick", "0", ADMIN_KICK)
    menu_additem(menu, "Slay", "1", ADMIN_SLAY)
    menu_additem(menu, "Move to Terrorists", "2", ADMIN_CFG)
    menu_additem(menu, "Move to Counter-Terrorists", "3", ADMIN_CFG)
    menu_additem(menu, "Move to Spectators", "4", ADMIN_CFG)
    menu_additem(menu, "Display Player Information", "5", ADMIN_KICK)
    set_back(menu)
    menu_display(id, menu)
}

public handle_player_action(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT) { show_player_list(id); return PLUGIN_HANDLED; }
    new target = resolve_target(id)
    if (!valid_target(id, target)) return PLUGIN_HANDLED
    switch (item)
    {
        case 0:
        {
            if (!require_flag(id, ADMIN_KICK)) return PLUGIN_HANDLED
            g_pending_action[id] = ACTION_KICK
            show_confirmation(id, "kick the selected player")
        }
        case 1:
        {
            if (require_flag(id, ADMIN_SLAY) && is_user_alive(target)) user_kill(target, 1)
        }
        case 2: move_player(id, target, CS_TEAM_T)
        case 3: move_player(id, target, CS_TEAM_CT)
        case 4: move_player(id, target, CS_TEAM_SPECTATOR)
        case 5: show_player_information(id, target)
    }
    return PLUGIN_HANDLED
}

show_server_controls(id)
{
    if (!require_flag(id, ADMIN_CFG)) return
    new label[64], menu = menu_create("Server Controls", "handle_server_controls")
    formatex(label, charsmax(label), "Friendly Fire: %s", get_cvar_num("mp_friendlyfire") ? "ON" : "OFF")
    menu_additem(menu, label, "0")
    formatex(label, charsmax(label), "Autobalance: %s", get_cvar_num("mp_autoteambalance") ? "ON" : "OFF")
    menu_additem(menu, label, "1")
    formatex(label, charsmax(label), "Team Limit: %d", get_cvar_num("mp_limitteams"))
    menu_additem(menu, label, "2")
    formatex(label, charsmax(label), "Gravity: %d", get_cvar_num("sv_gravity"))
    menu_additem(menu, label, "3")
    menu_additem(menu, "Restart Round", "4")
    set_back(menu)
    menu_display(id, menu)
}

public handle_server_controls(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT) { show_main_menu(id); return PLUGIN_HANDLED; }
    if (!require_flag(id, ADMIN_CFG)) return PLUGIN_HANDLED
    if (item < 0 || item >= sizeof CONTROL_LABELS) return PLUGIN_HANDLED
    switch (item)
    {
        case 0: g_pending_action[id] = ACTION_FRIENDLY_FIRE
        case 1: g_pending_action[id] = ACTION_AUTOBALANCE
        case 2: g_pending_action[id] = ACTION_TEAM_LIMITS
        case 3: g_pending_action[id] = ACTION_GRAVITY
        case 4: g_pending_action[id] = ACTION_RESTART_ROUND
    }
    show_confirmation(id, CONTROL_LABELS[item])
    return PLUGIN_HANDLED
}

show_server_information(id)
{
    new mode[32], map_name[32]
    mm_get_mode_name(mm_get_active_mode(), mode, charsmax(mode))
    get_mapname(map_name, charsmax(map_name))
    client_print(id, print_chat, "[Apexium] Mode: %s | Map: %s | Players: %d/%d", mode, map_name, get_playersnum(), get_maxplayers())
    client_print(id, print_chat, "[Apexium] Transition: %d | Vote active: %s | Decision pending: %s", _:mm_get_transition_state(), mm_voting_is_active() ? "yes" : "no", mm_voting_has_decision() ? "yes" : "no")
    show_main_menu(id)
}

show_confirmation(id, const description[])
{
    new title[192]
    if ((g_pending_action[id] == ACTION_MODE || g_pending_action[id] == ACTION_MAP) && mm_classic_change_blocked())
        formatex(title, charsmax(title), "CONFIRM: %s?^nWARNING: A committed Classic match will be interrupted.", description)
    else formatex(title, charsmax(title), "CONFIRM: %s?", description)
    new menu = menu_create(title, "handle_confirmation")
    menu_additem(menu, "Yes - execute", "1")
    menu_additem(menu, "No - cancel", "0")
    menu_display(id, menu)
}

public handle_confirmation(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT || item == 1) { clear_pending(id); show_main_menu(id); return PLUGIN_HANDLED; }
    execute_pending(id)
    clear_pending(id)
    return PLUGIN_HANDLED
}

execute_pending(id)
{
    if (g_pending_action[id] == ACTION_KICK)
    {
        if (!require_flag(id, ADMIN_KICK)) return
    }
    else if (!require_flag(id, ADMIN_CFG)) return
    switch (g_pending_action[id])
    {
        case ACTION_MODE:
        {
            mm_voting_admin_cancel(id)
            new MmRequestResult:result = mm_request_mode(g_pending_mode[id], id)
            client_print(id, print_chat, "[Apexium] Mode request result: %d", _:result)
        }
        case ACTION_MAP:
        {
            if (mm_get_active_mode() != g_pending_mode[id])
            {
                client_print(id, print_chat, "[Apexium] Active mode changed while the menu was open; map action cancelled.")
                return
            }
            new MmVotingAdminResult:result = mm_voting_admin_change(g_pending_mode[id], g_pending_map[id], id)
            client_print(id, print_chat, "[Apexium] Map request result: %d", _:result)
        }
        case ACTION_CLASSIC_WARMUP: print_classic_result(id, mm_classic_admin_warmup(id))
        case ACTION_CLASSIC_RESTART: print_classic_result(id, mm_classic_admin_restart(id))
        case ACTION_CLASSIC_STOP: print_classic_result(id, mm_classic_admin_stop(id))
        case ACTION_KICK:
        {
            if (!require_flag(id, ADMIN_KICK)) return
            new target = resolve_target(id)
            if (valid_target(id, target))
            {
                server_cmd("kick #%d", get_user_userid(target))
                server_exec()
            }
        }
        case ACTION_FRIENDLY_FIRE: set_cvar_num("mp_friendlyfire", !get_cvar_num("mp_friendlyfire"))
        case ACTION_AUTOBALANCE: set_cvar_num("mp_autoteambalance", !get_cvar_num("mp_autoteambalance"))
        case ACTION_TEAM_LIMITS: set_cvar_num("mp_limitteams", get_cvar_num("mp_limitteams") ? 0 : 1)
        case ACTION_GRAVITY: set_cvar_num("sv_gravity", get_cvar_num("sv_gravity") == 800 ? 600 : 800)
        case ACTION_RESTART_ROUND: server_cmd("sv_restart 3")
    }
}

add_bot(id, CsTeams:team)
{
    if (!bot_team_has_capacity(team))
    {
        client_print(id, print_chat, "[Apexium] That team has no available Classic slot.")
        return
    }
    server_cmd("yb add 2 0 %d 0 AF_Admin_Bot", team == CS_TEAM_T ? 1 : 2)
    client_print(id, print_chat, "[Apexium] YaPB bot requested.")
}

bool:bot_team_has_capacity(CsTeams:team)
{
    if (mm_get_active_mode() == MM_MODE_CLASSIC) return mm_classic_team_has_capacity(_:team)
    return get_playersnum() < get_maxplayers()
}

bool:yapb_available(id)
{
    if (cvar_exists("yb_version")) return true
    client_print(id, print_chat, "[Apexium] YaPB is not loaded; no bot command was executed.")
    return false
}

move_player(id, target, CsTeams:team)
{
    if (!require_flag(id, ADMIN_CFG)) return
    if (mm_get_active_mode() == MM_MODE_CLASSIC && mm_classic_change_blocked())
    {
        client_print(id, print_chat, "[Apexium] Player moves are locked during a committed Classic match.")
        return
    }
    if ((team == CS_TEAM_T || team == CS_TEAM_CT) && mm_get_active_mode() == MM_MODE_CLASSIC && !mm_classic_team_has_capacity(_:team))
    {
        client_print(id, print_chat, "[Apexium] The selected Classic team is full.")
        return
    }
    if (team == CS_TEAM_SPECTATOR && is_user_alive(target)) user_silentkill(target)
    cs_set_user_team(target, team)
}

show_player_information(id, target)
{
    new name[32], authid[35], ip[32]
    get_user_name(target, name, charsmax(name))
    get_user_authid(target, authid, charsmax(authid))
    get_user_ip(target, ip, charsmax(ip), 1)
    console_print(id, "[Apexium] #%d %s | %s | %s | Team %d | Bot %s", get_user_userid(target), name, authid, ip, _:cs_get_user_team(target), is_user_bot(target) ? "yes" : "no")
    client_print(id, print_chat, "[Apexium] Player information was printed to your console.")
}

remember_target(id, target)
{
    g_target_userid[id] = get_user_userid(target)
    get_user_authid(target, g_target_authid[id], 34)
}

resolve_target(id)
{
    new target = find_player("k", g_target_userid[id])
    if (!target || !is_user_connected(target)) return 0
    new authid[35]
    get_user_authid(target, authid, charsmax(authid))
    return equal(authid, g_target_authid[id]) ? target : 0
}

bool:valid_target(id, target)
{
    if (!target || !is_user_connected(target) || is_user_hltv(target))
    {
        client_print(id, print_chat, "[Apexium] That player is no longer available.")
        return false
    }
    if (target != id && (get_user_flags(target) & ADMIN_IMMUNITY) && !(get_user_flags(id) & ADMIN_RCON))
    {
        client_print(id, print_chat, "[Apexium] That administrator is protected by immunity.")
        return false
    }
    return true
}

show_classic_status(id)
{
    new status[128]
    mm_classic_get_status(status, charsmax(status))
    client_print(id, print_chat, "[Apexium] Classic: %s", status)
}

print_classic_result(id, MmClassicAdminResult:result)
{
    switch (result)
    {
        case MM_CLASSIC_ADMIN_OK: client_print(id, print_chat, "[Apexium] Classic action completed.")
        case MM_CLASSIC_ADMIN_INACTIVE: client_print(id, print_chat, "[Apexium] Classic mode is not active.")
        case MM_CLASSIC_ADMIN_INVALID_STATE: client_print(id, print_chat, "[Apexium] The Classic action is invalid in the current state.")
        case MM_CLASSIC_ADMIN_TEAMS_INCOMPLETE: client_print(id, print_chat, "[Apexium] Both teams must exactly match the selected format.")
        default: client_print(id, print_chat, "[Apexium] Classic action was refused.")
    }
}

bool:authorized_admin(id)
{
    return is_user_connected(id) && (get_user_flags(id) & (ADMIN_CFG | ADMIN_KICK | ADMIN_SLAY))
}

bool:require_flag(id, flag)
{
    if (is_user_connected(id) && (get_user_flags(id) & flag)) return true
    client_print(id, print_chat, "[Apexium] You do not have permission for that action.")
    return false
}

bool:safe_map_name(const map_name[])
{
    new length = strlen(map_name)
    if (length < 1 || length >= MAX_MAP_NAME) return false
    for (new i = 0; map_name[i]; i++)
    {
        if (!isalnum(map_name[i]) && map_name[i] != '_' && map_name[i] != '-') return false
    }
    return true
}

set_back(menu)
{
    menu_setprop(menu, MPROP_EXITNAME, "Back")
}

clear_pending(id)
{
    g_pending_action[id] = ACTION_NONE
    g_pending_map[id][0] = 0
    g_target_userid[id] = 0
    g_target_authid[id][0] = 0
}
