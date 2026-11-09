#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <xs>
#include <mm_mode_api>

new const PLUGIN_NAME[] = "Knife Admin Spectator"
new const PLUGIN_VERSION[] = "1.3.8"
new const PLUGIN_AUTHOR[] = "ApexiumForge"
new const ATTACH_SOUND[] = "weapons/xbow_hit2.wav"
new const GRAB_SOUND[] = "weapons/xbow_fire1.wav"

#define ACCESS_FLAG ADMIN_CFG
#define TASK_TOOL 981000
#define TASK_TEST_BOT 981100
#define TOOL_INTERVAL 0.10
#define HOOK_SPEED 600.0
#define HOOK_GRAVITY 0.01
#define ROPE_IMPULSE 100.0
#define ROPE_MAX_SPEED 950.0
#define TOOL_RANGE 9999.0
#define GRAB_RANGE 9999.0
#define GRAB_MIN_DISTANCE 72.0
#define GRAB_DISTANCE_RATE 360.0
#define GRAB_PULL_GAIN 3.0
#define BEAM_INTERVAL 0.20

enum SpecTool { TOOL_HOOK = 1, TOOL_GRAB = 2, TOOL_ROPE = 4 }
new bool:g_enabled[MAX_PLAYERS + 1]
new TeamName:g_previous_team[MAX_PLAYERS + 1]
new g_tools[MAX_PLAYERS + 1]
new g_target[MAX_PLAYERS + 1], g_grab_owner[MAX_PLAYERS + 1], g_beam
new Float:g_hook_anchor[MAX_PLAYERS + 1][3], Float:g_rope_anchor[MAX_PLAYERS + 1][3]
new Float:g_grab_length[MAX_PLAYERS + 1], Float:g_rope_length[MAX_PLAYERS + 1]
new g_grab_direction[MAX_PLAYERS + 1]
new Float:g_grab_saved_gravity[MAX_PLAYERS + 1]
new Float:g_next_beam[MAX_PLAYERS + 1], Float:g_saved_damage[MAX_PLAYERS + 1]
new Float:g_saved_gravity[MAX_PLAYERS + 1]
new const TEST_BOT_NAME[] = "Grab_Test"
new g_test_bot, g_bot_connect_ticks
new bool:g_bot_spawned

public plugin_precache()
{
    g_beam = precache_model("sprites/laserbeam.spr")
    precache_sound(ATTACH_SOUND)
    precache_sound(GRAB_SOUND)
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /spec", "mm_spec_toggle", ACCESS_FLAG, "- toggle Knife admin spectator")
    register_clcmd("say_team /spec", "mm_spec_toggle", ACCESS_FLAG)
    register_clcmd("+hook", "mm_hook", ACCESS_FLAG, "- hold to pull toward a surface")
    register_clcmd("+grab", "mm_grab", ACCESS_FLAG, "- hold to move the player in your crosshair")
    register_clcmd("+rope", "mm_rope", ACCESS_FLAG, "- hold to swing from a surface")
    register_clcmd("-hook", "mm_hook_release")
    register_clcmd("-grab", "mm_grab_release")
    register_clcmd("-rope", "mm_rope_release")
    register_clcmd("say /spectools", "mm_controls", ACCESS_FLAG, "- show Knife spectator binds")
    register_clcmd("say_team /spectools", "mm_controls", ACCESS_FLAG)
    register_clcmd("jointeam", "mm_block_team_command")
    register_clcmd("chooseteam", "mm_block_team_command")
    register_srvcmd("mm_knife_spec_status", "mm_status")
    register_srvcmd("mm_knife_grab_bot", "mm_add_test_bot")
    register_srvcmd("mm_knife_remove_grab_bot", "mm_remove_test_bot")
    register_event("TeamInfo", "mm_team_changed", "a")
    RegisterHam(Ham_TakeDamage, "player", "mm_damage_pre")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "mm_knife_attack")
    RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "mm_knife_attack")
    register_forward(FM_CmdStart, "mm_cmd_start")
    register_forward(FM_StartFrame, "mm_physics_frame")
    RegisterHam(Ham_Killed, "player", "mm_grab_target_killed", 1)
    register_forward(FM_AddToFullPack, "mm_grab_glow", 1)
    log_amx("%s v%s initialized.", PLUGIN_NAME, PLUGIN_VERSION)
}

