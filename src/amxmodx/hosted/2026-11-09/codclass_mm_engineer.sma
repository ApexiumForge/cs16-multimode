/* Source adaptation inspired by the supplied ByM sentry asset; current CoD API. */
#include <mm_cod_adapt>
#define PLUGIN_VERSION "1.0.0"
new const MODEL[]="models/CoDMod/adapt/sentry.mdl",ENTITY[]="mm_cod_sentry";
new bool:g_active[33],bool:g_used[33],g_sentry[33];
public plugin_precache(){precache_model(MODEL);}
public plugin_init()
{
    register_plugin("CoD Adapted Engineer",PLUGIN_VERSION,"ApexiumForge");
    cod_register_class("Engineer","Skill: deploy a destructible sentry for 20 seconds. One per life; 150 turret HP.","VIP Classes",(1<<CSW_P90)|(1<<CSW_GLOCK18),10,10,0,10,0);
    register_think(ENTITY,"mm_sentry_think");RegisterHam(Ham_TakeDamage,"info_target","mm_sentry_damage");
}
public cod_class_enabled(id,promotion){g_active[id]=true;g_used[id]=false;mm_remove_sentry(id);}
public cod_class_disabled(id){g_active[id]=false;mm_remove_sentry(id);}
public client_disconnected(id){g_active[id]=false;mm_remove_sentry(id);}
public cod_class_spawned(id,respawn){mm_remove_sentry(id);g_used[id]=false;}
public cod_class_killed(killer,victim,hit){mm_remove_sentry(victim);}
mm_remove_sentry(id)
{
    new ent=g_sentry[id];g_sentry[id]=0;if(!is_valid_ent(ent))return;
    new classname[32];entity_get_string(ent,EV_SZ_classname,classname,charsmax(classname));
    if(equal(classname,ENTITY) && entity_get_edict(ent,EV_ENT_owner)==id)remove_entity(ent);
}
public cod_class_skill_used(id)
{
    if(!mm_cod_alive(id) || !g_active[id])return;
    if(g_used[id]){client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Your sentry has already been used this life.");return;}
    if(!(pev(id,pev_flags)&FL_ONGROUND)){client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Stand on the ground to place your sentry.");return;}
    new Float:origin[3],Float:angle[3],Float:dir[3],Float:check[3];pev(id,pev_origin,origin);pev(id,pev_v_angle,angle);angle[0]=0.0;angle_vector(angle,ANGLEVECTOR_FORWARD,dir);
    origin[0]+=dir[0]*64.0;origin[1]+=dir[1]*64.0;origin[2]-=30.0;
    check[0]=origin[0];check[1]=origin[1];check[2]=origin[2]+20.0;
    new tr=create_tr2();engfunc(EngFunc_TraceHull,check,check,DONT_IGNORE_MONSTERS,HULL_HEAD,id,tr);
    new bool:blocked=bool:(get_tr2(tr,TR_StartSolid) || get_tr2(tr,TR_AllSolid));free_tr2(tr);
    if(blocked){client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Not enough room ahead for a sentry.");return;}
    new ent=create_entity("info_target");if(!is_valid_ent(ent))return;
    entity_set_string(ent,EV_SZ_classname,ENTITY);entity_set_model(ent,MODEL);
    entity_set_size(ent,Float:{-16.0,-16.0,0.0},Float:{16.0,16.0,40.0});entity_set_origin(ent,origin);
    entity_set_int(ent,EV_INT_solid,SOLID_BBOX);entity_set_int(ent,EV_INT_movetype,MOVETYPE_TOSS);entity_set_edict(ent,EV_ENT_owner,id);
    entity_set_float(ent,EV_FL_takedamage,DAMAGE_YES);entity_set_float(ent,EV_FL_health,150.0);
    set_pev(ent,pev_fuser1,get_gametime()+20.0);entity_set_float(ent,EV_FL_nextthink,get_gametime()+0.75);
    g_sentry[id]=ent;g_used[id]=true;mm_cod_end_protection(id);
    set_rendering(ent,kRenderFxGlowShell,get_user_team(id)==1?130:30,30,get_user_team(id)==2?130:30,kRenderNormal,8);
    client_print_color(id,print_team_blue,"^4[^1CoD^4]^3 Sentry deployed!^1 Active for 20 seconds or until destroyed.");
}
public mm_sentry_damage(ent,inflictor,attacker,Float:damage,bits)
{
    if(!is_valid_ent(ent))return HAM_IGNORED;
    new classname[32];entity_get_string(ent,EV_SZ_classname,classname,charsmax(classname));if(!equal(classname,ENTITY))return HAM_IGNORED;
    new owner=entity_get_edict(ent,EV_ENT_owner);
    if(!is_user_connected(attacker) || !is_user_connected(owner) || get_user_team(attacker)==get_user_team(owner))return HAM_SUPERCEDE;
    if(damage>=entity_get_float(ent,EV_FL_health)){g_sentry[owner]=0;remove_entity(ent);return HAM_SUPERCEDE;}
    return HAM_IGNORED;
}
public mm_sentry_think(ent)
{
    if(!is_valid_ent(ent))return;
    new owner=entity_get_edict(ent,EV_ENT_owner);new Float:expires;pev(ent,pev_fuser1,expires);
    if(mm_get_active_mode()!=MM_MODE_COD || !is_user_alive(owner) || !g_active[owner] || get_gametime()>=expires){if(owner>=1 && owner<=MaxClients)g_sentry[owner]=0;remove_entity(ent);return;}
    new Float:origin[3],Float:targetpos[3],Float:best=550.0,target;pev(ent,pev_origin,origin);origin[2]+=30.0;
    for(new id=1;id<=MaxClients;id++)
    {
        if(!is_user_alive(id) || get_user_team(id)==get_user_team(owner))continue;
        pev(id,pev_origin,targetpos);targetpos[2]+=8.0;
        new Float:distance=get_distance_f(origin,targetpos);if(distance>=best)continue;
        new tr=create_tr2();engfunc(EngFunc_TraceLine,origin,targetpos,DONT_IGNORE_MONSTERS,ent,tr);
        new hit=get_tr2(tr,TR_pHit);new Float:fraction;get_tr2(tr,TR_flFraction,fraction);free_tr2(tr);
        if(hit==id || fraction>=1.0){target=id;best=distance;}
    }
    if(target)
    {
        pev(target,pev_origin,targetpos);targetpos[2]+=8.0;
        message_begin(MSG_BROADCAST,SVC_TEMPENTITY);write_byte(TE_TRACER);
        for(new i=0;i<3;i++)write_coord(floatround(origin[i]));
        for(new i=0;i<3;i++)write_coord(floatround(targetpos[i]));message_end();
        cod_inflict_damage(owner,target,14.0,0.0,DMG_CODSKILL);
    }
    if(is_valid_ent(ent))entity_set_float(ent,EV_FL_nextthink,get_gametime()+0.75);
}
public plugin_end(){for(new id=1;id<=MaxClients;id++)mm_remove_sentry(id);}
