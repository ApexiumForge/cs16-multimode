/* New source adaptation of the user-provided ByM pack's documented abilities.
 * Uses the installed O'Zone/TheDoctor0 API; no compiled ByM code is loaded. */
#include <mm_cod_adapt>
#define PLUGIN_VERSION "1.1.0"
new bool:g_active[33];

public plugin_init(){register_plugin("CoD Adapted Phantom",PLUGIN_VERSION,"ApexiumForge");cod_register_class("Phantom","Knife concealment and silent steps. Hold E to cling; WASD moves along walls without a time limit.","VIP Classes",(1<<CSW_MP5NAVY)|(1<<CSW_USP),10,0,0,0,15);}
public cod_class_enabled(id,promotion){g_active[id]=true;cod_set_user_footsteps(id,true,CLASS);cod_set_user_render(id,60,CLASS,RENDER_ALWAYS,1<<CSW_KNIFE);}
public cod_class_disabled(id){g_active[id]=false;}
public client_disconnected(id){g_active[id]=false;}
public cod_class_spawned(id,respawn){}
