#include <amxmodx>
#include <cstrike>
#include <mm_presentation_api>

#define MM_HELP_TASK 885000
new g_podium_hud, g_seen_mode[33]
public plugin_natives()
{
    register_library("mm_presentation")
    register_native("mm_show_results", "mm_native_results")
}
public plugin_init()
{
    register_plugin("Multi-Mode Match Presentation", "1.2.0", "Torbeshi")
    g_podium_hud = CreateHudSyncObj()
    register_event("ResetHUD", "mm_spawn_help", "be")
    register_clcmd("say /chatpreview", "mm_preview")
    register_clcmd("say_team /chatpreview", "mm_preview")
}
public client_connect(id) g_seen_mode[id] = -1
public client_disconnected(id) {remove_task(MM_HELP_TASK+id); g_seen_mode[id] = -1;}
public client_putinserver(id) {g_seen_mode[id] = -1; mm_schedule_help(id);}
public mm_spawn_help(id)
{
    if (g_seen_mode[id] != _:mm_get_active_mode()) mm_schedule_help(id)
}
mm_schedule_help(id)
{
    remove_task(MM_HELP_TASK+id)
    set_task(2.0, "mm_help", MM_HELP_TASK+id)
}
public mm_mode_transition_started(old_mode, new_mode)
{
    ClearSyncHud(0, g_podium_hud)
    for (new id = 1; id <= MaxClients; id++) remove_task(MM_HELP_TASK+id)
}
public mm_mode_changed(old_mode, new_mode)
{
    for (new id = 1; id <= MaxClients; id++) if (is_user_connected(id)) {g_seen_mode[id] = -1; mm_schedule_help(id);}
}
public mm_help(task)
{
    new id = task-MM_HELP_TASK
    if (!is_user_connected(id) || is_user_bot(id)) return
    new MmMode:mode = mm_get_active_mode(), name[32]
    mm_get_mode_name(mode, name, charsmax(name))
    g_seen_mode[id] = _:mode
    client_print_color(id, print_team_grey, "^4[%s]^3 ^1/skins^3 toggles weapon models; ^1/knife^3 chooses your knife. ^1/rules^3 for mode rules.", name)
    switch (mode)
    {
        case MM_MODE_CLASSIC: client_print_color(id, print_team_grey, "^4[Classic]^3 Join T/CT, then ^1/ready^3 when teams are full. ^1/score^3 shows the match score.")
        case MM_MODE_DEATHMATCH: client_print_color(id, print_team_grey, "^4[Deathmatch]^3 Everyone is an enemy. ^1/dm^3 selects a saved loadout; ^1/reuse^3 equips it. ^1/top^3 for scores.")
        case MM_MODE_ARMS_RACE: client_print_color(id, print_team_grey, "^4[Arms Race]^3 ^4Two gun kills^3 advance; a knife kill skips a level and demotes the victim. ^1/ar^3 / ^1/artop^3.")
        case MM_MODE_AWP_ONLY: client_print_color(id, print_team_grey, "^4[Sniper Arena]^3 Vote ^4AWP or Scout^3 at match start. ^1/awp^3 shows rules, ^1/awptop^3 scores.")
        case MM_MODE_HE_BATTLE: client_print_color(id, print_team_grey, "^4[HE Battle]^3 HE grenades refill automatically. ^1/he^3 shows Team/FFA rules; ^1/hetop^3 for scores.")
        case MM_MODE_KNIFE: client_print_color(id, print_team_grey, "^4[Knife 35HP]^3 Team elimination, ^435 HP^3. ^1/knifescore^3 shows rounds; ^1/ktop^3 the knife leaderboard.")
        case MM_MODE_DEATHRUN: client_print_color(id,print_team_grey,"^4[^1Deathrun^4]^1 CTs run the course. One T operates the traps.")
        case MM_MODE_FURIEN: client_print_color(id,print_team_grey,"^4[^1Furien^4]^1 T: fast stealth knives. CT: guns. Use ^3/furien^1 for weapons and rules.")
        case MM_MODE_ZOMBIE: client_print_color(id, print_team_grey,"^4[^1ZP^4]^1 Classic infection! Survive with teammates, earn ^3ammo packs^1. Press ^3M^1 for weapons, zombie classes and extra items.")
        case MM_MODE_COD: client_print_color(id, print_team_grey, "^4[CoD]^1 Team deathmatch! ^3/cod^1 classes, upgrades, perks and shop. ^3/codhelp^1 for commands.")
        case MM_MODE_SURF: client_print_color(id, print_team_grey, "^4[Surf]^3 Combat Surf: ride ramps and collect weapons. ^1/surf^3 options, ^1/surfhelp^3 guide. Fall damage is off; teammates are solid.")
        case MM_MODE_FOOTBALL: client_print_color(id, print_team_grey, "^4[Football]^3 Run onto the ball. ^4E/left click^3 shoots; ^4R/right click^3 passes. ^1/football^3 power settings; ^1/ftop^3 goals/assists.")
    }
}
public mm_native_results(plugin, params)
{
    if (MmMode:get_param(1) != mm_get_active_mode()) return false
    new title[64], detail[128], text[256], names[3][32]
    get_string(5, title, charsmax(title)); get_string(6, detail, charsmax(detail))
    for (new i = 0; i < 3; i++)
    {
        new id = get_param(i+2)
        if (id >= 1 && id <= MaxClients && is_user_connected(id)) get_user_name(id, names[i], charsmax(names[]))
        else copy(names[i], charsmax(names[]), "--")
    }
    set_dhudmessage(255, 210, 60, -1.0, 0.25, 0, 0.0, 5.8, 0.2, 0.5)
    show_dhudmessage(0, "%s^n%s", title, detail)
    formatex(text, charsmax(text), "PODIUM^n1. %s^n2. %s^n3. %s", names[0], names[1], names[2])
    set_hudmessage(100, 235, 160, -1.0, 0.48, 0, 0.0, 5.8, 0.2, 0.5)
    ShowSyncHudMsg(0, g_podium_hud, "%s", text)
    client_print_color(0, print_team_grey, "^4[Results]^3 ^4%s^3 | %s", title, detail)
    return true
}
public plugin_end()
{
    for (new id = 1; id <= MaxClients; id++) remove_task(MM_HELP_TASK+id)
}

public mm_preview(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED
    client_print_color(id, print_team_grey, "^4[Info]^3 Clean white text | ^4Key values^3 | ^1/menu^3 command")
    client_print_color(id, print_team_blue, "^4[Vote]^3 VOTE^1 | Choose ^4AWP^1 or ^4Scout^1 in the menu.")
    client_print_color(id, print_team_red, "^4[Notice]^3 NOTICE^1 |  Voting is unavailable during a transition.")
    client_print_color(id, id, "^4[Arms Race]^3 %n^1 | LEVEL UP | ^47^1 - ^4M3", id)
    return PLUGIN_HANDLED
}
