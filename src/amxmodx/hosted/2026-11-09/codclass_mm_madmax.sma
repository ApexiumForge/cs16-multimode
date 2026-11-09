/* New source adaptation of the user-provided ByM pack's documented abilities.
 * Uses the installed O'Zone/TheDoctor0 API; no compiled ByM code is loaded. */
#include <mm_cod_adapt>
#define PLUGIN_VERSION "1.0.0"
new bool:g_active[33];

new Float:g_ready[33];
public plugin_init(){register_forward(FM_CmdStart,"mm_jet_cmd",1);register_plugin("CoD Adapted Mad Max",PLUGIN_VERSION,"ApexiumForge");cod_register_class("Mad Max","Jetpack pulse: press CTRL + SPACE. Four-second cooldown; one bonus air jump.","Super VIP Classes",(1<<CSW_M3)|(1<<CSW_USP),20,0,5,5,10);}
public cod_class_enabled(id,promotion){g_active[id]=true;g_ready[id]=0.0;cod_set_user_multijumps(id,1,CLASS);}
public cod_class_disabled(id){g_active[id]=false;}
public client_disconnected(id){g_active[id]=false;}
public cod_class_spawned(id,respawn){g_ready[id]=0.0;}
public mm_jet_cmd(id,uc,seed){new buttons=get_uc(uc,UC_Buttons),oldbuttons=pev(id,pev_oldbuttons);new itemName[32];if(mm_cod_alive(id))cod_get_user_item_name(id,itemName,charsmax(itemName));if(mm_cod_alive(id) && g_active[id] && !equal(itemName,"Jetpack") && !equal(itemName,"Super Jetpack"))mm_jet_pulse(id,buttons,oldbuttons,g_ready[id],4.0);}
