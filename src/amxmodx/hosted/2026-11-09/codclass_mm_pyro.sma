// M249-backed flamethrower; original stock animation data, palette-only reskin.
#include <mm_cod_adapt>
#include <fun>
#include <cstrike>
native mm_cod_is_protected(id);
#define FLAME_SPEED 720.0
#define FLAME_LIFE 0.65
#define FLAME_INTERVAL 0.18
#define MAX_FIREBALLS 96
new const VIEW[]="models/CoDMod/pyro/v_flamethrower.mdl",PLAYER[]="models/CoDMod/pyro/p_flamethrower.mdl",FIREBALL[]="mm_cod_fireball";
new bool:g_active[33],g_fuel[33],Float:g_ready[33],g_shots,g_impacts,g_count,g_frames;
new Float:g_burn_until[33],Float:g_burn_next[33],g_burn_owner[33];
public plugin_precache(){precache_model(VIEW);precache_model(PLAYER);g_frames=max(1,engfunc(EngFunc_ModelFrames,precache_model("sprites/CoDMod/dexplo.spr")));precache_sound("ambience/flameburst1.wav");}
public plugin_init()
{
    register_plugin("CoD Adapted Pyro","2.1.0","ApexiumForge");
    cod_register_class("Pyro","M249 flamethrower + M3 + USP. Hold fire: flying fireballs, 60 fuel per life, no reload. SWAT Shield blocks fire.","Standard Classes",(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_USP),20,10,0,5,0);
    RegisterHam(Ham_Weapon_PrimaryAttack,"weapon_m249","mm_primary");RegisterHam(Ham_Weapon_Reload,"weapon_m249","mm_reload");RegisterHam(Ham_Item_Deploy,"weapon_m249","mm_deploy",1);
    RegisterHam(Ham_Killed,"player","mm_dead",1);register_forward(FM_UpdateClientData,"mm_client_data",1);
    register_touch(FIREBALL,"*","mm_fireball_touch");register_think(FIREBALL,"mm_fireball_think");
    set_task(0.25,"mm_burn_tick",919700,_,_,"b");register_srvcmd("mm_cod_pyro_status","mm_status");
}
public cod_class_enabled(id,promotion){g_active[id]=true;g_fuel[id]=60;g_ready[id]=0.0;}
public cod_class_disabled(id){g_active[id]=false;mm_clear_owner(id);mm_remove_balls(id);}
public client_connect(id){g_active[id]=false;g_fuel[id]=0;g_ready[id]=0.0;g_burn_until[id]=0.0;}
public client_disconnected(id){g_active[id]=false;g_burn_until[id]=0.0;mm_clear_owner(id);mm_remove_balls(id);}
public cod_class_spawned(id,respawn){g_fuel[id]=60;g_ready[id]=0.0;g_burn_until[id]=0.0;mm_remove_balls(id);}
public mm_dead(id,killer,gib){g_burn_until[id]=0.0;mm_clear_owner(id);mm_remove_balls(id);}
mm_clear_owner(id){new userid=get_user_userid(id);for(new v=1;v<=MaxClients;v++)if(g_burn_owner[v]==userid)g_burn_until[v]=0.0;}
public mm_mode_transition_started(oldmode,newmode){if(MmMode:oldmode==MM_MODE_COD){for(new id=1;id<=MaxClients;id++)g_burn_until[id]=0.0;mm_remove_balls(0);}}
public cod_new_round(){mm_remove_balls(0);for(new id=1;id<=MaxClients;id++)g_burn_until[id]=0.0;}
public cod_class_skill_used(id){if(mm_cod_alive(id) && g_active[id])client_print_color(id,print_team_blue,"^4[^1Pyro^4]^1 Equip your ^3flamethrower (M249)^1 and hold ^3left click^1. Fuel: ^3%d/60^1.",g_fuel[id]);}
public mm_deploy(weapon)
{
    new id=get_member(weapon,m_pPlayer);if(!mm_cod_alive(id) || !g_active[id])return HAM_IGNORED;
    set_pev(id,pev_viewmodel2,VIEW);set_pev(id,pev_weaponmodel2,PLAYER);set_member(weapon,m_Weapon_iClip,g_fuel[id]);cs_set_user_bpammo(id,CSW_M249,0);return HAM_IGNORED;
}
public mm_client_data(id,sendweapons,cd)
{
    if(mm_cod_alive(id) && g_active[id] && cod_get_user_weapon(id)==CSW_M249){set_cd(cd,CD_flNextAttack,get_gametime()+0.001);cs_set_user_bpammo(id,CSW_M249,0);set_pev(id,pev_viewmodel2,VIEW);set_pev(id,pev_weaponmodel2,PLAYER);}
    return FMRES_IGNORED;
}
public mm_reload(weapon){new id=get_member(weapon,m_pPlayer);return mm_cod_alive(id) && g_active[id]?HAM_SUPERCEDE:HAM_IGNORED;}
public mm_primary(weapon)
{
    new id=get_member(weapon,m_pPlayer);if(!mm_cod_alive(id) || !g_active[id])return HAM_IGNORED;
    if(get_gametime()<g_ready[id])return HAM_SUPERCEDE;
    g_ready[id]=get_gametime()+FLAME_INTERVAL;set_member(weapon,m_Weapon_flNextPrimaryAttack,FLAME_INTERVAL);
    if(g_fuel[id]<=0 || pev(id,pev_waterlevel)>1 || g_count>=MAX_FIREBALLS){client_print(id,print_center,g_fuel[id]<=0?"Flamethrower empty - refills on spawn":"Flamethrower unavailable here");return HAM_SUPERCEDE;}
    new Float:eye[3],Float:offset[3],Float:angle[3],Float:dir[3],Float:muzzle[3];pev(id,pev_origin,eye);pev(id,pev_view_ofs,offset);pev(id,pev_v_angle,angle);angle_vector(angle,ANGLEVECTOR_FORWARD,dir);
    for(new i=0;i<3;i++){eye[i]+=offset[i];muzzle[i]=eye[i]+dir[i]*24.0;}
    new trace=create_tr2();engfunc(EngFunc_TraceLine,eye,muzzle,DONT_IGNORE_MONSTERS,id,trace);new Float:fraction;get_tr2(trace,TR_flFraction,fraction);
    if(fraction<1.0 || get_tr2(trace,TR_StartSolid)){free_tr2(trace);return HAM_SUPERCEDE;}
    free_tr2(trace);
    new ent=create_entity("info_target");if(!is_valid_ent(ent))return HAM_SUPERCEDE;
    entity_set_string(ent,EV_SZ_classname,FIREBALL);entity_set_model(ent,"sprites/CoDMod/dexplo.spr");entity_set_size(ent,Float:{-4.0,-4.0,-4.0},Float:{4.0,4.0,4.0});
    entity_set_origin(ent,muzzle);entity_set_int(ent,EV_INT_movetype,MOVETYPE_FLY);entity_set_int(ent,EV_INT_solid,SOLID_BBOX);entity_set_edict(ent,EV_ENT_owner,id);
    set_pev(ent,pev_frame,3.0);set_pev(ent,pev_iuser1,get_user_userid(id));set_pev(ent,pev_vuser1,muzzle);set_pev(ent,pev_fuser1,get_gametime()+FLAME_LIFE);set_pev(ent,pev_scale,1.0);set_pev(ent,pev_rendermode,kRenderTransAdd);set_pev(ent,pev_renderamt,220.0);
    new Float:velocity[3];for(new i=0;i<3;i++)velocity[i]=dir[i]*FLAME_SPEED;entity_set_vector(ent,EV_VEC_velocity,velocity);set_pev(ent,pev_nextthink,get_gametime()+0.02);
    g_count++;g_shots++;g_fuel[id]--;set_member(weapon,m_Weapon_iClip,g_fuel[id]);cs_set_user_bpammo(id,CSW_M249,0);mm_cod_end_protection(id);
    set_pev(id,pev_weaponanim,1);message_begin(MSG_ONE_UNRELIABLE,SVC_WEAPONANIM,_,id);write_byte(1);write_byte(pev(id,pev_body));message_end();emit_sound(id,CHAN_WEAPON,"ambience/flameburst1.wav",0.35,ATTN_NORM,0,110);
    return HAM_SUPERCEDE;
}
mm_delete_ball(ent){if(!is_valid_ent(ent))return;g_count=max(0,g_count-1);remove_entity(ent);}
mm_remove_balls(owner){new ent=-1;while((ent=find_ent_by_class(ent,FIREBALL))>0)if(!owner || entity_get_edict(ent,EV_ENT_owner)==owner)mm_delete_ball(ent);}
public mm_fireball_touch(ent,other)
{
    if(!is_valid_ent(ent) || other==entity_get_edict(ent,EV_ENT_owner))return;
    new Float:origin[3];pev(ent,pev_origin,origin);mm_impact(ent,other,origin);
}
public mm_fireball_think(ent)
{
    if(!is_valid_ent(ent))return;
    new owner=entity_get_edict(ent,EV_ENT_owner);
    if(!mm_cod_alive(owner) || !g_active[owner] || get_user_userid(owner)!=pev(ent,pev_iuser1) || get_gametime()>=pev(ent,pev_fuser1)){mm_delete_ball(ent);return;}
    new Float:origin[3],Float:last[3];pev(ent,pev_origin,origin);pev(ent,pev_vuser1,last);
    if(engfunc(EngFunc_PointContents,origin)==CONTENTS_WATER){mm_delete_ball(ent);return;}
    new trace=create_tr2();engfunc(EngFunc_TraceLine,last,origin,DONT_IGNORE_MONSTERS,ent,trace);new Float:fraction;get_tr2(trace,TR_flFraction,fraction);new hit=get_tr2(trace,TR_pHit);get_tr2(trace,TR_vecEndPos,origin);free_tr2(trace);
    if(fraction<1.0){mm_impact(ent,hit,origin);return;}
    set_pev(ent,pev_vuser1,origin);set_pev(ent,pev_frame,float(3+(pev(ent,pev_iuser2)/2)%min(8,g_frames-3)));set_pev(ent,pev_iuser2,pev(ent,pev_iuser2)+1);set_pev(ent,pev_nextthink,get_gametime()+0.02);
}
mm_impact(ent,direct,const Float:origin[3])
{
    new owner=entity_get_edict(ent,EV_ENT_owner),userid=pev(ent,pev_iuser1);
    // Remove the projectile before damage callbacks can trigger owner cleanup.
    mm_delete_ball(ent);g_impacts++;
    if(!mm_cod_alive(owner) || !g_active[owner] || get_user_userid(owner)!=userid)return;
    for(new victim=1;victim<=MaxClients;victim++){
        if(!is_user_alive(victim) || get_user_team(victim)==get_user_team(owner) || cod_get_user_resistance(victim) || mm_cod_is_protected(victim))continue;
        new Float:target[3];pev(victim,pev_origin,target);target[2]+=10.0;
        new Float:distance=get_distance_f(origin,target);if(victim!=direct && distance>52.0)continue;
        if(victim!=direct){new trace=create_tr2();engfunc(EngFunc_TraceLine,origin,target,DONT_IGNORE_MONSTERS,owner,trace);new Float:fraction;get_tr2(trace,TR_flFraction,fraction);new hit=get_tr2(trace,TR_pHit);free_tr2(trace);if(fraction<1.0 && hit!=victim)continue;}
        cod_inflict_damage(owner,victim,victim==direct?22.0:10.0,0.02,DMG_BURN);
        if(is_user_alive(victim)){g_burn_until[victim]=get_gametime()+1.5;g_burn_next[victim]=get_gametime()+0.5;g_burn_owner[victim]=userid;}
    }
}
public mm_burn_tick()
{
    if(mm_get_active_mode()!=MM_MODE_COD)return;
    new Float:now=get_gametime();
    for(new victim=1;victim<=MaxClients;victim++){
        if(g_burn_until[victim]<=now || g_burn_next[victim]>now)continue;
        new owner=find_player("k",g_burn_owner[victim]);
        if(!is_user_alive(victim) || !is_user_alive(owner) || !g_active[owner] || get_user_team(owner)==get_user_team(victim) || cod_get_user_resistance(victim) || mm_cod_is_protected(victim) || pev(victim,pev_waterlevel)>1){g_burn_until[victim]=0.0;continue;}
        g_burn_next[victim]=now+0.5;cod_inflict_damage(owner,victim,3.0,0.0,DMG_BURN);
    }
}

public mm_status(){server_print("[CoD Pyro] class=%d m249_fireballs=1 m3=1 round_flame=1 scale=1.0 speed=720 lifetime=0.65 fuel=60 damage=22 splash=10 interval=0.18 burn=1.5 live=%d shots=%d impacts=%d shield_counter=1",cod_get_class_id("Pyro"),g_count,g_shots,g_impacts);}
public plugin_end(){mm_remove_balls(0);}
