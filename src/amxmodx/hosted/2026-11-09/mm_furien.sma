#include <amxmodx>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <mm_mode_api>

#define TASK_LOADOUT 973000
const Float:FURIEN_FADE_TIME = 0.45
const Float:FURIEN_SWAP_WINDOW = 3.0
const FURIEN_SPAWN_HP = 125
const FURIEN_MAX_HP = 150
const HEALTH_PURCHASE_HP = 25
const TEAM_AUTO_SELECT_SLOT = 5
new const PLUGIN_VERSION[] = "0.5.7"
new const SOUND_HUNT[] = "multimode/furien/fmu_heartbeat.wav"
new const SOUND_SWAP[] = "weapons/mastercombat_draw.wav"
new const NORMAL_KNIFE[]="models/multimode/furien/v_normal.mdl"
new const SUPER_KNIFE[]="models/multimode/furien/v_super.mdl"
new Float:g_detach_until[33]
new bool:g_latched[33]
new bool:g_superknife[33]
new g_hp_cost,g_he_cost;
new Float:g_hud_next[33];
new bool:g_plant_announced;
new g_health_buys[33],g_grenade_buys[33];
new g_knife_cost, g_knife_damage, g_knife_callback, g_health_callback
new const FURIEN_MODEL[]="mm_furien_altair"
new g_air_jumps[33], g_previous_buttons[33]
new bool:g_movement_input[33]
new bool:g_model_owned[33]
new Float:g_old_maxspeed
new bool:g_active, bool:g_fading[33]
new Float:g_swap_until
new TeamName:g_round_reward_team[33]
new Float:g_fade_started[33]
new g_fade_alpha[33], g_primary[33], g_speed, g_gravity
new g_pistol[33];
new const PRIMARY[][]={"weapon_m4a1","weapon_ak47","weapon_aug","weapon_sg552","weapon_galil","weapon_famas","weapon_awp","weapon_scout","weapon_g3sg1","weapon_sg550","weapon_mp5navy","weapon_p90","weapon_ump45","weapon_mac10","weapon_tmp","weapon_m3","weapon_xm1014","weapon_m249"};
new const PRIMARY_NAME[][]={"M4A1","AK-47","AUG","SG 552","Galil","FAMAS","AWP","Scout","G3SG1","SG 550","MP5 Navy","P90","UMP45","MAC-10","TMP","M3","XM1014","M249"};
new const PRIMARY_ID[]={22,28,8,27,14,15,18,3,24,13,19,30,12,7,23,21,5,20};
new const PRIMARY_AMMO[]={90,90,90,90,90,90,30,90,90,90,120,100,100,100,120,32,32,200};
new const PISTOL[][]={"weapon_usp","weapon_glock18","weapon_deagle","weapon_p228","weapon_fiveseven","weapon_elite"};
new const PISTOL_NAME[][]={"USP","Glock 18","Desert Eagle","P228","Five-Seven","Dual Elites"};
new const PISTOL_ID[]={16,17,26,1,11,10};
new const PISTOL_AMMO[]={100,120,35,52,100,120};

