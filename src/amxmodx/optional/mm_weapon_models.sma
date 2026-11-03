#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <hamsandwich>
#include <nvault>

new const MM_MODELS[][] = {
    "models/multimode/csgo_inspect/v_ak47.mdl",
    "models/multimode/csgo_inspect/v_aug.mdl",
    "models/multimode/csgo_inspect/v_awp.mdl",
    "models/multimode/csgo_inspect/v_deagle.mdl",
    "models/multimode/csgo_inspect/v_elite.mdl",
    "models/multimode/csgo_inspect/v_famas.mdl",
    "models/multimode/csgo_inspect/v_fiveseven.mdl",
    "models/multimode/csgo_inspect/v_g3sg1.mdl",
    "models/multimode/csgo_inspect/v_galil.mdl",
    "models/multimode/csgo_inspect/v_glock18.mdl",
    "models/multimode/csgo_inspect/v_m249.mdl",
    "models/multimode/csgo_inspect/v_m3.mdl",
    "models/multimode/csgo_inspect/v_m4a1.mdl",
    "models/multimode/csgo_inspect/v_mac10.mdl",
    "models/multimode/csgo_inspect/v_mp5.mdl",
    "models/multimode/csgo_inspect/v_p228.mdl",
    "models/multimode/csgo_inspect/v_p90.mdl",
    "models/multimode/csgo_inspect/v_scout.mdl",
    "models/multimode/csgo_inspect/v_sg550.mdl",
    "models/multimode/csgo_inspect/v_sg552.mdl",
    "models/multimode/csgo_inspect/v_tmp.mdl",
    "models/multimode/csgo_inspect/v_ump45.mdl",
    "models/multimode/csgo_inspect/v_usp.mdl",
    "models/multimode/csgo_inspect/v_xm1014.mdl"
}
new const MM_ORIGINALS[][] = {
    "models/v_ak47.mdl",
    "models/v_aug.mdl",
    "models/v_awp.mdl",
    "models/v_deagle.mdl",
    "models/v_elite.mdl",
    "models/v_famas.mdl",
    "models/v_fiveseven.mdl",
    "models/v_g3sg1.mdl",
    "models/v_galil.mdl",
    "models/v_glock18.mdl",
    "models/v_m249.mdl",
    "models/v_m3.mdl",
    "models/v_m4a1.mdl",
    "models/v_mac10.mdl",
    "models/v_mp5.mdl",
    "models/v_p228.mdl",
    "models/v_p90.mdl",
    "models/v_scout.mdl",
    "models/v_sg550.mdl",
    "models/v_sg552.mdl",
    "models/v_tmp.mdl",
    "models/v_ump45.mdl",
    "models/v_usp.mdl",
    "models/v_xm1014.mdl"
}
new g_mm_enabled
new bool:g_mm_available[sizeof MM_MODELS]
new g_mm_deploys, g_mm_applied
new bool:g_custom[33], g_vault = INVALID_HANDLE
public plugin_precache()
{
    new file = fopen("models/multimode/csgo_inspect/sounds.ini", "rt")
    if (!file) { log_amx("Weapon model sound manifest missing; cosmetics disabled."); return; }
    new sound[96], bool:ready = true
    while (!feof(file))
    {
        fgets(file, sound, charsmax(sound)); trim(sound)
        if (!sound[0]) continue
        new path[112]
        formatex(path, charsmax(path), "sound/%s", sound)
        if (contain(sound, "multimode/csgo_inspect/") != 0 || contain(sound, "..") != -1 || !file_exists(path)) { ready = false; break; }
        precache_sound(sound)
    }
    fclose(file)
    if (!ready) { log_amx("Weapon model sound resources incomplete; cosmetics disabled."); return; }
    for (new i = 0; i < sizeof MM_MODELS; i++)
        if (file_exists(MM_MODELS[i])) { precache_model(MM_MODELS[i]); g_mm_available[i] = true; }
}
public plugin_init()
{
    register_plugin("Multi-Mode Weapon Models", "1.1.0", "ApexiumForge")
    register_clcmd("say /skins", "mm_toggle_skins")
    register_clcmd("say_team /skins", "mm_toggle_skins")
    g_vault = nvault_open("mm_weapon_skin_choice")
    for (new id = 1; id <= MaxClients; id++) g_custom[id] = true
    register_srvcmd("mm_weapon_models_status", "mm_status")
    g_mm_enabled = register_cvar("mm_weapon_models", "1")
    RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "mm_deploy_pre", false)
    log_amx("Optional weapon models initialized; knife remains independently managed.")
}
public mm_deploy_pre(entity, const viewmodel[], const weaponmodel[], animation, const extension[], skiplocal)
{
    if (!get_pcvar_num(g_mm_enabled) || is_nullent(entity)) return HC_CONTINUE
    new id = get_member(entity, m_pPlayer)
    if (id < 1 || id > MaxClients || !g_custom[id]) return HC_CONTINUE
    g_mm_deploys++
    for (new i = 0; i < sizeof MM_MODELS; i++)
    {
        if (equal(viewmodel, MM_ORIGINALS[i]) && g_mm_available[i])
        {
            SetHookChainArg(2, ATYPE_STRING, MM_MODELS[i])
            g_mm_applied++
            break
        }
    }
    return HC_CONTINUE
}

