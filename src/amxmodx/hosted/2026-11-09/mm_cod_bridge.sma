/* Integration only: gameplay/classes/items are the O'Zone upstream engine. */
#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <nvault>
#include <cod>
#include <mm_mode_api>
#include <mm_voting_api>
#define RESPAWN_TASK 918100
new Float:g_death_origin[33][3],Float:g_dead_at[33];
new g_honor[33],g_vault=-1,g_key[33][48],Float:g_until[33],g_score[4],bool:g_finished
public plugin_natives()
{
    register_native("cod_check_account","mm_true")
    register_native("cod_get_user_honor","mm_honor_get")
    register_native("cod_set_user_honor","mm_honor_set")
    register_native("cod_add_user_honor","mm_honor_add")
    new const unused[][]=
    {
        "cod_get_user_clan","cod_get_clan_name","cod_get_user_clan_bonus","cod_get_user_vip","cod_get_user_mission_need","cod_get_user_mission_progress"
    }
    for(new i=0;i<sizeof unused;i++)register_native(unused[i],"mm_zero")
    register_native("cod_get_user_mission","mm_none")
    register_native("cod_get_user_time_text","mm_time")
    register_native("mm_cod_is_protected","mm_protected")
    register_native("mm_cod_rescue","mm_rescue_native")
    register_native("mm_cod_end_protection","mm_end_protection")
}
public mm_true(plugin,params)
{
    return 1;
}
public mm_zero(plugin,params)
{
    return 0;
}
public mm_none(plugin,params)
{
    return -1;
}
public mm_time(plugin,params)
{
    set_string(2,"",get_param(3));
    return 0;
}
public mm_protected(plugin,params)
{
    new id=get_param(1);
    return id>=1 && id<=MaxClients && g_until[id]>get_gametime();
}
public mm_honor_get(plugin,params)
{
    new id=get_param(1);
    return id>=1 && id<=MaxClients?g_honor[id]:0;
}
public mm_honor_set(plugin,params)
{
    new id=get_param(1);
    if(id>=1 && id<=MaxClients)
    {
        g_honor[id]=clamp(get_param(2),0,100000);
        mm_save(id);
    }
    return 0;
}
public mm_honor_add(plugin,params)
{
    new id=get_param(1);
    if(id>=1 && id<=MaxClients)
    {
        g_honor[id]=clamp(g_honor[id]+get_param(2),0,100000);
        mm_save(id);
    }
    return 0;
}
public plugin_init()
{
    register_plugin("Multi-Mode CoD Upstream Bridge","2.3.3","Torbeshi")
    RegisterHookChain(RG_BuyWeaponByWeaponID,"mm_buy_weapon",false)
    RegisterHookChain(RG_BuyItem,"mm_buy_item",false)
    RegisterHam(Ham_Spawn,"player","mm_spawn",1)
    RegisterHam(Ham_Killed,"player","mm_killed",1)
    RegisterHam(Ham_TakeDamage,"player","mm_damage")
    register_forward(FM_CmdStart,"mm_buttons")
    register_forward(FM_AddToFullPack,"mm_glow",1)
    g_vault=nvault_open("mm_cod_upstream_honor")
    new const commands[][]=
    {
        "cod","codclass","codclasses","codstats","codreset","codperk","codperks","coddrop","codshop","codskill","codtop","codhelp"
    }
    new command[48]
    for(new i=0;i<sizeof commands;i++)
    {
        formatex(command,charsmax(command),"say /%s",commands[i]);
        register_clcmd(command,"mm_chat",0,"- CoD:MW player control")
        formatex(command,charsmax(command),"say_team /%s",commands[i]);
        register_clcmd(command,"mm_chat")
    }
    register_clcmd("chooseteam","mm_m_menu")
    register_clcmd("cod_skill","mm_skill",0,"- use upstream class ability")
    register_concmd("amx_codmenu","mm_admin_menu",ADMIN_RCON,"- CoD admin player selector")
    register_concmd("amx_cod_xp","mm_admin",ADMIN_RCON,"<player> <amount> - add upstream class XP")
    register_concmd("amx_cod_level","mm_admin",ADMIN_RCON,"<player> <level> - set upstream class level")
    register_concmd("amx_cod_credits","mm_admin",ADMIN_RCON,"<player> <amount> - add Gold")
    register_concmd("amx_cod_gold","mm_admin",ADMIN_RCON,"<player> <amount> - add Gold")
    register_concmd("amx_cod_item","mm_admin",ADMIN_RCON,"<player> <item ID> - give upstream item")
    register_concmd("amx_cod_reset","mm_admin",ADMIN_RCON,"<player> confirm - refund allocated skill points")
    register_concmd("amx_cod_restart","mm_restart",ADMIN_CFG,"- restart CoD team score")
    register_concmd("amx_cod_status","mm_status",ADMIN_CFG,"- upstream engine status")
    register_srvcmd("mm_cod_status","mm_status")
    register_srvcmd("mm_cod_selftest","mm_selftest")
}
bool:mm_active()
{
    return mm_get_active_mode()==MM_MODE_COD;
}
bool:mm_playing(id)
{
    return id>=1 && id<=MaxClients && is_user_connected(id) && (cs_get_user_team(id)==CS_TEAM_T || cs_get_user_team(id)==CS_TEAM_CT);
}
public client_connect(id)
{
    g_dead_at[id]=0.0;
    g_honor[id]=0;
    g_key[id][0]=0;
    g_until[id]=0.0;
}
public client_authorized(id)
{
    if(is_user_bot(id) || is_user_hltv(id) || g_vault==INVALID_HANDLE)return
    new auth[40];
    get_user_authid(id,auth,charsmax(auth));
    if(equal(auth,"STEAM_ID_PENDING") || equal(auth,"STEAM_ID_LAN") || equal(auth,"VALVE_ID_LAN"))return
    formatex(g_key[id],charsmax(g_key[]),"v1:%s",auth);
    g_honor[id]=clamp(nvault_get(g_vault,g_key[id]),0,100000)
}
mm_save(id)
{
    if(g_vault!=INVALID_HANDLE && g_key[id][0])
    {
        new value[16];
        num_to_str(g_honor[id],value,charsmax(value));
        nvault_set(g_vault,g_key[id],value);
    }
}
public client_disconnected(id)
{
    mm_save(id);
    remove_task(RESPAWN_TASK+id);
    g_key[id][0]=0;
}
public plugin_end()
{
    for(new id=1;id<=MaxClients;id++)mm_save(id);
    if(g_vault!=INVALID_HANDLE)nvault_close(g_vault);
}
public mm_mode_transition_started(old_mode,new_mode)
{
    if(MmMode:old_mode!=MM_MODE_COD)return
    for(new id=1;id<=MaxClients;id++)
    {
        remove_task(RESPAWN_TASK+id);
        g_until[id]=0.0;
        g_dead_at[id]=0.0;
    }
    remove_task(918000)
}
public mm_mode_changed(old_mode,new_mode)
{
    if(MmMode:new_mode!=MM_MODE_COD)return
    g_finished=false;
    g_score[1]=0;
    g_score[2]=0
    for(new id=1;id<=MaxClients;id++)if(mm_playing(id))
    {
        if(is_user_alive(id))mm_spawn(id);
        else set_task(0.5,"mm_respawn",RESPAWN_TASK+id);
    }
}
public mm_spawn(id)
{
    if(!mm_active() || !mm_playing(id) || !is_user_alive(id))return HAM_IGNORED
    g_dead_at[id]=0.0;
    g_until[id]=get_gametime()+2.0
    return HAM_IGNORED
}
public mm_killed(id,killer,gib)
{
    if(!mm_active() || !mm_playing(id))return HAM_IGNORED
    g_until[id]=0.0;
    g_dead_at[id]=get_gametime();pev(id,pev_origin,g_death_origin[id]);
    remove_task(RESPAWN_TASK+id);
    if(!g_finished)set_task(2.0,"mm_respawn",RESPAWN_TASK+id)
    return HAM_IGNORED
}
public mm_respawn(task)
{
    new id=task-RESPAWN_TASK;
    if(mm_active() && !g_finished && mm_playing(id) && !is_user_alive(id) && mm_get_transition_state()==MM_TRANSITION_IDLE)rg_round_respawn(id);
}
public mm_damage(victim,inflictor,attacker,Float:damage,bits)
{
    if(!mm_active())return HAM_IGNORED
    if(g_finished || g_until[victim]>get_gametime())return HAM_SUPERCEDE
    if(attacker!=victim && mm_playing(attacker) && mm_playing(victim) && cs_get_user_team(attacker)==cs_get_user_team(victim))return HAM_SUPERCEDE
    return HAM_IGNORED
}
public mm_buttons(id,command,seed)
{
    if(mm_active() && is_user_alive(id) && (get_uc(command,UC_Buttons)&(IN_ATTACK|IN_ATTACK2)))g_until[id]=0.0;
    return FMRES_IGNORED;
}
public mm_glow(packet,e,entity,host,hostflags,player,pset)
{
    if(!mm_active() || !player || entity<1 || entity>MaxClients || !is_user_alive(entity))return FMRES_IGNORED
    if(host>=1 && host<=MaxClients && is_user_alive(host) && cs_get_user_team(host)==cs_get_user_team(entity))
    {
        set_es(packet,ES_RenderMode,kRenderNormal);
        set_es(packet,ES_RenderAmt,255);
        set_es(packet,ES_RenderFx,kRenderFxNone)
    }
    if(g_until[entity]>get_gametime())
    {
        set_es(packet,ES_RenderFx,kRenderFxGlowShell);
        set_es(packet,ES_RenderAmt,12);
        set_es(packet,ES_RenderColor,cs_get_user_team(entity)==CS_TEAM_T?
        {
            255,70,50
        }
        :
        {
            60,120,255
        }
        );
    }
    return FMRES_IGNORED
}
public cod_killed(killer,victim,weapon,hitPlace)
{
    if(!mm_active() || !mm_playing(killer) || !mm_playing(victim) || killer==victim || cs_get_user_team(killer)==cs_get_user_team(victim))return
    g_honor[killer]=min(100000,g_honor[killer]+10);
    mm_save(killer);
    g_score[_:cs_get_user_team(killer)]++

}
public mm_end_vote()
{
    if(mm_active() && !mm_voting_start_rematch(MM_MODE_COD))mm_new_match();
}
public mm_rematch_finished(mode,change_map)
{
    if(MmMode:mode==MM_MODE_COD && mm_active() && !change_map)mm_new_match();
}
mm_new_match()
{
    g_finished=false;
    g_score[1]=0;
    g_score[2]=0;
    for(new id=1;id<=MaxClients;id++)if(mm_playing(id))rg_round_respawn(id);
}
mm_call(const function[],id,arg=-999,third=-999)
{
    if(callfunc_begin(function,"cod_mod.amxx")!=1)return 0
    callfunc_push_int(id);
    if(arg!=-999)callfunc_push_int(arg);
    if(third!=-999)callfunc_push_int(third)
    return callfunc_end()
}
public mm_chat(id)
{
    if(!mm_active())return PLUGIN_CONTINUE
    new text[40];
    read_args(text,charsmax(text));
    remove_quotes(text)
    if(equal(text,"/codclass"))mm_call("select_faction",id)
    else if(equal(text,"/codclasses"))mm_call("display_classes_description",id,0,0)
    else if(equal(text,"/codstats"))mm_call("assign_points",id,0)
    else if(equal(text,"/codreset"))mm_call("reset_stats",id)
    else if(equal(text,"/codperk"))mm_call("display_item_description",id)
    else if(equal(text,"/codperks"))mm_call("display_items_description",id,0,0)
    else if(equal(text,"/coddrop"))mm_call("drop_item",id)
    else if(equal(text,"/codskill"))mm_skill(id)
    else if(equal(text,"/codtop"))mm_call("level_top",id)
    else if(equal(text,"/codshop"))mm_shop(id)
    else if(equal(text,"/codhelp"))show_motd(id,"addons/amxmodx/configs/mm_cod_help.html","CoD:MW")
    else mm_menu(id)
    return PLUGIN_HANDLED
}
mm_menu(id)
{
    new menu=menu_create("\yCoD:MW \d| \wPlayer menu","mm_menu_pick");
    menu_additem(menu,"Choose class");
    menu_additem(menu,"Skill points");
    menu_additem(menu,"Class descriptions");
    menu_additem(menu,"Current item");
    menu_additem(menu,"All item descriptions");
    menu_additem(menu,"Shops: Gold / cash");
    menu_additem(menu,"Change team / spectate","team");
    if(get_user_flags(id)&ADMIN_RCON)menu_additem(menu,"\rManage VIP class access");
    menu_additem(menu,"Help / commands","help");
    menu_display(id,menu);
}
public mm_menu_pick(id,menu,item)
{
    new info[12],access,callback;
    if(item>=0)menu_item_getinfo(menu,item,access,info,charsmax(info),_,_,callback);
    menu_destroy(menu);
    if(equal(info,"help")){
        if(is_user_connected(id) && mm_active())show_motd(id,"addons/amxmodx/configs/mm_cod_help.html","CoD:MW");
        return PLUGIN_HANDLED;
    }
    if(equal(info,"team")){
        if(is_user_connected(id) && mm_active())engclient_cmd(id,"chooseteam");
        return PLUGIN_HANDLED;
    }
    if(item<0 || !is_user_connected(id) || !mm_active())return PLUGIN_HANDLED;
    switch(item)
    {
        case 0:mm_call("select_faction",id);
        case 1:mm_call("assign_points",id,0);
        case 2:mm_call("display_classes_description",id,0,0);
        case 3:mm_call("display_item_description",id);
        case 4:mm_call("display_items_description",id,0,0);
        case 5:mm_shop(id);
        case 7:if(get_user_flags(id)&ADMIN_RCON && callfunc_begin("mm_access_menu","mm_cod_access.amxx")==1){callfunc_push_int(id);callfunc_push_int(ADMIN_RCON);callfunc_push_int(0);callfunc_end();}
    }
    return PLUGIN_HANDLED;
}
public mm_skill(id)
{
    if(mm_active() && is_user_alive(id))mm_call("use_class",id);
    return PLUGIN_HANDLED;
}
mm_shop(id)
{
    if(callfunc_begin("mm_shop_hub","mm_cod_shop.amxx")==1){callfunc_push_int(id);callfunc_end();}
}
public mm_admin_menu(id,level,cid)
{
    if(!mm_active() || !id || !cmd_access(id,level,cid,1))return PLUGIN_HANDLED;
    new menu=menu_create("CoD admin - select player","mm_admin_pick"),name[32],key[12];
    for(new i=1;i<=MaxClients;i++)if(is_user_connected(i))
    {
        get_user_name(i,name,charsmax(name));
        num_to_str(get_user_userid(i),key,charsmax(key));
        menu_additem(menu,name,key);
    }
    menu_display(id,menu);
    return PLUGIN_HANDLED;
}
public mm_admin_pick(id,menu,item)
{
    if(item<0)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    new key[12],name[32],a,c;
    menu_item_getinfo(menu,item,a,key,charsmax(key),name,charsmax(name),c);
    menu_destroy(menu);
    if(mm_active() && is_user_connected(id) && (get_user_flags(id)&ADMIN_RCON))console_print(id,"[CoD] %s (#%s): amx_cod_xp #%s 100 | amx_cod_level #%s 10 | amx_cod_item #%s 1 | amx_cod_reset #%s confirm",name,key,key,key,key,key);
    return PLUGIN_HANDLED;
}
public mm_admin(id,level,cid)
{
    if(!mm_active())
    {
        console_print(id,"[CoD] Available only in CoD:MW.");
        return PLUGIN_HANDLED;
    }
    if(!cmd_access(id,level,cid,3))return PLUGIN_HANDLED
    new cmd[32],arg[40],value[20];
    read_argv(0,cmd,charsmax(cmd));
    read_argv(1,arg,charsmax(arg));
    read_argv(2,value,charsmax(value));
    new target=cmd_target(id,arg,CMDTARGET_ALLOW_SELF);
    if(!target)return PLUGIN_HANDLED
    if(!cod_get_user_class(target))
    {
        console_print(id,"[CoD] Player must select a class first.");
        return PLUGIN_HANDLED;
    }
    if(equal(cmd,"amx_cod_reset"))
    {
        if(equal(value,"confirm"))mm_call("reset_points",target);
        else console_print(id,"[CoD] Add confirm to refund allocated points.");
    }
    else
    {
        if(!is_str_num(value))
        {
            console_print(id,"[CoD] Use a non-negative integer.");
            return PLUGIN_HANDLED;
        }
        new amount=str_to_num(value)
        if(equal(cmd,"amx_cod_xp"))cod_set_user_exp(target,cod_get_user_exp(target)+clamp(amount,0,1000000))
        else if(equal(cmd,"amx_cod_level"))cod_set_user_exp(target,cod_get_level_exp(clamp(amount,1,get_cvar_num("cod_max_level"))-1))
        else if((equal(cmd,"amx_cod_credits") || equal(cmd,"amx_cod_gold")))
        {
            g_honor[target]=min(100000,g_honor[target]+clamp(amount,0,100000));
            mm_save(target);
        }
        else if(equal(cmd,"amx_cod_item"))cod_set_user_item(target,clamp(amount,0,cod_get_items_num()),RANDOM,true)
    }
    console_print(id,"[CoD] Profile updated.");
    return PLUGIN_HANDLED
}
public mm_restart(id,level,cid)
{
    if(mm_active() && cmd_access(id,level,cid,1))mm_new_match();
    return PLUGIN_HANDLED;
}
public mm_status(id,level,cid)
{
    if(id && (!mm_active() || !cmd_access(id,level,cid,1)))return PLUGIN_HANDLED;
    callfunc_begin("mm_upstream_status","cod_mod.amxx");
    callfunc_end();
    server_print("[CoD Bridge] mode=%d classes=%d items=%d score=%d:%d",_:mm_get_active_mode(),cod_get_classes_num(),cod_get_items_num(),g_score[1],g_score[2]);
    return PLUGIN_HANDLED;
}
public mm_selftest()
{
    server_print("[CoD Points] points_per_level=%d level_1_budget=0 level_2_budget=%d level_3_budget=%d",get_cvar_num("cod_points_per_level"),get_cvar_num("cod_points_per_level"),2*get_cvar_num("cod_points_per_level"));
}

