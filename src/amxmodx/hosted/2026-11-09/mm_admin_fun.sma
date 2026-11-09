#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#define MM_ACCESS ADMIN_RCON
#define MM_ESP_TASK 896810
#define MM_MARKERS 4
new const PLUGIN_NAME[] = "Multi-Mode Admin Fun"
new const PLUGIN_VERSION[] = "1.0.1"
new const PLUGIN_AUTHOR[] = "ApexiumForge"
new bool:g_recoil[33], bool:g_esp[33]
new g_enabled

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    g_enabled = register_cvar("mm_admin_fun", "1")
    register_clcmd("say /ww1", "mm_menu")
    register_clcmd("say_team /ww1", "mm_menu")
    register_clcmd("mm_ww1", "mm_menu")
    register_clcmd("mm_ww1_recoil", "mm_toggle_recoil")
    register_clcmd("mm_ww1_esp", "mm_toggle_esp")
    RegisterHookChain(RG_CBasePlayerWeapon_KickBack, "mm_kickback", false)
    register_forward(FM_PlayerPreThink, "mm_clear_punch")
    register_forward(FM_PlayerPostThink, "mm_clear_punch")
    new const guns[][] = {
        "weapon_ak47", "weapon_aug", "weapon_awp", "weapon_deagle", "weapon_elite",
        "weapon_famas", "weapon_fiveseven", "weapon_g3sg1", "weapon_galil", "weapon_glock18",
        "weapon_m249", "weapon_m3", "weapon_m4a1", "weapon_mac10", "weapon_mp5navy",
        "weapon_p228", "weapon_p90", "weapon_scout", "weapon_sg550", "weapon_sg552",
        "weapon_tmp", "weapon_ump45", "weapon_usp", "weapon_xm1014"
    }
    for (new i = 0; i < sizeof guns; i++)
        RegisterHam(Ham_Weapon_PrimaryAttack, guns[i], "mm_after_attack", 1)
    set_task(0.2, "mm_update_esp", MM_ESP_TASK, "", 0, "b")
    log_amx("%s v%s initialized; RCON-flag admins only; personal toggles default OFF.", PLUGIN_NAME, PLUGIN_VERSION)
}

public client_connect(id) { g_recoil[id] = false; g_esp[id] = false; }
public client_disconnected(id) { g_recoil[id] = false; g_esp[id] = false; }

bool:mm_allowed(id)
{
    return id >= 1 && id <= MaxClients && is_user_connected(id) && !is_user_bot(id)
        && get_pcvar_num(g_enabled) != 0 && (get_user_flags(id) & MM_ACCESS) != 0
}

public mm_menu(id)
{
    if (!mm_allowed(id)) return PLUGIN_HANDLED
    new menu = menu_create("WW1 - Admin Fun", "mm_selected"), label[64]
    formatex(label, charsmax(label), "No recoil: %s", g_recoil[id] ? "ON" : "OFF")
    menu_additem(menu, label, "1")
    formatex(label, charsmax(label), "ESP markers: %s", g_esp[id] ? "ON" : "OFF")
    menu_additem(menu, label, "2")
    menu_additem(menu, "Disable both", "3")
    menu_display(id, menu)
    return PLUGIN_HANDLED
}

public mm_selected(id, menu, item)
{
    if (item == MENU_EXIT || !mm_allowed(id)) { menu_destroy(menu); return PLUGIN_HANDLED; }
    new access, info[4], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)
    switch (str_to_num(info))
    {
        case 1: mm_toggle_recoil(id)
        case 2: mm_toggle_esp(id)
        case 3: { g_recoil[id] = false; g_esp[id] = false; }
    }
    return mm_menu(id)
}

public mm_toggle_recoil(id)
{
    if (!mm_allowed(id)) return PLUGIN_HANDLED
    g_recoil[id] = !g_recoil[id]
    mm_clear_punch(id)
    client_print_color(id, print_team_default, "^4[WW1]^1 No recoil: %s", g_recoil[id] ? "ON" : "OFF")
    return PLUGIN_HANDLED
}

