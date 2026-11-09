#include <amxmodx>
#include <mm_mode_api>

new const PLUGIN_NAME[] = "Multi-Mode Player Settings"
new const PLUGIN_VERSION[] = "1.0.0"
new const PLUGIN_AUTHOR[] = "ApexiumForge"

enum SettingsAction
{
    SETTINGS_CROSSHAIR = 1,
    SETTINGS_DM_LOADOUT,
    SETTINGS_MODE_STATUS,
    SETTINGS_LEADERBOARD,
    SETTINGS_VOTING,
    SETTINGS_RULES,
    SETTINGS_KNIFE
}

enum VotingAction
{
    VOTING_NEXT = 1,
    VOTING_MODE,
    VOTING_MAP,
    VOTING_RTV
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /settings", "command_settings")
    register_clcmd("say_team /settings", "command_settings")
    register_clcmd("say /set", "command_settings")
    register_clcmd("say_team /set", "command_settings")
    log_amx("%s v%s initialized. Players may use /settings or /set.", PLUGIN_NAME, PLUGIN_VERSION)
}

public command_settings(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED

    new title[96], mode_name[32]
    mm_get_mode_name(mm_get_active_mode(), mode_name, charsmax(mode_name))
    formatex(title, charsmax(title), "Player Settings \r| \w%s", mode_name)

    new menu = menu_create(title, "handle_settings")
    menu_additem(menu, "Crosshair customization", "1")
    menu_additem(menu, "Deathmatch weapon loadout", "2")
    menu_additem(menu, "My mode status / progress", "3")
    menu_additem(menu, "Current leaderboard", "4")
    menu_additem(menu, "Voting and next map", "5")
    menu_additem(menu, "Mode rules / how to play", "6")
    menu_additem(menu, "Knife model", "7")
    menu_setprop(menu, MPROP_EXITNAME, "Close")
    menu_display(id, menu)
    return PLUGIN_HANDLED
}

public handle_settings(id, menu, item)
{
    if (item == MENU_EXIT || !is_user_connected(id))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)

    switch (SettingsAction:str_to_num(info))
    {
        case SETTINGS_CROSSHAIR: run_chat_command(id, "/crosshair")
        case SETTINGS_DM_LOADOUT:
        {
            if (mm_get_active_mode() != MM_MODE_DEATHMATCH)
            {
                client_print_color(id, print_team_default, "^4[Settings]^1 Weapon loadout is available only in Deathmatch.")
                return command_settings(id)
            }
            run_chat_command(id, "/dm")
        }
        case SETTINGS_MODE_STATUS: show_mode_status(id)
        case SETTINGS_LEADERBOARD: show_mode_leaderboard(id)
        case SETTINGS_VOTING: show_voting_menu(id)
        case SETTINGS_RULES: run_chat_command(id, "/rules")
        case SETTINGS_KNIFE: run_chat_command(id, "/knife")
    }
    return PLUGIN_HANDLED
}

show_mode_status(id)
{
    switch (mm_get_active_mode())
    {
        case MM_MODE_ARMS_RACE: run_chat_command(id, "/ar")
        case MM_MODE_AWP_ONLY: run_chat_command(id, "/awp")
        case MM_MODE_DEATHMATCH, MM_MODE_HE_BATTLE: run_chat_command(id, "/top")
        default: run_chat_command(id, "/mode")
    }
}

show_mode_leaderboard(id)
{
    switch (mm_get_active_mode())
    {
        case MM_MODE_DEATHMATCH, MM_MODE_HE_BATTLE: run_chat_command(id, "/top")
        case MM_MODE_ARMS_RACE: run_chat_command(id, "/artop")
        case MM_MODE_AWP_ONLY: run_chat_command(id, "/awptop")
        default:
        {
            client_print_color(id, print_team_default, "^4[Settings]^1 This mode has no session leaderboard.")
            command_settings(id)
        }
    }
}

show_voting_menu(id)
{
    new menu = menu_create("Voting and Next Map", "handle_voting")
    menu_additem(menu, "Show planned next map", "1")
    menu_additem(menu, "Vote for next mode", "2")
    menu_additem(menu, "Vote for next map", "3")
    menu_additem(menu, "Request early vote (RTV)", "4")
    menu_setprop(menu, MPROP_BACKNAME, "Player Settings")
    menu_setprop(menu, MPROP_EXITNAME, "Close")
    menu_display(id, menu)
}

public handle_voting(id, menu, item)
{
    if (item == MENU_EXIT || !is_user_connected(id))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    if (item == MENU_BACK)
    {
        menu_destroy(menu)
        return command_settings(id)
    }

    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)

    switch (VotingAction:str_to_num(info))
    {
        case VOTING_NEXT: run_chat_command(id, "/nextmap")
        case VOTING_MODE: run_chat_command(id, "/votemode")
        case VOTING_MAP: run_chat_command(id, "/votemap")
        case VOTING_RTV: run_chat_command(id, "/rtv")
    }
    return PLUGIN_HANDLED
}

run_chat_command(id, const command[])
{
    if (is_user_connected(id)) client_cmd(id, "say %s", command)
}