bool:mm_knife_active()
{
    return mm_get_active_mode() == MM_MODE_KNIFE && mm_get_transition_state() == MM_TRANSITION_IDLE
}

bool:mm_authorized(id)
{
    return id >= 1 && id <= MaxClients && is_user_connected(id) && (get_user_flags(id) & ACCESS_FLAG) != 0
}

bool:mm_spectating(id)
{
    return mm_knife_active() && mm_authorized(id) && g_enabled[id] && is_user_alive(id) && get_member(id, m_iTeam) == TEAM_SPECTATOR
}

public mm_spec_toggle(id)
{
    if (!mm_knife_active()) return PLUGIN_CONTINUE
    if (!mm_authorized(id)) return PLUGIN_HANDLED

    if (g_enabled[id])
    {
        mm_end_session(id, true)
        client_print_color(id, print_team_default, "^4[^1Knife^4]^1 Admin spectator tools off.")
        return PLUGIN_HANDLED
    }

    new TeamName:team = get_member(id, m_iTeam)
    if (!is_user_alive(id))
    {
        if (team != TEAM_CT && team != TEAM_TERRORIST)
            rg_set_user_team(id, TEAM_CT, MODEL_AUTO, false)
        rg_round_respawn(id)
        if (!is_user_alive(id))
        {
            rg_set_user_team(id, team, MODEL_UNASSIGNED)
            client_print_color(id, print_team_default, "^4[^1Knife^4]^1 Couldn't spawn your spectator body. Try again next round.")
            return PLUGIN_HANDLED
        }
    }

    // Changing the team of a living player preserves the player body and movement.
    pev(id, pev_takedamage, g_saved_damage[id])
    g_previous_team[id] = team
    g_enabled[id] = true
    if (!rg_set_user_team(id, TEAM_SPECTATOR, MODEL_UNASSIGNED, true, true))
    {
        mm_clear(id)
        return PLUGIN_HANDLED
    }
    set_pev(id, pev_takedamage, DAMAGE_NO)
    client_print_color(id, print_team_default, "^4[^1Knife^4]^1 Playable spectator on. ^3/spectools^1 for binds, ^3/spec^1 to exit.")
    return PLUGIN_HANDLED
}

mm_end_session(id, bool:rejoin)
{
    new TeamName:previous = g_previous_team[id]
    mm_clear(id)
    if (!is_user_connected(id)) return

    // JoinTeam needs a different team to run the normal observer setup.
    rg_set_user_team(id, TEAM_CT, MODEL_UNASSIGNED, false)
    rg_join_team(id, TEAM_SPECTATOR)
    if (rejoin && (previous == TEAM_CT || previous == TEAM_TERRORIST))
        rg_join_team(id, previous)
}

public mm_controls(id)
{
    if (!mm_knife_active()) return PLUGIN_CONTINUE
    if (!mm_authorized(id)) return PLUGIN_HANDLED
    console_print(id, "[Knife] Example binds: bind f +hook | bind g +grab | bind r +rope")
    console_print(id, "[Knife] While holding grab, Mouse 1 pushes away and Mouse 2 pulls closer.")
    client_print_color(id, print_team_default, "^4[^1Knife^4]^1 Spectator tool binds printed in your console.")
    return PLUGIN_HANDLED
}

public mm_hook(id) return mm_start_tool(id, TOOL_HOOK)
public mm_grab(id) return mm_start_tool(id, TOOL_GRAB)
public mm_rope(id) return mm_start_tool(id, TOOL_ROPE)
public mm_hook_release(id) return mm_release_tool(id, TOOL_HOOK)
public mm_grab_release(id) return mm_release_tool(id, TOOL_GRAB)
public mm_rope_release(id) return mm_release_tool(id, TOOL_ROPE)

