#include <amxmodx>
#include <cod>
#include <mm_mode_api>
#define PLUGIN_VERSION "1.0.0"
new bool:g_active[33];
public plugin_init(){register_plugin("CoD Adapted SWAT",PLUGIN_VERSION,"ApexiumForge");cod_register_class("SWAT","Built-in SWAT Shield blocks lethal effects and enemy abilities. M4A1 deals 20% extra damage.","Super VIP Classes",(1<<CSW_M4A1)|(1<<CSW_USP),20,0,0,10,0);}
public cod_class_enabled(id,promotion){g_active[id]=true;cod_set_user_resistance(id,true,CLASS);}
public cod_class_disabled(id){g_active[id]=false;}
public client_disconnected(id){g_active[id]=false;}
public cod_class_damage_attacker(attacker,victim,weapon,&Float:damage,bits,hit){if(mm_get_active_mode()==MM_MODE_COD && g_active[attacker] && weapon==CSW_M4A1 && bits&DMG_BULLET && !(bits&DMG_CODSKILL))damage*=1.2;}
