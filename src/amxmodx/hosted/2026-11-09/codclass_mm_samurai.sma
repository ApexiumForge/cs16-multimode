/* New source adaptation of the user-provided ByM pack's documented abilities.
 * Uses the installed O'Zone/TheDoctor0 API; no compiled ByM code is loaded. */
#include <mm_cod_adapt>
#define PLUGIN_VERSION "1.2.1"
new bool:g_active[33];

new const VIEW[]="models/CoDMod/adapt/v_katana.mdl",PLAYER[]="models/CoDMod/adapt/p_katana.mdl";
public plugin_precache(){precache_model(VIEW);precache_model(PLAYER);precache_sound("weapons/katanad_draw.wav");}
public plugin_init(){register_plugin("CoD Adapted Ninja",PLUGIN_VERSION,"ApexiumForge");cod_register_class("Ninja","Invisible with the katana. Katana hits instantly kill unless shielded. Hold E to cling; WASD climbs without a time limit.","Super VIP Classes",(1<<CSW_FIVESEVEN),20,0,0,10,15);}
public cod_class_enabled(id,promotion)
{
    g_active[id] = true;
    cod_set_user_render(id, 0, CLASS, RENDER_ALWAYS, 1 << CSW_KNIFE);
}
public cod_class_disabled(id){g_active[id]=false;mm_restore_melee(id);}
public client_disconnected(id){g_active[id]=false;}
public cod_class_spawned(id,respawn){}
public cod_weapon_deploy(id,weapon,ent){if(mm_cod_alive(id) && g_active[id] && weapon==CSW_KNIFE)mm_melee_model(id,VIEW,PLAYER);}
public cod_class_damage_attacker(attacker,victim,weapon,&Float:damage,bits,hit){if(mm_cod_alive(attacker) && g_active[attacker] && weapon==CSW_KNIFE && !(bits&DMG_CODSKILL) && (bits&(DMG_BULLET|DMG_SLASH)))damage=cod_kill_player(attacker,victim,bits);}
