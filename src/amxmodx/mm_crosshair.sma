#include <amxmodx>
#include <cstrike>
#include <nvault>

#define MM_FAKE_WEAPON 2
#define MM_HIDE_CROSSHAIR (1<<6)
#define MM_STYLE_COUNT 4
#define MM_COLOR_COUNT 5
#define MM_NO_VAULT -1

new const PLUGIN_NAME[] = "Torbeshi Crosshair Menu"
new const PLUGIN_VERSION[] = "1.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new const STYLE_NAMES[][] = {"Tiny cross", "Small cross", "Dot", "Cross + dot"}
new const COLOR_NAMES[][] = {"Green", "Cyan", "White", "Red", "Yellow"}
new g_style[33], g_color[33], g_weapon[33], g_clip[33], g_fov[33], g_hide[33]
new bool:g_custom[33], bool:g_sending
new g_data[31][8], bool:g_known[31]
new g_msgWeaponList, g_msgCurWeapon, g_msgHide, g_msgFov, g_vault = MM_NO_VAULT

public plugin_precache()
{
    new path[96]
    for (new shape = 0; shape < MM_STYLE_COUNT; shape++)
    {
        for (new color = 0; color < MM_COLOR_COUNT; color++)
        {
            formatex(path, charsmax(path), "sprites/mm_xh_v1_%d_%d.spr", shape, color)
            precache_generic(path)
            formatex(path, charsmax(path), "sprites/mm_xh_v1_%d_%d.txt", shape, color)
            precache_generic(path)
        }
    }
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /crosshair", "mm_crosshair_menu")
    register_clcmd("say_team /crosshair", "mm_crosshair_menu")
    register_clcmd("say /ch", "mm_crosshair_menu")
    register_clcmd("say_team /ch", "mm_crosshair_menu")
    g_msgWeaponList = get_user_msgid("WeaponList")
    g_msgCurWeapon = get_user_msgid("CurWeapon")
    g_msgHide = get_user_msgid("HideWeapon")
    g_msgFov = get_user_msgid("SetFOV")
    register_message(g_msgWeaponList, "mm_weapon_list")
    register_message(g_msgCurWeapon, "mm_current_weapon")
    register_message(g_msgHide, "mm_hide_weapon")
    register_message(g_msgFov, "mm_set_fov")
    new command[48]
    for (new shape = 0; shape < MM_STYLE_COUNT; shape++)
        for (new color = 0; color < MM_COLOR_COUNT; color++)
        {
            formatex(command, charsmax(command), "mm_xh_v1_%d_%d", shape, color)
            register_clcmd(command, "mm_select_current_weapon")
        }
    g_vault = nvault_open("mm_crosshair")
    if (g_vault == MM_NO_VAULT) log_amx("Crosshair preferences will not persist: nVault could not open.")
    log_amx("%s v%s initialized. Use /crosshair or /ch.", PLUGIN_NAME, PLUGIN_VERSION)
}

public client_connect(id)
{
    g_style[id] = 0
    g_color[id] = 0
    g_weapon[id] = 0
    g_clip[id] = -1
    g_fov[id] = 90
    g_hide[id] = 0
    g_custom[id] = false
}

public client_authorized(id, const authid[])
{
    if (g_vault == MM_NO_VAULT || !mm_stable_auth(authid)) return
    new value[24], style[8], color[8]
    if (!nvault_get(g_vault, authid, value, charsmax(value))) return
    parse(value, style, charsmax(style), color, charsmax(color))
    g_style[id] = clamp(str_to_num(style), 0, MM_STYLE_COUNT)
    g_color[id] = clamp(str_to_num(color), 0, MM_COLOR_COUNT - 1)
}

bool:mm_stable_auth(const authid[])
{
    return (contain(authid, "STEAM_") == 0 || contain(authid, "VALVE_") == 0)
        && contain(authid, "LAN") == -1 && contain(authid, "PENDING") == -1
        && !equal(authid, "STEAM_ID_STOP_IGNORING_RETVALS")
}

mm_save(id)
{
    if (g_vault == MM_NO_VAULT) return
    new authid[40], value[24]
    get_user_authid(id, authid, charsmax(authid))
    if (!mm_stable_auth(authid)) return
    formatex(value, charsmax(value), "%d %d", g_style[id], g_color[id])
    nvault_set(g_vault, authid, value)
}

public mm_crosshair_menu(id)
{
    if (!is_user_connected(id) || is_user_bot(id)) return PLUGIN_HANDLED
    new title[128], label[96]
    formatex(title, charsmax(title), "\yCrosshair\w^nStyle: %s | Color: %s",
        g_style[id] ? STYLE_NAMES[g_style[id] - 1] : "Default", COLOR_NAMES[g_color[id]])
    new menu = menu_create(title, "mm_crosshair_choice")
    menu_additem(menu, "Default CS 1.6 crosshair")
    for (new i = 0; i < MM_STYLE_COUNT; i++) menu_additem(menu, STYLE_NAMES[i])
    formatex(label, charsmax(label), "Color: %s \y(next)", COLOR_NAMES[g_color[id]])
    menu_additem(menu, label)
    menu_setprop(menu, MPROP_EXITNAME, "Close")
    menu_display(id, menu)
    return PLUGIN_HANDLED
}

public mm_crosshair_choice(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT || !is_user_connected(id)) return PLUGIN_HANDLED
    if (item == MM_STYLE_COUNT + 1) g_color[id] = (g_color[id] + 1) % MM_COLOR_COUNT
    else if (item >= 0 && item <= MM_STYLE_COUNT) g_style[id] = item
    else return PLUGIN_HANDLED
    mm_save(id)
    mm_refresh(id)
    client_print_color(id, print_team_default, "^x04[Crosshair]^x01 %s | %s. Use ^x04/crosshair^x01 to change.",
        g_style[id] ? STYLE_NAMES[g_style[id] - 1] : "Default", COLOR_NAMES[g_color[id]])
    mm_crosshair_menu(id)
    return PLUGIN_HANDLED
}

