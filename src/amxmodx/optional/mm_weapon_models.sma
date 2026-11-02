#include <amxmodx>
#include <fakemeta>
#include <reapi>

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
    register_plugin("Multi-Mode Weapon Models", "1.0.2", "ApexiumForge")
    register_srvcmd("mm_weapon_models_status", "mm_status")
    g_mm_enabled = register_cvar("mm_weapon_models", "1")
    RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "mm_deploy_pre", false)
    log_amx("Optional weapon models initialized; knife remains independently managed.")
}
public mm_deploy_pre(entity, const viewmodel[], const weaponmodel[], animation, const extension[], skiplocal)
{
    if (!get_pcvar_num(g_mm_enabled) || is_nullent(entity)) return HC_CONTINUE
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
    server_print("[Weapon Models] version=1.0.2 enabled=%d precached=%d/24 deploys=%d applied=%d", get_pcvar_num(g_mm_enabled), count, g_mm_deploys, g_mm_applied)
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id)) continue
        pev(id, pev_viewmodel2, viewmodel, charsmax(viewmodel))
        server_print("[Weapon Models] player=%d viewmodel=%s", id, viewmodel)
    }
}
