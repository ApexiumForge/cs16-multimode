#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cod>
#include <mm_mode_api>
#define PLUGIN "Multi-Mode CoD Wall Movement"
#define VERSION_PLUGIN "1.2.0"
#define CLIMB_SPEED 180.0
#define ADHESION_SPEED 22.0
#define LEDGE_LIFT 48.0
#define LEDGE_REACH 40.0
#define LEDGE_FORWARD_SPEED 120.0
new g_samurai,g_phantom,g_grip;
new bool:g_clinging[33],Float:g_normal[33][3],Float:g_release_until[33],Float:g_motion[33][3];
public plugin_init()
{
    register_plugin(PLUGIN,VERSION_PLUGIN,"ApexiumForge");
    register_forward(FM_CmdStart,"mm_wall_command",1);
    RegisterHam(Ham_Killed,"player","mm_wall_killed",1);
    RegisterHam(Ham_Spawn,"player","mm_wall_spawn",1);
    register_srvcmd("mm_cod_climb_status","mm_status");
    register_srvcmd("mm_cod_climb_selftest","mm_selftest");
}
public plugin_cfg(){g_samurai=cod_get_class_id("Ninja");g_phantom=cod_get_class_id("Phantom");g_grip=cod_get_item_id("Wall Grip");}
bool:mm_eligible(id)
{
    new c=cod_get_user_class(id),item=cod_get_user_item(id);
    return (g_samurai>0 && c==g_samurai) || (g_phantom>0 && c==g_phantom) || (g_grip>0 && item==g_grip);
}
mm_release(id)
{
    if(g_clinging[id] && is_user_connected(id))set_pev(id,pev_gravity,cod_get_user_gravity(id));
    g_clinging[id]=false;
    for(new i=0;i<3;i++)g_motion[id][i]=0.0;
}
public client_connect(id){g_clinging[id]=false;g_release_until[id]=0.0;}
public client_disconnected(id){g_clinging[id]=false;g_release_until[id]=0.0;}
public mm_wall_killed(id,killer,gib){mm_release(id);}
public mm_wall_spawn(id){mm_release(id);g_release_until[id]=0.0;}
public cod_class_changed(id,classname){mm_release(id);}
public mm_mode_transition_started(oldmode,newmode){if(MmMode:oldmode==MM_MODE_COD)for(new id=1;id<=MaxClients;id++)mm_release(id);}
public mm_wall_command(id,uc,seed)
{
    if(mm_get_active_mode()!=MM_MODE_COD || !is_user_alive(id)){mm_release(id);return FMRES_IGNORED;}
    new buttons=get_uc(uc,UC_Buttons);
    if(!(buttons&IN_USE) || cod_get_user_weapon(id)!=CSW_KNIFE || !mm_eligible(id) || pev(id,pev_waterlevel)>1 || g_release_until[id]>get_gametime())
    {mm_release(id);return FMRES_IGNORED;}
    new Float:angle[3],Float:viewForward[3],Float:right[3],Float:wish[3],Float:normal[3];
    pev(id,pev_v_angle,angle);angle_vector(angle,ANGLEVECTOR_FORWARD,viewForward);angle_vector(angle,ANGLEVECTOR_RIGHT,right);
    new Float:fmove,Float:smove;
    if(buttons&IN_FORWARD)fmove+=1.0;if(buttons&IN_BACK)fmove-=1.0;
    if(buttons&IN_MOVERIGHT)smove+=1.0;if(buttons&IN_MOVELEFT)smove-=1.0;
    for(new i=0;i<3;i++)wish[i]=viewForward[i]*fmove+right[i]*smove;
    if(!mm_find_wall(id,wish,normal)){mm_release(id);return FMRES_IGNORED;}
    if(g_clinging[id] && buttons&IN_JUMP && !(pev(id,pev_oldbuttons)&IN_JUMP))
    {
        mm_release(id);g_release_until[id]=get_gametime()+0.18;
        new Float:jump[3];jump[0]=normal[0]*260.0;jump[1]=normal[1]*260.0;jump[2]=285.0;set_pev(id,pev_velocity,jump);
        return FMRES_IGNORED;
    }
    if(!g_clinging[id])for(new i=0;i<3;i++)g_motion[id][i]=0.0;
    g_clinging[id]=true;for(new i=0;i<3;i++)g_normal[id][i]=normal[i];
    new Float:target[3],Float:velocity[3];
    mm_wall_project(wish,normal,target);
    new Float:length=vector_length(target);
    // Preserve analog view projection near the wall normal; no tiny-vector speed jump.
    for(new i=0;i<3;i++)target[i]*=CLIMB_SPEED/(length>1.0?length:1.0);
    mm_wall_project(g_motion[id],normal,velocity);
    new Float:dt=floatclamp(float(get_uc(uc,UC_Msec))*0.001,0.001,0.05);
    new Float:rate=length>0.01?14.0:24.0;
    new Float:blend=mm_wall_blend(dt,rate);
    for(new i=0;i<3;i++)
    {
        g_motion[id][i]=velocity[i]+(target[i]-velocity[i])*blend;
        if(length<0.01 && floatabs(g_motion[id][i])<0.5)g_motion[id][i]=0.0;
        velocity[i]=g_motion[id][i]-normal[i]*ADHESION_SPEED;
    }
    // When the upper hull can pass over a supported lip, keep climbing and
    // gently move inward instead of pulling back against the wall normal.
    if(wish[2]>0.15 && mm_ledge_clear(id,normal))
    {
        for(new i=0;i<2;i++)velocity[i]=g_motion[id][i]-normal[i]*LEDGE_FORWARD_SPEED;
        velocity[2]=floatmax(velocity[2],CLIMB_SPEED);
    }
    // An actual zero means default gravity on GoldSrc, so use a tiny positive value.
    set_pev(id,pev_gravity,0.0001);set_pev(id,pev_velocity,velocity);
    // Keep normal wish-movement from fighting the wall-plane velocity above.
    set_uc(uc,UC_ForwardMove,0.0);set_uc(uc,UC_SideMove,0.0);set_uc(uc,UC_UpMove,0.0);
    return FMRES_IGNORED;
}
stock mm_wall_project(const Float:input[3],const Float:normal[3],Float:output[3])
{
    new Float:dot=input[0]*normal[0]+input[1]*normal[1]+input[2]*normal[2];
    for(new i=0;i<3;i++)output[i]=input[i]-normal[i]*dot;
}
bool:mm_probe_wall(id,const Float:direction[3],Float:normal[3],&Float:distance)
{
    new Float:origin[3],Float:eye[3],Float:start[3],Float:end[3],Float:candidate[3];
    pev(id,pev_origin,origin);pev(id,pev_view_ofs,eye);
    new bool:found;distance=999.0;
    new trace=create_tr2();
    for(new height=0;height<3;height++)
    {
        for(new i=0;i<3;i++){start[i]=origin[i];if(i==2)start[i]+=height==0?eye[2]:(height==1?8.0:-30.0);end[i]=start[i]+direction[i]*56.0;}
        engfunc(EngFunc_TraceLine,start,end,DONT_IGNORE_MONSTERS,id,trace);
        new Float:fraction;get_tr2(trace,TR_flFraction,fraction);get_tr2(trace,TR_vecPlaneNormal,candidate);
        new hit=get_tr2(trace,TR_pHit);
        if(fraction>=1.0 || floatabs(candidate[2])>=0.25 || (hit>0 && hit<=MaxClients) || fraction*56.0>=distance)continue;
        distance=fraction*56.0;for(new i=0;i<3;i++)normal[i]=candidate[i];found=true;
    }
    free_tr2(trace);return found;
}
bool:mm_ledge_clear(id,const Float:normal[3])
{
    new Float:origin[3],Float:raised[3],Float:over[3],Float:down[3],Float:plane[3],Float:fraction;
    pev(id,pev_origin,origin);
    for(new i=0;i<3;i++){raised[i]=origin[i];over[i]=origin[i]-normal[i]*LEDGE_REACH;}
    raised[2]+=LEDGE_LIFT;over[2]=raised[2];
    new hull=(pev(id,pev_flags)&FL_DUCKING)?HULL_HEAD:HULL_HUMAN;
    new trace=create_tr2();new bool:clear;
    // Test the whole player hull up, over, and down, including other players.
    engfunc(EngFunc_TraceHull,origin,raised,DONT_IGNORE_MONSTERS,hull,id,trace);
    get_tr2(trace,TR_flFraction,fraction);
    if(fraction>=1.0 && !get_tr2(trace,TR_StartSolid) && !get_tr2(trace,TR_AllSolid))
    {
        engfunc(EngFunc_TraceHull,raised,over,DONT_IGNORE_MONSTERS,hull,id,trace);
        get_tr2(trace,TR_flFraction,fraction);
        if(fraction>=1.0 && !get_tr2(trace,TR_StartSolid) && !get_tr2(trace,TR_AllSolid))
        {
            for(new i=0;i<3;i++)down[i]=over[i];down[2]-=LEDGE_LIFT+8.0;
            engfunc(EngFunc_TraceHull,over,down,DONT_IGNORE_MONSTERS,hull,id,trace);
            get_tr2(trace,TR_flFraction,fraction);get_tr2(trace,TR_vecPlaneNormal,plane);
            new hit=get_tr2(trace,TR_pHit);
            clear=fraction<1.0 && !get_tr2(trace,TR_StartSolid) && !get_tr2(trace,TR_AllSolid)
                && plane[2]>=0.7 && !(hit>0 && hit<=MaxClients);
        }
    }
    free_tr2(trace);return clear;
}
bool:mm_find_wall(id,const Float:wish[3],Float:normal[3])
{
    new Float:angle[3],Float:facing[3],Float:direction[3],Float:candidate[3],Float:distance;
    pev(id,pev_v_angle,angle);angle[0]=0.0;angle_vector(angle,ANGLEVECTOR_FORWARD,facing);
    new bool:held;
    if(g_clinging[id])
    {
        for(new i=0;i<3;i++)direction[i]=-g_normal[id][i];
        held=mm_probe_wall(id,direction,normal,distance);
    }
    for(new probe=0;probe<2;probe++)
    {
        direction[0]=probe?wish[0]:facing[0];direction[1]=probe?wish[1]:facing[1];direction[2]=0.0;
        new Float:length=vector_length(direction);if(length<0.05)continue;
        for(new i=0;i<3;i++)direction[i]/=length;
        if(!mm_probe_wall(id,direction,candidate,distance))continue;
        if(!held){for(new i=0;i<3;i++)normal[i]=candidate[i];return true;}
        new Float:alignment=normal[0]*candidate[0]+normal[1]*candidate[1]+normal[2]*candidate[2];
        new Float:approach=wish[0]*candidate[0]+wish[1]*candidate[1]+wish[2]*candidate[2];
        // Change surfaces only when close and deliberately moving into the next wall.
        if(distance<=30.0 && alignment<0.75 && approach< -0.15)
        {for(new i=0;i<3;i++)normal[i]=candidate[i];return true;}
    }
    if(held)return true;
    if(!g_clinging[id])return false;
    // A short-range fan catches adjacent corner faces when the old wall ends.
    // No timed air grace: there must still be actual nearby wall contact.
    new const Float:fan[][3]={{1.0,0.0,0.0},{0.7071,0.7071,0.0},{0.0,1.0,0.0},{-0.7071,0.7071,0.0},{-1.0,0.0,0.0},{-0.7071,-0.7071,0.0},{0.0,-1.0,0.0},{0.7071,-0.7071,0.0}};
    new Float:nearest=57.0;new bool:found;
    for(new probe=0;probe<sizeof fan;probe++)
    {
        if(!mm_probe_wall(id,fan[probe],candidate,distance) || distance>=nearest)continue;
        nearest=distance;for(new i=0;i<3;i++)normal[i]=candidate[i];found=true;
    }
    return found;
}
public mm_status(){new active;for(new id=1;id<=MaxClients;id++)if(g_clinging[id])active++;server_print("[CoD Climb] enabled=%d clinging=%d ninja=%d phantom=%d grip=%d unlimited=1 speed=180 view_relative=1 smooth=1 corner_transfer=1 ledge_assist=1",mm_get_active_mode()==MM_MODE_COD,active,g_samurai,g_phantom,g_grip);}
public plugin_end(){for(new id=1;id<=MaxClients;id++)mm_release(id);}


