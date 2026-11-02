#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN_NAME "Multi-Mode HD Skins"
#define PLUGIN_VERSION "0.2.0"
#define PLUGIN_AUTHOR "ApexiumForge"

#define CT_MODEL_NAME "mm_ct_hd"
#define T_MODEL_NAME "mm_t_hd"

new const CT_MODEL_FILE[] = "models/player/mm_ct_hd/mm_ct_hd.mdl"
new const CT_TEXTURE_FILE[] = "models/player/mm_ct_hd/mm_ct_hdT.mdl"
new const T_MODEL_FILE[] = "models/player/mm_t_hd/mm_t_hd.mdl"
new const T_TEXTURE_FILE[] = "models/player/mm_t_hd/mm_t_hdT.mdl"
new const BUTTERFLY_MODEL_FILE[] = "models/multimode/v_butterfly_lore.mdl"

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
    precache_model(CT_MODEL_FILE)
    precache_model(CT_TEXTURE_FILE)
    precache_model(T_MODEL_FILE)
    precache_model(T_TEXTURE_FILE)
    precache_model(BUTTERFLY_MODEL_FILE)

    for (new index = 0; index < sizeof BUTTERFLY_SOUNDS; index++)
    {
        precache_sound(BUTTERFLY_SOUNDS[index])
    }
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    RegisterHam(Ham_Spawn, "player", "on_player_spawn", 1)
    RegisterHam(Ham_Item_Deploy, "weapon_knife", "on_knife_deploy", 1)
    log_amx("%s v%s initialized.", PLUGIN_NAME, PLUGIN_VERSION)
}

public on_knife_deploy(weapon)
{
    new id = pev(weapon, pev_owner)
    if (is_user_alive(id))
    {
        set_pev(id, pev_viewmodel2, BUTTERFLY_MODEL_FILE)
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
    cs_reset_user_model(id)
}

public plugin_end()
{
    new players[32], count
    get_players(players, count, "ch")
    for (new index = 0; index < count; index++)
    {
        cs_reset_user_model(players[index])
    }
}
