/* Independent CoD-style RPG team deathmatch for the multi-mode lifecycle.
 * Research/attribution and differences from standalone CoD:MW4: docs/COD.md. */
#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <nvault>
#include <mm_mode_api>
#include <mm_voting_api>
#define TASK_TICK 907000
#define TASK_SPAWN 907100
#define TASK_GEAR 907200
#define TASK_RESTART 907300
#define TASK_PROMPT 907400
#define CLASS_NINJA 8
#define CLASS_JUMPER 9
#define CLASS_SAPPER 10
#define CLASS_BOMBER 11
#define CLASS_RAMBO 12
#define CLASS_COUNT 13
#define STAT_COUNT 4
#define ITEM_COUNT 10
#define MAX_LEVEL 100
#define STAT_CAP 50
#define MAX_XP 980100
#define MAX_CREDITS 100000
new const PLUGIN_NAME[]="Multi-Mode CoD RPG"
new const PLUGIN_VERSION[]="1.1.0"
new const PLUGIN_AUTHOR[]="Torbeshi"
new const CLASSES[][]=
{
    "Assault",
    "Support",
    "Scout",
    "Sniper",
    "Medic",
    "Engineer",
    "Commando",
    "Runner",
    "Ninja",
    "Jumper",
    "Sapper",
    "Bomberman",
    "Rambo"
}
new const GUNS[][]=
{
    "weapon_ak47",
    "weapon_m249",
    "weapon_scout",
    "weapon_awp",
    "weapon_mp5navy",
    "weapon_xm1014",
    "weapon_famas",
    "weapon_tmp",
    "weapon_tmp",
    "weapon_m3",
    "weapon_p90",
    "weapon_xm1014",
    "weapon_famas"
}
new const GUN_IDS[]={CSW_AK47,CSW_M249,CSW_SCOUT,CSW_AWP,CSW_MP5NAVY,CSW_XM1014,CSW_FAMAS,CSW_TMP,CSW_TMP,CSW_M3,CSW_P90,CSW_XM1014,CSW_FAMAS}
new const BASE_HP[]={110,120,100,100,105,115,110,95,90,100,110,100,115}
new const SKILLS[][]=
{
    "Battle Focus: +15% damage / 5s",
    "Supply: refill reserve ammo",
    "Adrenaline: +25 speed / 6s",
    "First Aid: heal 35 HP",
    "Field Medic: heal nearby allies",
    "Shield: gain 75 armor",
    "Frag: receive one HE grenade",
    "Sprint: +45 speed / 6s",
    "Knife invisibility + one-hit knife (passive)",
    "Auto-bhop + double jump (passive)",
    "Plant up to 2 proximity mines per life",
    "Plant/detonate dynamite; 50% gravity",
    "FAMAS +30% damage, silent steps, 2 flashes (passive)"
}
new const STATS[][]=
{
    "Health (+2 HP)","Power (+0.4% damage)","Stamina (-0.3% damage taken)","Agility (+0.6 speed)"
}
new const ITEMS[][]=
{
    "None","Damage Charm","Armor Plating","Medical Kit","Light Boots","Gravity Harness","Ammo Pack","Vampire Fang","Guardian Vest","Grenadier Kit","Payday Badge"
}
new const ITEM_INFO[][]=
{
    "No perk equipped.","+8% weapon damage.","8% less incoming weapon damage.","Regenerate 2 HP every 3 seconds.","+20 movement speed.","Reduced gravity (80%).","Refill weapon clip after an enemy kill.","Heal 15 HP after an enemy kill.","Start each life with 50 armor.","Receive an HE grenade on spawn.","Earn twice the credits for enemy kills."
}
new g_vault=-1,g_hud,g_kill_limit,g_delay,g_protection,g_xp_kill,g_xp_hs,g_drop_chance,g_reward_bots
new bool:g_enabled,bool:g_finished,bool:g_loaded[33],g_class[33],g_pending[33],g_xp[33][CLASS_COUNT],g_stats[33][CLASS_COUNT][STAT_COUNT]
new g_credits[33],g_item[33],g_durability[33],g_streak[33],g_kills[33],g_team_score[4],g_tick
new Float:g_initial_choice_until[33]
new bool:g_prompted[33],bool:g_old_auto[33],bool:g_old_mega[33],bool:g_airjump[33],g_charges[33],g_explosion_sprite
new const EXPLOSIVE_CLASS[]="mm_cod_explosive"
new g_auth[33][40],Float:g_until[33],Float:g_skill_ready[33],Float:g_boost_until[33],Float:g_focus_until[33],Float:g_shop_ready[33]
new Float:g_old_gravity[33],bool:g_gravity_saved[33],Float:g_damage[33][33],Float:g_hit_time[33][33]
public plugin_precache()
{
    precache_model("models/w_hegrenade.mdl")
    g_explosion_sprite=precache_model("sprites/zerogxplode.spr")
}
public plugin_init()
{
    register_plugin(PLUGIN_NAME,PLUGIN_VERSION,PLUGIN_AUTHOR)
    RegisterHam(Ham_Spawn,"player","mm_spawn",1)
    RegisterHam(Ham_Killed,"player","mm_killed",1)
    RegisterHam(Ham_TakeDamage,"player","mm_damage")
    RegisterHam(Ham_Touch,"weaponbox","mm_pickup")
    RegisterHam(Ham_Touch,"armoury_entity","mm_pickup")
    RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed,"mm_speed",true)
    RegisterHookChain(RG_BuyWeaponByWeaponID,"mm_buy_weapon",false)
    RegisterHookChain(RG_BuyItem,"mm_buy_item",false)
    register_forward(FM_CmdStart,"mm_buttons")
    register_forward(FM_PlayerPreThink,"mm_footsteps")
    register_forward(FM_Think,"mm_explosive_think")
    register_forward(FM_AddToFullPack,"mm_glow",1)
    new const commands[][]=
    {
        "cod","codclass","codclasses","codstats","codreset","codperk","codperks","coddrop","codshop","codskill","codtop","codhelp","class","classes","perk","perks","dropperk"
    }
    new command[48]
    for(new i=0;i<sizeof commands;i++)
    {
        formatex(command,charsmax(command),"say /%s",commands[i]);
        register_clcmd(command,"mm_chat",0,"- CoD:MW player menu/action")
        formatex(command,charsmax(command),"say_team /%s",commands[i]);
        register_clcmd(command,"mm_chat")
    }
    register_clcmd("cod_skill","mm_skill",0,"- use your CoD class ability")
    register_concmd("amx_codmenu","mm_admin_menu",ADMIN_RCON,"- CoD player administration")
    register_concmd("amx_cod_xp","mm_admin_command",ADMIN_RCON,"<player> <amount> - add XP to selected class")
    register_concmd("amx_cod_credits","mm_admin_command",ADMIN_RCON,"<player> <amount> - adjust CoD credits")
    register_concmd("amx_cod_item","mm_admin_command",ADMIN_RCON,"<player> <0-10> - set perk (0 removes)")
    register_concmd("amx_cod_reset","mm_admin_command",ADMIN_RCON,"<player> confirm - reset selected class XP/stats")
    register_concmd("amx_cod_restart","mm_admin_restart",ADMIN_CFG,"- restart CoD match; keep progression")
    register_concmd("amx_cod_status","mm_status",ADMIN_CFG,"- CoD mode and player status")
    register_srvcmd("mm_cod_status","mm_status")
    register_srvcmd("mm_cod_selftest","mm_selftest")
    g_kill_limit=register_cvar("mm_cod_kill_limit","75")
    g_delay=register_cvar("mm_cod_respawn_delay","2.0")
    g_protection=register_cvar("mm_cod_spawn_protection","2.0")
    g_xp_kill=register_cvar("mm_cod_xp_kill","100")
    g_xp_hs=register_cvar("mm_cod_xp_headshot","25")
    g_drop_chance=register_cvar("mm_cod_perk_chance","30")
    g_reward_bots=register_cvar("mm_cod_reward_bots","1")
    g_vault=nvault_open("mm_cod_profiles_v1")
    if(g_vault==INVALID_HANDLE)
    {
        set_fail_state("Could not open CoD progression vault");
        return;
    }
    g_hud=CreateHudSyncObj()
    log_amx("%s %s initialized: mode-scoped class XP, perks, credits and team DM.",PLUGIN_NAME,PLUGIN_VERSION)
}
bool:mm_active()
{
    return mm_get_active_mode()==MM_MODE_COD;
}
bool:mm_playing(id)
{
    return id>=1 && id<=MaxClients && is_user_connected(id) && (cs_get_user_team(id)==CS_TEAM_T || cs_get_user_team(id)==CS_TEAM_CT);
}
bool:mm_enemy(a,b)
{
    return a!=b && mm_playing(a) && mm_playing(b) && cs_get_user_team(a)!=cs_get_user_team(b);
}
public plugin_cfg()
{
    if(mm_active())mm_activate();
}
public client_connect(id)
{
    g_prompted[id]=false;g_initial_choice_until[id]=0.0;
    g_loaded[id]=false;
    g_auth[id][0]=0;
    g_class[id]=0;
    g_pending[id]=0;
    g_credits[id]=0;
    g_item[id]=0;
    g_durability[id]=0
    g_streak[id]=0;
    g_kills[id]=0;
    g_until[id]=0.0;
    g_skill_ready[id]=0.0;
    g_boost_until[id]=0.0;
    g_focus_until[id]=0.0;
    g_shop_ready[id]=0.0;
    g_gravity_saved[id]=false
    for(new c=0;c<CLASS_COUNT;c++)
    {
        g_xp[id][c]=0;
        for(new s=0;s<STAT_COUNT;s++)g_stats[id][c][s]=0;
    }
    for(new i=1;i<=MaxClients;i++)
    {
        g_damage[id][i]=0.0;
        g_damage[i][id]=0.0;
        g_hit_time[id][i]=0.0;
        g_hit_time[i][id]=0.0;
    }
}
public client_authorized(id)
{
    mm_load(id);
}
public client_disconnected(id)
{
    mm_save(id);
    mm_remove_explosives(id);
    remove_task(TASK_PROMPT+id);
    remove_task(TASK_SPAWN+id);
    remove_task(TASK_GEAR+id);
    g_loaded[id]=false;
    g_gravity_saved[id]=false
    for(new i=1;i<=MaxClients;i++)
    {
        g_damage[id][i]=0.0;
        g_damage[i][id]=0.0;
        g_hit_time[id][i]=0.0;
        g_hit_time[i][id]=0.0;
    }
}
public plugin_end()
{
    mm_shutdown();
    if(g_vault!=INVALID_HANDLE)nvault_close(g_vault);
}
public mm_mode_transition_started(old_mode,new_mode)
{
    if(MmMode:old_mode==MM_MODE_COD)mm_shutdown();
}
public mm_mode_changed(old_mode,new_mode)
{
    if(MmMode:new_mode==MM_MODE_COD)mm_activate();
    else if(g_enabled)mm_shutdown();
}
mm_activate()
{
    if(g_enabled)mm_shutdown()
    g_enabled=true;
    g_finished=false;
    g_team_score[1]=0;
    g_team_score[2]=0;
    g_tick=0
    set_task(1.0,"mm_tick",TASK_TICK,"",0,"b")
    for(new id=1;id<=MaxClients;id++)if(mm_playing(id))
    {
        g_prompted[id]=false;
        g_streak[id]=0;
        g_kills[id]=0;
        if(is_user_alive(id))mm_spawn(id);
        else set_task(0.3,"mm_respawn",TASK_SPAWN+id);
    }
    client_print_color(0,print_team_grey,"^4[CoD]^1 Team deathmatch: ^3/cod^1 for classes, upgrades, perks and shop. First team to ^4%d^1 kills!",get_pcvar_num(g_kill_limit))
}
mm_shutdown()
{
    g_enabled=false
    mm_remove_explosives(0)
    remove_task(TASK_TICK);
    remove_task(TASK_RESTART);
    ClearSyncHud(0,g_hud)
    for(new id=1;id<=MaxClients;id++)
    {
        mm_save(id);
        remove_task(TASK_PROMPT+id);
        remove_task(TASK_SPAWN+id);
        remove_task(TASK_GEAR+id)
        g_initial_choice_until[id]=0.0;
        g_until[id]=0.0;
        g_boost_until[id]=0.0;
        g_focus_until[id]=0.0;
        g_skill_ready[id]=0.0;g_shop_ready[id]=0.0
        if(g_gravity_saved[id] && is_user_connected(id))
        {
            set_pev(id,pev_gravity,g_old_gravity[id]);
            set_member(id,m_bAutoBunnyHopping,g_old_auto[id]);set_member(id,m_bMegaBunnyJumping,g_old_mega[id]);set_pev(id,pev_flTimeStepSound,0);
            if(is_user_alive(id))
            {
                set_pev(id,pev_health,100.0)
                cs_set_user_armor(id,0,CS_ARMOR_NONE)
                rg_remove_all_items(id,false)
                rg_give_item(id,"weapon_knife")
                if(cs_get_user_team(id)==CS_TEAM_CT)rg_give_item(id,"weapon_usp")
                else if(cs_get_user_team(id)==CS_TEAM_T)rg_give_item(id,"weapon_glock18")
                rg_reset_maxspeed(id)
            }
        }
        g_gravity_saved[id]=false
        for(new j=1;j<=MaxClients;j++)
        {
            g_damage[id][j]=0.0;
            g_hit_time[id][j]=0.0;
        }
    }
    g_enabled=false;
    g_finished=false
}
mm_load(id)
{
    if(g_vault==INVALID_HANDLE || is_user_bot(id) || is_user_hltv(id))return
    get_user_authid(id,g_auth[id],charsmax(g_auth[]))
    if(!g_auth[id][0] || equal(g_auth[id],"STEAM_ID_PENDING") || equal(g_auth[id],"STEAM_ID_LAN") || equal(g_auth[id],"VALVE_ID_LAN"))return
    new key[80],data[128],a[16],b[16],c[16],d[16],e[16]
    formatex(key,charsmax(key),"v1:%s:meta",g_auth[id])
    if(nvault_get(g_vault,key,data,charsmax(data)))
    {
        parse(data,a,charsmax(a),b,charsmax(b),c,charsmax(c),d,charsmax(d))
        g_pending[id]=g_class[id]=clamp(str_to_num(a),0,CLASS_COUNT-1);
        g_credits[id]=clamp(str_to_num(b),0,MAX_CREDITS)
        g_item[id]=clamp(str_to_num(c),0,ITEM_COUNT);
        g_durability[id]=clamp(str_to_num(d),0,3)
        if(!g_durability[id])g_item[id]=0
    }
    for(new k=0;k<CLASS_COUNT;k++)
    {
        formatex(key,charsmax(key),"v1:%s:c%d",g_auth[id],k)
        if(!nvault_get(g_vault,key,data,charsmax(data)))continue
        parse(data,a,charsmax(a),b,charsmax(b),c,charsmax(c),d,charsmax(d),e,charsmax(e))
        g_xp[id][k]=clamp(str_to_num(a),0,MAX_XP)
        g_stats[id][k][0]=clamp(str_to_num(b),0,STAT_CAP);
        g_stats[id][k][1]=clamp(str_to_num(c),0,STAT_CAP)
        g_stats[id][k][2]=clamp(str_to_num(d),0,STAT_CAP);
        g_stats[id][k][3]=clamp(str_to_num(e),0,STAT_CAP)
        new used;
        for(new z=0;z<STAT_COUNT;z++)used+=g_stats[id][k][z]
        if(used>2*(mm_level(g_xp[id][k])-1))for(new z=0;z<STAT_COUNT;z++)g_stats[id][k][z]=0
    }
    g_loaded[id]=true
}
mm_save(id)
{
    if(!g_loaded[id] || g_vault==INVALID_HANDLE)return
    new key[80],data[128]
    formatex(key,charsmax(key),"v1:%s:meta",g_auth[id]);
    formatex(data,charsmax(data),"%d %d %d %d",g_pending[id],g_credits[id],g_item[id],g_durability[id]);
    nvault_set(g_vault,key,data)
    for(new c=0;c<CLASS_COUNT;c++)
    {
        formatex(key,charsmax(key),"v1:%s:c%d",g_auth[id],c)
        formatex(data,charsmax(data),"%d %d %d %d %d",g_xp[id][c],g_stats[id][c][0],g_stats[id][c][1],g_stats[id][c][2],g_stats[id][c][3]);
        nvault_set(g_vault,key,data)
    }
}
mm_level(xp)
{
    new level=1;
    while(level<MAX_LEVEL && xp>=level*level*100)level++;
    return level;
}
mm_points(id)
{
    new used;
    for(new i=0;i<STAT_COUNT;i++)used+=g_stats[id][g_class[id]][i];
    return max(0,2*(mm_level(g_xp[id][g_class[id]])-1)-used);
}
Float:mm_maxhp(id)
{
    return float(BASE_HP[g_class[id]]+2*g_stats[id][g_class[id]][0]);
}
mm_award(id,xp,credits)
{
    new c=g_class[id],old=mm_level(g_xp[id][c]);
    g_xp[id][c]=clamp(g_xp[id][c]+xp,0,MAX_XP);
    g_credits[id]=clamp(g_credits[id]+credits,0,MAX_CREDITS)
    new level=mm_level(g_xp[id][c])
    if(level>old)client_print_color(id,print_team_blue,"^4[CoD]^1 %s reached ^3level %d^1! ^4+%d upgrade points^1. Use ^3/codstats^1.",CLASSES[c],level,2*(level-old))
    mm_save(id)
}
public mm_spawn(id)
{
    if(!g_enabled || !mm_active() || !mm_playing(id) || !is_user_alive(id))return HAM_IGNORED
    mm_remove_explosives(id);g_charges[id]=2;g_airjump[id]=false
    g_class[id]=g_pending[id];
    g_until[id]=get_gametime()+floatclamp(get_pcvar_float(g_protection),0.0,5.0);
    g_boost_until[id]=0.0;
    g_focus_until[id]=0.0
    if(!g_gravity_saved[id])
    {
        pev(id,pev_gravity,g_old_gravity[id]);
        g_old_auto[id]=bool:get_member(id,m_bAutoBunnyHopping);g_old_mega[id]=bool:get_member(id,m_bMegaBunnyJumping);
        g_gravity_saved[id]=true;
    }
    set_member(id,m_bAutoBunnyHopping,g_class[id]==CLASS_JUMPER?true:g_old_auto[id]);set_member(id,m_bMegaBunnyJumping,g_class[id]==CLASS_JUMPER?true:g_old_mega[id])
    set_pev(id,pev_flTimeStepSound,0)
    for(new i=1;i<=MaxClients;i++)
    {
        g_damage[i][id]=0.0;
        g_hit_time[i][id]=0.0;
    }
    remove_task(TASK_GEAR+id);
    set_task(0.15,"mm_gear",TASK_GEAR+id)
    if(!g_prompted[id] && !is_user_bot(id)){remove_task(TASK_PROMPT+id);set_task(1.5,"mm_class_prompt",TASK_PROMPT+id);}
    return HAM_IGNORED
}
public mm_gear(task)
{
    new id=task-TASK_GEAR;
    if(!g_enabled || !mm_active() || !mm_playing(id) || !is_user_alive(id))return
    rg_remove_all_items(id,false);
    rg_give_item(id,"weapon_knife");
    rg_give_item(id,GUNS[g_class[id]])
    cs_set_user_bpammo(id,GUN_IDS[g_class[id]],GUN_IDS[g_class[id]]==CSW_XM1014?32:90)
    if(cs_get_user_team(id)==CS_TEAM_CT)
    {
        rg_give_item(id,"weapon_usp");
        cs_set_user_bpammo(id,CSW_USP,100);
    }
    else
    {
        rg_give_item(id,"weapon_glock18");
        cs_set_user_bpammo(id,CSW_GLOCK18,120);
    }
    set_pev(id,pev_health,mm_maxhp(id));
    cs_set_user_armor(id,g_item[id]==8?50:0,g_item[id]==8?CS_ARMOR_KEVLAR:CS_ARMOR_NONE)
    if(g_item[id]==9)rg_give_item(id,"weapon_hegrenade")
    mm_apply_gravity(id);
    if(g_class[id]==CLASS_RAMBO){rg_give_item(id,"weapon_flashbang");cs_set_user_bpammo(id,CSW_FLASHBANG,2);}
    if(g_class[id]==CLASS_BOMBER){rg_give_item(id,"weapon_smokegrenade");cs_set_user_bpammo(id,CSW_SMOKEGRENADE,2);}
    rg_reset_maxspeed(id)
}
public mm_speed(id)
{
    if(!g_enabled || !mm_active() || !is_user_alive(id))return HC_CONTINUE
    new Float:speed;
    pev(id,pev_maxspeed,speed)
    if(speed>1.0)
    {
        speed+=float(g_stats[id][g_class[id]][3])*0.6;
        if(g_item[id]==4)speed+=20.0;
        if(g_boost_until[id]>get_gametime())speed+=g_class[id]==7?45.0:25.0;
        set_pev(id,pev_maxspeed,floatmin(speed,380.0));
    }
    return HC_CONTINUE
}
public mm_damage(victim,inflictor,attacker,Float:damage,bits)
{
    if(!g_enabled || !mm_active())return HAM_IGNORED
    if(g_finished || g_until[victim]>get_gametime())return HAM_SUPERCEDE
    if(attacker==victim || !mm_playing(attacker) || !mm_playing(victim))return HAM_IGNORED
    if(!mm_enemy(attacker,victim))return HAM_SUPERCEDE
    g_initial_choice_until[attacker]=0.0;g_initial_choice_until[victim]=0.0
    new Float:factor=1.0+float(g_stats[attacker][g_class[attacker]][1])*0.004
    if(g_item[attacker]==1)factor+=0.08
    if(g_focus_until[attacker]>get_gametime())factor+=0.15
    factor*=1.0-float(g_stats[victim][g_class[victim]][2])*0.003
    if(g_item[victim]==2)factor*=0.92
    new source_weapon=get_member(attacker,m_pActiveItem)
    if(g_class[attacker]==CLASS_RAMBO && inflictor==attacker && (bits&DMG_BULLET) && !is_nullent(source_weapon) && get_member(source_weapon,m_iId)==WEAPON_FAMAS)factor*=1.3
    damage*=factor;
    new active_item=get_member(attacker,m_pActiveItem)
    if(g_class[attacker]==CLASS_NINJA && inflictor==attacker && !is_nullent(active_item) && get_member(active_item,m_iId)==WEAPON_KNIFE)damage=9999.0
    SetHamParamFloat(4,damage)
    g_damage[attacker][victim]+=damage;
    g_hit_time[attacker][victim]=get_gametime()
    return HAM_HANDLED
}
public mm_killed(victim,killer,gib)
{
    if(!g_enabled || !mm_active() || !mm_playing(victim))return HAM_IGNORED
    mm_remove_explosives(victim)
    g_until[victim]=0.0;
    g_streak[victim]=0;
    remove_task(TASK_GEAR+victim);
    remove_task(TASK_SPAWN+victim)
    if(g_item[victim] && --g_durability[victim]<=0)
    {
        g_item[victim]=0;
        g_durability[victim]=0;
        client_print_color(victim,print_team_red,"^4[CoD]^1 Your perk wore out after three deaths.");
    }
    if(!g_finished && mm_enemy(killer,victim))
    {
        g_team_score[_:cs_get_user_team(killer)]++;
        g_kills[killer]++;
        g_streak[killer]++
        if(get_pcvar_num(g_reward_bots) || !is_user_bot(victim))
        {
            new xp=clamp(get_pcvar_num(g_xp_kill),0,10000);
            if(get_member(victim,m_bHeadshotKilled))xp+=clamp(get_pcvar_num(g_xp_hs),0,10000)
            mm_award(killer,xp,g_item[killer]==10?20:10)
            new assist;
            new Float:best=39.9
            for(new i=1;i<=MaxClients;i++)if(i!=killer && mm_enemy(i,victim) && get_gametime()-g_hit_time[i][victim]<=10.0 && g_damage[i][victim]>best)
            {
                best=g_damage[i][victim];
                assist=i;
            }
            if(assist)
            {
                mm_award(assist,25,4);
                client_print_color(assist,print_team_blue,"^4[CoD]^1 Assist: ^3+25 XP^1 and ^4+4 credits^1.");
            }
            if(!g_item[killer] && random_num(1,100)<=clamp(get_pcvar_num(g_drop_chance),0,100))mm_give_perk(killer,random_num(1,ITEM_COUNT))
            if(g_streak[killer]%3==0)
            {
                mm_award(killer,25,20);
                client_print_color(killer,print_team_blue,"^4[CoD]^3 %d-kill streak! ^1Bonus: ^4+25 XP, +20 credits^1.",g_streak[killer]);
            }
        }
        if(is_user_alive(killer))
        {
            if(g_item[killer]==7)mm_heal(killer,15.0)
            if(g_item[killer]==6)
            {
                new item=get_member(killer,m_pActiveItem);
                if(!is_nullent(item))
                {
                    new WeaponIdType:w=WeaponIdType:get_member(item,m_iId);
                    new clip=rg_get_iteminfo(item,ItemInfo_iMaxClip);
                    if(clip>0 && w!=WEAPON_KNIFE)set_member(item,m_Weapon_iClip,clip);
                }
            }
        }
        if(g_team_score[_:cs_get_user_team(killer)]>=clamp(get_pcvar_num(g_kill_limit),10,1000))mm_finish(cs_get_user_team(killer))
    }
    mm_save(victim)
    for(new i=1;i<=MaxClients;i++)
    {
        g_damage[i][victim]=0.0;
        g_hit_time[i][victim]=0.0;
    }
    if(!g_finished)set_task(floatclamp(get_pcvar_float(g_delay),0.5,10.0),"mm_respawn",TASK_SPAWN+victim)
    return HAM_IGNORED
}
public mm_respawn(task)
{
    new id=task-TASK_SPAWN;
    if(g_enabled && mm_active() && !g_finished && mm_playing(id) && !is_user_alive(id) && mm_get_transition_state()==MM_TRANSITION_IDLE)rg_round_respawn(id);
}
public mm_buttons(id,command,seed)
{
    if(!g_enabled || !mm_active() || !is_user_alive(id))return FMRES_IGNORED
    new buttons=get_uc(command,UC_Buttons)
    if(buttons&(IN_ATTACK|IN_ATTACK2)){g_until[id]=0.0;g_initial_choice_until[id]=0.0;}
    if(g_class[id]==CLASS_JUMPER)
    {
        if(pev(id,pev_flags)&FL_ONGROUND)g_airjump[id]=false
        else if((buttons&IN_JUMP) && !(pev(id,pev_oldbuttons)&IN_JUMP) && !g_airjump[id] && pev(id,pev_waterlevel)<2 && pev(id,pev_movetype)==MOVETYPE_WALK)
        {
            new Float:velocity[3];pev(id,pev_velocity,velocity);velocity[2]=260.0;set_pev(id,pev_velocity,velocity);g_airjump[id]=true
        }
    }
    return FMRES_IGNORED
}
public mm_footsteps(id)
{
    if(g_enabled && mm_active() && is_user_alive(id) && g_class[id]==CLASS_RAMBO)set_pev(id,pev_flTimeStepSound,999)
    return FMRES_IGNORED
}

