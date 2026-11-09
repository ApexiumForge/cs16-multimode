#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <reapi>
#include <zombieplague>
#include <mm_mode_api>
#define GOLD_TAG 901727
new g_item,g_armor;
new const VIEW[]="models/zombie_plague/v_golden_ak47.mdl",PLAYER[]="models/zombie_plague/p_golden_ak47.mdl";
public plugin_precache(){if(mm_get_active_mode()==MM_MODE_ZOMBIE){precache_model(VIEW);precache_model(PLAYER);}}
public plugin_init(){
 register_plugin("Classic ZP Golden AK / Armor","1.0.0","ApexiumForge");
 if(mm_get_active_mode()!=MM_MODE_ZOMBIE)return;
 g_item=zp_register_extra_item("Golden AK47 (+20% damage)",30,ZP_TEAM_HUMAN);
 g_armor=zp_register_extra_item("Anti-infection armor (+50)",15,ZP_TEAM_HUMAN);
 RegisterHam(Ham_Item_Deploy,"weapon_ak47","mm_deploy",1);RegisterHam(Ham_TakeDamage,"player","mm_damage");
 register_forward(FM_UpdateClientData,"mm_model",1);
}
public zp_extra_item_selected(id,item){
 if(item!=g_item && item!=g_armor)return PLUGIN_CONTINUE;
 if(mm_get_active_mode()!=MM_MODE_ZOMBIE || !is_user_alive(id) || zp_get_user_zombie(id))return ZP_PLUGIN_HANDLED;
 if(item==g_armor){new CsArmorType:type;new armor=cs_get_user_armor(id,type);if(armor>=100)return ZP_PLUGIN_HANDLED;cs_set_user_armor(id,min(100,armor+50),CS_ARMOR_KEVLAR);return PLUGIN_CONTINUE;}
 if(item!=g_item)return PLUGIN_CONTINUE;
 new weapon=rg_find_weapon_bpack_by_name(id,"weapon_ak47");
 if(!is_nullent(weapon) && pev(weapon,pev_iuser4)==GOLD_TAG)return ZP_PLUGIN_HANDLED;
 if(is_nullent(weapon))weapon=rg_give_item(id,"weapon_ak47",GT_APPEND);
 if(is_nullent(weapon))return ZP_PLUGIN_HANDLED;
 set_pev(weapon,pev_iuser4,GOLD_TAG);cs_set_user_bpammo(id,CSW_AK47,90);
 engclient_cmd(id,"weapon_ak47");mm_deploy(weapon);
 client_print_color(id,print_team_blue,"^4[^1ZP^4]^1 Purchased ^3Golden AK47^1: ^3+20%%^1 damage.");return PLUGIN_CONTINUE;
}
public mm_deploy(weapon)
{
 new id=get_member(weapon,m_pPlayer);
 if(is_user_alive(id) && !zp_get_user_zombie(id) && pev(weapon,pev_iuser4)==GOLD_TAG){set_pev(id,pev_viewmodel2,VIEW);set_pev(id,pev_weaponmodel2,PLAYER);}
 return HAM_IGNORED;
}
public mm_model(id,sendweapons,cd)
{
 if(mm_get_active_mode()==MM_MODE_ZOMBIE && is_user_alive(id) && !zp_get_user_zombie(id))
 {
  new weapon=get_member(id,m_pActiveItem);
  if(!is_nullent(weapon) && get_member(weapon,m_iId)==WEAPON_AK47 && pev(weapon,pev_iuser4)==GOLD_TAG){set_pev(id,pev_viewmodel2,VIEW);set_pev(id,pev_weaponmodel2,PLAYER);}
 }
 return FMRES_IGNORED;
}
public mm_damage(victim,inflictor,attacker,Float:damage,bits){
 if(mm_get_active_mode()!=MM_MODE_ZOMBIE || attacker<1 || attacker>MaxClients || inflictor!=attacker || !is_user_alive(attacker) || !zp_get_user_zombie(victim) || zp_get_user_zombie(attacker) || !(bits&DMG_BULLET))return HAM_IGNORED;
 new weapon=get_member(attacker,m_pActiveItem);
 if(!is_nullent(weapon) && get_member(weapon,m_iId)==WEAPON_AK47 && pev(weapon,pev_iuser4)==GOLD_TAG)SetHamParamFloat(4,damage*1.2);
 return HAM_IGNORED;
}