public plugin_precache()
{
 if(mm_get_active_mode()!=MM_MODE_FURIEN)return;
 precache_model("models/player/mm_furien_altair/mm_furien_altair.mdl");
 precache_model(NORMAL_KNIFE);precache_model(SUPER_KNIFE);
 precache_model("models/p_knife.mdl");
 precache_sound(SOUND_HUNT);
 precache_sound(SOUND_SWAP);
}
public plugin_init()
{
 register_plugin("Multi-Mode Furien", PLUGIN_VERSION, "ApexiumForge")
 g_hp_cost=register_cvar("mm_furien_health_cost","2500");
 g_he_cost=register_cvar("mm_furien_grenade_cost","2000");

 g_speed=register_cvar("mm_furien_speed","810")
 g_gravity=register_cvar("mm_furien_gravity","0.4")
 g_knife_cost=register_cvar("mm_furien_superknife_cost","10000")
 g_knife_damage=register_cvar("mm_furien_superknife_damage","2.0")
 g_knife_callback=menu_makecallback("knife_availability")
 g_health_callback=menu_makecallback("health_availability")
 register_clcmd("chooseteam","block_team_menu")
 register_clcmd("say","shop_chat")
 register_clcmd("say_team","shop_chat")
 register_clcmd("mm_furien_shop","command_shop")
 register_clcmd("say /shop","command_shop",0,"- Furien health, grenade and knife shop")
 register_clcmd("say_team /shop","command_shop",0,"- Furien shop")
 register_clcmd("say /knife","command_shop")
 register_clcmd("say_team /knife","command_shop")
 register_clcmd("say /furien","command_menu")
 register_clcmd("say_team /furien","command_menu")
 register_srvcmd("mm_furien_status","command_status")
 new const blocked[][]={"buy","buyequip","autobuy","rebuy","cl_autobuy","cl_rebuy","vest","vesthelm","shield"}
 for(new i=0;i<sizeof blocked;i++)register_clcmd(blocked[i],"block_buy")
 RegisterHam(Ham_Weapon_PrimaryAttack,"weapon_c4","plant_pre",0)
 RegisterHam(Ham_Weapon_PrimaryAttack,"weapon_knife","latched_attack",0)
 RegisterHam(Ham_Weapon_SecondaryAttack,"weapon_knife","latched_attack",0)
 RegisterHam(Ham_Item_Deploy,"weapon_knife","knife_deploy_post",1)
 register_forward(FM_UpdateClientData,"clientdata_post",1)
 RegisterHam(Ham_Spawn,"player","spawn_post",1)
 RegisterHam(Ham_Killed,"player","killed_post",1)
 RegisterHam(Ham_TakeDamage,"player","damage_pre",0)
 RegisterHam(Ham_AddPlayerItem,"player","add_item_pre",0)
 RegisterHam(Ham_Touch,"weaponbox","pickup_pre",0)
 RegisterHam(Ham_Touch,"armoury_entity","pickup_pre",0)
 RegisterHam(Ham_Touch,"weapon_shield","pickup_pre",0)
 RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed,"speed_post",true)
 RegisterHookChain(RG_HandleMenu_ChooseTeam,"choose_team_pre")
 register_forward(FM_PlayerPreThink,"player_think",1)
 register_forward(FM_CmdStart,"command_start")
 register_event("TeamInfo","team_changed","a")
 register_event("HLTV","round_start","a","1=0","2=0")
 RegisterHookChain(RG_RoundEnd,"round_end_pre");
 RegisterHookChain(RG_RoundEnd,"round_end_post",true);
 RegisterHookChain(RG_CBasePlayer_AddAccount,"round_reward_pre");
 RegisterHookChain(RG_CSGameRules_RestartRound,"restart_round_post",true);
 RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd,"hunt_start_post",true);
}
public plugin_cfg()
{
 server_cmd("exec addons/amxmodx/configs/mm_furien.cfg");server_exec()
 g_active=mm_get_active_mode()==MM_MODE_FURIEN
 if(g_active){g_old_maxspeed=get_cvar_float("sv_maxspeed");set_cvar_float("sv_maxspeed",floatmax(g_old_maxspeed,get_pcvar_float(g_speed)));}
}
bool:is_furien(id){return g_active && id>=1 && id<=MaxClients && is_user_connected(id) && is_user_alive(id) && cs_get_user_team(id)==CS_TEAM_T;}
public block_buy(id){return is_furien(id)?PLUGIN_HANDLED:PLUGIN_CONTINUE;}
public block_team_menu(id)
{
 if(!g_active || !is_user_connected(id))return PLUGIN_CONTINUE;
 return cs_get_user_team(id)==CS_TEAM_UNASSIGNED?PLUGIN_CONTINUE:PLUGIN_HANDLED;
}
public choose_team_pre(id,slot)
{
 if(!g_active || !is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))return HC_CONTINUE;
 if(get_member_game(m_bSkipShowMenu))return HC_CONTINUE;
 // If automatic joining failed, allow the unassigned player to retry Auto-Select.
 if(cs_get_user_team(id)==CS_TEAM_UNASSIGNED && slot==TEAM_AUTO_SELECT_SLOT)return HC_CONTINUE;
 SetHookChainReturn(ATYPE_BOOL,false);
 return HC_SUPERCEDE;
}
public add_item_pre(id,item)
{
 if(!is_furien(id) || !pev_valid(item))return HAM_IGNORED
 new WeaponIdType:weapon=WeaponIdType:get_member(item,m_iId)
 if(weapon==WEAPON_KNIFE || weapon==WEAPON_C4 || weapon==WEAPON_HEGRENADE || weapon==WEAPON_FLASHBANG || weapon==WEAPON_SMOKEGRENADE)return HAM_IGNORED
 SetHamReturnInteger(0);return HAM_SUPERCEDE
}
public pickup_pre(entity,id)
{
 if(!is_furien(id))return HAM_IGNORED;
 new classname[24];pev(entity,pev_classname,classname,charsmax(classname));
 if(equal(classname,"weaponbox"))
 {
  new bomb=get_member(entity,m_WeaponBox_rgpPlayerItems,5);
  if(!is_nullent(bomb) && WeaponIdType:get_member(bomb,m_iId)==WEAPON_C4)return HAM_IGNORED;
 }
 return HAM_SUPERCEDE;
}
public client_putinserver(id){g_latched[id]=false;g_primary[id]=0;g_pistol[id]=0;g_fading[id]=false;g_superknife[id]=false;g_model_owned[id]=false;g_health_buys[id]=0;g_grenade_buys[id]=0;}
public client_disconnected(id){g_latched[id]=false;remove_task(TASK_LOADOUT+id);g_fading[id]=false;g_model_owned[id]=false;g_superknife[id]=false;g_round_reward_team[id]=TEAM_UNASSIGNED;}
public spawn_post(id)
{
 if(!g_active || !is_user_connected(id) || !is_user_alive(id))return HAM_IGNORED
 apply_role(id)
 set_user_health(id,is_furien(id)?FURIEN_SPAWN_HP:100)
 remove_task(TASK_LOADOUT+id);set_task(0.2,"loadout",TASK_LOADOUT+id)
 return HAM_IGNORED
}
apply_role(id)
{
 new bool:furien=is_furien(id);
 restore_visibility(id);
 if(furien){cs_set_user_model(id,FURIEN_MODEL);g_model_owned[id]=true;}
 else if(g_model_owned[id]){cs_reset_user_model(id);g_model_owned[id]=false;}
 if(!furien)g_superknife[id]=false;
 g_latched[id]=false;
 g_air_jumps[id]=0;
 g_previous_buttons[id]=0;
 g_movement_input[id]=false;
 set_user_gravity(id,furien?get_pcvar_float(g_gravity):1.0);
 set_user_footsteps(id,furien?1:0);
}
public loadout(task)
{
 new id=task-TASK_LOADOUT
 if(!g_active || !is_user_alive(id))return
 if(is_furien(id))
 {
  // Preserve the round's bomb assignment while removing default pistols.
  new bool:bomb=bool:user_has_weapon(id,CSW_C4)
  rg_remove_all_items(id,false)
  rg_give_item(id,"weapon_knife")
  if(bomb){rg_give_item(id,"weapon_c4");cs_set_user_plant(id,1,1);}
  cs_set_user_armor(id,0,CS_ARMOR_NONE)
 }
 else if(cs_get_user_team(id)==CS_TEAM_CT)
 {
  give_human_weapons(id)
  show_weapons(id)
 }
 rg_reset_maxspeed(id)
}
give_human_weapons(id)
{
 if(!g_active || !is_user_alive(id) || cs_get_user_team(id)!=CS_TEAM_CT)return
 rg_remove_items_by_slot(id,PRIMARY_WEAPON_SLOT);rg_remove_items_by_slot(id,PISTOL_SLOT);
 if(!user_has_weapon(id,CSW_KNIFE))rg_give_item(id,"weapon_knife");
 new primary=rg_give_item(id,PRIMARY[g_primary[id]]);
 rg_give_item(id,PISTOL[g_pistol[id]]);
 cs_set_user_bpammo(id,PISTOL_ID[g_pistol[id]],PISTOL_AMMO[g_pistol[id]]);
 cs_set_user_bpammo(id,PRIMARY_ID[g_primary[id]],PRIMARY_AMMO[g_primary[id]]);
 cs_set_user_armor(id,100,CS_ARMOR_VESTHELM)
 if(!is_nullent(primary) && user_has_weapon(id,PRIMARY_ID[g_primary[id]]))
  rg_switch_weapon(id,primary);
 else
  log_amx("Furien CT primary grant failed: player=%d weapon=%s VIP=%d",id,PRIMARY[g_primary[id]],get_member(id,m_bIsVIP));
}
public speed_post(id){if(is_furien(id))set_entvar(id,var_maxspeed,get_pcvar_float(g_speed));}
public command_start(id,uc,seed)
{
 if(!g_active || !is_user_alive(id))return FMRES_IGNORED;
 new buttons=get_uc(uc,UC_Buttons);
 new Float:forward_move, Float:side_move;
 get_uc(uc,UC_ForwardMove,forward_move);
 get_uc(uc,UC_SideMove,side_move);
 g_movement_input[id] = forward_move != 0.0 || side_move != 0.0;
 if(pev(id,pev_flags)&FL_ONGROUND)g_air_jumps[id]=0;
 else if(!g_latched[id] && (buttons&IN_JUMP) && !(g_previous_buttons[id]&IN_JUMP) && g_air_jumps[id]<2 && pev(id,pev_movetype)==MOVETYPE_WALK && pev(id,pev_waterlevel)<2)
 {
  new Float:velocity[3];pev(id,pev_velocity,velocity);
  velocity[2]=floatmax(velocity[2],275.0);set_pev(id,pev_velocity,velocity);g_air_jumps[id]++;
 }
 g_previous_buttons[id]=buttons;
 return FMRES_IGNORED;
}
public damage_pre(victim,inflictor,attacker,Float:damage,bits)
{
 if(g_active && get_gametime()<g_swap_until)return HAM_SUPERCEDE;
 if(g_active && (bits&DMG_FALL))return HAM_SUPERCEDE;
 if(is_furien(attacker) && g_superknife[attacker] && inflictor==attacker && get_user_weapon(attacker)==CSW_KNIFE && victim>=1 && victim<=MaxClients && is_user_connected(victim) && cs_get_user_team(victim)==CS_TEAM_CT)
 {
  SetHamParamFloat(4,damage*floatclamp(get_pcvar_float(g_knife_damage),1.0,5.0));
  return HAM_HANDLED;
 }
 return HAM_IGNORED;
}
public player_think(id)
{
 if (!is_furien(id))
 {
  if (g_active) restore_visibility(id)
  return FMRES_IGNORED
 }

 plant_announcement()
 climb_wall(id)
 new weapon = get_user_weapon(id)
 new bool:using_weapon = (g_previous_buttons[id] & (IN_ATTACK | IN_ATTACK2)) != 0
 new bool:grounded = (pev(id, pev_flags) & FL_ONGROUND) != 0
 new bool:can_hide = (weapon == CSW_KNIFE || weapon == CSW_C4)
  && (g_latched[id] || (grounded && !g_movement_input[id] && !using_weapon))
 if (!can_hide)
 {
  restore_visibility(id)
  return FMRES_IGNORED
 }

 new Float:now = get_gametime()
 if (!g_fading[id])
 {
  g_fading[id] = true
  g_fade_started[id] = now
  g_fade_alpha[id] = 255
 }

 new alpha = max(0, 255 - floatround(255.0 * (now - g_fade_started[id]) / FURIEN_FADE_TIME))
 if (alpha != g_fade_alpha[id])
 {
  set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransTexture, alpha)
  g_fade_alpha[id] = alpha
 }
 return FMRES_IGNORED
}
restore_visibility(id)
{
 if (g_fading[id] && g_fade_alpha[id] < 255 && is_user_connected(id))
  set_user_rendering(id, kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
 g_fading[id] = false
}
public killed_post(id)
{
 g_latched[id]=false;g_superknife[id]=false
 if(g_active){restore_visibility(id);if(is_user_connected(id))set_user_footsteps(id,0);}
 return HAM_IGNORED
}
public round_end_pre(WinStatus:status,ScenarioEventEndRound:event,Float:delay)
{
 if(g_active && status==WINSTATUS_CTS)SetHookChainArg(3,ATYPE_FLOAT,FURIEN_SWAP_WINDOW);
 return HC_CONTINUE;
}
public round_end_post(WinStatus:status,ScenarioEventEndRound:event,Float:delay)
{
 if(!g_active || !GetHookChainReturn(ATYPE_BOOL) || !get_member_game(m_bRoundTerminating))return;
 if(status!=WINSTATUS_CTS || get_gametime()<g_swap_until)return;

 g_swap_until=get_gametime()+FURIEN_SWAP_WINDOW;
 for(new id=1;id<=MaxClients;id++)
  if(is_user_connected(id))g_round_reward_team[id]=TeamName:get_member(id,m_iTeam);

 rg_swap_all_players();
 for(new id=1;id<=MaxClients;id++)
 {
  if(!is_user_alive(id))continue;
  remove_task(TASK_LOADOUT+id);
  apply_role(id);
  rg_remove_all_items(id,false);
  if(is_furien(id))
  {
   rg_give_item(id,"weapon_knife");
   cs_set_user_armor(id,0,CS_ARMOR_NONE);
  }
  else if(cs_get_user_team(id)==CS_TEAM_CT)give_human_weapons(id);
  rg_reset_maxspeed(id);
 }
 play_furien_sound(SOUND_SWAP);
 set_hudmessage(210,140,65,-1.0,0.22,0,0.0,FURIEN_SWAP_WINDOW,0.05,0.2,-1);
 show_hudmessage(0,"Anti-Furiens win!^nTeams switched");
}
public round_reward_pre(id,amount,RewardType:type,bool:track_change)
{
 if(!g_active || type!=RT_ROUND_BONUS)return HC_CONTINUE;
 // The engine credits round cash at restart, when the teams have already switched.
 switch(g_round_reward_team[id])
 {
  case TEAM_CT: SetHookChainArg(2,ATYPE_INTEGER,get_member_game(m_iAccountCT));
  case TEAM_TERRORIST: SetHookChainArg(2,ATYPE_INTEGER,get_member_game(m_iAccountTerrorist));
 }
 return HC_CONTINUE;
}
public hunt_start_post()
{
 if(g_active)play_furien_sound(SOUND_HUNT);
}
public restart_round_post()
{
 if(g_active)arrayset(g_round_reward_team,TEAM_UNASSIGNED,sizeof g_round_reward_team);
}
play_furien_sound(const sample[])
{
 for(new id=1;id<=MaxClients;id++)
  if(is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id))
   rh_emit_sound2(id,id,CHAN_STATIC,sample,0.65,ATTN_NONE,0,PITCH_NORM,SND_EMIT2_NOPAS);
}
public round_start()
{
 if(!g_active)return

 for(new i=1;i<=MaxClients;i++){g_health_buys[i]=0;g_grenade_buys[i]=0;}
 g_plant_announced=false;
 g_swap_until=0.0;
}
public command_menu(id)
{
 if(!g_active){client_print_color(id,print_team_default,"^4[^1Furien^4]^1 This command is available in Furien mode.");return PLUGIN_HANDLED;}
 if(is_furien(id))show_knife_shop(id)
 else if(cs_get_user_team(id)==CS_TEAM_CT && is_user_alive(id))show_weapons(id)
 else client_print_color(id,print_team_red,"^4[^1Furien^4]^1 Fast knife movement, low gravity and silent footsteps. Stand still with your knife or C4 to fade out. Plant the bomb or eliminate CTs.")
 return PLUGIN_HANDLED
}
show_weapons(id)
{
 new menu=menu_create("Anti-Furien: Primary weapon","weapon_selected"),data[8];
 for(new i=0;i<sizeof PRIMARY;i++){num_to_str(i,data,charsmax(data));menu_additem(menu,PRIMARY_NAME[i],data);}
 menu_display(id,menu);
}
public weapon_selected(id,menu,item)
{
 if(item==MENU_EXIT || !g_active || !is_user_alive(id) || cs_get_user_team(id)!=CS_TEAM_CT){menu_destroy(menu);return PLUGIN_HANDLED;}
 new data[8],access,callback;menu_item_getinfo(menu,item,access,data,charsmax(data),_,_,callback);menu_destroy(menu);
 new choice=str_to_num(data);if(choice<0 || choice>=sizeof PRIMARY)return PLUGIN_HANDLED;
 g_primary[id]=choice;
 menu=menu_create("Anti-Furien: Pistol","pistol_selected");
 for(new i=0;i<sizeof PISTOL;i++){num_to_str(i,data,charsmax(data));menu_additem(menu,PISTOL_NAME[i],data);}
 menu_display(id,menu);return PLUGIN_HANDLED;
}
public pistol_selected(id,menu,item)
{
 if(item==MENU_EXIT || !g_active || !is_user_alive(id) || cs_get_user_team(id)!=CS_TEAM_CT){menu_destroy(menu);return PLUGIN_HANDLED;}
 new data[8],access,callback;menu_item_getinfo(menu,item,access,data,charsmax(data),_,_,callback);menu_destroy(menu);
 new choice=str_to_num(data);if(choice<0 || choice>=sizeof PISTOL)return PLUGIN_HANDLED;
 g_pistol[id]=choice;give_human_weapons(id);return PLUGIN_HANDLED;
}

