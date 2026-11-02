#include <amxmodx>
#include <amxmisc>
#include <mm_mode_api>

#define PLUGIN_NAME    "Multi-Mode Network Mode Manager"
#define PLUGIN_VERSION "0.4.5-colors"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"
#define MODE_CONFIG_DIR "addons/amxmodx/configs/mm_modes"
#define TASK_APPLY_MODE 22021
#define TASK_VERIFY_MODE 22022

new const MODE_NAMES[MM_MODE_COUNT][] =
{
    "Classic",
    "Deathmatch",
    "Arms Race",
    "AWP Only",
    "HE Battle"
}
new const MODE_COMMAND_NAMES[MM_MODE_COUNT][] =
{
    "classic",
    "deathmatch",
    "armsrace",
    "awponly",
    "hebattle"
}

new const MODE_CONFIG_NAMES[MM_MODE_COUNT][] =
{
    "classic.cfg",
    "deathmatch.cfg",
    "armsrace.cfg",
    "awp_only.cfg",
    "he_battle.cfg"
}

new const CLASSIC_FORMAT_NAMES[MM_FORMAT_COUNT][] =
{
    "1v1", "2v2", "3v3", "4v4", "5v5",
    "1v2", "2v3", "3v4", "4v5"
}

new MmMode:g_active_mode = MM_MODE_CLASSIC
new MmMode:g_requested_mode = MM_MODE_CLASSIC
new MmTransitionState:g_transition_state = MM_TRANSITION_IDLE
new MmClassicFormat:g_classic_format = MM_FORMAT_5V5
new MmMode:g_previous_mode = MM_MODE_CLASSIC
new g_transition_requester
new g_verify_attempts
new g_active_config_cvar
new g_transition_started_forward
new g_mode_changed_forward
new g_format_changed_forward

public plugin_natives()
{
    register_library("mm_mode_manager")
    register_native("mm_get_active_mode", "native_get_active_mode")
    register_native("mm_get_requested_mode", "native_get_requested_mode")
    register_native("mm_get_transition_state", "native_get_transition_state")
    register_native("mm_get_classic_format", "native_get_classic_format")
    register_native("mm_get_mode_name", "native_get_mode_name")
    register_native("mm_get_classic_format_name", "native_get_classic_format_name")
    register_native("mm_request_mode", "native_request_mode")
    register_native("mm_request_classic_format", "native_request_classic_format")
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /mode", "handle_mode_status")
    register_clcmd("say_team /mode", "handle_mode_status")
    // AMX Mod X reserves the server cvar "amx_mode" for admin authentication.
    // A client command can safely use the requested name without replacing it.
    register_clcmd("amx_mode", "handle_admin_mode", ADMIN_CFG, "<classic|deathmatch|armsrace|awponly|hebattle>")
    register_concmd("amx_classic_format", "handle_admin_classic_format", ADMIN_CFG, "<1v1|2v2|3v3|4v4|5v5|1v2|2v3|3v4|4v5>")
    register_srvcmd("mm_mode", "handle_server_mode")

    g_active_config_cvar = register_cvar("mm_active_config", "uninitialized")
    g_transition_started_forward = CreateMultiForward("mm_mode_transition_started", ET_IGNORE, FP_CELL, FP_CELL)
    g_mode_changed_forward = CreateMultiForward("mm_mode_changed", ET_IGNORE, FP_CELL, FP_CELL)
    g_format_changed_forward = CreateMultiForward("mm_classic_format_changed", ET_IGNORE, FP_CELL, FP_CELL)

    if (!apply_mode_config(MM_MODE_CLASSIC))
    {
        g_transition_state = MM_TRANSITION_FAILED
        log_amx("Default Classic configuration could not be applied.")
    }
    else
    {
        g_transition_state = MM_TRANSITION_IDLE
    }

    log_amx("%s mode manager v%s initialized. Active mode: Classic, format: 5v5.", PROJECT_NAME, PLUGIN_VERSION)
}

public plugin_end()
{
    DestroyForward(g_transition_started_forward)
    DestroyForward(g_mode_changed_forward)
    DestroyForward(g_format_changed_forward)
}

public native_get_active_mode()
{
    return _:g_active_mode
}

public native_get_requested_mode()
{
    return _:g_requested_mode
}

public native_get_transition_state()
{
    return _:g_transition_state
}

public native_get_classic_format()
{
    return _:g_classic_format
}

public native_get_mode_name(plugin_id, parameter_count)
{
    new MmMode:mode = MmMode:get_param(1)
    if (!is_valid_mode(mode))
    {
        return 0
    }

    set_string(2, MODE_NAMES[mode], get_param(3))
    return 1
}

public native_get_classic_format_name(plugin_id, parameter_count)
{
    new MmClassicFormat:format = MmClassicFormat:get_param(1)
    if (!is_valid_format(format))
    {
        return 0
    }

    set_string(2, CLASSIC_FORMAT_NAMES[format], get_param(3))
    return 1
}

