// Expert perk adaptation: retain the class loadout and add its expert weapon.
#include <amxmodx>
#include <cod>
#include <mm_mode_api>
#define PLUGIN_VERSION "1.1.0"
public plugin_init(){register_plugin("CoD Item AK47 Expert",PLUGIN_VERSION,"ApexiumForge");cod_register_item("AK47 Expert","Receive AK47; 12% instant-kill chance on a hit. SWAT Shield counters this ability.");}
public cod_item_enabled(id,value){cod_give_weapon(id,CSW_AK47,1);}
public cod_item_spawned(id,respawn){cod_give_weapon(id,CSW_AK47,1);}
public cod_item_disabled(id){cod_take_weapon(id,CSW_AK47);}
public cod_item_damage_attacker(attacker,victim,weapon,&Float:damage,bits,hit)
{
    if(mm_get_active_mode()!=MM_MODE_COD || !is_user_alive(attacker) || !is_user_alive(victim))return;
    if(weapon==CSW_AK47 && (bits&DMG_BULLET) && !(bits&DMG_CODSKILL) && random_num(1,100)<=12)damage=cod_kill_player(attacker,victim,bits);
}
