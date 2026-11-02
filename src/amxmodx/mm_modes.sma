#include <amxmodx>
#include <amxmisc>
#include <mm_mode_api>

#define PLUGIN_NAME    "Multi-Mode Network Menus"
#define PLUGIN_VERSION "0.6.0"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"

new MmMode:g_pending_mode[33]
new MmClassicFormat:g_pending_format[33]

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /menu", "handle_main_menu_command")
    register_clcmd("say_team /menu", "handle_main_menu_command")
    register_clcmd("say /modes", "handle_modes_menu_command")
    register_clcmd("say_team /modes", "handle_modes_menu_command")
    register_clcmd("say /rules", "mm_rules")
    register_clcmd("say_team /rules", "mm_rules")
    log_amx("%s menu module v%s initialized successfully.", PROJECT_NAME, PLUGIN_VERSION)
}

public client_connect(id)
{
    clear_pending_selection(id)
}

public client_disconnected(id)
{
    clear_pending_selection(id)
}

public handle_main_menu_command(id)
{
    if (is_user_connected(id)) show_main_menu(id)
    return PLUGIN_HANDLED
}

public handle_modes_menu_command(id)
{
    if (is_user_connected(id)) show_modes_menu(id)
    return PLUGIN_HANDLED
}

show_main_menu(id)
{
    new menu = menu_create("Multi-Mode Network", "handle_main_menu_selection")
    menu_additem(menu, "Game Modes", "1")
    menu_additem(menu, "Classic Match Formats", "2")
    menu_additem(menu, "Server Information", "3")
    menu_additem(menu, "Mode Rules / How to Play", "4")
    menu_setprop(menu, MPROP_EXITNAME, "Close")
    menu_display(id, menu)
}

public handle_main_menu_selection(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new info[4], name[64], access, callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback)
    menu_destroy(menu)
    switch (str_to_num(info))
    {
        case 4: mm_rules(id)
        case 1: show_modes_menu(id)
        case 2: show_classic_formats_menu(id)
        case 3: client_print_color(id, print_team_default, "^x04[%s]^x01 Server Foundation %s", PROJECT_NAME, PLUGIN_VERSION)
    }
    return PLUGIN_HANDLED
}

show_modes_menu(id)
{
    new title[96], active_name[32]
    mm_get_mode_name(mm_get_active_mode(), active_name, charsmax(active_name))
    formatex(title, charsmax(title), "Available Game Modes^n\yActive: %s", active_name)
    new menu = menu_create(title, "handle_mode_selection")
    for (new MmMode:mode = MM_MODE_CLASSIC; mode < MM_MODE_COUNT; mode++)
    {
        add_mode_item(menu, mode)
    }
    menu_setprop(menu, MPROP_EXITNAME, "Close")
    menu_display(id, menu)
}

add_mode_item(menu, MmMode:mode)
{
    new item_name[160], info[4], mode_name[32]
    mm_get_mode_name(mode, mode_name, charsmax(mode_name))
    if (mode == mm_get_active_mode()) formatex(item_name, charsmax(item_name), "%s \y[ACTIVE]", mode_name)
    else copy(item_name, charsmax(item_name), mode_name)
    new const descriptions[][] = {"Team rounds and objectives", "FFA | /dm weapons, /top scores", "FFA | 2 gun kills or 1 knife kill to advance", "FFA | AWP and knife", "Teams | unlimited HE, first to 30 kills", "Teams | knives only, 35 HP, round-based"}
    format(item_name, charsmax(item_name), "%s \d- %s", item_name, descriptions[_:mode])
    num_to_str(_:mode, info, charsmax(info))
    menu_additem(menu, item_name, info)
}

public handle_mode_selection(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new info[4], mode_name[64], access, callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), mode_name, charsmax(mode_name), callback)
    menu_destroy(menu)
    new MmMode:mode = MmMode:str_to_num(info)
    mm_get_mode_name(mode, mode_name, charsmax(mode_name))
    if (!has_mode_admin_access(id))
    {
        client_print_color(id, print_team_default, "^x04[%s]^x01 %s is available. An administrator must confirm activation.", PROJECT_NAME, mode_name)
        return PLUGIN_HANDLED
    }
    if (mode == mm_get_active_mode())
    {
        client_print_color(id, print_team_default, "^x04[%s]^x01 %s is already active.", PROJECT_NAME, mode_name)
        return PLUGIN_HANDLED
    }
    g_pending_mode[id] = mode
    new title[96]
    formatex(title, charsmax(title), "Activate %s mode?", mode_name)
    new confirm_menu = menu_create(title, "handle_mode_confirmation")
    menu_additem(confirm_menu, "Confirm", "1")
    menu_additem(confirm_menu, "Cancel", "0")
    menu_setprop(confirm_menu, MPROP_EXIT, MEXIT_NEVER)
    menu_display(id, confirm_menu)
    return PLUGIN_HANDLED
}

