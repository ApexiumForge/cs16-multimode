#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <nvault>

#define PLUGIN_NAME "Multi-Mode HD Skins"
#define PLUGIN_VERSION "0.4.0"
#define PLUGIN_AUTHOR "ApexiumForge"

#define CT_MODEL_NAME "mm_ct_hd"
#define T_MODEL_NAME "mm_t_hd"

new const CT_MODEL_FILE[] = "models/player/mm_ct_hd/mm_ct_hd.mdl"
new const CT_TEXTURE_FILE[] = "models/player/mm_ct_hd/mm_ct_hdT.mdl"
new const T_MODEL_FILE[] = "models/player/mm_t_hd/mm_t_hd.mdl"
new const T_TEXTURE_FILE[] = "models/player/mm_t_hd/mm_t_hdT.mdl"
new const BUTTERFLY_MODEL_FILE[] = "models/multimode/v_butterfly_lore.mdl"

new const MM_PACK_KNIFE[] = "models/multimode/csgo_inspect/v_knife.mdl"
new const DEFAULT_KNIFE[] = "models/v_knife.mdl"
new const KNIFE_NAMES[][] = {"Butterfly", "CS GO pack knife", "Default CS 1.6 knife"}
new bool:g_pack_ready
new g_choice[33], g_vault = INVALID_HANDLE

new const BUTTERFLY_SOUNDS[][] =
{
    "weapons/csgo/butterfly/backstab.wav",
    "weapons/csgo/butterfly/draw1.wav",
    "weapons/csgo/butterfly/draw2.wav",
    "weapons/csgo/butterfly/insp1a.wav",
    "weapons/csgo/butterfly/insp1b.wav",
    "weapons/csgo/butterfly/insp1c.wav",
    "weapons/csgo/butterfly/insp2a.wav",
    "weapons/csgo/butterfly/insp2b.wav",
    "weapons/csgo/butterfly/insp2c.wav"
}

public plugin_precache()
{
    new file = fopen("models/multimode/csgo_inspect/knife_sounds.ini", "rt")
    if (file && file_exists(MM_PACK_KNIFE))
    {
        new sound[96], path[112], bool:ready = true
        while (!feof(file))
        {
            fgets(file, sound, charsmax(sound)); trim(sound)
            if (!sound[0]) continue
            formatex(path, charsmax(path), "sound/%s", sound)
            if (contain(sound, "multimode/csgo_inspect/") != 0 || contain(sound, "..") != -1 || !file_exists(path)) { ready = false; break; }
            precache_sound(sound)
        }
        if (ready) { precache_model(MM_PACK_KNIFE); g_pack_ready = true; }
    }
    if (file) fclose(file)
    precache_model(CT_MODEL_FILE)
    precache_model(CT_TEXTURE_FILE)
    precache_model(T_MODEL_FILE)
    precache_model(T_TEXTURE_FILE)
    precache_model(BUTTERFLY_MODEL_FILE)
    precache_model(DEFAULT_KNIFE)

    for (new index = 0; index < sizeof BUTTERFLY_SOUNDS; index++)
    {
        precache_sound(BUTTERFLY_SOUNDS[index])
    }
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /knife", "mm_knife_menu")
    register_clcmd("say_team /knife", "mm_knife_menu")
    g_vault = nvault_open("mm_knife_choice")
    RegisterHam(Ham_Spawn, "player", "on_player_spawn", 1)
    RegisterHam(Ham_Item_Deploy, "weapon_knife", "on_knife_deploy", 1)
    RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "mm_knife_deploy_pre", false)
    set_task(0.2, "mm_refresh_knives", 895000, "", 0, "b")
    register_srvcmd("mm_skins_status", "mm_skins_status")
    log_amx("%s v%s initialized.", PLUGIN_NAME, PLUGIN_VERSION)
}

public on_knife_deploy(weapon)
{
    new id = get_member(weapon, m_pPlayer)
    if (id >= 1 && id <= MaxClients && is_user_alive(id))
    {
        new model[96]
        mm_knife_model(id, model, charsmax(model))
        set_pev(id, pev_viewmodel2, model)
    }
    return HAM_IGNORED
}

public on_player_spawn(id)
{
    if (!is_user_alive(id))
    {
        return HAM_IGNORED
    }

    switch (cs_get_user_team(id))
    {
        case CS_TEAM_T: cs_set_user_model(id, T_MODEL_NAME)
        case CS_TEAM_CT: cs_set_user_model(id, CT_MODEL_NAME)
        default: cs_reset_user_model(id)
    }
    return HAM_IGNORED
}

