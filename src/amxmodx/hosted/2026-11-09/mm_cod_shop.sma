#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <cod>
#include <mm_mode_api>
native mm_cod_add_xp(id, amount);
#define PLUGIN "Multi-Mode CoD Shops"
#define PLUGIN_VERSION "1.0.0"
#define TASK_REDBULL 919300
#define SELL_PRICE 2000
new bool:g_redbull[33], Float:g_old_gravity[33], g_pending[33], g_sell[33];
new const CASH_NAMES[][]={"Red Bull: +75 speed / higher jumps for 20s","Random perk","Small XP pack: +100 XP","Big XP pack: +300 XP","Medkit: +50 HP","Full kevlar + helmet"};
new const CASH_COSTS[]={3000,6000,5000,10000,2500,4000};
public plugin_init()
{
    register_plugin(PLUGIN,PLUGIN_VERSION,"ApexiumForge");
    new const commands[][]={"shop","goldshop","sell"};new command[40];
    for(new i=0;i<sizeof commands;i++){
        formatex(command,charsmax(command),"say /%s",commands[i]);register_clcmd(command,"mm_chat",0,"- CoD cash shop, Gold shop, or sell perk");
        formatex(command,charsmax(command),"say_team /%s",commands[i]);register_clcmd(command,"mm_chat");
    }
    RegisterHam(Ham_Spawn,"player","mm_spawn",1);RegisterHam(Ham_Killed,"player","mm_killed",1);
    RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed,"mm_speed",true);
    register_srvcmd("mm_cod_shop_status","mm_status");
}
bool:mm_active(){return mm_get_active_mode()==MM_MODE_COD;}
bool:mm_ready(id){return id>0 && id<=MaxClients && is_user_alive(id) && mm_active() && cod_get_user_class(id)>0 && (get_user_team(id)==1 || get_user_team(id)==2);}
public client_connect(id){g_redbull[id]=false;g_pending[id]=g_sell[id]=0;remove_task(TASK_REDBULL+id);}
public client_disconnected(id){remove_task(TASK_REDBULL+id);g_redbull[id]=false;g_pending[id]=g_sell[id]=0;}
public mm_chat(id)
{
    if(!mm_active())return PLUGIN_CONTINUE;
    new text[32];read_args(text,charsmax(text));remove_quotes(text);
    if(equal(text,"/shop"))mm_cash_menu(id);else if(equal(text,"/goldshop"))mm_gold_menu(id);else mm_sell_menu(id);
    return PLUGIN_HANDLED;
}
public mm_shop_hub(id)
{
    if(!is_user_connected(id) || !mm_active())return;
    new title[96];formatex(title,charsmax(title),"\yCoD Shops\R\w%d Gold | $%d",cod_get_user_honor(id),cs_get_user_money(id));
    new menu=menu_create(title,"mm_hub_pick");menu_additem(menu,"\yGold shop\w - choose your perk");menu_additem(menu,"\yCash shop\w - boosts, XP and supplies");menu_display(id,menu);
}
public mm_hub_pick(id,menu,item){menu_destroy(menu);if(!is_user_connected(id) || !mm_active())return PLUGIN_HANDLED;if(item==0)mm_gold_menu(id);else if(item==1)mm_cash_menu(id);return PLUGIN_HANDLED;}
mm_gold_cost(item)
{
    new name[64];cod_get_item_name(item,name,charsmax(name));
    if(equal(name,"Super Jetpack"))return 175;
    if(containi(name,"Expert")!=-1 || equal(name,"No Recoil") || equal(name,"SWAT Shield") || equal(name,"Xray Vision"))return 150;
    return 75;
}
mm_gold_menu(id)
{
    if(!is_user_connected(id) || !mm_active())return;
    new title[96],name[64],row[112],key[12];formatex(title,charsmax(title),"\yGold Shop\R\w%d Gold",cod_get_user_honor(id));
    new menu=menu_create(title,"mm_gold_pick");
    for(new item=1;item<=cod_get_items_num();item++){
        if(!cod_check_item(id,item))continue;
        cod_get_item_name(item,name,charsmax(name));formatex(row,charsmax(row),"\w%s\R\y%d Gold",name,mm_gold_cost(item));num_to_str(item,key,charsmax(key));menu_additem(menu,row,key);
    }
    menu_display(id,menu);
}
public mm_gold_pick(id,menu,item)
{
    if(item<0){menu_destroy(menu);return PLUGIN_HANDLED;}
    new key[12],access,callback;menu_item_getinfo(menu,item,access,key,charsmax(key),_,_,callback);menu_destroy(menu);
    if(!mm_ready(id))return PLUGIN_HANDLED;
    new perk=str_to_num(key);if(perk<1 || perk>cod_get_items_num() || !cod_check_item(id,perk))return PLUGIN_HANDLED;
    g_pending[id]=perk;
    new name[64],desc[512],title[640],row[80];cod_get_item_name(perk,name,charsmax(name));cod_get_item_desc(perk,desc,charsmax(desc));
    // Unrolled items use %s in the description; do not treat it as a format string.
    replace_all(desc,charsmax(desc),"%s","(rolled value)");
    formatex(title,charsmax(title),"\y%s\w^n%s",name,desc);menu=menu_create(title,"mm_gold_confirm");
    formatex(row,charsmax(row),"Buy for \y%d Gold",mm_gold_cost(perk));menu_additem(menu,row);menu_additem(menu,"Back to Gold shop");menu_display(id,menu);
    return PLUGIN_HANDLED;
}
bool:mm_empty_perk(id)
{
    if(!cod_get_user_item(id))return true;
    client_print_color(id,print_team_red,"^4[^1CoD^4]^1 You already have a perk. Use ^3/sell^1 or ^3/coddrop^1 first.");return false;
}
public mm_gold_confirm(id,menu,item)
{
    menu_destroy(menu);if(!mm_ready(id) || item<0)return PLUGIN_HANDLED;
    if(item!=0){mm_gold_menu(id);return PLUGIN_HANDLED;}
    new perk=g_pending[id];g_pending[id]=0;
    if(perk<1 || perk>cod_get_items_num() || !cod_check_item(id,perk) || !mm_empty_perk(id))return PLUGIN_HANDLED;
    new cost=mm_gold_cost(perk),gold=cod_get_user_honor(id);
    if(gold<cost){client_print_color(id,print_team_red,"^4[^1Gold Shop^4]^1 You need ^3%d Gold^1.",cost);return PLUGIN_HANDLED;}
    cod_set_user_item(id,perk,RANDOM,false);
    if(cod_get_user_item(id)==perk){cod_set_user_honor(id,gold-cost);client_print_color(id,print_team_blue,"^4[^1Gold Shop^4]^1 Perk purchased for ^3%d Gold^1.",cost);}
    mm_gold_menu(id);return PLUGIN_HANDLED;
}
mm_cash_menu(id)
{
    if(!is_user_connected(id) || !mm_active())return;
    new title[80],row[128];formatex(title,charsmax(title),"\yCash Shop\R\w$%d",cs_get_user_money(id));new menu=menu_create(title,"mm_cash_pick");
    for(new i=0;i<sizeof CASH_COSTS;i++){formatex(row,charsmax(row),"\w%s\R\y$%d",CASH_NAMES[i],CASH_COSTS[i]);menu_additem(menu,row);}
    menu_display(id,menu);
}
public mm_cash_pick(id,menu,item)
{
    menu_destroy(menu);if(!mm_ready(id) || item<0 || item>=sizeof CASH_COSTS)return PLUGIN_HANDLED;
    new cash=cs_get_user_money(id),cost=CASH_COSTS[item];
    if(cash<cost){client_print_color(id,print_team_red,"^4[^1Cash Shop^4]^1 You need ^3$%d^1.",cost);return PLUGIN_HANDLED;}
    switch(item){
        case 0:{
            if(g_redbull[id]){client_print_color(id,print_team_red,"^4[^1Cash Shop^4]^1 Red Bull is already active.");return PLUGIN_HANDLED;}
            g_redbull[id]=true;g_old_gravity[id]=cod_get_user_gravity(id,ADDITIONAL);cod_set_user_gravity(id,0.65,ADDITIONAL);
            ExecuteHamB(Ham_CS_Player_ResetMaxSpeed,id);set_task(20.0,"mm_redbull_end",TASK_REDBULL+id);
        }
        case 1:{
            if(!mm_empty_perk(id))return PLUGIN_HANDLED;
            new eligible[256],count;
            for(new perk=1;perk<=cod_get_items_num() && count<sizeof eligible;perk++)if(cod_check_item(id,perk))eligible[count++]=perk;
            if(!count)return PLUGIN_HANDLED;
            new perk=eligible[random_num(0,count-1)];cod_set_user_item(id,perk,RANDOM,false);if(cod_get_user_item(id)!=perk)return PLUGIN_HANDLED;
        }
        case 2,3:{if(!mm_cod_add_xp(id,item==2?100:300)){client_print_color(id,print_team_red,"^4[^1Cash Shop^4]^1 XP unavailable: finish choosing your class or check its level limit.");return PLUGIN_HANDLED;}}
        case 4:{if(get_user_health(id)>=cod_get_user_max_health(id))return PLUGIN_HANDLED;cod_add_user_health(id,50);}
        case 5:{new CsArmorType:type;new armor=cs_get_user_armor(id,type);if(armor>=100 && type==CS_ARMOR_VESTHELM)return PLUGIN_HANDLED;cs_set_user_armor(id,100,CS_ARMOR_VESTHELM);}
    }
    cs_set_user_money(id,cash-cost,1);client_print_color(id,print_team_blue,"^4[^1Cash Shop^4]^1 Purchased ^3%s^1 for ^3$%d^1.",CASH_NAMES[item],cost);mm_cash_menu(id);return PLUGIN_HANDLED;
}
mm_sell_menu(id)
{
    if(!mm_ready(id))return;
    new perk=cod_get_user_item(id);if(!perk){client_print_color(id,print_team_red,"^4[^1CoD^4]^1 You have no perk to sell.");return;}
    g_sell[id]=perk;new name[64],title[128];cod_get_item_name(perk,name,charsmax(name));formatex(title,charsmax(title),"\ySell %s for $%d?",name,SELL_PRICE);
    new menu=menu_create(title,"mm_sell_pick");menu_additem(menu,"Sell perk");menu_additem(menu,"Keep perk");menu_display(id,menu);
}
public mm_sell_pick(id,menu,item)
{
    menu_destroy(menu);if(item!=0 || !mm_ready(id))return PLUGIN_HANDLED;
    new perk=g_sell[id];g_sell[id]=0;if(!perk || cod_get_user_item(id)!=perk)return PLUGIN_HANDLED;
    new cash=cs_get_user_money(id);if(cash>16000-SELL_PRICE){client_print_color(id,print_team_red,"^4[^1CoD^4]^1 Make room for ^3$%d^1 before selling (cash limit $16000).",SELL_PRICE);return PLUGIN_HANDLED;}
    cod_set_user_item(id,0);if(cod_get_user_item(id))return PLUGIN_HANDLED;
    cs_set_user_money(id,cash+SELL_PRICE,1);client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Perk sold for ^3$%d^1.",SELL_PRICE);return PLUGIN_HANDLED;
}
public mm_speed(id)
{
    if(mm_ready(id) && g_redbull[id]){new Float:speed=get_entvar(id,var_maxspeed);if(speed>1.0)set_entvar(id,var_maxspeed,speed+75.0);}
    return HC_CONTINUE;
}
mm_clear_redbull(id)
{
    remove_task(TASK_REDBULL+id);if(!g_redbull[id])return;g_redbull[id]=false;
    if(is_user_connected(id)){cod_set_user_gravity(id,g_old_gravity[id],ADDITIONAL);if(is_user_alive(id))ExecuteHamB(Ham_CS_Player_ResetMaxSpeed,id);}
}
public mm_redbull_end(task){new id=task-TASK_REDBULL;mm_clear_redbull(id);if(is_user_connected(id) && mm_active())client_print_color(id,print_team_blue,"^4[^1CoD^4]^1 Red Bull has worn off.");}
public mm_spawn(id){mm_clear_redbull(id);g_pending[id]=g_sell[id]=0;}
public mm_killed(id,killer,gib){mm_clear_redbull(id);g_pending[id]=g_sell[id]=0;}
public cod_class_changed(id,classname){mm_clear_redbull(id);g_pending[id]=g_sell[id]=0;}
public mm_mode_transition_started(oldmode,newmode){if(MmMode:oldmode==MM_MODE_COD)for(new id=1;id<=MaxClients;id++){mm_clear_redbull(id);g_pending[id]=g_sell[id]=0;}}
public plugin_end(){for(new id=1;id<=MaxClients;id++)mm_clear_redbull(id);}
public mm_status(){new boosts;for(new id=1;id<=MaxClients;id++)if(g_redbull[id])boosts++;server_print("[CoD Shops] active=%d gold_items=%d cash_options=%d sell_cash=%d redbull_active=%d gold_prices=75/150/175 cash_prices=3000/6000/5000/10000/2500/4000",mm_active(),cod_get_items_num(),sizeof CASH_COSTS,SELL_PRICE,boosts);}
