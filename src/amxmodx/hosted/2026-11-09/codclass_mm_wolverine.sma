/* New source adaptation of the user-provided ByM pack's documented abilities.
 * Uses the installed O'Zone/TheDoctor0 API; no compiled ByM code is loaded. */
#include <mm_cod_adapt>
#define PLUGIN_VERSION "1.0.0"
new bool:g_active[33];

#define TASK_RAGE 936100
new Float:g_ready[33],bool:g_rage[33];
new const VIEW[]="models/CoDMod/adapt/v_wolverine.mdl",PLAYER[]="models/CoDMod/adapt/p_wolverine.mdl";
new const SOUNDS[][]={"n21_admin_wolverine/claws_off.wav","n21_admin_wolverine/draw_B.wav","n21_admin_wolverine/slash1_B.wav","n21_admin_wolverine/slash2_B.wav","n21_admin_wolverine/slash3_B.wav"};
public plugin_precache(){precache_model(VIEW);precache_model(PLAYER);for(new i=0;i<sizeof SOUNDS;i++)precache_sound(SOUNDS[i]);}
public plugin_init(){register_plugin("CoD Adapted Wolverine",PLUGIN_VERSION,"ApexiumForge");cod_register_class("Wolverine","Melee kills heal 25 HP. Skill: six-second rage boosts speed, jump and melee damage (20s cooldown).","Super VIP Classes",(1<<CSW_DEAGLE),30,0,5,0,10);}
public cod_class_enabled(id,promotion){g_active[id]=true;g_ready[id]=0.0;g_rage[id]=false;}
public cod_class_disabled(id){mm_end_rage(id);g_active[id]=false;mm_restore_melee(id);}
public client_disconnected(id){remove_task(TASK_RAGE+id);g_active[id]=false;g_rage[id]=false;}
public cod_class_spawned(id,respawn){mm_end_rage(id);g_ready[id]=0.0;}
public cod_class_killed(killer,victim,hit){mm_end_rage(victim);}
public cod_weapon_deploy(id,weapon,ent){if(mm_cod_alive(id) && g_active[id] && weapon==CSW_KNIFE)mm_melee_model(id,VIEW,PLAYER);}
public cod_class_skill_used(id)
{
    if(!mm_cod_alive(id) || !g_active[id])return;
    if(g_ready[id]>get_gametime()){client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Rage ready in ^3%.0f seconds^1.",g_ready[id]-get_gametime());return;}
    g_ready[id]=get_gametime()+20.0;g_rage[id]=true;
    cod_set_user_speed(id,55.0,CLASS);cod_set_user_gravity(id,0.65,CLASS);
    remove_task(TASK_RAGE+id);set_task(6.0,"mm_rage_expired",TASK_RAGE+id);
    client_print_color(id,print_team_blue,"^4[^1CoD^4]^3 Wolverine rage!^1 Six seconds of boosted movement and melee damage.");
}
public mm_rage_expired(task){new id=task-TASK_RAGE;if(mm_get_active_mode()==MM_MODE_COD && is_user_connected(id))mm_end_rage(id);}
mm_end_rage(id)
{
    remove_task(TASK_RAGE+id);
    if(g_rage[id] && is_user_connected(id) && mm_get_active_mode()==MM_MODE_COD)
    {
        cod_set_user_speed(id,0.0,CLASS);
        cod_set_user_gravity(id,1.0,CLASS);
    }
    g_rage[id]=false;
}
public cod_class_damage_attacker(attacker,victim,weapon,&Float:damage,bits,hit){if(mm_cod_alive(attacker) && g_active[attacker] && weapon==CSW_KNIFE && !(bits&DMG_CODSKILL) && (bits&(DMG_BULLET|DMG_SLASH)))damage*=g_rage[attacker]?1.75:1.3;}
public cod_class_kill(killer,victim,hit){if(mm_cod_alive(killer) && g_active[killer] && cod_get_user_weapon(killer)==CSW_KNIFE)cod_add_user_health(killer,25);}
public plugin_end(){for(new id=1;id<=MaxClients;id++)remove_task(TASK_RAGE+id);}
