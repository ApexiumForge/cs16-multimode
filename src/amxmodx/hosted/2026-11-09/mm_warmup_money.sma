#include <amxmodx>
#include <cstrike>
#include <mm_mode_api>
#include <mm_classic_api>

#define MM_MONEY_TASK 914720
#define MM_PRACTICE_MONEY 16000
new const PLUGIN_NAME[] = "Classic Practice Money"
new const PLUGIN_VERSION[] = "2.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    set_task(0.2, "mm_refill_practice_money", MM_MONEY_TASK, "", 0, "b")
    log_amx("%s v%s initialized using the Classic API.", PLUGIN_NAME, PLUGIN_VERSION)
}

public mm_refill_practice_money()
{
    if (mm_get_active_mode() != MM_MODE_CLASSIC) return
    if (mm_get_transition_state() != MM_TRANSITION_IDLE) return
    // READY also covers the live restart countdown; never refill committed matches.
    if (mm_classic_change_blocked()) return
    new MmClassicState:phase = mm_classic_get_state()
    if (phase != MM_CLASSIC_WAITING && phase != MM_CLASSIC_WARMUP && phase != MM_CLASSIC_READY) return
    new players[32], count
    get_players(players, count, "h")
    for (new i = 0; i < count; i++)
    {
        new id = players[i]
        if (!is_user_alive(id)) continue
        new CsTeams:team = cs_get_user_team(id)
        if (team != CS_TEAM_T && team != CS_TEAM_CT) continue
        if (cs_get_user_money(id) < MM_PRACTICE_MONEY)
            cs_set_user_money(id, MM_PRACTICE_MONEY, 0)
    }
}

public plugin_end()
{
    remove_task(MM_MONEY_TASK)
}
