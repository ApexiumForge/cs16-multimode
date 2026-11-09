/* Mode-aware replacement for the stock AMXX help list.
 * Command access still comes from AMXX; mode ownership comes from plugin IDs. */
#include <amxmodx>
#include <mm_mode_api>
new Trie:g_modes
public plugin_init()
{
    register_plugin("Mode-Aware Admin Help","1.0.1","Torbeshi")
    register_concmd("amx_help","mm_help",0,"<start> - shared and current-mode commands")
    register_clcmd("say /commands","mm_commands")
    register_clcmd("say_team /commands","mm_commands")
    register_srvcmd("mm_help_mode_status","mm_help_status")
    g_modes=TrieCreate()
}
public plugin_end()
{
    TrieDestroy(g_modes);
}
mm_owner_mask(const filename[],const cmd[])
{
    if(equal(filename,"mm_furien.amxx"))return 1<<_:MM_MODE_FURIEN
    if(equali(filename,"mm_zp_",6))return 1<<_:MM_MODE_ZOMBIE
    if(equal(cmd,"amx_classic_format"))return 1<<_:MM_MODE_CLASSIC
    if(equal(filename,"cod_mod.amxx") || equal(filename,"mm_cod_bridge.amxx") || equal(filename,"mm_cod_cycle.amxx") || equal(filename,"mm_cod_access.amxx") || equal(filename,"mm_cod_supply.amxx") || equal(filename,"mm_cod_climb.amxx") || equal(filename,"mm_cod_shop.amxx") || equali(filename,"codclass_",9) || equali(filename,"coditem_",8))return 1<<_:MM_MODE_COD
    if(equal(filename,"mm_cod.amxx"))return 1<<_:MM_MODE_COD
    if(equal(filename,"mm_classic.amxx") || equal(filename,"mm_classic_ready_test.amxx"))return 1<<_:MM_MODE_CLASSIC
    if(equal(filename,"mm_deathmatch.amxx"))return 1<<_:MM_MODE_DEATHMATCH
    if(equal(filename,"mm_armsrace.amxx") || equal(filename,"mm_armsrace_restrictions.amxx"))return 1<<_:MM_MODE_ARMS_RACE
    if(equal(filename,"mm_awponly.amxx"))return 1<<_:MM_MODE_AWP_ONLY
    if(equal(filename,"mm_he_battle.amxx"))return 1<<_:MM_MODE_HE_BATTLE
    if(equal(filename,"mm_knife.amxx"))return 1<<_:MM_MODE_KNIFE
    if(equal(filename,"mm_football.amxx"))return 1<<_:MM_MODE_FOOTBALL
    if(equal(filename,"mm_surf.amxx"))return 1<<_:MM_MODE_SURF
    if(equal(filename,"mm_random_spawns.amxx"))return (1<<_:MM_MODE_DEATHMATCH)|(1<<_:MM_MODE_ARMS_RACE)
    if(equal(filename,"mm_weapon_tuning.amxx") || equal(filename,"mm_counterstrafe.amxx"))return 15
    return 0
}
mm_mask(index,flags,id)
{
    new cmd[96],info[192],access,filename[96],name[96],version[24],author[64],status[24]
    get_concmd(index,cmd,charsmax(cmd),access,info,charsmax(info),flags,id)
    new plugin=get_concmd_plid(index,flags,id)
    if(plugin<0)return 0
    get_plugin(plugin,filename,charsmax(filename),name,charsmax(name),version,charsmax(version),author,charsmax(author),status,charsmax(status))
    return mm_owner_mask(filename,cmd)
}
public plugin_cfg()
{
    new total=get_concmdsnum(-1,-1),cmd[96],info[192],flags
    for(new i=0;i<total;i++)
    {
        get_concmd(i,cmd,charsmax(cmd),flags,info,charsmax(info),-1,-1)
        new mask=mm_mask(i,-1,-1),old
        if(TrieGetCell(g_modes,cmd,old))
        {
            // Any shared owner keeps the command shared (e.g. /knife cosmetics).
            mask=old && mask ? (old|mask) : 0
        }
        TrieSetCell(g_modes,cmd,mask)
    }
}
public client_command(id)
{
    new cmd[96],arg[72],mask
    read_argv(0,cmd,charsmax(cmd))
    if(equal(cmd,"say") || equal(cmd,"say_team"))
    {
        read_args(arg,charsmax(arg));
        remove_quotes(arg)
        if(arg[0]!='/')return PLUGIN_CONTINUE
        format(cmd,charsmax(cmd),"%s %s",cmd,arg)
    }
    // /shop has two mode-scoped owners. Some client-only registrations are
    // absent from the console command enumeration used to build g_modes.
    if(equal(cmd,"say /shop") || equal(cmd,"say_team /shop"))
    {
        new mode= _:mm_get_active_mode();
        if(mode==_:MM_MODE_FURIEN || mode==_:MM_MODE_COD)return PLUGIN_CONTINUE;
    }
    if(TrieGetCell(g_modes,cmd,mask) && mask && !(mask&(1<<_:mm_get_active_mode())))
    {
        console_print(id,"[Modes] This command belongs to another game mode. Use amx_help for current commands.")
        return PLUGIN_HANDLED
    }
    return PLUGIN_CONTINUE
}
public mm_help(id)
{
    new arg[16];
    read_argv(1,arg,charsmax(arg));
    mm_print_help(id,max(1,str_to_num(arg)));
    return PLUGIN_HANDLED
}
public mm_commands(id)
{
    mm_print_help(id,1);
    client_print_color(id,print_team_blue,"^4[Commands]^1 Current-mode commands printed in your console. Use ^3amx_help^1 for more pages.");
    return PLUGIN_HANDLED;
}
mm_print_help(id,start)
{
    new flags=id?get_user_flags(id):-1
    if(id && flags>0 && !(flags&ADMIN_USER))flags|=ADMIN_ADMIN
    new total=get_concmdsnum(flags,id),Array:indices=ArrayCreate(),mode=(_:mm_get_active_mode()),cmd[96],info[192],access
    for(new i=0;i<total;i++)
    {
        new mask=mm_mask(i,flags,id);
        if(!mask || (mask&(1<<mode)))ArrayPushCell(indices,i);
    }
    new count=ArraySize(indices);
    start=clamp(start-1,0,max(0,count-1));
    new end=min(start+10,count),name[40]
    mm_get_mode_name(MmMode:mode,name,charsmax(name));
    console_print(id,"^n----- Shared + %s commands -----",name)
    for(new j=start;j<end;j++)
    {
        new bool:ml;
        get_concmd(ArrayGetCell(indices,j),cmd,charsmax(cmd),access,info,charsmax(info),flags,id,ml)
        if(ml)console_print(id,"%3d: %s %L",j+1,cmd,id,info)
        else console_print(id,"%3d: %s %s",j+1,cmd,info)
    }
    console_print(id,"----- Entries %d-%d of %d -----",count?start+1:0,end,count)
    if(end<count)console_print(id,"Next: amx_help %d",end+1)
    ArrayDestroy(indices)
}
public mm_help_status()
{
    new total=get_concmdsnum(-1,-1),cod,leaks,cmd[96],info[192],flags
    for(new i=0;i<total;i++)
    {
        get_concmd(i,cmd,charsmax(cmd),flags,info,charsmax(info),-1,-1)
        if(containi(cmd,"cod")!=-1)
        {
            new mask=mm_mask(i,-1,-1);
            if(mask==(1<<_:MM_MODE_COD))cod++;
            else leaks++;
        }
    }
    server_print("[Mode Help] active_mode=%d cod_exclusive=%d unexpected_cod_commands=%d total=%d",_:mm_get_active_mode(),cod,leaks,total)
}
