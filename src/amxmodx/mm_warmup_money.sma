#include <amxmodx>
#include <cstrike>
#include <mm_mode_api>
#include <mm_classic_api>

#define PLUGIN_NAME "Multi-Mode Classic Practice Money"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR "ApexiumForge"
#define TASK_PRACTICE_MONEY 914720
#define MAX_CS_MONEY 16000

new g_money_cvar

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    g_money_cvar = register_cvar("mm_classic_practice_money", "16000")
    set_task(1.0, "task_refill_practice_money", TASK_PRACTICE_MONEY, _, _, "b")
    log_amx("%s v%s initialized.", PLUGIN_NAME, PLUGIN_VERSION)
}

public task_refill_practice_money()
{
    if (mm_get_active_mode() != MM_MODE_CLASSIC || mm_get_transition_state() != MM_TRANSITION_IDLE)
    {
        return
    }
    if (mm_classic_change_blocked())
    {
        return
    }

    new MmClassicState:match_state = mm_classic_get_state()
    if (match_state != MM_CLASSIC_WAITING && match_state != MM_CLASSIC_WARMUP && match_state != MM_CLASSIC_READY)
    {
        return
    }

    new target_money = clamp(get_pcvar_num(g_money_cvar), 0, MAX_CS_MONEY)
    if (target_money <= 0)
    {
        return
    }

    new players[32], count
    get_players(players, count, "h")
    for (new index = 0; index < count; index++)
    {
        new id = players[index]
        if (!is_user_alive(id))
        {
            continue
        }

        new CsTeams:team = cs_get_user_team(id)
        if (team != CS_TEAM_T && team != CS_TEAM_CT)
        {
            continue
        }

        if (cs_get_user_money(id) < target_money)
        {
            cs_set_user_money(id, target_money, 0)
        }
    }
}

public plugin_end()
{
    remove_task(TASK_PRACTICE_MONEY)
}