mm_start_tool(id, SpecTool:tool)
{
    if (!mm_spectating(id)) return PLUGIN_CONTINUE
    if (g_tools[id] & _:tool) return PLUGIN_HANDLED
    if (tool == TOOL_GRAB)
    {
        g_grab_direction[id] = 0
        mm_enable_tool(id, tool)
        mm_tool_tick(TASK_TOOL + id)
        return PLUGIN_HANDLED
    }

    new Float:origin[3], Float:direction[3], Float:end[3], Float:offset[3]
    mm_aim(id, origin, direction)
    pev(id, pev_view_ofs, offset)
    xs_vec_add(origin, offset, origin)
    xs_vec_mul_scalar(direction, TOOL_RANGE, end)
    xs_vec_add(origin, end, end)
    new trace = create_tr2()
    engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, id, trace)
    new Float:fraction, Float:normal[3]
    get_tr2(trace, TR_flFraction, fraction)
    get_tr2(trace, TR_vecEndPos, end)
    get_tr2(trace, TR_vecPlaneNormal, normal)
    free_tr2(trace)
    if (fraction >= 1.0)
    {
        client_print(id, print_center, "Aim at a surface in range.")
        return PLUGIN_HANDLED
    }

    pev(id, pev_origin, origin)
    if (tool == TOOL_HOOK)
    {
        // Stop the player hull short of the wall or ceiling.
        new Float:height = (pev(id, pev_flags) & FL_DUCKING) ? 18.0 : 36.0
        new Float:clearance = 4.0 + 16.0 * (floatabs(normal[0]) + floatabs(normal[1])) + height * floatabs(normal[2])
        xs_vec_mul_scalar(normal, clearance, normal)
        xs_vec_add(end, normal, g_hook_anchor[id])
        pev(id, pev_gravity, g_saved_gravity[id])
        set_pev(id, pev_gravity, HOOK_GRAVITY)
        mm_beam(id, tool, g_hook_anchor[id])
    }
    else
    {
        xs_vec_copy(end, g_rope_anchor[id])
        g_rope_length[id] = floatmax(48.0, get_distance_f(origin, g_rope_anchor[id]))
        if ((pev(id, pev_flags) & FL_ONGROUND) && g_rope_anchor[id][2] > origin[2] + 32.0)
        {
            new Float:velocity[3]
            pev(id, pev_velocity, velocity)
            velocity[2] = 180.0
            set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_ONGROUND)
            set_pev(id, pev_velocity, velocity)
        }
        mm_beam(id, tool, g_rope_anchor[id])
    }

    mm_enable_tool(id, tool)
    emit_sound(id, CHAN_ITEM, ATTACH_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
    g_next_beam[id] = get_gametime() + BEAM_INTERVAL
    mm_tool_tick(TASK_TOOL + id)
    return PLUGIN_HANDLED
}

mm_enable_tool(id, SpecTool:tool)
{
    if (!g_tools[id])
        set_task(TOOL_INTERVAL, "mm_tool_tick", TASK_TOOL + id, _, _, "b")
    g_tools[id] |= _:tool
}

public mm_tool_tick(task)
{
    new id = task - TASK_TOOL
    if (!mm_spectating(id))
    {
        mm_stop_tool(id)
        return
    }

    new Float:origin[3]
    pev(id, pev_origin, origin)

    // Hook sets the pull, then rope adds swing and limits outward motion.
    if (g_tools[id] & _:TOOL_HOOK) mm_hook_move(id, origin)
    if (g_tools[id] & _:TOOL_ROPE) mm_rope_move(id, origin)
    if (g_tools[id] & _:TOOL_GRAB)
    {
        if (!g_target[id]) mm_grab_acquire(id, origin)
        if (g_target[id] && !mm_grab_move(id, origin)) mm_release_tool(id, TOOL_GRAB)
    }

    if (get_gametime() >= g_next_beam[id])
    {
        g_next_beam[id] = get_gametime() + BEAM_INTERVAL
        if (g_tools[id] & _:TOOL_HOOK) mm_beam(id, TOOL_HOOK, g_hook_anchor[id])
        if (g_tools[id] & _:TOOL_ROPE) mm_beam(id, TOOL_ROPE, g_rope_anchor[id])
        if (g_target[id])
        {
            new Float:target_origin[3]
            pev(g_target[id], pev_origin, target_origin)
            mm_beam(id, TOOL_GRAB, target_origin)
        }
    }
}