public mm_glow(packet,e,entity,host,hostflags,player,pset)
{
    if(!g_enabled || !mm_active() || !player || entity<1 || entity>MaxClients || !is_user_alive(entity))return FMRES_IGNORED
    // Per-viewer packet rendering: enemies cannot see a knife-equipped Ninja;
    // teammates remain fully visible and solid. No global render state changes.
    new item=get_member(entity,m_pActiveItem)
    if(g_class[entity]==CLASS_NINJA && g_until[entity]<=get_gametime() && mm_enemy(entity,host) && !is_nullent(item) && get_member(item,m_iId)==WEAPON_KNIFE)
    {
        set_es(packet,ES_RenderFx,kRenderFxNone)
        set_es(packet,ES_RenderMode,kRenderTransTexture)
        set_es(packet,ES_RenderAmt,0)
        set_es(packet,ES_WeaponModel,0)
        set_es(packet,ES_Effects,get_es(packet,ES_Effects)|EF_NODRAW)
    }
    else if(g_until[entity]>get_gametime())
    {
        set_es(packet,ES_RenderFx,kRenderFxGlowShell);set_es(packet,ES_RenderAmt,12)
        set_es(packet,ES_RenderColor,cs_get_user_team(entity)==CS_TEAM_T?{255,70,50}:{60,120,255})
    }
    return FMRES_IGNORED
}