cleanup()
{
 if(!g_active)return
 g_active=false
 for(new id=1;id<=MaxClients;id++)
 {
  remove_task(TASK_LOADOUT+id)
  g_round_reward_team[id]=TEAM_UNASSIGNED;
  g_latched[id]=false;g_superknife[id]=false
  if(!is_user_connected(id))continue
  restore_visibility(id);set_user_footsteps(id,0);set_user_gravity(id,1.0)
  if(g_model_owned[id]){cs_reset_user_model(id);g_model_owned[id]=false;}
  if(is_user_alive(id))rg_reset_maxspeed(id)
 }
 set_cvar_float("sv_maxspeed",g_old_maxspeed)
 g_swap_until=0.0;
}
public mm_mode_transition_started(oldmode,newmode){if(MmMode:oldmode==MM_MODE_FURIEN)cleanup();}
public plugin_end(){cleanup();}
public command_status()
{
 server_print("[Furien] version=%s active=%d speed=%.0f gravity=%.2f swap_active=%d fade_ms=%d",PLUGIN_VERSION,g_active,get_pcvar_float(g_speed),get_pcvar_float(g_gravity),get_gametime()<g_swap_until,floatround(FURIEN_FADE_TIME*1000.0));
 server_print("[Furien] auto_join=%d auto_balance=%d team_limit=%d spawn_hp=%d max_hp=%d",get_cvar_num("mp_auto_join_team"),get_cvar_num("mp_autoteambalance"),get_cvar_num("mp_limitteams"),FURIEN_SPAWN_HP,FURIEN_MAX_HP);
}

