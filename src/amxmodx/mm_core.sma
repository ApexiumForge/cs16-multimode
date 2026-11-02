#include <amxmodx>

#define PLUGIN_NAME    "Multi-Mode Network Core"
#define PLUGIN_VERSION "0.4.4"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /serverinfo", "handle_server_info")
    register_clcmd("say_team /serverinfo", "handle_server_info")

    log_amx("%s v%s initialized successfully.", PROJECT_NAME, PLUGIN_VERSION)
}

public handle_server_info(id)
{
    client_print(id, print_chat, "[%s] Server Foundation %s", PROJECT_NAME, PLUGIN_VERSION)
    return PLUGIN_HANDLED
}