public mm_toggle_esp(id)
{
    if (!mm_allowed(id)) return PLUGIN_HANDLED
    g_esp[id] = !g_esp[id]
    client_print_color(id, print_team_default, "^4[WW1]^1 ESP markers: %s", g_esp[id] ? "ON" : "OFF")
    return PLUGIN_HANDLED
}

public mm_clear_punch(id)
{
    if (!mm_allowed(id))
    {
        if (id >= 1 && id <= MaxClients) { g_recoil[id] = false; g_esp[id] = false; }
        return FMRES_IGNORED
    }
    if (g_recoil[id] && is_user_alive(id))
    {
        new Float:zero[3]
        set_pev(id, pev_punchangle, zero)
    }
    return FMRES_IGNORED
}

public mm_kickback(weapon, Float:up, Float:side, Float:upmod, Float:sidemod, Float:upmax, Float:sidemax, direction)
{
    if (is_nullent(weapon)) return HC_CONTINUE
    new id = get_member(weapon, m_pPlayer)
    if (mm_allowed(id) && g_recoil[id] && is_user_alive(id)) return HC_SUPERCEDE
    return HC_CONTINUE
}

public mm_after_attack(weapon)
{
    if (pev_valid(weapon)) mm_clear_punch(get_member(weapon, m_pPlayer))
    return HAM_IGNORED
}

// HUD projection is independent of world depth, so markers remain visible behind walls.
// Limit to four nearest on-screen living players to fit the GoldSrc HUD channels.
public mm_update_esp()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!mm_allowed(id) || !g_esp[id] || !is_user_alive(id)) continue
        new Float:eye[3], Float:offset[3], Float:angles[3], Float:view_forward[3], Float:right[3], Float:up[3]
        pev(id, pev_origin, eye); pev(id, pev_view_ofs, offset)
        for (new axis = 0; axis < 3; axis++) eye[axis] += offset[axis]
        pev(id, pev_v_angle, angles)
        engfunc(EngFunc_AngleVectors, angles, view_forward, right, up)
        new targets[MM_MARKERS], Float:distances[MM_MARKERS], Float:xs[MM_MARKERS], Float:ys[MM_MARKERS]
        new Float:fov
        pev(id, pev_fov, fov)
        if (fov < 10.0 || fov > 150.0) fov = 90.0
        new Float:scale = floattan(fov * 0.5, degrees)
        for (new target = 1; target <= MaxClients; target++)
        {
            if (target == id || !is_user_alive(target)) continue
            new Float:delta[3], Float:depth, Float:horizontal, Float:vertical, Float:distance
            pev(target, pev_origin, delta)
            for (new axis = 0; axis < 3; axis++)
            {
                delta[axis] -= eye[axis]
                depth += delta[axis] * view_forward[axis]
                horizontal += delta[axis] * right[axis]
                vertical += delta[axis] * up[axis]
                distance += delta[axis] * delta[axis]
            }
            if (depth <= 1.0) continue
            new Float:x = 0.5 + horizontal / (2.0 * depth * scale)
            new Float:y = 0.5 - vertical / (1.5 * depth * scale)
            if (x < 0.03 || x > 0.85 || y < 0.05 || y > 0.90) continue
            for (new slot = 0; slot < MM_MARKERS; slot++)
            {
                if (targets[slot] && distance >= distances[slot]) continue
                for (new next = MM_MARKERS - 1; next > slot; next--)
                {
                    targets[next] = targets[next-1]; distances[next] = distances[next-1]
                    xs[next] = xs[next-1]; ys[next] = ys[next-1]
                }
                targets[slot] = target; distances[slot] = distance; xs[slot] = x; ys[slot] = y
                break
            }
        }
        for (new slot = 0; slot < MM_MARKERS; slot++)
        {
            if (!targets[slot]) continue
            new name[32]
            get_user_name(targets[slot], name, charsmax(name))
            set_hudmessage(255, 80, 80, xs[slot], ys[slot], 0, 0.0, 0.21, 0.0, 0.0, slot + 1)
            show_hudmessage(id, "+ %s [%dm]", name, floatround(floatsqroot(distances[slot]) * 0.0254))
        }
    }
}

public plugin_end() remove_task(MM_ESP_TASK)