public knife_deploy_post(weapon)
{
 if(!g_active || !pev_valid(weapon))return HAM_IGNORED;
 new id=get_member(weapon,m_pPlayer);
 if(is_furien(id))apply_knife(id);
 return HAM_IGNORED;
}
apply_knife(id)
{
 set_pev(id,pev_viewmodel2,g_superknife[id]?SUPER_KNIFE:NORMAL_KNIFE);
 set_pev(id,pev_weaponmodel2,"models/p_knife.mdl");
}
public clientdata_post(id,sendweapons,cd)
{
 if(is_furien(id))
 {
  new weapon=get_member(id,m_pActiveItem);
  if(!is_nullent(weapon) && WeaponIdType:get_member(weapon,m_iId)==WEAPON_KNIFE)apply_knife(id);
 }
 return FMRES_IGNORED;
}
public command_shop(id)
{
 if(!g_active || !is_user_connected(id))return PLUGIN_CONTINUE;
 if(!is_user_alive(id)){client_print_color(id,print_team_default,"^4[^1Furien^4]^1 You must be alive to use the shop.");return PLUGIN_HANDLED;}
 show_knife_shop(id);return PLUGIN_HANDLED;
}
show_knife_shop(id)
{
 new menu=menu_create("Furien Shop","knife_selected"),label[96];

 if(g_superknife[id])copy(label,charsmax(label),"Super Knife - ACTIVE");
 else formatex(label,charsmax(label),"Super Knife - $%d | %.1fx damage",clamp(get_pcvar_num(g_knife_cost),0,16000),floatclamp(get_pcvar_float(g_knife_damage),1.0,5.0));
 menu_additem(menu,label,"super",0,g_knife_callback);
 formatex(label,charsmax(label),"+%d HP (max %d, %d/round) - $%d",HEALTH_PURCHASE_HP,health_cap(id),health_limit(id),get_pcvar_num(g_hp_cost));
 menu_additem(menu,label,"health",0,g_health_callback);
 formatex(label,charsmax(label),"HE grenade (twice/round) - $%d",get_pcvar_num(g_he_cost));
 menu_additem(menu,label,"grenade");
 menu_display(id,menu);
}
public knife_availability(id,menu,item)
{
 return is_furien(id) && !g_superknife[id] && cs_get_user_money(id)>=clamp(get_pcvar_num(g_knife_cost),0,16000)?ITEM_ENABLED:ITEM_DISABLED;
}
health_cap(id){return is_furien(id)?FURIEN_MAX_HP:150;}
health_limit(id){return is_furien(id)?1:2;}
bool:can_buy_health(id){return get_user_health(id)<health_cap(id) && g_health_buys[id]<health_limit(id);}
public health_availability(id,menu,item){return can_buy_health(id)?ITEM_ENABLED:ITEM_DISABLED;}
public knife_selected(id,menu,item)
{
 new data[12],access,callback;
 if(item!=MENU_EXIT)menu_item_getinfo(menu,item,access,data,charsmax(data),_,_,callback);
 menu_destroy(menu);
 if(item==MENU_EXIT || !g_active || !is_user_alive(id))return PLUGIN_HANDLED;
 if(equal(data,"health") || equal(data,"grenade"))
 {
  new bool:health=bool:equal(data,"health");
  new cost=clamp(get_pcvar_num(health?g_hp_cost:g_he_cost),0,16000);
  if((health && !can_buy_health(id)) || (!health && (user_has_weapon(id,CSW_HEGRENADE) || g_grenade_buys[id]>=2)))
   client_print_color(id,print_team_default,"^4[^1Furien^4]^1 Item unavailable: already full or round limit reached.");
  else if(cs_get_user_money(id)<cost)client_print_color(id,print_team_default,"^4[^1Furien^4]^1 You need ^3$%d^1.",cost);
  else {
   if(health){set_user_health(id,min(health_cap(id),get_user_health(id)+HEALTH_PURCHASE_HP));g_health_buys[id]++;}
   else {if(is_nullent(rg_give_item(id,"weapon_hegrenade")))return PLUGIN_HANDLED;g_grenade_buys[id]++;}
   cs_set_user_money(id,cs_get_user_money(id)-cost,1);
   client_print_color(id,print_team_red,"^4[^1Furien^4]^1 Bought ^3%s^1 for ^3$%d^1.",health?"25 HP":"HE grenade",cost);
  }
  show_knife_shop(id);return PLUGIN_HANDLED;
 }
 if(equal(data,"normal"))
 {
  if(g_superknife[id])client_print_color(id,print_team_default,"^4[^1Furien^4]^1 Super Knife stays active until death or switching to CT.");
  return PLUGIN_HANDLED;
 }
 if(!equal(data,"super") || !is_furien(id) || g_superknife[id])return PLUGIN_HANDLED;
 new cost=clamp(get_pcvar_num(g_knife_cost),0,16000),money=cs_get_user_money(id);
 if(money<cost){client_print_color(id,print_team_default,"^4[^1Furien^4]^1 You need ^3$%d^1 for Super Knife.",cost);return PLUGIN_HANDLED;}
 cs_set_user_money(id,money-cost,1);g_superknife[id]=true;
 if(get_user_weapon(id)==CSW_KNIFE)
 {
  new weapon=get_member(id,m_pActiveItem);
  if(!is_nullent(weapon))ExecuteHamB(Ham_Item_Deploy,weapon);
 }
 client_print_color(id,print_team_red,"^4[^1Furien^4]^1 Bought ^3Super Knife^1: ^3%.1fx^1 knife damage until death or switching to CT.",floatclamp(get_pcvar_float(g_knife_damage),1.0,5.0));
 return PLUGIN_HANDLED;
}

