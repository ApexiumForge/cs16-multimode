/* New source adaptation of the user-provided ByM pack's documented abilities.
 * Uses the installed O'Zone/TheDoctor0 API; no compiled ByM code is loaded. */
#include <mm_cod_adapt>
#define PLUGIN_VERSION "1.1.0"
new bool:g_active[33];
public plugin_init(){register_plugin("CoD Adapted Wall Grip",PLUGIN_VERSION,"ApexiumForge");cod_register_item("Wall Grip","Hold E with knife to cling to walls. Use WASD to move; no time limit. Space jumps away.");}
public cod_item_enabled(id,value){g_active[id]=true;}
public cod_item_disabled(id){g_active[id]=false;}
public client_disconnected(id){g_active[id]=false;}
public cod_item_spawned(id,respawn){}
