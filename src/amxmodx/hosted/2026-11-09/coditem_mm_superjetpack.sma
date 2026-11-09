#include <mm_cod_adapt>
new bool:g_active[33];new Float:g_ready[33];
public plugin_init(){register_forward(FM_CmdStart,"mm_jet_cmd",1);register_plugin("CoD Item Super Jetpack","1.3.0","ApexiumForge");cod_register_item("Super Jetpack","On the ground, hold CTRL and press SPACE for a stronger, higher and longer jet jump. Six-second cooldown.");}
public cod_item_enabled(id,value){g_active[id]=true;g_ready[id]=0.0;}
public cod_item_disabled(id){g_active[id]=false;}
public client_connect(id){g_active[id]=false;g_ready[id]=0.0;}
public client_disconnected(id){g_active[id]=false;g_ready[id]=0.0;}
public cod_item_spawned(id,respawn){g_ready[id]=0.0;}
public mm_jet_cmd(id,uc,seed){if(mm_cod_alive(id) && g_active[id] && (pev(id,pev_flags)&FL_ONGROUND))mm_jet_pulse(id,get_uc(uc,UC_Buttons),pev(id,pev_oldbuttons),g_ready[id],6.0,495.0,690.0,900.0,true);}