public mm_tick()
{
    if(!g_enabled || !mm_active())return
    g_tick++
    for(new id=1;id<=MaxClients;id++)if(mm_playing(id))
    {
        if(is_user_alive(id))
        {
            if(g_item[id]==3 && g_tick%3==0)mm_heal(id,2.0)
            if(g_boost_until[id]>0.0 && g_boost_until[id]<=get_gametime())
            {
                g_boost_until[id]=0.0;
                rg_reset_maxspeed(id);
            }
            if(g_tick%10==0)mm_save(id)
        }
        new c=g_class[id],level=mm_level(g_xp[id][c]),next=level<MAX_LEVEL?level*level*100:MAX_XP
        set_hudmessage(100,210,255,0.02,0.18,0,0.0,1.05,0.0,0.0)
        ShowSyncHudMsg(id,g_hud,"CoD:MW | T %d : %d CT^n%s | Level %d | XP %d / %d^nPoints %d | Credits %d | %s (%d lives)^n/cod menu | /codskill ability",g_team_score[1],g_team_score[2],CLASSES[c],level,g_xp[id][c],next,mm_points(id),g_credits[id],ITEMS[g_item[id]],g_durability[id])
    }
}
mm_finish(CsTeams:team)
{
    g_finished=true
    client_print_color(0,team==CS_TEAM_CT?print_team_blue:print_team_red,"^4[CoD]^3 %s win! ^1T ^4%d : %d^1 CT. Rematch/map vote starts shortly.",team==CS_TEAM_CT?"CTs":"Terrorists",g_team_score[1],g_team_score[2])
    set_dhudmessage(255,210,60,-1.0,0.25,0,0.0,6.0,0.2,0.5);
    show_dhudmessage(0,"CoD:MW - %s WIN!^nT %d : %d CT",team==CS_TEAM_CT?"CTs":"TERRORISTS",g_team_score[1],g_team_score[2])
    for(new id=1;id<=MaxClients;id++)if(mm_playing(id) && cs_get_user_team(id)==team)mm_award(id,50,20)
    set_task(6.0,"mm_vote",TASK_RESTART)
}
public mm_vote()
{
    if(!g_enabled || !mm_active())return;
    if(!mm_voting_start_rematch(MM_MODE_COD))
    {
        mm_new_match();
        return;
    }
    set_task(60.0,"mm_vote_fallback",TASK_RESTART);
}
public mm_vote_fallback()
{
    if(!g_enabled || !mm_active() || !g_finished)return
    if(mm_voting_is_active() || mm_voting_has_decision()){set_task(10.0,"mm_vote_fallback",TASK_RESTART);return;}
    mm_new_match()
}

