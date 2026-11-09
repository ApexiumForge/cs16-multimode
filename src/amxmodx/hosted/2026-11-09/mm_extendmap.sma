#include <amxmodx>
#include <amxmisc>

new const PLUGIN_NAME[] = "Multi-Mode Extend Map"
new const PLUGIN_VERSION[] = "1.0.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_concmd("amx_extendmap", "mm_extend_map", ADMIN_MAP, "<minutes> - add 1 to 1440 minutes to the current map")
    register_srvcmd("mm_extendmap_status", "mm_status")
    log_amx("Map extension command registered independently of map voting.")
}

public mm_extend_map(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new argument[32]
    read_argv(1, argument, charsmax(argument))
    if (strlen(argument) > 4 || !is_str_num(argument))
    {
        console_print(id, "Usage: amx_extendmap <minutes> (whole number from 1 to 1440)")
        return PLUGIN_HANDLED
    }
    new minutes = str_to_num(argument)
    if (minutes < 1 || minutes > 1440)
    {
        console_print(id, "Minutes must be between 1 and 1440.")
        return PLUGIN_HANDLED
    }
    new Float:before = get_cvar_float("mp_timelimit")
    if (before <= 0.0)
    {
        console_print(id, "This map has no time limit; there is no timer to extend.")
        return PLUGIN_HANDLED
    }
    if (get_cvar_num("mp_winlimit") > 0 || get_cvar_num("mp_maxrounds") > 0)
    {
        console_print(id, "A win/round limit can still end this map; disable that limit before extending its timer.")
        return PLUGIN_HANDLED
    }
    new Float:after = before + float(minutes), name[32]
    set_cvar_float("mp_timelimit", after)
    if (id) get_user_name(id, name, charsmax(name))
    else copy(name, charsmax(name), "Server Console")
    client_print_color(0, print_team_default, "^4[Admin] %s^1 extended the map by ^4%d^1 minutes.", name, minutes)
    console_print(id, "Map extended by %d minutes. Total time limit: %.0f minutes.", minutes, after)
    log_amx("Map extension by %s: +%d minutes (%.0f -> %.0f).", name, minutes, before, after)
    return PLUGIN_HANDLED
}

public mm_status()
{
    server_print("[Extend Map] version=%s command=amx_extendmap timelimit=%.0f winlimit=%d maxrounds=%d", PLUGIN_VERSION, get_cvar_float("mp_timelimit"), get_cvar_num("mp_winlimit"), get_cvar_num("mp_maxrounds"))
}
