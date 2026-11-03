/* Combat Surf tools for Torbeshi. Feature references: Hawk552's uSurf 5.2
 * and OneEyed's Surf Olympics 1.5.2a. Independently implemented for the
 * mm_mode_api lifecycle; see docs/SURF.md for sources and attribution. */
#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <mm_mode_api>
#define SURF_HUD 903000
#define SURF_RESPAWN 903100
#define SURF_LOADOUT 903200
new const PLUGIN_VERSION[] = "1.1.0"
new const PHYSICS_NAMES[][] = {"sv_airaccelerate", "sv_maxvelocity"}
new const PHYSICS_VALUES[][] = {"100", "4096"}
new const GUNS[][] = {"weapon_scout", "weapon_ak47", "weapon_m4a1", "weapon_awp"}
new const GUN_NAMES[][] = {"Scout", "AK-47", "M4A1", "AWP"}
new const GUN_IDS[] = {CSW_SCOUT, CSW_AK47, CSW_M4A1, CSW_AWP}
new g_jail, g_jail_count, g_jail_targets[16][32], g_jail_returns
new Float:g_jail_next[33]
new const JAIL_SETTINGS[] = "addons/amxmodx/configs/mm_surf_settings.cfg"
new g_physics[2], g_saved[2][32], g_hud, g_delay, g_protection, g_respawns, g_added_spawns
new bool:g_enabled, bool:g_saved_player[33], bool:g_old_auto[33], bool:g_old_mega[33]
new bool:g_auto[33], bool:g_speed[33], g_weapon[33], Float:g_peak[33], Float:g_until[33], Float:g_last_restart[33]
public plugin_init()
{
    register_plugin("Multi-Mode Combat Surf", PLUGIN_VERSION, "Torbeshi")
    RegisterHam(Ham_Spawn, "player", "mm_spawn", 1)
    RegisterHam(Ham_Killed, "player", "mm_killed", 1)
    RegisterHam(Ham_TakeDamage, "player", "mm_damage")
    RegisterHam(Ham_Touch, "trigger_teleport", "mm_jail_touch")
    register_forward(FM_CmdStart, "mm_buttons")
    register_forward(FM_AddToFullPack, "mm_glow", 1)
    register_clcmd("say /surf", "mm_menu"); register_clcmd("say_team /surf", "mm_menu")
    register_clcmd("say /surfhelp", "mm_help"); register_clcmd("say_team /surfhelp", "mm_help")
    register_clcmd("say /respawn", "mm_restart"); register_clcmd("say /restart", "mm_restart")
    register_srvcmd("mm_surf_status", "mm_status")
    g_jail = register_cvar("mm_surf_jail", "0")
    register_concmd("mm_surf_set_jail", "mm_jail_command", ADMIN_CFG, "<0|1> Save Surf jail rules")
    register_srvcmd("mm_surf_jail_selftest", "mm_jail_selftest")
    g_delay = register_cvar("mm_surf_respawn_delay", "1.5")
    g_protection = register_cvar("mm_surf_spawn_protection", "2.0")
    for (new i=0; i<sizeof PHYSICS_NAMES; i++) g_physics[i] = get_cvar_pointer(PHYSICS_NAMES[i])
    g_hud = CreateHudSyncObj()
    log_amx("Combat Surf %s initialized: mode-scoped movement, team combat and surf tools.", PLUGIN_VERSION)
}
public plugin_cfg()
{
    // Some classic skill maps have only one team's spawn entities.
    if (file_exists(JAIL_SETTINGS)) {server_cmd("exec %s", JAIL_SETTINGS); server_exec();}
    mm_load_jail_targets()
    new map[32]; get_mapname(map, charsmax(map))
    if (equali(map, "surf_", 5))
    {
        mm_supply_spawns("info_player_start", "info_player_deathmatch")
        mm_supply_spawns("info_player_deathmatch", "info_player_start")
    }
    if (mm_active()) mm_activate()
}
bool:mm_active() {return mm_get_active_mode() == MM_MODE_SURF;}
bool:mm_playing(id) {return id>=1 && id<=MaxClients && is_user_connected(id) && (cs_get_user_team(id)==CS_TEAM_T || cs_get_user_team(id)==CS_TEAM_CT);}
public client_connect(id) {g_jail_next[id]=0.0;g_auto[id]=true; g_speed[id]=true; g_weapon[id]=0; g_saved_player[id]=false; g_peak[id]=0.0; g_until[id]=0.0; g_last_restart[id]=0.0;}
public client_disconnected(id) {g_jail_next[id]=0.0;remove_task(SURF_RESPAWN+id); remove_task(SURF_LOADOUT+id); g_saved_player[id]=false; g_until[id]=0.0;}
public mm_mode_transition_started(old_mode, new_mode) {if (MmMode:old_mode == MM_MODE_SURF) mm_shutdown();}
public mm_mode_changed(old_mode, new_mode) {if (MmMode:new_mode == MM_MODE_SURF) mm_activate(); else if (g_enabled) mm_shutdown();}
mm_activate()
{
    if (g_enabled) mm_shutdown()
    g_enabled=true
    for (new i=0; i<sizeof PHYSICS_NAMES; i++) if (g_physics[i]) {get_pcvar_string(g_physics[i],g_saved[i],charsmax(g_saved[])); set_pcvar_string(g_physics[i],PHYSICS_VALUES[i]);}
    set_task(0.25,"mm_hud",SURF_HUD,"",0,"b")
    for (new id=1; id<=MaxClients; id++) if (mm_playing(id)) {g_peak[id]=0.0; if (is_user_alive(id)) mm_spawn(id); else set_task(0.2,"mm_respawn",SURF_RESPAWN+id);}
    client_print_color(0,print_team_grey,"^4[Surf]^3 Combat Surf active! Ride ramps, collect weapons and fight. ^1/surf^3 options | ^1/surfhelp^3 guide.")
}
mm_shutdown()
{
    remove_task(SURF_HUD)
    for (new id=1; id<=MaxClients; id++)
    {
        remove_task(SURF_RESPAWN+id); remove_task(SURF_LOADOUT+id); g_until[id]=0.0
        if (g_saved_player[id] && is_user_connected(id)) {set_member(id,m_bAutoBunnyHopping,g_old_auto[id]); set_member(id,m_bMegaBunnyJumping,g_old_mega[id]);}
        g_saved_player[id]=false
    }
    if (g_enabled) for (new i=0; i<sizeof PHYSICS_NAMES; i++) if (g_physics[i]) set_pcvar_string(g_physics[i],g_saved[i])
    g_enabled=false; ClearSyncHud(0,g_hud)
}
public plugin_end() mm_shutdown()
public mm_spawn(id)
{
    if (!g_enabled || !mm_active() || !is_user_alive(id) || !mm_playing(id)) return HAM_IGNORED
    if (!g_saved_player[id]) {g_old_auto[id]=bool:get_member(id,m_bAutoBunnyHopping); g_old_mega[id]=bool:get_member(id,m_bMegaBunnyJumping); g_saved_player[id]=true;}
    set_member(id,m_bAutoBunnyHopping,g_auto[id]); set_member(id,m_bMegaBunnyJumping,true)
    g_until[id]=get_gametime()+floatclamp(get_pcvar_float(g_protection),0.0,5.0)
    remove_task(SURF_LOADOUT+id); set_task(0.1,"mm_loadout",SURF_LOADOUT+id)
    return HAM_IGNORED
}
public mm_loadout(task)
{
    new id=task-SURF_LOADOUT
    if (!g_enabled || !mm_active() || !mm_playing(id) || !is_user_alive(id)) return
    set_pev(id,pev_health,100.0)
    rg_remove_all_items(id,false)
    rg_give_item(id,"weapon_knife"); rg_give_item(id,"weapon_deagle"); rg_give_item(id,GUNS[g_weapon[id]])
    cs_set_user_bpammo(id,CSW_DEAGLE,35); cs_set_user_bpammo(id,GUN_IDS[g_weapon[id]],90)
    cs_set_user_armor(id,100,CS_ARMOR_VESTHELM)
}
public mm_killed(id, attacker, gib)
{
    if (!g_enabled || !mm_active() || !mm_playing(id)) return HAM_IGNORED
    g_until[id]=0.0; remove_task(SURF_LOADOUT+id); remove_task(SURF_RESPAWN+id)
    set_task(floatclamp(get_pcvar_float(g_delay),0.3,10.0),"mm_respawn",SURF_RESPAWN+id)
    return HAM_IGNORED
}
public mm_respawn(task)
{
    new id=task-SURF_RESPAWN
    if (g_enabled && mm_active() && mm_playing(id) && !is_user_alive(id) && mm_get_transition_state()==MM_TRANSITION_IDLE) {ExecuteHamB(Ham_CS_RoundRespawn,id); g_respawns++;}
}
public mm_damage(victim, inflictor, attacker, Float:damage, bits)
{
    if (!g_enabled || !mm_active()) return HAM_IGNORED
    if (bits & DMG_FALL) return HAM_SUPERCEDE
    if (g_until[victim]>get_gametime()) return HAM_SUPERCEDE
    if (attacker!=victim && mm_playing(attacker) && mm_playing(victim) && cs_get_user_team(attacker)==cs_get_user_team(victim)) return HAM_SUPERCEDE
    return HAM_IGNORED
}
public mm_buttons(id, command, seed)
{
    if (!g_enabled || !mm_active() || !is_user_alive(id) || g_until[id]<=get_gametime()) return FMRES_IGNORED
    new buttons=get_uc(command,UC_Buttons), item=get_member(id,m_pActiveItem)
    if (buttons & IN_ATTACK || ((buttons & IN_ATTACK2) && !is_nullent(item) && get_member(item,m_iId)==WEAPON_KNIFE)) g_until[id]=0.0
    return FMRES_IGNORED
}
public mm_glow(packet,e,entity,host,host_flags,player,pset)
{
    if (!g_enabled || !mm_active() || !player || entity<1 || entity>MaxClients || !is_user_alive(entity) || g_until[entity]<=get_gametime()) return FMRES_IGNORED
    set_es(packet,ES_RenderFx,kRenderFxGlowShell); set_es(packet,ES_RenderAmt,12)
    set_es(packet,ES_RenderColor,cs_get_user_team(entity)==CS_TEAM_T ? {255,70,50} : {60,120,255})
    return FMRES_IGNORED
}
public mm_hud()
{
    if (!g_enabled || !mm_active()) return
    for (new id=1; id<=MaxClients; id++)
    {
        if (!is_user_alive(id) || !g_speed[id]) continue
        new Float:v[3]; pev(id,pev_velocity,v); new Float:speed=floatsqroot(v[0]*v[0]+v[1]*v[1])
        if (speed>g_peak[id]) g_peak[id]=speed
        set_hudmessage(100,210,255,0.02,0.18,0,0.0,0.3,0.0,0.0)
        ShowSyncHudMsg(id,g_hud,"COMBAT SURF | Speed %d u/s^nPeak %d | Auto-bhop %s^n/surf options | /surfhelp guide",floatround(speed),floatround(g_peak[id]),g_auto[id]?"ON":"OFF")
    }
}
public mm_menu(id)
{
    if (!mm_active()) return PLUGIN_CONTINUE
    new menu=menu_create("Combat Surf","mm_menu_handler"), label[80]
    formatex(label,charsmax(label),"Auto-bhop: %s",g_auto[id]?"ON":"OFF"); menu_additem(menu,label)
    formatex(label,charsmax(label),"Speed display: %s",g_speed[id]?"ON":"OFF"); menu_additem(menu,label)
    formatex(label,charsmax(label),"Next respawn weapon: %s",GUN_NAMES[g_weapon[id]]); menu_additem(menu,label)
    menu_additem(menu,"Restart at spawn"); menu_additem(menu,"How to surf")
    formatex(label,charsmax(label),"Jail: %s (admin)",get_pcvar_num(g_jail)?"ON":"OFF - return to spawn")
    menu_additem(menu,label,"",ADMIN_CFG)
    menu_display(id,menu); return PLUGIN_HANDLED
}
public mm_menu_handler(id,menu,item)
{
    menu_destroy(menu)
    if (item==MENU_EXIT || !is_user_connected(id) || !mm_active()) return PLUGIN_HANDLED
    switch(item)
    {
        case 0:{g_auto[id]=!g_auto[id]; if (is_user_alive(id)) set_member(id,m_bAutoBunnyHopping,g_auto[id]);}
        case 1:{g_speed[id]=!g_speed[id]; if (!g_speed[id]) ClearSyncHud(id,g_hud);}
        case 2:{g_weapon[id]=(g_weapon[id]+1)%sizeof GUNS; client_print_color(id,print_team_grey,"^4[Surf]^3 Next respawn: ^4%s^3. You can also pick up map weapons.",GUN_NAMES[g_weapon[id]]);}
        case 3:{mm_restart(id); return PLUGIN_HANDLED;}
        case 4:{mm_help(id); return PLUGIN_HANDLED;}
        case 5:{if (get_user_flags(id) & ADMIN_CFG) mm_set_jail(id,get_pcvar_num(g_jail)?0:1);}
    }
    mm_menu(id); return PLUGIN_HANDLED
}
public mm_restart(id)
{
    if (!mm_active()) return PLUGIN_CONTINUE
    if (!mm_playing(id) || get_gametime()<g_last_restart[id]+3.0) return PLUGIN_HANDLED
    g_last_restart[id]=get_gametime()
    if (is_user_alive(id)) user_silentkill(id)
    remove_task(SURF_RESPAWN+id); set_task(0.3,"mm_respawn",SURF_RESPAWN+id)
    return PLUGIN_HANDLED
}
public mm_help(id)
{
    if (!mm_active()) return PLUGIN_CONTINUE
    show_motd(id,"addons/amxmodx/configs/mm_surf_help.html","Torbeshi | Combat Surf")
    return PLUGIN_HANDLED
}
mm_supply_spawns(const target[],const source[])
{
    if (engfunc(EngFunc_FindEntityByString,0,"classname",target)>0) return
    new entity, Float:origin[3], Float:angles[3]
    while ((entity=engfunc(EngFunc_FindEntityByString,entity,"classname",source))>0)
    {
        new added=engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,target))
        if (!pev_valid(added)) continue
        pev(entity,pev_origin,origin); pev(entity,pev_angles,angles)
        engfunc(EngFunc_SetOrigin,added,origin); set_pev(added,pev_angles,angles); dllfunc(DLLFunc_Spawn,added); g_added_spawns++
    }
}
public mm_status()
{
    server_print("[Surf Jail] enabled=%d configured_targets=%d bypassed=%d",get_pcvar_num(g_jail),g_jail_count,g_jail_returns)
    server_print("[Surf] version=%s active=%d enabled=%d airaccelerate=%.0f maxvelocity=%.0f respawns=%d extra_spawns=%d",PLUGIN_VERSION,mm_active(),g_enabled,get_cvar_float("sv_airaccelerate"),get_cvar_float("sv_maxvelocity"),g_respawns,g_added_spawns)
    for (new id=1;id<=MaxClients;id++) if (is_user_alive(id) && mm_active()) server_print("[Surf] client=%d auto_bhop=%d native_auto=%d native_uncapped=%d protected=%d",id,g_auto[id],get_member(id,m_bAutoBunnyHopping),get_member(id,m_bMegaBunnyJumping),g_until[id]>get_gametime())
}

