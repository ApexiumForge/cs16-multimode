#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <mm_mode_api>

new const PLUGIN_NAME[] = "Multi-Mode Arcade Spawn Protection"
new const PLUGIN_VERSION[] = "1.1.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new Float:g_until[33]
new g_duration

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_forward(FM_AddToFullPack, "mm_protection_glow", 1)
    RegisterHam(Ham_Spawn, "player", "mm_spawn_post", 1)
    RegisterHam(Ham_Killed, "player", "mm_death_post", 1)
    RegisterHam(Ham_TakeDamage, "player", "mm_damage_pre")
    register_forward(FM_CmdStart, "mm_command")
    g_duration = register_cvar("mm_arcade_spawn_protection", "2.0")
    log_amx("Arms Race and HE Battle spawn protection initialized; attack cancels protection.")
}

bool:mm_target()
{
    new MmMode:mode = mm_get_active_mode()
    return mm_get_transition_state() == MM_TRANSITION_IDLE && (mode == MM_MODE_ARMS_RACE || mode == MM_MODE_HE_BATTLE)
}

public mm_spawn_post(id)
{
    g_until[id] = 0.0
    if (is_user_alive(id) && mm_target())
        g_until[id] = get_gametime() + floatclamp(get_pcvar_float(g_duration), 0.0, 5.0)
}

public mm_command(id, command, seed)
{
    if (g_until[id] > 0.0 && (get_uc(command, UC_Buttons) & (IN_ATTACK | IN_ATTACK2))) g_until[id] = 0.0
    return FMRES_IGNORED
}

public mm_damage_pre(victim, inflictor, attacker, Float:damage, bits)
{
    if (mm_target() && g_until[victim] > get_gametime()) return HAM_SUPERCEDE
    return HAM_IGNORED
}

public mm_death_post(victim, attacker, gib) g_until[victim] = 0.0
public client_disconnected(id) g_until[id] = 0.0
public client_putinserver(id) g_until[id] = 0.0

public mm_mode_transition_started(old_mode, new_mode)
{
    arrayset(g_until, 0, sizeof g_until)
}

public mm_mode_changed(old_mode, new_mode)
{
    for (new id = 1; id <= MaxClients; id++) mm_spawn_post(id)
}

// Packet-only effect: protection ending restores the normal model automatically.
public mm_protection_glow(packet, e, entity, host, host_flags, player, pset)
{
    if (!player || entity < 1 || entity > MaxClients || !is_user_alive(entity)) return FMRES_IGNORED
    if (mm_target() && g_until[entity] > get_gametime())
    {
        set_es(packet, ES_RenderFx, kRenderFxGlowShell)
        set_es(packet, ES_RenderColor, {80, 220, 120})
        set_es(packet, ES_RenderAmt, 8)
        set_es(packet, ES_RenderMode, kRenderNormal)
    }
    return FMRES_IGNORED
}