public team_changed()
{
 if(!g_active)return;
 new id=read_data(1),team[16];
 if(id<1 || id>MaxClients)return;
 read_data(2,team,charsmax(team));
 if(!equal(team,"TERRORIST"))g_superknife[id]=false;
}

plant_wait()
{
 if(get_member_game(m_bFreezePeriod))return max(0,get_member_game(m_iRoundTime)-60);
 new Float:elapsed=get_gametime()-Float:get_member_game(m_fRoundStartTime);
 return max(0,floatround(float(get_member_game(m_iRoundTime))-elapsed-60.0,floatround_ceil));
}
plant_hud(id)
{
 if(!is_furien(id) || !user_has_weapon(id,CSW_C4) || get_gametime()<g_hud_next[id])return;
 new wait=plant_wait();if(wait<=0)return;
 g_hud_next[id]=get_gametime()+0.5;
 set_hudmessage(255,180,30,-1.0,0.72,0,0.0,1.5,0.0,0.15,3);
 show_hudmessage(id,"Can't plant for %d sec",wait);
}
public plant_pre(weapon)
{
 if(!g_active || !pev_valid(weapon))return HAM_IGNORED;
 new id=get_member(weapon,m_pPlayer);
 if(!is_furien(id) || plant_wait()<=0)return HAM_IGNORED;
 plant_hud(id);return HAM_SUPERCEDE;
}
// Hold E with knife. Project camera-relative movement onto nearby world walls.
climb_wall(id)
{
 g_latched[id]=false;
 if(get_gametime()<g_detach_until[id])return;
 if(!(pev(id,pev_button)&IN_USE) || get_user_weapon(id)!=CSW_KNIFE || get_member_game(m_bFreezePeriod) || pev(id,pev_movetype)!=MOVETYPE_WALK || pev(id,pev_waterlevel)>1)return;
 new Float:origin[3],Float:end[3],Float:normal[3],Float:angles[3],Float:ahead[3],Float:right[3];
 pev(id,pev_origin,origin);pev(id,pev_v_angle,angles);engfunc(EngFunc_MakeVectors,angles);global_get(glb_v_forward,ahead);global_get(glb_v_right,right);
 new tr=create_tr2();new bool:found=false;
 for(new i=0;i<8;i++){
  new Float:a=float(i)*45.0;
  end[0]=origin[0]+floatcos(a,degrees)*28.0;end[1]=origin[1]+floatsin(a,degrees)*28.0;end[2]=origin[2];
  engfunc(EngFunc_TraceLine,origin,end,IGNORE_MONSTERS,id,tr);
  new Float:f;get_tr2(tr,TR_flFraction,f);
  if(f<1.0 && (get_tr2(tr,TR_pHit)<=0 || get_tr2(tr,TR_pHit)>MaxClients)){get_tr2(tr,TR_vecPlaneNormal,normal);if(floatabs(normal[2])<0.2){found=true;break;}}
 }
 // At corners, looking upward selects the ceiling; level/down selects the wall.
 end[0]=origin[0];end[1]=origin[1];end[2]=origin[2]+((pev(id,pev_flags)&FL_DUCKING)?26.0:44.0);
 engfunc(EngFunc_TraceLine,origin,end,IGNORE_MONSTERS,id,tr);
 new bool:ceilingReachable=false;
 new Float:ceilingFraction;get_tr2(tr,TR_flFraction,ceilingFraction);
 if(ceilingFraction<1.0 && (get_tr2(tr,TR_pHit)<=0 || get_tr2(tr,TR_pHit)>MaxClients)){
  new Float:ceilingNormal[3];get_tr2(tr,TR_vecPlaneNormal,ceilingNormal);
  if(ceilingNormal[2]< -0.7){
   ceilingReachable=true;
   if(!found || angles[0]< -20.0){for(new j=0;j<3;j++)normal[j]=ceilingNormal[j];found=true;}
  }
 }
 free_tr2(tr);if(!found)return;
 g_latched[id]=true;
 new buttons=pev(id,pev_button),Float:move[3],Float:velocity[3];
 new Float:f=((buttons&IN_FORWARD)?1.0:0.0)-((buttons&IN_BACK)?1.0:0.0);
 new Float:r=((buttons&IN_MOVERIGHT)?1.0:0.0)-((buttons&IN_MOVELEFT)?1.0:0.0);
 for(new i=0;i<3;i++)move[i]=ahead[i]*f+right[i]*r;
 new Float:dot=move[0]*normal[0]+move[1]*normal[1]+move[2]*normal[2];
 for(new i=0;i<3;i++)move[i]-=normal[i]*dot;
 new Float:length=vector_length(move);
 if(length<0.2 && f!=0.0 && floatabs(normal[2])<0.2){move[0]=0.0;move[1]=0.0;move[2]=ceilingReachable?-f:f;length=floatabs(f);}
 if(length>0.01)for(new i=0;i<3;i++)move[i]=move[i]/length*240.0;
 // Gentle inward pressure maintains contact; compensate gravity without changing ownership.
 for(new i=0;i<3;i++)velocity[i]=move[i]-normal[i]*25.0;
 velocity[2]+=get_cvar_float("sv_gravity")*get_pcvar_float(g_gravity)*0.5*global_get_frame_time();
 if((buttons&IN_JUMP) && !(pev(id,pev_oldbuttons)&IN_JUMP)){g_latched[id]=false;g_detach_until[id]=get_gametime()+0.35;velocity[0]=normal[0]*260.0;velocity[1]=normal[1]*260.0;velocity[2]=normal[2]< -0.7?-200.0:290.0;}
 set_pev(id,pev_velocity,velocity);
}
Float:global_get_frame_time(){new Float:t;global_get(glb_frametime,t);return t;}

public shop_chat(id)
{
 if(!g_active)return PLUGIN_CONTINUE;
 new text[64];read_args(text,charsmax(text));remove_quotes(text);trim(text);
 if(!equali(text,"/shop"))return PLUGIN_CONTINUE;
 return command_shop(id);
}
plant_announcement()
{
 if(g_plant_announced || get_member_game(m_bFreezePeriod) || plant_wait()>0)return;
 g_plant_announced=true;
 set_hudmessage(80,255,80,-1.0,0.18,0,0.0,4.0,0.1,0.3,4);
 show_hudmessage(0,"Furiens can now plant the bomb!");
}

public latched_attack(weapon)
{
 if(!g_active || !pev_valid(weapon))return HAM_IGNORED;
 new id=get_member(weapon,m_pPlayer);
 if(is_furien(id) && g_latched[id])return HAM_SUPERCEDE;
 return HAM_IGNORED;
}
