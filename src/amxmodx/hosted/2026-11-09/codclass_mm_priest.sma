/* New source adaptation of the user-provided ByM pack's documented abilities.
 * Uses the installed O'Zone/TheDoctor0 API; no compiled ByM code is loaded. */
#include <mm_cod_adapt>
#define PLUGIN_VERSION "1.0.0"
new bool:g_active[33];

new Float:g_ready[33];
public plugin_init(){register_plugin("CoD Adapted Priest",PLUGIN_VERSION,"ApexiumForge");cod_register_class("Priest","Skill: rescue a nearby dead ally before their respawn, or heal nearby allies 35 HP (15s cooldown).","VIP Classes",(1<<CSW_MP5NAVY)|(1<<CSW_USP),20,10,0,10,0);}
public cod_class_enabled(id,promotion){g_active[id]=true;g_ready[id]=0.0;}
public cod_class_disabled(id){g_active[id]=false;}
public client_disconnected(id){g_active[id]=false;}
public cod_class_spawned(id,respawn){g_ready[id]=0.0;}
public cod_class_skill_used(id)
{
    if(!mm_cod_alive(id) || !g_active[id])return;
    if(g_ready[id]>get_gametime()){client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Rescue/heal ready in ^3%.0f seconds^1.",g_ready[id]-get_gametime());return;}
    if(mm_cod_rescue(id,260.0)){g_ready[id]=get_gametime()+15.0;return;}
    new Float:origin[3],Float:other[3],healed;pev(id,pev_origin,origin);
    for(new player=1;player<=MaxClients;player++)
    {
        if(!is_user_alive(player) || get_user_team(player)!=get_user_team(id) || cod_get_user_health(player,1)>=cod_get_user_max_health(player))continue;
        pev(player,pev_origin,other);if(get_distance_f(origin,other)>260.0)continue;
        cod_add_user_health(player,35);healed++;
    }
    if(healed){g_ready[id]=get_gametime()+15.0;client_print_color(id,print_team_blue,"^4[^1CoD^4]^3 Healing pulse:^1 restored health to ^3%d^1 nearby players.",healed);}
    else client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 No nearby ally needs healing or revival. Your skill is still ready.");
}
