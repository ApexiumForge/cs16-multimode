#include <amxmodx>
#include <amxmisc>
#include <cstrike>

#define PLUGIN_NAME    "Multi-Mode Network Classic Test Bridge"
#define PLUGIN_VERSION "0.4.4"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define TASK_AUTORUN_ADD   39001
#define TASK_AUTORUN_READY 39002
#define TASK_AUTORUN_CHECK 39003

new g_autorun_cvar

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_concmd("mm_test_bots_ready", "command_bots_ready", ADMIN_CFG, "<all|t|ct>")
    g_autorun_cvar = register_cvar("mm_test_autorun_1v1", "0")
    log_amx("Classic bot-ready test bridge v%s initialized (development only).", PLUGIN_VERSION)
}

public plugin_cfg()
{
    // server.cfg (which opts into mm_solo_test.cfg) may execute after
    // plugin_cfg, so inspect the disabled-by-default cvar on the next frame.
    set_task(1.0, "task_check_autorun", TASK_AUTORUN_CHECK)
}

public task_check_autorun()
{
    if (get_pcvar_num(g_autorun_cvar) == 1)
    {
        set_task(2.0, "task_autorun_add", TASK_AUTORUN_ADD)
        log_amx("Development autorun requested: scheduling a controlled YaPB 1v1 test.")
    }
}

public task_autorun_add()
{
    server_cmd("mm_match_format 1v1")
    server_cmd("yb add 2 0 1 0 MM_Test_T")
    server_cmd("yb add 2 0 2 0 MM_Test_CT")
    server_exec()
    set_task(5.0, "task_autorun_ready", TASK_AUTORUN_READY)
}

public task_autorun_ready()
{
    server_cmd("mm_test_bots_ready all")
    log_amx("Development autorun sent bots through the normal /ready command path.")
}

public command_bots_ready(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED

    new selection[8]
    read_argv(1, selection, charsmax(selection))
    if (!equali(selection, "all") && !equali(selection, "t") && !equali(selection, "ct"))
    {
        console_print(id, "[MM TEST] Usage: mm_test_bots_ready <all|t|ct>")
        return PLUGIN_HANDLED
    }

    new marked
    for (new player = 1; player <= MaxClients; player++)
    {
        if (!is_user_connected(player) || !is_user_bot(player)) continue

        new CsTeams:team = cs_get_user_team(player)
        if (team != CS_TEAM_T && team != CS_TEAM_CT) continue
        if (equali(selection, "t") && team != CS_TEAM_T) continue
        if (equali(selection, "ct") && team != CS_TEAM_CT) continue

        // Call the production /ready handler itself. YaPB fake clients do not
        // pass engclient_cmd("say") through AMX Mod X's chat hook reliably.
        // This retains every production team/state check and never writes
        // Classic's private ready state from the test plugin.
        if (callfunc_begin("command_ready", "mm_classic.amxx") == 1)
        {
            callfunc_push_int(player)
            callfunc_end()
            marked++
        }
    }

    console_print(id, "[MM TEST] Sent /ready through %d connected YaPB bot(s).", marked)
    log_amx("Sent bots through the production /ready handler: %d bot(s).", marked)
    return PLUGIN_HANDLED
}