public mm_weapon_list(msg, destination, id)
{
    if (g_sending) return PLUGIN_CONTINUE
    new weapon = get_msg_arg_int(8)
    if (weapon <= 0 || weapon > 30 || weapon == MM_FAKE_WEAPON) return PLUGIN_CONTINUE
    for (new i = 0; i < 6; i++) g_data[weapon][i] = get_msg_arg_int(i + 2)
    g_data[weapon][6] = weapon
    g_data[weapon][7] = get_msg_arg_int(9)
    g_known[weapon] = true
    return PLUGIN_CONTINUE
}

public mm_current_weapon(msg, destination, id)
{
    if (g_sending || id < 1 || id > 32 || !is_user_connected(id)) return PLUGIN_CONTINUE
    if (get_msg_arg_int(1) != 1)
    {
        if (!is_user_alive(id) && g_custom[id]) mm_restore(id)
        return PLUGIN_CONTINUE
    }
    g_weapon[id] = get_msg_arg_int(2)
    g_clip[id] = get_msg_arg_int(3)
    if (mm_can_draw(id))
    {
        mm_draw(id)
        return PLUGIN_HANDLED
    }
    mm_restore_hide(id)
    g_custom[id] = false
    return PLUGIN_CONTINUE
}

public mm_set_fov(msg, destination, id)
{
    if (g_sending || id < 1 || id > 32) return PLUGIN_CONTINUE
    new fov = get_msg_arg_int(1)
    g_fov[id] = fov ? fov : 90
    // A scoped CurWeapon must stay genuine. Refresh on the next engine update.
    if (g_fov[id] != 90 && g_custom[id]) mm_restore(id)
    return PLUGIN_CONTINUE
}

public mm_hide_weapon(msg, destination, id)
{
    if (g_sending || id < 1 || id > 32) return PLUGIN_CONTINUE
    g_hide[id] = get_msg_arg_int(1)
    if (g_custom[id]) set_msg_arg_int(1, ARG_BYTE, g_hide[id] | MM_HIDE_CROSSHAIR)
    return PLUGIN_CONTINUE
}

bool:mm_can_draw(id)
{
    if (!g_style[id] || !is_user_alive(id) || g_fov[id] != 90) return false
    if (g_hide[id] & (1 | 4 | MM_HIDE_CROSSHAIR)) return false
    new weapon = g_weapon[id]
    if (weapon <= 0 || weapon > 30 || !g_known[weapon]) return false
    // Preserve native sniper scopes, knife/grenade/C4 behavior and spectators.
    return weapon != CSW_AWP && weapon != CSW_SCOUT && weapon != CSW_G3SG1
        && weapon != CSW_SG550 && weapon != CSW_KNIFE && weapon != CSW_C4
        && weapon != CSW_HEGRENADE && weapon != CSW_FLASHBANG && weapon != CSW_SMOKEGRENADE
}

mm_refresh(id)
{
    if (!is_user_connected(id)) return
    if (mm_can_draw(id)) mm_draw(id)
    else if (g_custom[id]) mm_restore(id)
}

mm_draw(id)
{
    new name[48], weapon = g_weapon[id]
    formatex(name, charsmax(name), "mm_xh_v1_%d_%d", g_style[id] - 1, g_color[id])
    g_sending = true
    message_begin(MSG_ONE, g_msgWeaponList, _, id)
    write_string(name)
    for (new i = 0; i < 4; i++) write_byte(g_data[weapon][i])
    write_byte(6)
    write_byte(0)
    write_byte(MM_FAKE_WEAPON)
    write_byte(g_data[weapon][7])
    message_end()
    message_begin(MSG_ONE, g_msgHide, _, id)
    write_byte(g_hide[id] | MM_HIDE_CROSSHAIR)
    message_end()
    // CS renders the sprite reticle for the unused weapon ID. This transient
    // FOV pair updates the client HUD only; server weapon/zoom state is untouched.
    message_begin(MSG_ONE, g_msgFov, _, id)
    write_byte(89)
    message_end()
    message_begin(MSG_ONE, g_msgCurWeapon, _, id)
    write_byte(1)
    write_byte(MM_FAKE_WEAPON)
    write_byte(g_clip[id])
    message_end()
    message_begin(MSG_ONE, g_msgFov, _, id)
    write_byte(90)
    message_end()
    g_sending = false
    g_custom[id] = true
}

mm_restore_hide(id)
{
    if (!g_custom[id]) return
    g_sending = true
    message_begin(MSG_ONE, g_msgHide, _, id)
    write_byte(g_hide[id])
    message_end()
    g_sending = false
}

mm_restore(id)
{
    mm_restore_hide(id)
    g_sending = true
    message_begin(MSG_ONE, g_msgCurWeapon, _, id)
    write_byte(0)
    write_byte(MM_FAKE_WEAPON)
    write_byte(-1)
    message_end()
    message_begin(MSG_ONE, g_msgCurWeapon, _, id)
    write_byte(is_user_alive(id) ? 1 : 0)
    write_byte(g_weapon[id])
    write_byte(g_clip[id])
    message_end()
    g_sending = false
    g_custom[id] = false
}

public mm_select_current_weapon(id)
{
    if (!is_user_alive(id)) return PLUGIN_HANDLED
    new name[32]
    if (get_weaponname(get_user_weapon(id), name, charsmax(name))) engclient_cmd(id, name)
    return PLUGIN_HANDLED
}

public plugin_end()
{
    if (g_vault != MM_NO_VAULT) nvault_close(g_vault)
}
