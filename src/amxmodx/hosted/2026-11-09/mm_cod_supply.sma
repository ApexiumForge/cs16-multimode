#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <cod>
#include <mm_mode_api>
#define PLUGIN "Multi-Mode CoD Supply Drops"
#define PLUGIN_VERSION "1.0.0"
#define AUTHOR "ApexiumForge"
#define MAX_DROPS 24
new const CLASSNAME[]="mm_cod_supply",MODEL[]="models/CoDMod/adapt/supply_box.mdl";
new g_chance,g_count,g_spawned,g_picked;
public plugin_precache(){precache_model(MODEL);precache_sound("ByM_Cod/BoxPickup.wav");}
public plugin_init()
{
    register_plugin(PLUGIN,PLUGIN_VERSION,AUTHOR);
    g_chance=register_cvar("mm_cod_supply_chance","20");
    register_touch(CLASSNAME,"player","mm_pickup");register_think(CLASSNAME,"mm_expire");
    register_srvcmd("mm_cod_supply_status","mm_status");
}
public cod_killed(killer,victim,weapon,hit)
{
    if(mm_get_active_mode()!=MM_MODE_COD || killer==victim || !is_user_connected(killer) || !is_user_connected(victim) || get_user_team(killer)==get_user_team(victim) || g_count>=MAX_DROPS || random_num(1,100)>clamp(get_pcvar_num(g_chance),0,100))return;
    new Float:origin[3];pev(victim,pev_origin,origin);origin[2]+=8.0;
    new ent=create_entity("info_target");if(!is_valid_ent(ent))return;
    entity_set_string(ent,EV_SZ_classname,CLASSNAME);entity_set_model(ent,MODEL);
    entity_set_size(ent,Float:{-10.0,-10.0,0.0},Float:{10.0,10.0,20.0});
    entity_set_int(ent,EV_INT_solid,SOLID_TRIGGER);entity_set_int(ent,EV_INT_movetype,MOVETYPE_TOSS);
    entity_set_origin(ent,origin);entity_set_float(ent,EV_FL_nextthink,get_gametime()+20.0);
    set_rendering(ent,kRenderFxGlowShell,40,160,60,kRenderNormal,10);g_count++;g_spawned++;
}
public mm_pickup(ent,id)
{
    if(mm_get_active_mode()!=MM_MODE_COD || !is_valid_ent(ent) || !is_user_alive(id) || !cod_get_user_class(id))return;
    remove_entity(ent);g_count=max(0,g_count-1);g_picked++;
    emit_sound(id,CHAN_ITEM,"ByM_Cod/BoxPickup.wav",0.65,ATTN_NORM,0,PITCH_NORM);
    new reward=random_num(0,cod_get_user_item(id)?3:4);
    switch(reward)
    {
        case 0:{cod_set_user_exp(id,25);client_print_color(id,print_team_blue,"^4[^1Supply^4]^1 Picked up ^3+25 XP^1.");}
        case 1:{cod_add_user_honor(id,15);client_print_color(id,print_team_blue,"^4[^1Supply^4]^1 Picked up ^3+15 Gold^1.");}
        case 2:{cod_add_user_health(id,30);client_print_color(id,print_team_blue,"^4[^1Supply^4]^1 Picked up ^3health supplies^1 (+30 HP, up to your maximum).");}
        case 3:{cod_refill_ammo(id);client_print_color(id,print_team_blue,"^4[^1Supply^4]^1 Picked up a ^3magazine refill^1.");}
        case 4:{cod_set_user_item(id,RANDOM);client_print_color(id,print_team_blue,"^4[^1Supply^4]^1 Picked up a ^3random perk^1! Use /codperk.");}
    }
}
public mm_expire(ent){if(is_valid_ent(ent)){remove_entity(ent);g_count=max(0,g_count-1);}}
mm_cleanup(){remove_entity_name(CLASSNAME);g_count=0;}
public mm_mode_transition_started(oldmode,newmode){if(MmMode:oldmode==MM_MODE_COD)mm_cleanup();}
public cod_new_round(){mm_cleanup();}
public plugin_end(){mm_cleanup();}
public mm_status(){server_print("[CoD Supply] active=%d live=%d spawned=%d picked=%d chance=%d cap=%d lifetime=20",mm_get_active_mode()==MM_MODE_COD,g_count,g_spawned,g_picked,get_pcvar_num(g_chance),MAX_DROPS);}
