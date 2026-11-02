#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <mm_mode_api>

#define PLUGIN_NAME    "Multi-Mode Network Arcade Rounds"
#define PLUGIN_VERSION "0.4.4"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"

#define ARCADE_CONFIG "addons/amxmodx/configs/mm_modes/arcade_rounds.cfg"

enum ArcadeCvar
{
    CVAR_ROUND_INFINITE = 0,
    CVAR_ROUND_OVER,
    CVAR_ROUND_RESPAWN_TIME,
    CVAR_GIVE_PLAYER_C4,
    CVAR_FREE_FOR_ALL,
    CVAR_REQUIRED_COUNT,
    CVAR_SHOW_SCENARIO_ICON = CVAR_REQUIRED_COUNT,
    CVAR_SHOW_BOMB_TIMER,
    CVAR_COUNT
}

new const REGAMEDLL_CVAR_NAMES[CVAR_COUNT][] =
{
    "mp_round_infinite",
    "mp_roundover",
    "mp_roundrespawn_time",
    "mp_give_player_c4",
    "mp_freeforall",
    "mp_show_scenarioicon",
    "mp_show_bomb_timer"
}

new const ARCADE_CVAR_VALUES[CVAR_COUNT][] =
{
    "1",
    "0",
    "-1",
    "0",
    "1",
    "0",
    "0"
}

new g_regamedll_cvars[CVAR_COUNT]
new g_saved_values[CVAR_COUNT][32]
new bool:g_values_saved
new bool:g_regamedll_supported
new g_policy_enabled_cvar
new g_disable_objectives_cvar

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_srvcmd("mm_arcade_round_status", "command_round_status")

    g_policy_enabled_cvar = register_cvar("mm_arcade_round_policy", "1")
    g_disable_objectives_cvar = register_cvar("mm_arcade_disable_objectives", "1")

    if (file_exists(ARCADE_CONFIG))
    {
        server_cmd("exec %s", ARCADE_CONFIG)
        server_exec()
    }
    else
    {
        log_amx("Shared arcade configuration is missing: %s", ARCADE_CONFIG)
    }

    g_regamedll_supported = discover_regamedll_cvars()
    report_compatibility()

    if (is_arcade_mode(mm_get_active_mode()))
    {
        enable_arcade_round_policy()
    }

    log_amx("%s arcade round controller v%s initialized.", PROJECT_NAME, PLUGIN_VERSION)
}

public plugin_end()
{
    restore_saved_cvars()
}

public mm_mode_transition_started(old_mode, requested_mode)
{
    new bool:old_is_arcade = is_arcade_mode(MmMode:old_mode)
    new bool:new_is_arcade = is_arcade_mode(MmMode:requested_mode)

    if (!old_is_arcade && new_is_arcade)
    {
        save_current_cvars()
    }
    else if (old_is_arcade && !new_is_arcade)
    {
        restore_saved_cvars()
    }
}

public mm_mode_changed(old_mode, new_mode)
{
    if (is_arcade_mode(MmMode:new_mode))
    {
        enable_arcade_round_policy()
    }
    else if (is_arcade_mode(MmMode:old_mode) || g_values_saved)
    {
        // Also covers a failed arcade transition that falls back to Classic
        // without emitting a second transition-started forward.
        restore_saved_cvars()
    }
}

public command_round_status()
{
    server_print("[MM] Arcade round controller: %s", g_regamedll_supported ? "ReGameDLL cvars available" : "unsupported GameDLL")
    server_print("[MM] Active mode is %s; saved Classic baseline: %s", is_arcade_mode(mm_get_active_mode()) ? "arcade" : "Classic", g_values_saved ? "yes" : "no")

    if (!g_regamedll_supported)
    {
        server_print("[MM] No cvars were changed. Install and validate ReGameDLL_CS in a separate test runtime first.")
        for (new ArcadeCvar:required_index = CVAR_ROUND_INFINITE; required_index < CVAR_REQUIRED_COUNT; required_index++)
        {
            if (!g_regamedll_cvars[required_index])
            {
                server_print("[MM] Missing required round-control cvar: %s", REGAMEDLL_CVAR_NAMES[required_index])
            }
        }
    }

    for (new ArcadeCvar:optional_index = CVAR_SHOW_SCENARIO_ICON; optional_index < CVAR_COUNT; optional_index++)
    {
        if (!g_regamedll_cvars[optional_index])
        {
            server_print("[MM] Optional presentation cvar unavailable (skipped): %s", REGAMEDLL_CVAR_NAMES[optional_index])
        }
    }
    return PLUGIN_HANDLED
}

