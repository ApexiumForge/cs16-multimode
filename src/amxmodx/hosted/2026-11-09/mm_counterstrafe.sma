#include <amxmodx>
#include <mm_mode_api>
#include <reapi>

new const PLUGIN_NAME[] = "Multi-Mode Counter-Strafe Feel"
new const PLUGIN_VERSION[] = "1.0.1"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new const MM_CONFIG[] = "addons/amxmodx/configs/mm_counterstrafe.cfg"
new const MOVEMENT_CVARS[][] = {"sv_accelerate", "sv_friction", "sv_stopspeed"}
new g_engine[3], g_preset[3], g_enabled
new Float:g_saved[3], Float:g_applied_values[3]
new bool:g_applied
new bool:g_in_rules_think
new g_guarded_resets
new const Float:NATIVE_VALUES[] = {5.0, 4.0, 75.0}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    g_enabled = register_cvar("mm_counterstrafe", "1")
    g_preset[0] = register_cvar("mm_cs_accelerate", "6.0")
    g_preset[1] = register_cvar("mm_cs_friction", "4.4")
    g_preset[2] = register_cvar("mm_cs_stopspeed", "85.0")
    for (new i = 0; i < 3; i++)
    {
        g_engine[i] = get_cvar_pointer(MOVEMENT_CVARS[i])
        hook_cvar_change(g_preset[i], "mm_setting_changed")
    }
    hook_cvar_change(g_enabled, "mm_setting_changed")
    register_srvcmd("mm_counterstrafe_status", "mm_status")
    RegisterHookChain(RG_CSGameRules_Think, "mm_rules_pre", false)
    RegisterHookChain(RG_CSGameRules_Think, "mm_rules_post", true)
    RegisterHookChain(RH_Cvar_DirectSet, "mm_engine_cvar_pre", false)
    log_amx("Shared engine movement preset initialized for shooting modes.")
}

public plugin_cfg()
{
    if (file_exists(MM_CONFIG)) {server_cmd("exec %s", MM_CONFIG); server_exec();}
    mm_apply()
}

bool:mm_shooting_mode()
{
    new MmMode:mode = mm_get_active_mode()
    return mode == MM_MODE_CLASSIC || mode == MM_MODE_DEATHMATCH || mode == MM_MODE_ARMS_RACE || mode == MM_MODE_AWP_ONLY
}

mm_apply()
{
    if (g_applied || !get_pcvar_num(g_enabled) || !mm_shooting_mode() || mm_get_transition_state() != MM_TRANSITION_IDLE) return
    for (new i = 0; i < 3; i++) g_saved[i] = get_pcvar_float(g_engine[i])
    g_applied_values[0] = floatclamp(get_pcvar_float(g_preset[0]), 1.0, 10.0)
    g_applied_values[1] = floatclamp(get_pcvar_float(g_preset[1]), 1.0, 8.0)
    g_applied_values[2] = floatclamp(get_pcvar_float(g_preset[2]), 20.0, 120.0)
    for (new i = 0; i < 3; i++) set_pcvar_float(g_engine[i], g_applied_values[i])
    g_applied = true
}

mm_restore()
{
    if (!g_applied) return
    for (new i = 0; i < 3; i++)
    {
        // Preserve deliberate external edits made after this preset was applied.
        if (floatabs(get_pcvar_float(g_engine[i])-g_applied_values[i]) < 0.001) set_pcvar_float(g_engine[i], g_saved[i])
    }
    g_applied = false
}

public mm_setting_changed(pointer, const old_value[], const new_value[])
{
    mm_restore()
    mm_apply()
}
public mm_mode_transition_started(old_mode, new_mode) mm_restore()
public mm_mode_changed(old_mode, new_mode) mm_apply()
public plugin_end() mm_restore()

public mm_rules_pre()
{
    g_in_rules_think = g_applied && get_pcvar_num(g_enabled) != 0
    return HC_CONTINUE
}
public mm_rules_post()
{
    g_in_rules_think = false
    return HC_CONTINUE
}
public mm_engine_cvar_pre(pointer, const value[])
{
    if (!g_in_rules_think || !g_applied) return HC_CONTINUE
    for (new i = 0; i < 3; i++)
    {
        // CSGameRules restores these three constants once per second. Block
        // only that native reset while our preset still owns the current value.
        if (pointer == g_engine[i] && floatabs(str_to_float(value)-NATIVE_VALUES[i]) < 0.001 && floatabs(get_pcvar_float(pointer)-g_applied_values[i]) < 0.001)
        {
            g_guarded_resets++
            return HC_SUPERCEDE
        }
    }
    return HC_CONTINUE
}

public mm_status()
{
    server_print("[Counter-Strafe] version=%s enabled=%d applied=%d mode=%d accelerate=%.2f friction=%.2f stopspeed=%.0f", PLUGIN_VERSION, get_pcvar_num(g_enabled), g_applied, _:mm_get_active_mode(), get_pcvar_float(g_engine[0]), get_pcvar_float(g_engine[1]), get_pcvar_float(g_engine[2]))
    server_print("[Counter-Strafe] saved_baseline=%.2f,%.2f,%.0f", g_saved[0], g_saved[1], g_saved[2])
    server_print("[Counter-Strafe] native_resets_guarded=%d", g_guarded_resets)
}