public native_request_mode(plugin_id, parameter_count)
{
    return _:request_mode(MmMode:get_param(1), get_param(2))
}

public native_request_classic_format(plugin_id, parameter_count)
{
    return _:request_classic_format(MmClassicFormat:get_param(1), get_param(2))
}

public handle_mode_status(id)
{
    new mode_name[32]
    new format_name[16]
    copy(mode_name, charsmax(mode_name), MODE_NAMES[g_active_mode])
    copy(format_name, charsmax(format_name), CLASSIC_FORMAT_NAMES[g_classic_format])

    client_print_color(id, print_team_default, "^x04[%s]^x01 Active mode: %s | Classic format: %s", PROJECT_NAME, mode_name, format_name)
    return PLUGIN_HANDLED
}

public handle_admin_mode(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
    {
        return PLUGIN_HANDLED
    }

    new argument[32]
    read_argv(1, argument, charsmax(argument))
    new MmMode:mode = find_mode(argument)
    if (!is_valid_mode(mode))
    {
        console_print(id, "[MM] Invalid mode. Use: classic, deathmatch, armsrace, awponly, or hebattle.")
        return PLUGIN_HANDLED
    }

    print_request_result(id, request_mode(mode, id), MODE_NAMES[mode])
    return PLUGIN_HANDLED
}

public handle_admin_classic_format(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
    {
        return PLUGIN_HANDLED
    }

    new argument[16]
    read_argv(1, argument, charsmax(argument))
    new MmClassicFormat:format = find_format(argument)
    if (!is_valid_format(format))
    {
        console_print(id, "[MM] Invalid Classic format. Use 1v1, 2v2, 3v3, 4v4, 5v5, 1v2, 2v3, 3v4, or 4v5.")
        return PLUGIN_HANDLED
    }

    print_request_result(id, request_classic_format(format, id), CLASSIC_FORMAT_NAMES[format])
    return PLUGIN_HANDLED
}

public handle_server_mode()
{
    new argument[32]
    read_argv(1, argument, charsmax(argument))
    new MmMode:mode = find_mode(argument)
    if (!is_valid_mode(mode))
    {
        server_print("[MM] Invalid mode. Use: classic, deathmatch, armsrace, awponly, or hebattle.")
        return PLUGIN_HANDLED
    }

    print_request_result(0, request_mode(mode, 0), MODE_NAMES[mode])
    return PLUGIN_HANDLED
}

MmRequestResult:request_mode(MmMode:mode, requester)
{
    if (!is_authorized_requester(requester))
    {
        return MM_REQUEST_UNAUTHORIZED
    }
    if (!is_valid_mode(mode))
    {
        return MM_REQUEST_INVALID
    }
    if (g_transition_state != MM_TRANSITION_IDLE)
    {
        return MM_REQUEST_BUSY
    }
    if (mode == g_active_mode)
    {
        return MM_REQUEST_DUPLICATE
    }

    new MmMode:old_mode = g_active_mode
    new forward_result
    g_previous_mode = old_mode
    g_transition_requester = requester
    g_verify_attempts = 0
    g_requested_mode = mode
    g_transition_state = MM_TRANSITION_RESETTING
    ExecuteForward(g_transition_started_forward, forward_result, _:old_mode, _:mode)
    reset_temporary_mode_state()

    g_transition_state = MM_TRANSITION_APPLYING
    remove_task(TASK_APPLY_MODE)
    remove_task(TASK_VERIFY_MODE)
    set_task(0.1, "task_apply_requested_mode", TASK_APPLY_MODE)
    return MM_REQUEST_ACCEPTED
}

public task_apply_requested_mode()
{
    new config_path[128]
    get_mode_config_path(g_requested_mode, config_path, charsmax(config_path))
    if (!file_exists(config_path))
    {
        handle_transition_failure()
        return
    }

    server_cmd("exec %s", config_path)
    set_task(0.1, "task_verify_requested_mode", TASK_VERIFY_MODE)
}

public task_verify_requested_mode()
{
    new applied_config[32]
    get_pcvar_string(g_active_config_cvar, applied_config, charsmax(applied_config))
    if (!equal(applied_config, MODE_COMMAND_NAMES[g_requested_mode]))
    {
        if (g_verify_attempts < 10)
        {
            g_verify_attempts++
            set_task(0.1, "task_verify_requested_mode", TASK_VERIFY_MODE)
            return
        }
        handle_transition_failure()
        return
    }

    new MmMode:new_mode = g_requested_mode
    new forward_result
    g_active_mode = new_mode
    g_transition_state = MM_TRANSITION_IDLE
    ExecuteForward(g_mode_changed_forward, forward_result, _:g_previous_mode, _:new_mode)

    new requester_name[32]
    get_requester_name(g_transition_requester, requester_name, charsmax(requester_name))
    client_print_color(0, print_team_default, "^x04[%s]^x01 ^x04%s^x01 activated %s mode.", PROJECT_NAME, requester_name, MODE_NAMES[new_mode])
    log_amx("Mode changed from %s to %s by %s.", MODE_NAMES[g_previous_mode], MODE_NAMES[new_mode], requester_name)
}