bool:discover_regamedll_cvars()
{
    new bool:available = true

    for (new ArcadeCvar:index = CVAR_ROUND_INFINITE; index < CVAR_COUNT; index++)
    {
        g_regamedll_cvars[index] = get_cvar_pointer(REGAMEDLL_CVAR_NAMES[index])
        if (!g_regamedll_cvars[index])
        {
            if (index < CVAR_REQUIRED_COUNT)
            {
                available = false
                log_amx("Required ReGameDLL round-control cvar is unavailable: %s", REGAMEDLL_CVAR_NAMES[index])
            }
            else
            {
                log_amx("Optional ReGameDLL presentation cvar is unavailable and will be skipped: %s", REGAMEDLL_CVAR_NAMES[index])
            }
        }
    }
    return available
}

report_compatibility()
{
    if (g_regamedll_supported)
    {
        log_amx("ReGameDLL arcade-round cvars detected. Use 'game version' to verify the installed GameDLL build.")
    }
    else
    {
        log_amx("Arcade round control is unavailable: the active GameDLL lacks the required ReGameDLL cvars.")
    }
}

enable_arcade_round_policy()
{
    if (get_pcvar_num(g_policy_enabled_cvar) == 0)
    {
        log_amx("Shared arcade round policy is disabled by configuration.")
        return
    }

    if (!g_regamedll_supported)
    {
        log_amx("Arcade mode is active, but continuous rounds cannot be enforced with the current GameDLL.")
        return
    }

    if (!g_values_saved)
    {
        save_current_cvars()
    }

    for (new ArcadeCvar:index = CVAR_ROUND_INFINITE; index < CVAR_COUNT; index++)
    {
        if (g_regamedll_cvars[index])
        {
            set_pcvar_string(g_regamedll_cvars[index], ARCADE_CVAR_VALUES[index])
        }
    }

    if (get_pcvar_num(g_disable_objectives_cvar) != 0)
    {
        remove_active_bomb_objective()
    }

    log_amx("Continuous FFA arcade policy enabled: all players are enemies and ordinary round endings are blocked.")
}

save_current_cvars()
{
    if (!g_regamedll_supported || g_values_saved)
    {
        return
    }

    for (new ArcadeCvar:index = CVAR_ROUND_INFINITE; index < CVAR_COUNT; index++)
    {
        if (g_regamedll_cvars[index])
        {
            get_pcvar_string(g_regamedll_cvars[index], g_saved_values[index], charsmax(g_saved_values[]))
        }
    }
    g_values_saved = true
}

restore_saved_cvars()
{
    if (!g_regamedll_supported || !g_values_saved)
    {
        return
    }

    for (new ArcadeCvar:index = CVAR_ROUND_INFINITE; index < CVAR_COUNT; index++)
    {
        if (g_regamedll_cvars[index])
        {
            set_pcvar_string(g_regamedll_cvars[index], g_saved_values[index])
        }
    }

    g_values_saved = false
    log_amx("Pre-arcade round, objective, and FFA cvars restored for Classic gameplay.")
}

remove_active_bomb_objective()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id))
        {
            continue
        }

        new weapon = find_ent_by_owner(-1, "weapon_c4", id)
        if (weapon > 0)
        {
            ExecuteHamB(Ham_RemovePlayerItem, id, weapon)
            ExecuteHamB(Ham_Item_Kill, weapon)
        }
    }

    remove_entities_by_class("weapon_c4")

    new entity = -1
    new model[32]
    while ((entity = find_ent_by_class(entity, "grenade")) > 0)
    {
        entity_get_string(entity, EV_SZ_model, model, charsmax(model))
        if (equal(model, "models/w_c4.mdl"))
        {
            remove_entity(entity)
        }
    }

    entity = -1
    while ((entity = find_ent_by_class(entity, "weaponbox")) > 0)
    {
        entity_get_string(entity, EV_SZ_model, model, charsmax(model))
        if (equal(model, "models/w_backpack.mdl"))
        {
            remove_entity(entity)
        }
    }
}

remove_entities_by_class(const classname[])
{
    new entity = -1
    while ((entity = find_ent_by_class(entity, classname)) > 0)
    {
        remove_entity(entity)
    }
}

bool:is_arcade_mode(MmMode:mode)
{
    return mode == MM_MODE_DEATHMATCH ||
        mode == MM_MODE_ARMS_RACE ||
        mode == MM_MODE_AWP_ONLY ||
        mode == MM_MODE_HE_BATTLE
}
