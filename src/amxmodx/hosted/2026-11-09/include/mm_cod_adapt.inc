#if defined _mm_cod_adapt_included
    #endinput
#endif
#define _mm_cod_adapt_included
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <cod>
#include <mm_mode_api>
native mm_cod_rescue(id,Float:range)
native mm_cod_end_protection(id)
stock bool:mm_cod_alive(id){return mm_get_active_mode()==MM_MODE_COD && is_user_alive(id);}
stock mm_jet_pulse(id,buttons,oldbuttons,&Float:ready,Float:cooldown,Float:thrust=220.0,Float:lift=340.0,Float:cap=450.0,bool:cleanLaunch=false)
{
    if(!(buttons&IN_DUCK) || !(buttons&IN_JUMP) || oldbuttons&IN_JUMP || pev(id,pev_waterlevel)>1 || pev(id,pev_movetype)!=MOVETYPE_WALK || ready>get_gametime())return;
    new Float:velocity[3],Float:angle[3],Float:dir[3];pev(id,pev_velocity,velocity);pev(id,pev_v_angle,angle);
    angle[0]=0.0;angle_vector(angle,ANGLEVECTOR_FORWARD,dir);
    // Preserve an existing faster run/launch instead of snapping it down to the cap.
    new Float:limit=cap;
    if(cleanLaunch)limit=floatmax(cap,floatsqroot(velocity[0]*velocity[0]+velocity[1]*velocity[1]));
    velocity[0]+=dir[0]*thrust;velocity[1]+=dir[1]*thrust;
    new Float:speed=floatsqroot(velocity[0]*velocity[0]+velocity[1]*velocity[1]);
    if(speed>limit){velocity[0]*=limit/speed;velocity[1]*=limit/speed;}
    // Detach before engine movement so stock ground jumping/friction cannot
    // replace this impulse in the same command. No timed hover/acceleration ramp.
    if(cleanLaunch)set_pev(id,pev_flags,pev(id,pev_flags)&~FL_ONGROUND);
    velocity[2]=floatmax(velocity[2],lift);set_pev(id,pev_velocity,velocity);ready=get_gametime()+cooldown;
    client_print_color(id,print_team_blue,"^4[^1CoD^4]^3 Jet boost!^1 Ready again in %.0f seconds.",cooldown);
}
stock mm_melee_model(id,const view[],const player[])
{
    set_pev(id,pev_viewmodel2,view);set_pev(id,pev_weaponmodel2,player);
}
stock mm_restore_melee(id)
{
    if(!is_user_alive(id))return;
    new item=get_member(id,m_pActiveItem);
    if(!is_nullent(item) && get_member(item,m_iId)==WEAPON_KNIFE)ExecuteHamB(Ham_Item_Deploy,item);
}