public client_disconnected(id)
{
    // Disconnected players cannot be passed to cs_reset_user_model.
    g_choice[id] = 0
}

public plugin_end()
{
    if (g_vault != INVALID_HANDLE) nvault_close(g_vault)
    remove_task(895000)
    new players[32], count
    get_players(players, count, "ch")
    for (new index = 0; index < count; index++)
    {
        cs_reset_user_model(players[index])
    }
}

// Read actual equipped items: custom crosshair HUD messages may advertise a fake ID.
public mm_refresh_knives()
{
    new current[96], desired[96]
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id)) continue
        new item = get_member(id, m_pActiveItem)
        if (is_nullent(item) || get_member(item, m_iId) != WEAPON_KNIFE) continue
        pev(id, pev_viewmodel2, current, charsmax(current))
        mm_knife_model(id, desired, charsmax(desired))
        if (!equal(current, desired))
        {
            // Deploy selects a valid draw animation in the newly chosen model.
            ExecuteHamB(Ham_Item_Deploy, item)
        }
    }
}

public mm_skins_status()
{
    server_print("[Skins] version=%s butterfly=%s", PLUGIN_VERSION, BUTTERFLY_MODEL_FILE)
    new current[96]
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id)) continue
        new item = get_member(id, m_pActiveItem)
        pev(id, pev_viewmodel2, current, charsmax(current))
        server_print("[Skins] player=%d choice=%d actual_weapon=%d viewmodel=%s", id, g_choice[id], is_nullent(item) ? 0 : get_member(item, m_iId), current)
    }
}

public client_connect(id) g_choice[id] = 0

mm_knife_model(id, model[], length)
{
    if (g_choice[id] == 2) copy(model, length, DEFAULT_KNIFE)
    else copy(model, length, g_choice[id] == 1 && g_pack_ready ? MM_PACK_KNIFE : BUTTERFLY_MODEL_FILE)
}

bool:mm_identity(id, key[], length)
{
    get_user_authid(id, key, length)
    return !is_user_bot(id) && (contain(key, "STEAM_") == 0 || contain(key, "VALVE_") == 0)
        && contain(key, "LAN") == -1 && contain(key, "PENDING") == -1
}
public client_authorized(id, const authid[])
{
    new key[40], value[8]
    if (g_vault != INVALID_HANDLE && mm_identity(id, key, charsmax(key))
        && nvault_get(g_vault, key, value, charsmax(value)))
        g_choice[id] = clamp(str_to_num(value), 0, 2)
}
public mm_knife_menu(id)
{
    if (!is_user_connected(id) || is_user_bot(id)) return PLUGIN_HANDLED
    new menu = menu_create("Your Knife Model", "mm_knife_selected")
    for (new choice = 0; choice < sizeof KNIFE_NAMES; choice++)
    {
        new label[64], info[4]
        formatex(label, charsmax(label), "%s%s", KNIFE_NAMES[choice], g_choice[id] == choice ? " [selected]" : "")
        num_to_str(choice, info, charsmax(info))
        menu_additem(menu, label, info)
    }
    menu_display(id, menu)
    return PLUGIN_HANDLED
}
public mm_knife_selected(id, menu, item)
{
    if (item == MENU_EXIT || !is_user_connected(id)) { menu_destroy(menu); return PLUGIN_HANDLED; }
    new access, info[4], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)
    new choice = str_to_num(info)
    if (choice < 0 || choice > 2) return PLUGIN_HANDLED
    if (choice == 1 && !g_pack_ready)
    {
        client_print_color(id, print_team_default, "^4[Skins]^1 Pack knife resources are unavailable on this map.")
        return PLUGIN_HANDLED
    }
    g_choice[id] = choice
    new key[40], value[4]
    if (g_vault != INVALID_HANDLE && mm_identity(id, key, charsmax(key)))
    {
        num_to_str(choice, value, charsmax(value))
        nvault_set(g_vault, key, value)
    }
    mm_refresh_knives()
    client_print_color(id, print_team_default, "^4[Skins]^1 Knife selected: ^4%s^1.", KNIFE_NAMES[choice])
    return PLUGIN_HANDLED
}

public mm_knife_deploy_pre(item, const viewmodel[], const weaponmodel[], animation, const extension[], skiplocal)
{
    if (is_nullent(item) || get_member(item, m_iId) != WEAPON_KNIFE) return HC_CONTINUE
    new id = get_member(item, m_pPlayer), model[96]
    if (id < 1 || id > MaxClients || !is_user_alive(id)) return HC_CONTINUE
    mm_knife_model(id, model, charsmax(model))
    SetHookChainArg(2, ATYPE_STRING, model)
    return HC_CONTINUE
}