mm_load_jail_targets()
{
    g_jail_count=0
    new map[32],path[160],line[96]; get_mapname(map,charsmax(map))
    formatex(path,charsmax(path),"addons/amxmodx/configs/mm_surf/jails/%s.ini",map)
    new file=fopen(path,"rt")
    if (!file) return
    while (!feof(file) && g_jail_count<sizeof g_jail_targets)
    {
        fgets(file,line,charsmax(line)); trim(line)
        if (!line[0] || line[0]==';' || line[0]=='/' || strlen(line)>charsmax(g_jail_targets[])) continue
        copy(g_jail_targets[g_jail_count++],charsmax(g_jail_targets[]),line)
    }
    fclose(file)
}
bool:mm_is_jail_target(const target[])
{
    for (new i=0;i<g_jail_count;i++) if (equal(target,g_jail_targets[i])) return true
    return false
}
public mm_jail_touch(entity,id)
{
    if (!g_enabled || !mm_active() || get_pcvar_num(g_jail) || !mm_playing(id) || !is_user_alive(id)) return HAM_IGNORED
    new target[64]; pev(entity,pev_target,target,charsmax(target))
    if (!mm_is_jail_target(target)) return HAM_IGNORED
    if (get_gametime()>=g_jail_next[id])
    {
        g_jail_next[id]=get_gametime()+0.5
        if (mm_return_to_spawn(id))
        {
            g_jail_returns++
            client_print_color(id,print_team_grey,"^4[Surf]^3 Jail is ^4OFF^3 - returned to your team's spawn.")
        }
    }
    // Do not run the original teleport or its killtarget side effects.
    return HAM_SUPERCEDE
}
bool:mm_return_to_spawn(id)
{
    new classname[32], entity, chosen, count, trace=create_tr2()
    copy(classname,charsmax(classname),cs_get_user_team(id)==CS_TEAM_T ? "info_player_deathmatch" : "info_player_start")
    new Float:origin[3], Float:angles[3]
    while ((entity=engfunc(EngFunc_FindEntityByString,entity,"classname",classname))>0)
    {
        pev(entity,pev_origin,origin); origin[2]+=1.0
        engfunc(EngFunc_TraceHull,origin,origin,DONT_IGNORE_MONSTERS,HULL_HUMAN,id,trace)
        if (get_tr2(trace,TR_StartSolid) || get_tr2(trace,TR_AllSolid)) continue
        if (random_num(1,++count)==1) chosen=entity
    }
    free_tr2(trace)
    if (!chosen) return false
    pev(chosen,pev_origin,origin); origin[2]+=1.0; pev(chosen,pev_angles,angles)
    engfunc(EngFunc_SetOrigin,id,origin)
    set_pev(id,pev_velocity,Float:{0.0,0.0,0.0}); set_pev(id,pev_basevelocity,Float:{0.0,0.0,0.0})
    set_pev(id,pev_angles,angles); set_pev(id,pev_v_angle,angles); set_pev(id,pev_fixangle,1)
    set_member(id,m_flFallVelocity,0.0)
    g_until[id]=get_gametime()+floatclamp(get_pcvar_float(g_protection),0.0,5.0)
    return true
}
mm_set_jail(id,enabled)
{
    new file=fopen(JAIL_SETTINGS,"wt")
    if (!file) {console_print(id,"[Surf] Could not save jail setting; unchanged."); return;}
    fprintf(file,"// Saved from /surf or mm_surf_set_jail^nmm_surf_jail %d^n",enabled); fclose(file)
    set_pcvar_num(g_jail,enabled)
    client_print_color(0,print_team_grey,"^4[Surf]^3 Jail is now ^4%s^3. %s",enabled?"ON":"OFF",enabled?"Normal map jail routes restored.":"Jail routes return players to their team's spawn.")
}
public mm_jail_command(id,level,cid)
{
    if (!cmd_access(id,level,cid,2)) return PLUGIN_HANDLED
    new arg[8]; read_argv(1,arg,charsmax(arg))
    if (!equal(arg,"0") && !equal(arg,"1")) {console_print(id,"Usage: mm_surf_set_jail <0|1>"); return PLUGIN_HANDLED;}
    mm_set_jail(id,str_to_num(arg)); return PLUGIN_HANDLED
}
public mm_jail_selftest()
{
    new entity,jail,normal,target[64]
    while ((entity=engfunc(EngFunc_FindEntityByString,entity,"classname","trigger_teleport"))>0)
    {
        pev(entity,pev_target,target,charsmax(target))
        if (mm_is_jail_target(target)) jail++; else normal++
    }
    server_print("[Surf Jail Test] configured=%d jail_teleports=%d normal_teleports=%d gunroom_preserved=%d top_preserved=%d",g_jail_count,jail,normal,!mm_is_jail_target("groom"),!mm_is_jail_target("top1"))
}
