#include <amxmodx>
#include <amxmisc>
#include <nvault>
#include <cod>
#include <mm_mode_api>
#define PLUGIN "Multi-Mode CoD Class Access"
#define PLUGIN_VERSION "1.1.0"
#define AUTHOR "ApexiumForge"
new g_vault=INVALID_HANDLE,g_tier[33],g_class_tier[128],g_target[33];
new const TIER_NAMES[][]={"Standard","VIP","Super VIP"};
public plugin_init()
{
    register_plugin(PLUGIN,PLUGIN_VERSION,AUTHOR);
    g_vault=nvault_open("mm_cod_class_access");if(g_vault==INVALID_HANDLE)set_fail_state("Cannot open CoD class access storage");
    register_concmd("amx_cod_access","mm_access_command",ADMIN_RCON,"<player> <none|vip|super> - persistent CoD class access");
    register_concmd("amx_cod_accessmenu","mm_access_menu",ADMIN_RCON,"- manage friends' CoD class access");
    register_clcmd("say /codaccess","mm_my_access",0,"- show your CoD class access");
    register_clcmd("say_team /codaccess","mm_my_access");
    register_srvcmd("mm_cod_access_status","mm_status");
}
public plugin_cfg()
{
    new const names[][]={"Phantom","Priest","Wolverine","Mad Max","Engineer","SWAT","Ninja"};
    new const tiers[]={1,1,2,2,1,2,2};
    for(new i=0;i<sizeof names;i++){new c=cod_get_class_id(names[i]);if(c>0 && c<sizeof g_class_tier)g_class_tier[c]=tiers[i];}
}
public client_connect(id){g_tier[id]=0;g_target[id]=0;}
public client_authorized(id)
{
    if(is_user_bot(id) || is_user_hltv(id))return;
    new auth[40];get_user_authid(id,auth,charsmax(auth));
    if(equal(auth,"STEAM_ID_PENDING") || equal(auth,"STEAM_ID_LAN") || equal(auth,"VALVE_ID_LAN"))return;
    g_tier[id]=clamp(nvault_get(g_vault,auth),0,2);
}
public client_disconnected(id){g_tier[id]=0;g_target[id]=0;}
mm_effective_tier(id){return get_user_flags(id)&ADMIN_RCON?2:g_tier[id];}
public mm_cod_class_check(id,class)
{
    if(!is_user_connected(id) || class<1 || class>=sizeof g_class_tier)return COD_CONTINUE;
    return mm_effective_tier(id)>=g_class_tier[class]?COD_CONTINUE:COD_STOP;
}
public mm_my_access(id)
{
    if(mm_get_active_mode()!=MM_MODE_COD)return PLUGIN_CONTINUE;
    client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Your class access: ^3%s^1.",TIER_NAMES[mm_effective_tier(id)]);
    return PLUGIN_HANDLED;
}
public mm_access_command(id,level,cid)
{
    if(mm_get_active_mode()!=MM_MODE_COD || !cmd_access(id,level,cid,3))return PLUGIN_HANDLED;
    new arg[40],tier[12];read_argv(1,arg,charsmax(arg));read_argv(2,tier,charsmax(tier));
    new value=-1;if(equali(tier,"none"))value=0;else if(equali(tier,"vip"))value=1;else if(equali(tier,"super"))value=2;
    if(value<0){console_print(id,"Usage: amx_cod_access <player> <none|vip|super>");return PLUGIN_HANDLED;}
    new target=cmd_target(id,arg,CMDTARGET_ALLOW_SELF);if(target)mm_grant(id,target,value);
    return PLUGIN_HANDLED;
}
mm_grant(admin,target,tier)
{
    new auth[40],value[4],name[32];get_user_authid(target,auth,charsmax(auth));
    if(is_user_bot(target) || equal(auth,"STEAM_ID_PENDING") || equal(auth,"STEAM_ID_LAN") || equal(auth,"VALVE_ID_LAN"))
    {console_print(admin,"CoD access requires an authenticated player; try again after connection completes.");return;}
    num_to_str(tier,value,charsmax(value));nvault_set(g_vault,auth,value);g_tier[target]=tier;
    get_user_name(target,name,charsmax(name));
    if(mm_cod_class_check(target,cod_get_user_class(target))==COD_STOP)cod_set_user_class(target,1,true);
    client_print_color(target,print_team_blue,"^4[^1CoD^4]^1 Your class access is now ^3%s^1.",TIER_NAMES[mm_effective_tier(target)]);
    console_print(admin,"[CoD] %s: stored class access = %s.",name,TIER_NAMES[tier]);
    log_amx("CoD class access changed: admin_userid=%d target_userid=%d tier=%d",admin?get_user_userid(admin):0,get_user_userid(target),tier);
}
public mm_access_menu(id,level,cid)
{
    if(mm_get_active_mode()!=MM_MODE_COD || !cmd_access(id,level,cid,1))return PLUGIN_HANDLED;
    new menu=menu_create("CoD | Friends' class access","mm_player_selected"),name[32],label[80],info[8];
    for(new player=1;player<=MaxClients;player++)if(is_user_connected(player) && !is_user_bot(player) && !is_user_hltv(player))
    {get_user_name(player,name,charsmax(name));formatex(label,charsmax(label),"%s \d[%s]",name,TIER_NAMES[mm_effective_tier(player)]);num_to_str(get_user_userid(player),info,charsmax(info));menu_additem(menu,label,info);}
    menu_display(id,menu);return PLUGIN_HANDLED;
}
public mm_player_selected(id,menu,item)
{
    if(item==MENU_EXIT || !is_user_connected(id) || !(get_user_flags(id)&ADMIN_RCON) || mm_get_active_mode()!=MM_MODE_COD){menu_destroy(menu);return PLUGIN_HANDLED;}
    new info[8],access,callback;menu_item_getinfo(menu,item,access,info,charsmax(info),_,_,callback);menu_destroy(menu);g_target[id]=str_to_num(info);
    menu=menu_create("CoD | Set class access","mm_tier_selected");menu_additem(menu,"Standard only");menu_additem(menu,"VIP classes");menu_additem(menu,"VIP + Super VIP classes");menu_display(id,menu);return PLUGIN_HANDLED;
}
public mm_tier_selected(id,menu,item)
{
    menu_destroy(menu);
    if(item==MENU_EXIT || !is_user_connected(id) || !(get_user_flags(id)&ADMIN_RCON) || mm_get_active_mode()!=MM_MODE_COD)return PLUGIN_HANDLED;
    new target=find_player("k",g_target[id]);if(target)mm_grant(id,target,item);else client_print(id,print_chat,"That player disconnected; reopen the access menu.");
    return PLUGIN_HANDLED;
}
public mm_status(){new counts[3];for(new c=1;c<sizeof g_class_tier;c++)if(g_class_tier[c])counts[g_class_tier[c]]++;server_print("[CoD Access] vip_classes=%d super_classes=%d vault=%d admin_override=ADMIN_RCON",counts[1],counts[2],g_vault!=INVALID_HANDLE);}
public plugin_end(){if(g_vault!=INVALID_HANDLE)nvault_close(g_vault);}