handle_transition_failure()
{
    if (g_requested_mode != MM_MODE_CLASSIC)
    {
        log_amx("Mode transition to %s failed; applying safe Classic fallback.", MODE_NAMES[g_requested_mode])
        g_transition_state = MM_TRANSITION_FAILED
        g_requested_mode = MM_MODE_CLASSIC
        g_verify_attempts = 0
        set_task(0.1, "task_apply_requested_mode", TASK_APPLY_MODE)
        return
    }

    g_transition_state = MM_TRANSITION_FAILED
    g_active_mode = MM_MODE_CLASSIC
    log_amx("Critical: Classic fallback configuration also failed.")
}

MmRequestResult:request_classic_format(MmClassicFormat:format, requester)
{
    if (!is_authorized_requester(requester))
    {
        return MM_REQUEST_UNAUTHORIZED
    }
    if (!is_valid_format(format))
    {
        return MM_REQUEST_INVALID
    }
    if (g_transition_state != MM_TRANSITION_IDLE)
    {
        return MM_REQUEST_BUSY
    }
    if (format == g_classic_format)
    {
        return MM_REQUEST_DUPLICATE
    }

    new MmClassicFormat:old_format = g_classic_format
    new forward_result
    g_classic_format = format
    ExecuteForward(g_format_changed_forward, forward_result, _:old_format, _:format)

    new requester_name[32]
    get_requester_name(requester, requester_name, charsmax(requester_name))
    client_print_color(0, print_team_default, "^x04[%s]^x01 ^x04%s^x01 selected Classic format %s.", PROJECT_NAME, requester_name, CLASSIC_FORMAT_NAMES[format])
    log_amx("Classic format changed from %s to %s by %s.", CLASSIC_FORMAT_NAMES[old_format], CLASSIC_FORMAT_NAMES[format], requester_name)
    return MM_REQUEST_ACCEPTED
}

reset_temporary_mode_state()
{
    set_pcvar_string(g_active_config_cvar, "transitioning")
}

bool:apply_mode_config(MmMode:mode)
{
    new config_path[128]
    get_mode_config_path(mode, config_path, charsmax(config_path))
    if (!file_exists(config_path))
    {
        log_amx("Mode configuration is missing: %s", config_path)
        return false
    }

    server_cmd("exec %s", config_path)
    server_exec()

    new applied_config[32]
    get_pcvar_string(g_active_config_cvar, applied_config, charsmax(applied_config))
    return bool:equal(applied_config, MODE_COMMAND_NAMES[mode])
}

get_mode_config_path(MmMode:mode, output[], output_length)
{
    formatex(output, output_length, "%s/%s", MODE_CONFIG_DIR, MODE_CONFIG_NAMES[mode])
}

bool:is_valid_mode(MmMode:mode)
{
    return _:mode >= _:MM_MODE_CLASSIC && _:mode < _:MM_MODE_COUNT
}

bool:is_valid_format(MmClassicFormat:format)
{
    return _:format >= _:MM_FORMAT_1V1 && _:format < _:MM_FORMAT_COUNT
}

bool:is_authorized_requester(requester)
{
    if (requester == 0)
    {
        return true
    }
    return requester >= 1 && requester <= MaxClients && is_user_connected(requester) && (get_user_flags(requester) & ADMIN_CFG) != 0
}

MmMode:find_mode(const input[])
{
    for (new MmMode:mode = MM_MODE_CLASSIC; mode < MM_MODE_COUNT; mode++)
    {
        if (equali(input, MODE_COMMAND_NAMES[mode]))
        {
            return mode
        }
    }
    return MmMode:-1
}

MmClassicFormat:find_format(const input[])
{
    for (new MmClassicFormat:format = MM_FORMAT_1V1; format < MM_FORMAT_COUNT; format++)
    {
        if (equali(input, CLASSIC_FORMAT_NAMES[format]))
        {
            return format
        }
    }
    return MmClassicFormat:-1
}

get_requester_name(requester, output[], output_length)
{
    if (requester >= 1 && requester <= MaxClients && is_user_connected(requester))
    {
        get_user_name(requester, output, output_length)
    }
    else
    {
        copy(output, output_length, "Server Console")
    }
}

print_request_result(id, MmRequestResult:result, const target_name[])
{
    switch (result)
    {
        case MM_REQUEST_ACCEPTED: console_print(id, "[MM] Request accepted: %s.", target_name)
        case MM_REQUEST_DUPLICATE: console_print(id, "[MM] Already active/selected: %s.", target_name)
        case MM_REQUEST_BUSY: console_print(id, "[MM] Another mode transition is already in progress.")
        case MM_REQUEST_INVALID: console_print(id, "[MM] Invalid request: %s.", target_name)
        case MM_REQUEST_UNAUTHORIZED: console_print(id, "[MM] You are not authorized to change mode state.")
        default: console_print(id, "[MM] Request failed; Classic fallback was attempted.")
    }
}
