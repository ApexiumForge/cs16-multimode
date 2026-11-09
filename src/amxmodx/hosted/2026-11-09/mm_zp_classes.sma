#include <amxmodx>
#include <fun>
#include <zombieplague>
#include <mm_mode_api>
new g_leech;
public plugin_init(){register_plugin("Classic ZP Zombie Classes","1.0.1","ApexiumForge");}
public plugin_precache(){
 if(mm_get_active_mode()!=MM_MODE_ZOMBIE)return;
 zp_register_zombie_class("Classic Zombie","Balanced","rev_classic","v_knife_zombie.mdl",1800,190,1.0,1.0);
 zp_register_zombie_class("Raptor Zombie","Fast, low health","rev_classic","v_knife_zombie.mdl",1000,225,1.0,1.4);
 zp_register_zombie_class("Big Zombie","Slow, tough, less knockback","rev_classic","v_knife_zombie.mdl",3000,165,1.0,0.6);
 g_leech=zp_register_zombie_class("Leech Zombie","Gain 200 HP per infection","rev_classic","v_knife_zombie.mdl",1500,190,1.0,1.1);
 zp_register_zombie_class("Tight Zombie","Higher jumps","rev_classic","v_knife_zombie.mdl",1200,200,0.65,1.2);
}
public zp_user_infected_post(id,infector,nemesis){if(mm_get_active_mode()==MM_MODE_ZOMBIE && is_user_alive(infector) && zp_get_user_zombie_class(infector)==g_leech && !zp_get_user_nemesis(infector))set_user_health(infector,min(get_user_health(infector)+200,4000));}