public mm_status()
{
    new count, viewmodel[96]
    for (new i = 0; i < sizeof MM_MODELS; i++) if (g_mm_available[i]) count++
    server_print("[Weapon Models] version=1.1.0 enabled=%d precached=%d/24 deploys=%d applied=%d", get_pcvar_num(g_mm_enabled), count, g_mm_deploys, g_mm_applied)
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id)) continue
        pev(id, pev_viewmodel2, viewmodel, charsmax(viewmodel))
        server_print("[Weapon Models] player=%d custom=%d viewmodel=%s", id, g_custom[id], viewmodel)
    }
}

public client_connect(id) g_custom[id] = true
public client_disconnected(id) g_custom[id] = true
bool:mm_stable_auth(const authid[])
{
    return (contain(authid, "STEAM_") == 0 || contain(authid, "VALVE_") == 0) && contain(authid, "LAN") == -1 && contain(authid, "PENDING") == -1 && !equal(authid, "STEAM_ID_STOP_IGNORING_RETVALS")
}
public client_authorized(id, const authid[])
{
    new value[4]
    if (g_vault != INVALID_HANDLE && mm_stable_auth(authid) && nvault_get(g_vault, authid, value, charsmax(value))) g_custom[id] = str_to_num(value) != 0
}
public plugin_end()
{
    if (g_vault != INVALID_HANDLE) nvault_close(g_vault)
}
public mm_toggle_skins(id)
{
    if (!is_user_connected(id) || is_user_bot(id)) return PLUGIN_HANDLED
    g_custom[id] = !g_custom[id]
    new authid[40], value[4]
    get_user_authid(id, authid, charsmax(authid))
    if (g_vault != INVALID_HANDLE && mm_stable_auth(authid))
    {
        num_to_str(_:g_custom[id], value, charsmax(value))
        nvault_set(g_vault, authid, value)
    }
    if (is_user_alive(id))
    {
        new item = get_member(id, m_pActiveItem)
        if (!is_nullent(item) && get_member(item, m_iId) != WEAPON_KNIFE)
        {
            // Deploy restores the correct idle/draw animation for either model,
            // including silenced USP/M4 state; inventory and ammunition stay intact.
            ExecuteHamB(Ham_Item_Deploy, item)
        }
    }
    client_print_color(id, print_team_default, "^4[Skins]^1 Weapon skins: ^4%s^1. Knife choice is separate in ^4/knife^1.", g_custom[id] ? "Custom" : "Default")
    return PLUGIN_HANDLED
}