stock Float:mm_wall_blend(Float:dt,Float:rate){return 1.0-floatpower(2.7182818,-rate*dt);}
public mm_selftest()
{
    new passed;new Float:normal[3]={1.0,0.0,0.0},Float:angle[3],Float:direction[3],Float:result[3];
    angle[1]=135.0;angle_vector(angle,ANGLEVECTOR_FORWARD,direction);mm_wall_project(direction,normal,result);
    if(floatabs(result[0])<0.001 && result[1]>0.5 && floatabs(result[2])<0.001)passed++;
    angle[0]=-45.0;angle[1]=180.0;angle_vector(angle,ANGLEVECTOR_FORWARD,direction);mm_wall_project(direction,normal,result);
    if(result[2]>0.5 && floatabs(result[0])<0.001)passed++;
    angle[0]=45.0;angle_vector(angle,ANGLEVECTOR_FORWARD,direction);for(new i=0;i<3;i++)direction[i]=-direction[i];mm_wall_project(direction,normal,result);
    if(result[2]>0.5 && floatabs(result[0])<0.001)passed++;
    new Float:slow,Float:fast;
    for(new i=0;i<30;i++)slow+=(180.0-slow)*mm_wall_blend(1.0/30.0,14.0);
    for(new i=0;i<100;i++)fast+=(180.0-fast)*mm_wall_blend(0.01,14.0);
    if(floatabs(slow-fast)<0.05)passed++;
    server_print("[CoD Climb] direction/smoothing checks=%d/4 (right+W, up+W, down+S, 30vs100Hz)",passed);
}
