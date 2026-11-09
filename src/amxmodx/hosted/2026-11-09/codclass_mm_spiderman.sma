// Original adaptation inspired by the AMXX CoD Spiderman class concept.
#include <mm_cod_adapt>
#include <fun>
#define HOOK_RANGE 900.0
#define HOOK_SPEED 420.0
new bool:g_active[33],bool:g_hooked[33],Float:g_anchor[33][3],Float:g_end[33],Float:g_ready[33],Float:g_beam_at[33],g_sprite,g_uses;
public plugin_precache(){g_sprite=precache_model("sprites/white.spr");}
public plugin_init(){register_plugin("CoD Adapted Spiderman","1.0.0","ApexiumForge");cod_register_class("Spiderman","Skill toggles a 900-unit grappling hook (3 seconds, 4-second cooldown). Space releases. MP5 + USP.","Standard Classes",(1<<CSW_MP5NAVY)|(1<<CSW_USP),10,0,0,0,15);register_forward(FM_CmdStart,"mm_hook_command",1);RegisterHam(Ham_Killed,"player","mm_dead",1);register_srvcmd("mm_cod_spider_status","mm_status");}
mm_detach(id){if(g_hooked[id])g_ready[id]=get_gametime()+4.0;g_hooked[id]=false;}
public cod_class_enabled(id,promotion){g_active[id]=true;g_hooked[id]=false;g_ready[id]=0.0;}
public cod_class_disabled(id){mm_detach(id);g_active[id]=false;}
public client_connect(id){g_active[id]=g_hooked[id]=false;g_ready[id]=0.0;}
public client_disconnected(id){g_active[id]=g_hooked[id]=false;g_ready[id]=0.0;}
public cod_class_spawned(id,respawn){g_hooked[id]=false;g_ready[id]=0.0;}
public mm_dead(id,killer,gib){mm_detach(id);}
public mm_mode_transition_started(oldmode,newmode){if(MmMode:oldmode==MM_MODE_COD)for(new id=1;id<=MaxClients;id++)mm_detach(id);}
public cod_class_skill_used(id)
{
    if(!mm_cod_alive(id) || !g_active[id])return;
    if(g_hooked[id]){mm_detach(id);return;}
    if(get_gametime()<g_ready[id]){client_print_color(id,print_team_blue,"^4[^1Spiderman^4]^1 Hook ready in ^3%.1f seconds^1.",g_ready[id]-get_gametime());return;}
    new Float:eye[3],Float:offset[3],Float:angle[3],Float:dir[3],Float:end[3];pev(id,pev_origin,eye);pev(id,pev_view_ofs,offset);pev(id,pev_v_angle,angle);angle_vector(angle,ANGLEVECTOR_FORWARD,dir);
    for(new i=0;i<3;i++){eye[i]+=offset[i];end[i]=eye[i]+dir[i]*HOOK_RANGE;}
    new trace=create_tr2();engfunc(EngFunc_TraceLine,eye,end,DONT_IGNORE_MONSTERS,id,trace);new Float:fraction;get_tr2(trace,TR_flFraction,fraction);new hit=get_tr2(trace,TR_pHit);
    new bool:blocked=fraction>=1.0 || (hit>0 && hit<=MaxClients) || get_tr2(trace,TR_StartSolid) || engfunc(EngFunc_PointContents,end)==CONTENTS_SKY;
    get_tr2(trace,TR_vecEndPos,g_anchor[id]);free_tr2(trace);
    // Pull only to fixed map geometry, not doors, players or breakables.
    if(blocked || hit>0 || get_distance_f(eye,g_anchor[id])<60.0){client_print_color(id,print_team_blue,"^4[^1Spiderman^4]^1 Aim at a solid map surface within ^3900 units^1.");return;}
    g_hooked[id]=true;g_end[id]=get_gametime()+3.0;g_beam_at[id]=0.0;g_uses++;mm_cod_end_protection(id);
}
public mm_hook_command(id,uc,seed)
{
    if(!g_hooked[id])return FMRES_IGNORED;
    if(!mm_cod_alive(id) || !g_active[id] || get_gametime()>=g_end[id] || pev(id,pev_waterlevel)>1 || pev(id,pev_movetype)!=MOVETYPE_WALK || get_user_maxspeed(id)<=1.0){mm_detach(id);return FMRES_IGNORED;}
    if((get_uc(uc,UC_Buttons)&IN_JUMP) && !(pev(id,pev_oldbuttons)&IN_JUMP)){mm_detach(id);return FMRES_IGNORED;}
    new Float:origin[3],Float:eye[3],Float:offset[3],Float:dir[3],Float:velocity[3];pev(id,pev_origin,origin);pev(id,pev_view_ofs,offset);
    for(new i=0;i<3;i++){eye[i]=origin[i]+offset[i];dir[i]=g_anchor[id][i]-eye[i];}
    new Float:distance=vector_length(dir);if(distance<45.0){mm_detach(id);return FMRES_IGNORED;}
    new trace=create_tr2();engfunc(EngFunc_TraceLine,eye,g_anchor[id],IGNORE_MONSTERS,id,trace);new Float:end[3];get_tr2(trace,TR_vecEndPos,end);free_tr2(trace);
    if(get_distance_f(end,g_anchor[id])>12.0){mm_detach(id);return FMRES_IGNORED;}
    new Float:blend=1.0-floatpower(2.7182818,-14.0*floatclamp(float(get_uc(uc,UC_Msec))*0.001,0.001,0.05));
    new Float:speed=floatmin(HOOK_SPEED,distance*4.0);pev(id,pev_velocity,velocity);
    for(new i=0;i<3;i++)velocity[i]+=(dir[i]/distance*speed-velocity[i])*blend;
    if(velocity[2]>0.0)set_pev(id,pev_flags,pev(id,pev_flags)&~FL_ONGROUND);
    set_pev(id,pev_velocity,velocity);
    if(get_gametime()>=g_beam_at[id]){
        g_beam_at[id]=get_gametime()+0.15;
        engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,origin,0);write_byte(TE_BEAMENTPOINT);write_short(id);write_coord_f(g_anchor[id][0]);write_coord_f(g_anchor[id][1]);write_coord_f(g_anchor[id][2]);write_short(g_sprite);write_byte(0);write_byte(0);write_byte(2);write_byte(3);write_byte(0);write_byte(220);write_byte(230);write_byte(255);write_byte(180);write_byte(0);message_end();
    }
    return FMRES_IGNORED;
}
public mm_status(){new attached;for(new id=1;id<=MaxClients;id++)if(g_hooked[id])attached++;server_print("[CoD Spiderman] class=%d range=900 speed=420 duration=3 cooldown=4 attached=%d uses=%d",cod_get_class_id("Spiderman"),attached,g_uses);}