public handle_mode_confirmation(id, menu, item)
{
    new info[4], name[32], access, callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback)
    menu_destroy(menu)
    if (str_to_num(info) != 1)
    {
        clear_pending_selection(id)
        client_print_color(id, print_team_default, "^x04[%s]^x01 Mode change cancelled.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    if (!has_mode_admin_access(id))
    {
        clear_pending_selection(id)
        client_print_color(id, print_team_default, "^x04[%s]^x01 You are no longer authorized to change modes.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    new MmMode:mode = g_pending_mode[id]
    clear_pending_selection(id)
    print_request_result(id, mm_request_mode(mode, id))
    return PLUGIN_HANDLED
}

show_classic_formats_menu(id)
{
    new title[96], selected_name[16]
    mm_get_classic_format_name(mm_get_classic_format(), selected_name, charsmax(selected_name))
    formatex(title, charsmax(title), "Classic Match Formats^n\ySelected: %s", selected_name)
    new menu = menu_create(title, "handle_classic_format_selection")
    for (new MmClassicFormat:format = MM_FORMAT_1V1; format < MM_FORMAT_COUNT; format++)
    {
        add_format_item(menu, format)
    }
    menu_setprop(menu, MPROP_EXITNAME, "Close")
    menu_display(id, menu)
}

add_format_item(menu, MmClassicFormat:format)
{
    new item_name[48], info[4], format_name[16]
    mm_get_classic_format_name(format, format_name, charsmax(format_name))
    if (format == mm_get_classic_format()) formatex(item_name, charsmax(item_name), "%s \y[SELECTED]", format_name)
    else if (format >= MM_FORMAT_1V2) formatex(item_name, charsmax(item_name), "%s (Casual)", format_name)
    else copy(item_name, charsmax(item_name), format_name)
    num_to_str(_:format, info, charsmax(info))
    menu_additem(menu, item_name, info)
}

public handle_classic_format_selection(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new info[4], format_name[64], access, callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), format_name, charsmax(format_name), callback)
    menu_destroy(menu)
    new MmClassicFormat:format = MmClassicFormat:str_to_num(info)
    mm_get_classic_format_name(format, format_name, charsmax(format_name))
    if (!has_mode_admin_access(id))
    {
        client_print_color(id, print_team_default, "^x04[%s]^x01 Classic %s is available. An administrator must confirm selection.", PROJECT_NAME, format_name)
        return PLUGIN_HANDLED
    }
    if (format == mm_get_classic_format())
    {
        client_print_color(id, print_team_default, "^x04[%s]^x01 Classic format %s is already selected.", PROJECT_NAME, format_name)
        return PLUGIN_HANDLED
    }
    g_pending_format[id] = format
    new title[96]
    formatex(title, charsmax(title), "Select Classic format %s?", format_name)
    new confirm_menu = menu_create(title, "handle_format_confirmation")
    menu_additem(confirm_menu, "Confirm", "1")
    menu_additem(confirm_menu, "Cancel", "0")
    menu_setprop(confirm_menu, MPROP_EXIT, MEXIT_NEVER)
    menu_display(id, confirm_menu)
    return PLUGIN_HANDLED
}

public handle_format_confirmation(id, menu, item)
{
    new info[4], name[32], access, callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback)
    menu_destroy(menu)
    if (str_to_num(info) != 1)
    {
        clear_pending_selection(id)
        client_print_color(id, print_team_default, "^x04[%s]^x01 Classic format change cancelled.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    if (!has_mode_admin_access(id))
    {
        clear_pending_selection(id)
        client_print_color(id, print_team_default, "^x04[%s]^x01 You are no longer authorized to change formats.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    new MmClassicFormat:format = g_pending_format[id]
    clear_pending_selection(id)
    print_request_result(id, mm_request_classic_format(format, id))
    return PLUGIN_HANDLED
}

bool:has_mode_admin_access(id) { return (get_user_flags(id) & ADMIN_CFG) != 0; }

clear_pending_selection(id)
{
    g_pending_mode[id] = MM_MODE_CLASSIC
    g_pending_format[id] = MM_FORMAT_5V5
}

print_request_result(id, MmRequestResult:result)
{
    switch (result)
    {
        case MM_REQUEST_ACCEPTED: client_print_color(id, print_team_default, "^x04[%s]^x01 Request accepted; transition is being verified.", PROJECT_NAME)
        case MM_REQUEST_DUPLICATE: client_print_color(id, print_team_default, "^x04[%s]^x01 That selection is already active.", PROJECT_NAME)
        case MM_REQUEST_BUSY: client_print_color(id, print_team_default, "^x04[%s]^x01 Another transition is already in progress.", PROJECT_NAME)
        case MM_REQUEST_INVALID: client_print_color(id, print_team_default, "^x04[%s]^x01 Invalid selection.", PROJECT_NAME)
        case MM_REQUEST_UNAUTHORIZED: client_print_color(id, print_team_default, "^x04[%s]^x01 You are not authorized to change mode state.", PROJECT_NAME)
        default: client_print_color(id, print_team_default, "^x04[%s]^x01 Request failed; Classic fallback was attempted.", PROJECT_NAME)
    }
}

public mm_rules(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED
    show_motd(id, "addons/amxmodx/configs/mm_rules.html", "Torbeshi | Mode Rules")
    return PLUGIN_HANDLED
}