mm_grab_acquire(id, const Float:origin[3])
{
    if (get_member_game(m_bFreezePeriod)) return
    new target, hitgroup
    get_user_aiming(id, target, hitgroup, floatround(GRAB_RANGE))
    if (target < 1 || target > MaxClients || !is_user_alive(target) || g_enabled[target]
        || g_grab_owner[target] || (get_user_flags(target) & ADMIN_IMMUNITY)) return

    new Float:target_origin[3]
    pev(target, pev_origin, target_origin)
    g_grab_owner[target] = id
    g_target[id] = target
    g_grab_length[id] = floatclamp(get_distance_f(origin, target_origin), GRAB_MIN_DISTANCE, GRAB_RANGE)
    pev(target, pev_gravity, g_grab_saved_gravity[id])
    set_pev(target, pev_gravity, 0.0)
    emit_sound(id, CHAN_ITEM, GRAB_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
    mm_beam(id, TOOL_GRAB, target_origin)
    g_next_beam[id] = get_gametime() + BEAM_INTERVAL
}

bool:mm_grab_move(id, const Float:origin[3])
{
    new target = g_target[id]
    if (!is_user_alive(target) || g_enabled[target] || get_member_game(m_bFreezePeriod)) return false

    // GHW GHR projects the origin-to-aim-hit vector to the initial grab distance.
    // Mouse buttons adjust that distance before applying the original velocity gain.
    new aim_hit[3]
    get_user_origin(id, aim_hit, 3)
    new Float:offset[3], Float:target_origin[3]
    IVecFVec(aim_hit, offset)
    xs_vec_sub(offset, origin, offset)
    new Float:aim_distance = xs_vec_len(offset)
    if (aim_distance <= 1.0) return true

    g_grab_length[id] = floatclamp(g_grab_length[id] + GRAB_DISTANCE_RATE * TOOL_INTERVAL * float(g_grab_direction[id]), GRAB_MIN_DISTANCE, GRAB_RANGE)
    xs_vec_mul_scalar(offset, g_grab_length[id] / aim_distance, offset)
    xs_vec_add(origin, offset, offset)
    pev(target, pev_origin, target_origin)
    xs_vec_sub(offset, target_origin, offset)
    xs_vec_mul_scalar(offset, GRAB_PULL_GAIN, offset)
    set_pev(target, pev_velocity, offset)
    return true
}

mm_beam(id, SpecTool:tool, const Float:end[3])
{
    message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id)
    write_byte(TE_BEAMENTPOINT)
    write_short(id)
    engfunc(EngFunc_WriteCoord, end[0])
    engfunc(EngFunc_WriteCoord, end[1])
    engfunc(EngFunc_WriteCoord, end[2])
    write_short(g_beam)
    write_byte(0); write_byte(0); write_byte(3); write_byte(tool == TOOL_GRAB ? 10 : 8); write_byte(0)
    write_byte(tool == TOOL_GRAB ? 255 : 25)
    write_byte(tool == TOOL_ROPE ? 255 : tool == TOOL_HOOK ? 70 : 12)
    write_byte(tool == TOOL_HOOK ? 255 : tool == TOOL_GRAB ? 12 : 80)
    write_byte(tool == TOOL_GRAB ? 255 : 190); write_byte(0)
    message_end()
}

mm_aim(id, Float:origin[3], Float:direction[3])
{
    new Float:angles[3]
    pev(id, pev_origin, origin)
    pev(id, pev_v_angle, angles)
    engfunc(EngFunc_MakeVectors, angles)
    global_get(glb_v_forward, direction)
}

// Movement adapted from GHW_Chronic's GHR release:
// https://forums.alliedmods.net/showthread.php?t=41054
mm_hook_move(id, const Float:origin[3])
{
    new Float:velocity[3]
    xs_vec_sub(g_hook_anchor[id], origin, velocity)
    new Float:distance = xs_vec_len(velocity)
    if (distance <= 2.0)
    {
        xs_vec_set(velocity, 0.0, 0.0, 0.0)
    }
    else
    {
        new Float:speed = floatmin(HOOK_SPEED, distance / TOOL_INTERVAL)
        xs_vec_mul_scalar(velocity, speed / distance, velocity)
        set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_ONGROUND)
    }
    set_pev(id, pev_velocity, velocity)
}