public mm_buy_weapon(id,WeaponIdType:weapon)
{
    if(!mm_active())return HC_CONTINUE
    SetHookChainReturn(ATYPE_INTEGER,0)
    return HC_SUPERCEDE
}
public mm_buy_item(id,item)
{
    return mm_active()?HC_SUPERCEDE:HC_CONTINUE
}

public mm_rescue_native(plugin,params)
{
    new priest=get_param(1);new Float:range=get_param_f(2);
    if(!mm_active() || !mm_playing(priest) || !is_user_alive(priest))return 0;
    new Float:origin[3],Float:candidate[3];pev(priest,pev_origin,origin);
    new target,Float:nearest=range;
    for(new id=1;id<=MaxClients;id++)
    {
        if(id==priest || !mm_playing(id) || is_user_alive(id) || cs_get_user_team(id)!=cs_get_user_team(priest) || g_dead_at[id]<=0.0 || get_gametime()-g_dead_at[id]>2.1)continue;
        new Float:distance=get_distance_f(origin,g_death_origin[id]);
        if(distance<nearest){nearest=distance;target=id;}
    }
    if(!target)return 0;
    new bool:space;
    new const Float:offsets[][]={{64.0,0.0},{-64.0,0.0},{0.0,64.0},{0.0,-64.0}};
    for(new i=0;i<sizeof offsets;i++)
    {
        candidate[0]=origin[0]+offsets[i][0];candidate[1]=origin[1]+offsets[i][1];candidate[2]=origin[2]+8.0;
        new tr=create_tr2();engfunc(EngFunc_TraceHull,candidate,candidate,DONT_IGNORE_MONSTERS,HULL_HUMAN,target,tr);
        space=!get_tr2(tr,TR_StartSolid) && !get_tr2(tr,TR_AllSolid);free_tr2(tr);
        if(space)
        {
            tr=create_tr2();engfunc(EngFunc_TraceHull,origin,candidate,DONT_IGNORE_MONSTERS,HULL_HUMAN,priest,tr);
            new Float:path;get_tr2(tr,TR_flFraction,path);free_tr2(tr);space=path>=1.0;
        }
        if(space)
        {
            new Float:end[3];end[0]=candidate[0];end[1]=candidate[1];end[2]=candidate[2]-96.0;
            tr=create_tr2();engfunc(EngFunc_TraceLine,candidate,end,IGNORE_MONSTERS,target,tr);
            new Float:fraction,Float:normal[3];get_tr2(tr,TR_flFraction,fraction);get_tr2(tr,TR_vecPlaneNormal,normal);free_tr2(tr);
            space=fraction<1.0 && normal[2]>0.7;
        }
        if(space)break;
    }
    if(!space)return 0;
    remove_task(RESPAWN_TASK+target);g_dead_at[target]=0.0;
    rg_round_respawn(target);
    if(!is_user_alive(target))return 0;
    engfunc(EngFunc_SetOrigin,target,candidate);
    new name[32];get_user_name(target,name,charsmax(name));
    client_print_color(priest,target,"^4[^1CoD^4]^1 Rescued ^3%s^1 beside you!",name);
    client_print_color(target,priest,"^4[^1CoD^4]^1 A ^3Priest^1 rescued you beside them.");
    return target;
}

public mm_end_protection(plugin,params){new id=get_param(1);if(mm_active() && id>=1 && id<=MaxClients)g_until[id]=0.0;return 0;}

public mm_m_menu(id)
{
    // Default M sends chooseteam. Allow initial team selection normally.
    if(!mm_active() || !mm_playing(id))return PLUGIN_CONTINUE;
    mm_menu(id);
    return PLUGIN_HANDLED;
}
