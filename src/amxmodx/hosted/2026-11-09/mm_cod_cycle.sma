#include <amxmodx>
#include <mm_mode_api>
#include <mm_voting_api>

#define PLUGIN "Multi-Mode CoD Map Cycle"
#define VERSION "1.0.0"
#define AUTHOR "Torbeshi"
#define TASK_CLOCK 919010
#define MAP_SECONDS 2700.0
#define EXTEND_SECONDS 900.0

new Float:g_deadline, Float:g_retry;
new bool:g_clock;

public plugin_init()
{
    register_plugin(PLUGIN,VERSION,AUTHOR);
    register_srvcmd("mm_cod_cycle_status","mm_status");
    register_srvcmd("mm_cod_cycle_selftest","mm_selftest");
    register_clcmd("say /codtime","mm_time",0,"- CoD map time remaining");
    register_clcmd("say_team /codtime","mm_time");
}
public plugin_cfg()
{
    if(mm_get_active_mode()==MM_MODE_COD)mm_start();
}
mm_start()
{
    remove_task(TASK_CLOCK);
    g_clock=true;
    g_deadline=get_gametime()+MAP_SECONDS;
    g_retry=0.0;
    set_task(1.0,"mm_tick",TASK_CLOCK,_,_,"b");
    log_amx("CoD map clock started: 45 minutes; extensions are 15 minutes.");
}
public mm_mode_transition_started(old_mode,new_mode)
{
    if(MmMode:old_mode==MM_MODE_COD)
    {
        remove_task(TASK_CLOCK);
        g_clock=false;
        g_deadline=0.0;
        g_retry=0.0;
    }
}
public mm_mode_changed(old_mode,new_mode)
{
    if(MmMode:new_mode==MM_MODE_COD)mm_start();
}
public mm_tick()
{
    if(!g_clock || mm_get_active_mode()!=MM_MODE_COD || mm_get_transition_state()!=MM_TRANSITION_IDLE)return;
    new Float:now=get_gametime();
    if(now<g_deadline || now<g_retry || mm_voting_is_active() || mm_voting_has_decision())return;
    // No players or a cancelled vote: retry quietly, without interrupting play.
    g_retry=now+30.0;
    mm_voting_start_cod_vote();
}
public mm_cod_map_extended(minutes)
{
    if(!g_clock || mm_get_active_mode()!=MM_MODE_COD || minutes!=15)return;
    g_deadline=floatmax(get_gametime(),g_deadline)+EXTEND_SECONDS;
    g_retry=0.0;
    client_print_color(0,print_team_blue,"^4[^1CoD^4]^1 Map extended by ^3%d minutes^1. Keep fighting!",minutes);
}
public mm_time(id)
{
    if(mm_get_active_mode()!=MM_MODE_COD)return PLUGIN_CONTINUE;
    new seconds=max(0,floatround(g_deadline-get_gametime(),floatround_ceil));
    if(seconds)client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Map vote in ^3%d:%02d^1. Extensions add ^315 minutes^1.",seconds/60,seconds%60);
    else client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Map time finished: vote for ^3next map^1 or ^3extend 15 minutes^1.");
    return PLUGIN_HANDLED;
}
public mm_status()
{
    server_print("[CoD Cycle] active=%d running=%d remaining=%d map_minutes=45 extend_minutes=15 voting=%d decision=%d",mm_get_active_mode()==MM_MODE_COD,g_clock,max(0,floatround(g_deadline-get_gametime())),mm_voting_is_active(),mm_voting_has_decision());
}
public mm_selftest()
{
    server_print("[CoD Cycle] selftest=%d/3",(MAP_SECONDS==45.0*60.0)+(EXTEND_SECONDS==15.0*60.0)+(floatmax(2800.0,2700.0)+EXTEND_SECONDS==3700.0));
}
public plugin_end(){remove_task(TASK_CLOCK);}