mm_rope_move(id, const Float:origin[3])
{
    new Float:velocity[3], Float:radial[3]
    pev(id, pev_velocity, velocity)
    xs_vec_sub(origin, g_rope_anchor[id], radial)
    new Float:horizontal = floatsqroot(radial[0] * radial[0] + radial[1] * radial[1])
    if (horizontal > 1.0)
    {
        velocity[0] -= radial[0] * ROPE_IMPULSE / horizontal
        velocity[1] -= radial[1] * ROPE_IMPULSE / horizontal
    }

    // Keep tangential speed. Correct only outward motion at the rope limit.
    new Float:distance = xs_vec_len(radial)
    // GHR's hook supplies the main pull while the rope adds a smaller impulse.
    if (!(g_tools[id] & _:TOOL_HOOK) && distance > 1.0 && distance >= g_rope_length[id] - 4.0)
    {
        xs_vec_mul_scalar(radial, 1.0 / distance, radial)
        new Float:outward = xs_vec_dot(velocity, radial)
        new Float:allowed = (g_rope_length[id] - distance) / TOOL_INTERVAL
        if (outward > allowed)
        {
            xs_vec_mul_scalar(radial, outward - allowed, radial)
            xs_vec_sub(velocity, radial, velocity)
        }
    }
    new Float:speed = xs_vec_len(velocity)
    if (speed > ROPE_MAX_SPEED) xs_vec_mul_scalar(velocity, ROPE_MAX_SPEED / speed, velocity)
    set_pev(id, pev_velocity, velocity)
}

mm_release_tool(id, SpecTool:tool)
{
    if (id < 1 || id > MaxClients || !(g_tools[id] & _:tool)) return PLUGIN_CONTINUE
    if (tool == TOOL_HOOK && is_user_connected(id))
        set_pev(id, pev_gravity, g_saved_gravity[id])
    if (tool == TOOL_GRAB)
    {
        new target = g_target[id]
        if (target && g_grab_owner[target] == id)
        {
            g_grab_owner[target] = 0
            if (is_user_connected(target)) set_pev(target, pev_gravity, g_grab_saved_gravity[id])
        }
        g_target[id] = 0
    }
    g_tools[id] &= ~(_:tool)
    if (!g_tools[id]) remove_task(TASK_TOOL + id)
    return PLUGIN_HANDLED
}

mm_stop_tool(id)
{
    mm_release_tool(id, TOOL_HOOK)
    mm_release_tool(id, TOOL_ROPE)
    mm_release_tool(id, TOOL_GRAB)
}

mm_clear(id)
{
    mm_stop_tool(id)
    g_enabled[id] = false
    g_previous_team[id] = TEAM_UNASSIGNED
}

public mm_team_changed()
{
    new id = read_data(1)
    if (id < 1 || id > MaxClients || !g_enabled[id]) return
    new team[16]
    read_data(2, team, charsmax(team))
    if (!equal(team, "SPECTATOR"))
    {
        if (is_user_alive(id)) set_pev(id, pev_takedamage, g_saved_damage[id])
        mm_clear(id)
    }
}

public client_disconnected(id)
{
    if (id == g_test_bot)
    {
        remove_task(TASK_TEST_BOT)
        g_test_bot = 0
    }
    mm_clear(id)
    for (new owner = 1; owner <= MaxClients; owner++)
        if (g_target[owner] == id) mm_release_tool(owner, TOOL_GRAB)
}

public mm_mode_transition_started(old_mode, new_mode)
{
    if (MmMode:old_mode != MM_MODE_KNIFE) return
    mm_remove_test_bot()
    for (new id = 1; id <= MaxClients; id++)
        if (g_enabled[id]) mm_end_session(id, false)
}

public mm_cmd_start(id, command)
{
    if (!mm_spectating(id)) return FMRES_IGNORED
    new buttons = get_uc(command, UC_Buttons)
    if (g_tools[id] & _:TOOL_GRAB)
        g_grab_direction[id] = ((buttons & IN_ATTACK) ? 1 : 0) - ((buttons & IN_ATTACK2) ? 1 : 0)
    new blocked = buttons & (IN_ATTACK | IN_ATTACK2 | IN_USE | IN_RELOAD)
    if (!blocked) return FMRES_IGNORED
    set_uc(command, UC_Buttons, buttons & ~blocked)
    return FMRES_HANDLED
}

public mm_grab_target_killed(id)
{
    if (g_grab_owner[id]) mm_release_tool(g_grab_owner[id], TOOL_GRAB)
    return HAM_IGNORED
}