mm_new_match()
{
    remove_task(TASK_RESTART);
    g_finished=false;
    g_team_score[1]=0;
    g_team_score[2]=0
    for(new id=1;id<=MaxClients;id++)if(mm_playing(id))
    {
        g_streak[id]=0;
        g_kills[id]=0;
        rg_round_respawn(id);
    }
    client_print_color(0,print_team_blue,"^4[CoD]^1 New match! Class progression and credits are saved.")
}
public mm_chat(id)
{
    if(!mm_active())return PLUGIN_CONTINUE
    new text[48];
    read_args(text,charsmax(text));
    remove_quotes(text)
    if(equali(text,"/codclass") || equali(text,"/codclasses") || equali(text,"/class") || equali(text,"/classes"))mm_class_menu(id)
    else if(equali(text,"/codstats"))mm_stats_menu(id)
    else if(equali(text,"/codreset"))mm_reset_menu(id)
    else if(equali(text,"/codperk") || equali(text,"/perk"))mm_perk_info(id)
    else if(equali(text,"/codperks") || equali(text,"/perks"))mm_perks_menu(id)
    else if(equali(text,"/coddrop") || equali(text,"/dropperk"))
    {
        g_item[id]=0;
        g_durability[id]=0;
        mm_save(id);
        if(is_user_alive(id))
        {
            mm_apply_gravity(id);
            rg_reset_maxspeed(id);
        }
        client_print_color(id,print_team_grey,"^4[CoD]^1 Perk discarded.");
    }
    else if(equali(text,"/codshop"))mm_shop_menu(id)
    else if(equali(text,"/codskill"))mm_skill(id)
    else if(equali(text,"/codtop"))mm_top(id)
    else if(equali(text,"/codhelp"))show_motd(id,"addons/amxmodx/configs/mm_cod_help.html","CoD:MW - Commands")
    else mm_menu(id)
    return PLUGIN_HANDLED
}
mm_menu(id)
{
    new title[128];
    formatex(title,charsmax(title),"CoD:MW | %s Lv.%d^nCredits %d | Upgrade points %d",CLASSES[g_class[id]],mm_level(g_xp[id][g_class[id]]),g_credits[id],mm_points(id))
    new menu=menu_create(title,"mm_menu_select")
    menu_additem(menu,"Choose class (next spawn)");
    menu_additem(menu,"Upgrade stats");
    menu_additem(menu,"Current perk");
    menu_additem(menu,"Perk catalogue");
    menu_additem(menu,"Credits shop");
    menu_additem(menu,"Use class ability");
    menu_additem(menu,"Reset allocated stats");
    menu_additem(menu,"Scores");
    menu_additem(menu,"Help / commands");
    menu_display(id,menu)
}
public mm_menu_select(id,menu,item)
{
    menu_destroy(menu);
    if(item==MENU_EXIT || !is_user_connected(id) || !mm_active())return PLUGIN_HANDLED
    switch(item)
    {
        case 0:mm_class_menu(id);
        case 1:mm_stats_menu(id);
        case 2:mm_perk_info(id);
        case 3:mm_perks_menu(id);
        case 4:mm_shop_menu(id);
        case 5:mm_skill(id);
        case 6:mm_reset_menu(id);
        case 7:mm_top(id);
        case 8:show_motd(id,"addons/amxmodx/configs/mm_cod_help.html","CoD:MW - Commands");
    }
    return PLUGIN_HANDLED
}
mm_class_menu(id)
{
    new menu=menu_create("Choose class - applied on next spawn","mm_class_select"),label[180]
    for(new c=0;c<CLASS_COUNT;c++)
    {
        formatex(label,charsmax(label),"%s | Lv.%d | %s",CLASSES[c],mm_level(g_xp[id][c]),SKILLS[c]);
        menu_additem(menu,label);
    }
    menu_display(id,menu)
}
public mm_class_select(id,menu,item)
{
    menu_destroy(menu);
    if(item<0 || item>=CLASS_COUNT || !is_user_connected(id) || !mm_active())return PLUGIN_HANDLED
    g_pending[id]=item;
    mm_save(id);
    if(g_initial_choice_until[id]>get_gametime() && is_user_alive(id))
    {
        g_initial_choice_until[id]=0.0;rg_round_respawn(id)
        client_print_color(id,print_team_blue,"^4[CoD]^1 Starting class: ^3%s^1.",CLASSES[item])
        return PLUGIN_HANDLED
    }
    client_print_color(id,print_team_blue,"^4[CoD]^1 Next spawn: ^3%s^1. Its XP and upgrades are saved separately.",CLASSES[item]);
    return PLUGIN_HANDLED
}
mm_stats_menu(id)
{
    new title[96],label[80];
    formatex(title,charsmax(title),"%s upgrades | %d free points",CLASSES[g_class[id]],mm_points(id));
    new menu=menu_create(title,"mm_stats_select")
    for(new s=0;s<STAT_COUNT;s++)
    {
        formatex(label,charsmax(label),"%s: %d / %d",STATS[s],g_stats[id][g_class[id]][s],STAT_CAP);
        menu_additem(menu,label);
    }
    menu_display(id,menu)
}
public mm_stats_select(id,menu,item)
{
    menu_destroy(menu);
    if(item<0 || item>=STAT_COUNT || !is_user_connected(id) || !mm_active())return PLUGIN_HANDLED
    if(mm_points(id)>0 && g_stats[id][g_class[id]][item]<STAT_CAP)
    {
        g_stats[id][g_class[id]][item]++;
        mm_save(id);
        if(is_user_alive(id))rg_reset_maxspeed(id);
    }
    else client_print_color(id,print_team_red,"^4[CoD]^1 No free points, or this stat is at its limit.")
    mm_stats_menu(id);
    return PLUGIN_HANDLED
}
mm_reset_menu(id)
{
    new menu=menu_create("Reset this class's allocated stats?^nXP and level are kept. Current HP is capped.","mm_reset_select");
    menu_additem(menu,"Yes - refund upgrade points");
    menu_additem(menu,"Cancel");
    menu_display(id,menu);
}
public mm_reset_select(id,menu,item)
{
    menu_destroy(menu);
    if(item==0 && is_user_connected(id) && mm_active())
    {
        for(new s=0;s<STAT_COUNT;s++)g_stats[id][g_class[id]][s]=0;
        mm_cap_stats(id);
        mm_save(id);
        client_print_color(id,print_team_blue,"^4[CoD]^1 Upgrade points refunded. Health and speed limits updated.");
    }
    return PLUGIN_HANDLED;
}
mm_perk_info(id)
{
    client_print_color(id,print_team_blue,"^4[CoD]^3 %s^1: %s ^4%d deaths remaining^1.",ITEMS[g_item[id]],ITEM_INFO[g_item[id]],g_durability[id]);
}
mm_perks_menu(id)
{
    new menu=menu_create("Perk catalogue - earned from kills/shop","mm_perk_select"),label[160];
    for(new i=1;i<=ITEM_COUNT;i++)
    {
        formatex(label,charsmax(label),"%s: %s",ITEMS[i],ITEM_INFO[i]);
        menu_additem(menu,label);
    }
    menu_display(id,menu);
}
public mm_perk_select(id,menu,item)
{
    menu_destroy(menu);
    if(item>=0 && item<ITEM_COUNT && is_user_connected(id) && mm_active())client_print_color(id,print_team_blue,"^4[CoD]^3 %s^1: %s",ITEMS[item+1],ITEM_INFO[item+1]);
    return PLUGIN_HANDLED;
}
mm_give_perk(id,item)
{
    g_item[id]=clamp(item,0,ITEM_COUNT);
    g_durability[id]=item?3:0;
    mm_save(id)
    if(is_user_alive(id))
    {
        mm_apply_gravity(id);
        rg_reset_maxspeed(id);
    }
    client_print_color(id,print_team_blue,"^4[CoD]^1 Received ^3%s^1! %s",ITEMS[g_item[id]],ITEM_INFO[g_item[id]])
}
mm_shop_menu(id)
{
    new title[64];
    formatex(title,charsmax(title),"CoD shop | %d credits",g_credits[id]);
    new menu=menu_create(title,"mm_shop_select");
    menu_additem(menu,"Heal 50 HP - 25 credits");
    menu_additem(menu,"75 armor - 30 credits");
    menu_additem(menu,"Random perk (replace current) - 75 credits");
    menu_display(id,menu);
}
public mm_shop_select(id,menu,item)
{
    menu_destroy(menu);
    if(item<0 || item>2 || !mm_active() || !mm_playing(id) || !is_user_alive(id) || g_finished)return PLUGIN_HANDLED
    new const cost[]=
    {
        25,30,75
    }
    if(get_gametime()<g_shop_ready[id])
    {
        client_print_color(id,print_team_red,"^4[CoD]^1 Wait before your next shop purchase.");
        return PLUGIN_HANDLED;
    }
    if(g_credits[id]<cost[item])
    {
        client_print_color(id,print_team_red,"^4[CoD]^1 Not enough credits.");
        return PLUGIN_HANDLED;
    }
    new Float:hp;
    pev(id,pev_health,hp)
    if((item==0 && hp>=mm_maxhp(id)) || (item==1 && get_user_armor(id)>=75))
    {
        client_print_color(id,print_team_red,"^4[CoD]^1 You already have enough health/armor.");
        return PLUGIN_HANDLED;
    }
    g_credits[id]-=cost[item];
    g_shop_ready[id]=get_gametime()+10.0
    switch(item)
    {
        case 0:mm_heal(id,50.0);
        case 1:cs_set_user_armor(id,75,CS_ARMOR_KEVLAR);
        case 2:mm_give_perk(id,random_num(1,ITEM_COUNT));
    }
    mm_save(id);
    client_print_color(id,print_team_blue,"^4[CoD]^1 Purchase complete. ^4%d credits^1 remain.",g_credits[id]);
    return PLUGIN_HANDLED
}
mm_heal(id,Float:amount)
{
    if(is_user_alive(id))
    {
        new Float:hp;
        pev(id,pev_health,hp);
        set_pev(id,pev_health,floatmin(hp+amount,mm_maxhp(id)));
    }
}
public mm_skill(id)
{
    if(!mm_active())return PLUGIN_HANDLED
    if(!mm_playing(id) || !is_user_alive(id) || g_finished)return PLUGIN_HANDLED
    new Float:now=get_gametime()
    if(now<g_skill_ready[id])
    {
        client_print_color(id,print_team_red,"^4[CoD]^1 Ability ready in ^3%d seconds^1.",floatround(g_skill_ready[id]-now,floatround_ceil));
        return PLUGIN_HANDLED;
    }
    new c=g_class[id]
    if(c==CLASS_JUMPER || c==CLASS_RAMBO){client_print_color(id,print_team_blue,"^4[CoD]^1 Passive class skills: ^3%s^1.",SKILLS[c]);return PLUGIN_HANDLED;}
    if(c==CLASS_NINJA){client_print_color(id,print_team_blue,"^4[CoD]^1 Ninja skills are passive: hold your ^3knife^1 for invisibility to enemies and one-hit knife attacks.");return PLUGIN_HANDLED;}
    if(c==CLASS_BOMBER || c==CLASS_SAPPER)
    {
        if(c==CLASS_BOMBER && mm_has_explosive(id)){mm_detonate(id);g_skill_ready[id]=now+1.0;return PLUGIN_HANDLED;}
        if(g_charges[id]<=0){client_print_color(id,print_team_red,"^4[CoD]^1 No explosives left this life.");return PLUGIN_HANDLED;}
        if(mm_plant(id,c==CLASS_SAPPER)){g_charges[id]--;g_skill_ready[id]=now+1.0;g_until[id]=0.0;client_print_color(id,print_team_blue,"^4[CoD]^1 %s placed. ^4%d^1 remaining this life.",c==CLASS_SAPPER?"Mine":"Dynamite",g_charges[id]);}
        return PLUGIN_HANDLED
    }
    if(c==6 && user_has_weapon(id,CSW_HEGRENADE))
    {
        client_print_color(id,print_team_red,"^4[CoD]^1 You already have an HE grenade.");
        return PLUGIN_HANDLED;
    }
    g_skill_ready[id]=now+25.0;
    g_until[id]=0.0
    switch(c)
    {
        case 0:g_focus_until[id]=now+5.0
        case 1:cs_set_user_bpammo(id,GUN_IDS[c],90)
        case 2,7:
        {
            g_boost_until[id]=now+6.0;
            rg_reset_maxspeed(id);
        }
        case 3:mm_heal(id,35.0)
        case 4:
        {
            new Float:a[3],Float:b[3];
            pev(id,pev_origin,a);
            for(new i=1;i<=MaxClients;i++)if(mm_playing(i) && is_user_alive(i) && cs_get_user_team(id)==cs_get_user_team(i))
            {
                pev(i,pev_origin,b);
                if(get_distance_f(a,b)<=350.0)mm_heal(i,i==id?45.0:30.0);
            }
        }
        case 5:cs_set_user_armor(id,max(75,get_user_armor(id)),CS_ARMOR_KEVLAR)
        case 6:rg_give_item(id,"weapon_hegrenade")
    }
    client_print_color(id,print_team_blue,"^4[CoD]^1 Ability used: ^3%s^1. Cooldown: ^425s^1.",SKILLS[c]);
    return PLUGIN_HANDLED
}
mm_top(id)
{
    new text[1024],len,name[32];
    len=formatex(text,charsmax(text),"CoD:MW match | T %d : %d CT^n^n",g_team_score[1],g_team_score[2]);
    new bool:used[33]
    for(new rank=1;rank<=10;rank++)
    {
        new best;
        for(new i=1;i<=MaxClients;i++)if(mm_playing(i) && !used[i] && (!best || g_kills[i]>g_kills[best]))best=i;
        if(!best)break;
        used[best]=true;
        get_user_name(best,name,charsmax(name));
        len+=formatex(text[len],charsmax(text)-len,"%d. %s | %d kills | %s Lv.%d^n",rank,name,g_kills[best],CLASSES[g_class[best]],mm_level(g_xp[best][g_class[best]]));
    }
    show_motd(id,text,"CoD:MW - Match Scores")
}
public mm_pickup(entity,id)
{
    return g_enabled && mm_active() && id>=1 && id<=MaxClients && is_user_alive(id)?HAM_SUPERCEDE:HAM_IGNORED;
}
public mm_buy_weapon(id,WeaponIdType:weapon)
{
    if(!g_enabled || !mm_active())return HC_CONTINUE;
    SetHookChainReturn(ATYPE_INTEGER,0);
    return HC_SUPERCEDE;
}
public mm_buy_item(id,item)
{
    if(!g_enabled || !mm_active())return HC_CONTINUE;
    return HC_SUPERCEDE;
}
public mm_admin_command(id,level,cid)
{
    if(!mm_active())
    {
        console_print(id,"[CoD] This command is available only in CoD:MW.");
        return PLUGIN_HANDLED;
    }
    if(!cmd_access(id,level,cid,3))return PLUGIN_HANDLED
    new command[32],arg[32],value[20];
    read_argv(0,command,charsmax(command));
    read_argv(1,arg,charsmax(arg));
    read_argv(2,value,charsmax(value))
    new target=cmd_target(id,arg,CMDTARGET_ALLOW_SELF);
    if(!target)return PLUGIN_HANDLED
    if(equal(command,"amx_cod_reset"))
    {
        if(!equal(value,"confirm"))
        {
            console_print(id,"[CoD] Use: amx_cod_reset <player> confirm. Resets selected class only.");
            return PLUGIN_HANDLED;
        }
        g_xp[target][g_class[target]]=0;
        for(new s=0;s<STAT_COUNT;s++)g_stats[target][g_class[target]][s]=0
    }
    else
    {
        if(!is_str_num(value) && !(value[0]=='-' && is_str_num(value[1])))
        {
            console_print(id,"[CoD] Amount must be an integer.");
            return PLUGIN_HANDLED;
        }
        new amount=str_to_num(value)
        if(equal(command,"amx_cod_xp"))
        {
            if(amount<1 || amount>MAX_XP)return PLUGIN_HANDLED;
            mm_award(target,amount,0);
        }
        else if(equal(command,"amx_cod_credits"))g_credits[target]=clamp(g_credits[target]+clamp(amount,-MAX_CREDITS,MAX_CREDITS),0,MAX_CREDITS)
        else if(equal(command,"amx_cod_item"))
        {
            if(amount<0 || amount>ITEM_COUNT)return PLUGIN_HANDLED;
            mm_give_perk(target,amount);
        }
    }
    mm_cap_stats(target);
    mm_save(target);
    new name[32];
    get_user_name(target,name,charsmax(name));
    console_print(id,"[CoD] Updated %s; saved progression.",name);
    client_print_color(target,print_team_blue,"^4[CoD]^1 An admin updated your CoD profile.");
    log_amx("CoD admin #%d executed %s on #%d (%s).",(id?get_user_userid(id):0),command,get_user_userid(target),value);
    return PLUGIN_HANDLED
}
public mm_admin_restart(id,level,cid)
{
    if(!mm_active())return PLUGIN_HANDLED;
    if(cmd_access(id,level,cid,1))mm_new_match();
    return PLUGIN_HANDLED;
}
public mm_admin_menu(id,level,cid)
{
    if(!mm_active() || !id || !cmd_access(id,level,cid,1))return PLUGIN_HANDLED
    new menu=menu_create("CoD admin - select player","mm_admin_select"),name[32],info[12]
    for(new i=1;i<=MaxClients;i++)if(is_user_connected(i))
    {
        get_user_name(i,name,charsmax(name));
        num_to_str(get_user_userid(i),info,charsmax(info));
        menu_additem(menu,name,info);
    }
    menu_display(id,menu);
    return PLUGIN_HANDLED
}
public mm_admin_select(id,menu,item)
{
    if(item==MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    new info[12],name[32],access,callback;
    menu_item_getinfo(menu,item,access,info,charsmax(info),name,charsmax(name),callback);
    menu_destroy(menu)
    if(!is_user_connected(id) || !(get_user_flags(id)&ADMIN_RCON) || !mm_active())return PLUGIN_HANDLED
    console_print(id,"[CoD] Player %s (#%s). Use: amx_cod_xp #%s 100 | amx_cod_credits #%s 100 | amx_cod_item #%s 1 | amx_cod_reset #%s confirm",name,info,info,info,info,info)
    client_print_color(id,print_team_blue,"^4[CoD]^1 Player command templates printed in your console.");
    return PLUGIN_HANDLED
}
public mm_status(id,level,cid)
{
    if(id && (!mm_active() || !cmd_access(id,level,cid,1)))return PLUGIN_HANDLED
    console_print(id,"[CoD] version=%s active=%d enabled=%d finished=%d classes=%d perks=%d vault=%d T=%d CT=%d",PLUGIN_VERSION,mm_active(),g_enabled,g_finished,CLASS_COUNT,ITEM_COUNT,g_vault!=INVALID_HANDLE,g_team_score[1],g_team_score[2])
    for(new i=1;i<=MaxClients;i++)if(is_user_connected(i))console_print(id,"[CoD] client=%d profile_saved=%d class=%s level=%d xp=%d points=%d credits=%d perk=%d durability=%d alive=%d",i,g_loaded[i],CLASSES[g_class[i]],mm_level(g_xp[i][g_class[i]]),g_xp[i][g_class[i]],mm_points(i),g_credits[i],g_item[i],g_durability[i],is_user_alive(i))
    for(new i=1;i<=MaxClients;i++)if(is_user_connected(i))console_print(id,"[CoD Class] client=%d prompted=%d charges=%d auto_bhop=%d",i,g_prompted[i],g_charges[i],get_member(i,m_bAutoBunnyHopping))
    return PLUGIN_HANDLED
}
public mm_selftest()
{
    new ok=(sizeof CLASSES==CLASS_COUNT && sizeof GUNS==CLASS_COUNT && sizeof GUN_IDS==CLASS_COUNT && sizeof BASE_HP==CLASS_COUNT && sizeof SKILLS==CLASS_COUNT);
    if(mm_level(0)!=1 || mm_level(99)!=1 || mm_level(100)!=2 || mm_level(MAX_XP)!=100)ok=0
    for(new c=0;c<CLASS_COUNT;c++)if(get_weaponid(GUNS[c])!=GUN_IDS[c])ok=0
    server_print("[CoD Test] passed=%d classes=%d perks=%d max_level=%d stat_cap=%d lifecycle_active=%d",ok,CLASS_COUNT,ITEM_COUNT,MAX_LEVEL,STAT_CAP,g_enabled)
}
public mm_rematch_finished(mode,change_map)
{
    if(MmMode:mode==MM_MODE_COD && mm_active() && g_enabled && !change_map)mm_new_match();
}

mm_cap_stats(id)
{
    if(!is_user_alive(id))return
    new Float:hp;pev(id,pev_health,hp)
    if(hp>mm_maxhp(id))set_pev(id,pev_health,mm_maxhp(id))
    rg_reset_maxspeed(id)
}

public mm_class_prompt(task)
{
    new id=task-TASK_PROMPT
    if(!g_enabled || !mm_active() || !mm_playing(id) || !is_user_alive(id) || is_user_bot(id) || g_prompted[id])return
    g_prompted[id]=true;g_initial_choice_until[id]=get_gametime()+20.0
    mm_class_menu(id)
    client_print_color(id,print_team_blue,"^4[CoD]^1 Choose your class. Choose now to start with that class. Later changes apply on respawn. ^3/class^1 reopens the menu.")
}

mm_apply_gravity(id)
{
    new Float:gravity=g_class[id]==CLASS_BOMBER?0.5:g_old_gravity[id]
    if(g_item[id]==5)gravity=floatmin(gravity,0.8)
    set_pev(id,pev_gravity,gravity)
}
bool:mm_is_explosive(entity)
{
    if(!pev_valid(entity))return false
    new classname[32];pev(entity,pev_classname,classname,charsmax(classname))
    return bool:equal(classname,EXPLOSIVE_CLASS)
}
mm_remove_explosives(owner)
{
    new entity
    while((entity=engfunc(EngFunc_FindEntityByString,entity,"classname",EXPLOSIVE_CLASS))>0)
        if(!owner || pev(entity,pev_owner)==owner)engfunc(EngFunc_RemoveEntity,entity)
}
bool:mm_has_explosive(owner)
{
    new entity
    while((entity=engfunc(EngFunc_FindEntityByString,entity,"classname",EXPLOSIVE_CLASS))>0)
        if(pev(entity,pev_owner)==owner)return true
    return false
}
bool:mm_plant(id,bool:mine)
{
    if(!(pev(id,pev_flags)&FL_ONGROUND)){client_print_color(id,print_team_red,"^4[CoD]^1 Stand on the ground to place explosives.");return false;}
    new Float:start[3],Float:angle[3],Float:direction[3],Float:down[3],Float:point[3]
    pev(id,pev_origin,start);pev(id,pev_v_angle,angle);angle[0]=0.0;angle[2]=0.0
    engfunc(EngFunc_MakeVectors,angle);global_get(glb_v_forward,direction)
    for(new i=0;i<2;i++)start[i]+=direction[i]*42.0
    down=start;down[2]-=100.0
    new trace=create_tr2();engfunc(EngFunc_TraceLine,start,down,IGNORE_MONSTERS,id,trace)
    new Float:fraction;get_tr2(trace,TR_flFraction,fraction);get_tr2(trace,TR_vecEndPos,point)
    new bool:blocked=bool:get_tr2(trace,TR_StartSolid);free_tr2(trace)
    if(blocked || fraction>=1.0){client_print_color(id,print_team_red,"^4[CoD]^1 No clear ground ahead.");return false;}
    point[2]+=6.0
    new entity=engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"))
    if(!pev_valid(entity))return false
    set_pev(entity,pev_classname,EXPLOSIVE_CLASS);set_pev(entity,pev_owner,id)
    set_pev(entity,pev_iuser1,mine?1:2);set_pev(entity,pev_fuser1,get_gametime()+1.5)
    engfunc(EngFunc_SetModel,entity,"models/w_hegrenade.mdl");engfunc(EngFunc_SetOrigin,entity,point)
    set_pev(entity,pev_solid,SOLID_NOT);set_pev(entity,pev_movetype,MOVETYPE_NONE)
    set_pev(entity,pev_renderfx,kRenderFxGlowShell);set_pev(entity,pev_renderamt,8.0)
    if(cs_get_user_team(id)==CS_TEAM_T)set_pev(entity,pev_rendercolor,Float:{255.0,60.0,40.0})
    else set_pev(entity,pev_rendercolor,Float:{40.0,100.0,255.0})
    set_pev(entity,pev_nextthink,get_gametime()+0.2)
    return true
}
public mm_explosive_think(entity)
{
    if(!mm_is_explosive(entity))return FMRES_IGNORED
    new owner=pev(entity,pev_owner)
    if(!g_enabled || !mm_active() || !mm_playing(owner) || !is_user_alive(owner)){engfunc(EngFunc_RemoveEntity,entity);return FMRES_SUPERCEDE;}
    new Float:armed;pev(entity,pev_fuser1,armed)
    if(pev(entity,pev_iuser1)==1 && get_gametime()>=armed && !g_finished)
    {
        new Float:a[3],Float:b[3];pev(entity,pev_origin,a)
        for(new id=1;id<=MaxClients;id++)if(mm_enemy(owner,id) && is_user_alive(id))
        {
            pev(id,pev_origin,b)
            if(get_distance_f(a,b)<=110.0 && mm_blast_visible(entity,id)){mm_blast(entity);return FMRES_SUPERCEDE;}
        }
    }
    set_pev(entity,pev_nextthink,get_gametime()+0.2)
    return FMRES_SUPERCEDE
}
bool:mm_blast_visible(entity,id)
{
    new Float:a[3],Float:b[3];pev(entity,pev_origin,a);a[2]+=8.0;pev(id,pev_origin,b)
    new trace=create_tr2();engfunc(EngFunc_TraceLine,a,b,IGNORE_MONSTERS,entity,trace)
    new Float:fraction;get_tr2(trace,TR_flFraction,fraction);free_tr2(trace)
    return fraction>=0.99
}
mm_detonate(owner)
{
    // Restart lookup after removal; entity indices may be reused during damage forwards.
    new entity
    while((entity=engfunc(EngFunc_FindEntityByString,0,"classname",EXPLOSIVE_CLASS))>0)
    {
        // Collect only this owner's charges; other players' entities remain untouched.
        new chosen
        do {if(pev(entity,pev_owner)==owner){chosen=entity;break;}} while((entity=engfunc(EngFunc_FindEntityByString,entity,"classname",EXPLOSIVE_CLASS))>0)
        if(!chosen)break
        mm_blast(chosen)
    }
}
mm_blast(entity)
{
    new owner=pev(entity,pev_owner),kind=pev(entity,pev_iuser1);new Float:origin[3];pev(entity,pev_origin,origin)
    if(!g_enabled || !mm_active() || g_finished || !mm_playing(owner)){engfunc(EngFunc_RemoveEntity,entity);return;}
    // Disable the charge before damage callbacks to avoid re-entry/chained think.
    set_pev(entity,pev_nextthink,0.0);set_pev(entity,pev_iuser1,0)
    engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,origin,0);write_byte(TE_EXPLOSION)
    engfunc(EngFunc_WriteCoord,origin[0]);engfunc(EngFunc_WriteCoord,origin[1]);engfunc(EngFunc_WriteCoord,origin[2])
    write_short(g_explosion_sprite);write_byte(20);write_byte(15);write_byte(0);message_end()
    new Float:point[3],Float:radius=kind==1?200.0:260.0,Float:maximum=kind==1?130.0:180.0
    for(new id=1;id<=MaxClients;id++)if(mm_enemy(owner,id) && is_user_alive(id))
    {
        pev(id,pev_origin,point);new Float:distance=get_distance_f(origin,point)
        if(distance<radius && mm_blast_visible(entity,id))ExecuteHamB(Ham_TakeDamage,id,entity,owner,maximum*(1.0-distance/radius),DMG_BLAST)
        if(!pev_valid(entity))return
    }
    if(pev_valid(entity))engfunc(EngFunc_RemoveEntity,entity)
}