public mm_physics_frame()
{
    if (!mm_knife_active()) return

    new Float:dt
    global_get(glb_frametime, dt)
    if (dt <= 0.0) return
    dt = floatmin(dt, 0.05)

    if (g_test_bot && g_bot_spawned && is_user_alive(g_test_bot))
    {
        new Float:angles[3]
        pev(g_test_bot, pev_v_angle, angles)
        new milliseconds = max(1, floatround(dt * 1000.0))
        engfunc(EngFunc_RunPlayerMove, g_test_bot, angles, 0.0, 0.0, 0.0, 0, 0, milliseconds)
    }
}

public mm_grab_glow(entity_state, entity_index, entity, host, host_flags, player, set)
{
    if (!player || entity < 1 || entity > MaxClients || !g_grab_owner[entity])
        return FMRES_IGNORED

    // Apply the shell only to the networked copy. Release leaves underlying rendering intact.
    static const red[3] = {255, 0, 0}
    set_es(entity_state, ES_RenderFx, kRenderFxGlowShell)
    set_es(entity_state, ES_RenderColor, red)
    set_es(entity_state, ES_RenderMode, kRenderTransAlpha)
    set_es(entity_state, ES_RenderAmt, 70)
    return FMRES_IGNORED
}

public mm_damage_pre(victim, inflictor, attacker, Float:damage, bits)
{
    return mm_spectating(victim) || mm_spectating(attacker) ? HAM_SUPERCEDE : HAM_IGNORED
}

public mm_status()
{
    new admins
    for (new id = 1; id <= MaxClients; id++)
        if (mm_spectating(id)) admins++
    server_print("[MM Knife Spec] version=%s active=%d admins=%d", PLUGIN_VERSION, mm_knife_active(), admins)
}

public mm_knife_attack(weapon)
{
    return mm_spectating(get_member(weapon, m_pPlayer)) ? HAM_SUPERCEDE : HAM_IGNORED
}

public mm_block_team_command(id)
{
    return mm_spectating(id) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public mm_add_test_bot()
{
    if (!mm_knife_active() || g_test_bot || find_player("a", TEST_BOT_NAME)) return

    new bot = engfunc(EngFunc_CreateFakeClient, TEST_BOT_NAME)
    if (bot < 1 || bot > MaxClients)
    {
        server_print("[MM Knife Spec] Could not create grab test bot.")
        return
    }

    engfunc(EngFunc_FreeEntPrivateData, bot)
    new rejected[128]
    if (!dllfunc(DLLFunc_ClientConnect, bot, TEST_BOT_NAME, "127.0.0.1", rejected))
    {
        server_cmd("kick ^"%s^"", TEST_BOT_NAME)
        server_print("[MM Knife Spec] Grab test bot connection rejected.")
        return
    }

    dllfunc(DLLFunc_ClientPutInServer, bot)
    set_pev(bot, pev_flags, pev(bot, pev_flags) | FL_FAKECLIENT)
    g_test_bot = bot
    g_bot_connect_ticks = 0
    g_bot_spawned = false
    set_task(0.10, "mm_test_bot_tick", TASK_TEST_BOT, _, _, "b")
}

public mm_test_bot_tick()
{
    if (!mm_knife_active() || !g_test_bot)
    {
        mm_remove_test_bot()
        return
    }
    if (!is_user_connected(g_test_bot))
    {
        if (++g_bot_connect_ticks >= 20) mm_remove_test_bot()
        return
    }

    if (!g_bot_spawned)
    {
        rg_set_user_team(g_test_bot, TEAM_TERRORIST)
        set_member(g_test_bot, m_iJoiningState, JOINED)
        rg_round_respawn(g_test_bot)
        g_bot_spawned = true
        server_print("[MM Knife Spec] Grab_Test added. Alive=%d", is_user_alive(g_test_bot))
    }

    remove_task(TASK_TEST_BOT)
}

public mm_remove_test_bot()
{
    remove_task(TASK_TEST_BOT)
    if (!g_test_bot) return
    new userid = get_user_userid(g_test_bot)
    if (userid > 0) server_cmd("kick #%d", userid)
    else server_cmd("kick ^"%s^"", TEST_BOT_NAME)
    g_test_bot = 0
}
