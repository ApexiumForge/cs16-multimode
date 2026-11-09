/*
 * CSB SoccerJam
 * Copyright (C) 2026 counter-strike-boost.com
 *
 * A football game mode. A bouncing physics ball is spawned from a per-map data
 * file; touching it (or knifing into it) kicks it with an impulse along your aim,
 * scaled by how fast you are moving. Two goal zones from the data file are watched
 * on a task; putting the ball in the enemy goal scores a point, resets the ball
 * to centre and plays a goal sound. The score is shown on a HUD.
 *
 * Inspired by SoccerJam by Freecode. Independent GPL re-implementation.
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. It is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See <https://www.gnu.org/licenses/> for details.
 */

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <reapi>
#include <mm_mode_api>
#include <mm_presentation_api>

// Adapted for Torbeshi multimode: scoped lifecycle, pitch boxes, controls and rounds.
new const PLUGIN_NAME[] = "Multi-Mode Football"
new const PLUGIN_VERSION[] = "1.4.3"
new const PLUGIN_AUTHOR[] = "CSB / Torbeshi"
new const BALL_CLASS[] = "mm_football_ball"
new const BALL_MODEL[] = "models/kickball/ball.mdl"
new const BOUNCE_SOUND[] = "kickball/bounce.wav"
new const WHISTLE_SOUND[] = "kickball/whistle.wav"
#define MM_FB_TICK 897000
#define MM_FB_RESET 897001
#define MM_FB_COUNTDOWN 897002
#define MM_FB_GOAL_LIGHT 897003
#define MM_FB_RESPAWN 897100
#define MM_FB_LOADOUT 897200
#define MM_FB_CARRY_DISTANCE 42.0
#define MM_FB_PICKUP_DISTANCE 100.0
#define MM_FB_TACKLE_DISTANCE 44.0
#define MM_FB_ROLL_DECEL 240.0
#define MM_FB_PLAYER_SPEED 400.0
#define MM_FB_BALL_RADIUS 10.0
#define MM_FB_RESTART_INSET 56.0
#define MM_FB_RESTART_WINDOW 2.0
new g_ball, g_last_touch, g_score[2], g_hud, g_goal_limit, g_added_spawns
new g_carrier, CsTeams:g_carrier_team, g_pickups, g_releases
new g_trail_sprite, CsTeams:g_trail_team
new g_notice_hud, g_sv_maxspeed
new Float:g_saved_maxspeed
new bool:g_speed_applied
new bool:g_bounds_ready
new Float:g_pitch_min[2], Float:g_pitch_max[2], Float:g_restart_until
new CsTeams:g_restart_team, CsTeams:g_next_kickoff
new g_explosion_sprite, g_goal_explosions
new g_goal_lights, g_light_team, g_light_ticks, g_light_bursts, g_light_pulses
new g_restart_seconds
new g_minutes, g_shot_power, g_pass_power, g_goals[33], g_assists[33], g_power[33][2], g_assist
new Float:g_match_started, Float:g_touch_time
new g_out_count
new bool:g_enabled, bool:g_field_ready, bool:g_paused
new Float:g_spawn[3], Float:g_goal[2][3], Float:g_previous[3]
new Float:g_last_manual[33]
new Float:g_last_bounce, Float:g_last_motion, Float:g_last_hud, Float:g_last_tick
new Float:g_pickup_after, Float:g_player_pickup_after[33]

public plugin_precache()
{
    precache_model(BALL_MODEL)
    precache_sound(BOUNCE_SOUND)
    precache_sound(WHISTLE_SOUND)
    g_trail_sprite = precache_model("sprites/laserbeam.spr")
    g_explosion_sprite = precache_model("sprites/zerogxplode.spr")
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    RegisterHam(Ham_Spawn, "player", "mm_spawn_post", 1)
    RegisterHam(Ham_Killed, "player", "mm_killed_post", 1)
    RegisterHam(Ham_TakeDamage, "player", "mm_damage_pre")
    RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "mm_reset_speed_post", 1)
    RegisterHookChain(RG_CBasePlayer_GiveDefaultItems, "mm_default_items", false)
    RegisterHookChain(RG_BuyWeaponByWeaponID, "mm_buy_weapon", false)
    RegisterHookChain(RG_BuyGunAmmo, "mm_buy_ammo", false)
    RegisterHookChain(RG_BuyItem, "mm_buy_item", false)
    RegisterHam(Ham_Touch, "weaponbox", "mm_world_touch")
    RegisterHam(Ham_Touch, "armoury_entity", "mm_world_touch")
    RegisterHam(Ham_Touch, "weapon_shield", "mm_world_touch")
    RegisterHam(Ham_Use, "game_player_equip", "mm_map_use")
    RegisterHam(Ham_Touch, "game_player_equip", "mm_world_touch")
    register_touch(BALL_CLASS, "*", "mm_ball_touch")
    register_forward(FM_CmdStart, "mm_command")
    register_forward(FM_PlayerPostThink, "mm_player_postthink", 1)
    register_forward(FM_AddToFullPack, "mm_carrier_glow", 1)
    new const commands[][] = {"buy","buyequip","autobuy","rebuy","cl_autobuy","cl_rebuy","buyammo1","buyammo2","drop"}
    for (new i = 0; i < sizeof commands; i++) register_clcmd(commands[i], "mm_block_command")
    register_clcmd("say /football", "mm_help")
    register_clcmd("say_team /football", "mm_help")
    register_clcmd("say /soccer", "mm_help")
    register_concmd("mm_football_reset", "mm_admin_reset", ADMIN_CFG, "Reset football scores and kickoff")
    register_srvcmd("mm_football_status", "mm_status")
    register_srvcmd("mm_football_selftest", "mm_selftest")
    register_clcmd("say /ftop", "mm_top")
    register_clcmd("say_team /ftop", "mm_top")
    g_minutes = register_cvar("mm_football_minutes", "10")
    g_shot_power = register_cvar("mm_football_shot_power", "1100")
    g_pass_power = register_cvar("mm_football_pass_power", "650")
    g_goal_lights = register_cvar("mm_football_goal_lights", "1")
    register_srvcmd("mm_football_light_test", "mm_light_test")
    g_goal_limit = register_cvar("mm_football_goal_limit", "5")
    g_hud = CreateHudSyncObj()
    g_notice_hud = CreateHudSyncObj()
    g_sv_maxspeed = get_cvar_pointer("sv_maxspeed")
    log_amx("Football initialized: GPL CSB ball core adapted for mode-scoped team play.")
}

public plugin_cfg()
{
    g_field_ready = mm_load_field()
    if (g_field_ready)
    {
        mm_expand_spawns("info_player_start")
        mm_expand_spawns("info_player_deathmatch")
    }
    if (mm_active()) mm_activate()
}

bool:mm_active() {return mm_get_active_mode() == MM_MODE_FOOTBALL;}
bool:mm_playing(id)
{
    if (id < 1 || id > MaxClients || !is_user_connected(id)) return false
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

public mm_mode_transition_started(old_mode, new_mode)
{
    if (MmMode:old_mode == MM_MODE_FOOTBALL) mm_shutdown()
}
public mm_mode_changed(old_mode, new_mode)
{
    if (MmMode:new_mode == MM_MODE_FOOTBALL) mm_activate()
    else if (g_enabled) mm_shutdown()
}

mm_activate()
{
    mm_shutdown()
    g_enabled = true
    g_saved_maxspeed = get_pcvar_float(g_sv_maxspeed)
    set_pcvar_float(g_sv_maxspeed, floatmax(g_saved_maxspeed, MM_FB_PLAYER_SPEED))
    g_speed_applied = true
    arrayset(g_score, 0, sizeof g_score)
    arrayset(g_goals, 0, sizeof g_goals); arrayset(g_assists, 0, sizeof g_assists)
    g_match_started = get_gametime(); g_assist = 0
    if (!g_field_ready) {log_amx("No pitch data here; waiting for dedicated map routing."); return;}
    g_ball = create_entity("info_target")
    if (!is_valid_ent(g_ball)) {g_ball = 0; log_amx("Could not create football."); return;}
    entity_set_string(g_ball, EV_SZ_classname, BALL_CLASS)
    entity_set_model(g_ball, BALL_MODEL)
    entity_set_int(g_ball, EV_INT_movetype, MOVETYPE_BOUNCE)
    entity_set_int(g_ball, EV_INT_solid, SOLID_BBOX)
    entity_set_float(g_ball, EV_FL_gravity, 0.65)
    entity_set_float(g_ball, EV_FL_friction, 0.6)
    entity_set_float(g_ball, EV_FL_dmg, 0.0)
    entity_set_size(g_ball, Float:{-10.0,-10.0,-10.0}, Float:{10.0,10.0,10.0})
    set_task(0.05, "mm_tick", MM_FB_TICK, "", 0, "b")
    mm_kickoff()
    client_print_color(0, print_team_grey, "^4[Football]^3 First to ^4%d^3 goals! Run over the ball to control it; ^4E/left click^3 shoot, ^4R/right click^3 pass. ^1/football^3 for help.", clamp(get_pcvar_num(g_goal_limit), 1, 30))
}

mm_shutdown()
{
    if (g_speed_applied)
    {
        set_pcvar_float(g_sv_maxspeed, g_saved_maxspeed)
        g_speed_applied = false
    }
    remove_task(MM_FB_TICK); remove_task(MM_FB_RESET); remove_task(MM_FB_COUNTDOWN); remove_task(MM_FB_GOAL_LIGHT)
    g_light_ticks = 0
    for (new id = 1; id <= MaxClients; id++)
    {
        remove_task(MM_FB_RESPAWN + id); remove_task(MM_FB_LOADOUT + id)
        if (g_enabled && is_user_connected(id)) set_user_maxspeed(id, -1.0)
    }
    if (is_valid_ent(g_ball)) {mm_clear_trail(); remove_entity(g_ball);}
    g_ball = 0; g_enabled = false; g_paused = false; g_last_touch = 0
    g_carrier = 0; g_carrier_team = CS_TEAM_UNASSIGNED
    g_restart_team = CS_TEAM_UNASSIGNED; g_next_kickoff = CS_TEAM_UNASSIGNED; g_restart_until = 0.0
    arrayset(g_player_pickup_after, 0, sizeof g_player_pickup_after)
    ClearSyncHud(0, g_hud)
    ClearSyncHud(0, g_notice_hud)
}
public plugin_end() mm_shutdown()
public client_disconnected(id)
{
    if (g_carrier == id) mm_release_ball()
    remove_task(MM_FB_RESPAWN + id); remove_task(MM_FB_LOADOUT + id)
    if (g_last_touch == id) g_last_touch = 0
    g_goals[id] = 0; g_assists[id] = 0; g_power[id][0] = 0; g_power[id][1] = 0
    if (g_assist == id) g_assist = 0
    g_last_manual[id] = 0.0
    g_player_pickup_after[id] = 0.0
}

bool:mm_load_field()
{
    new map[32], path[192], line[128], x[24], y[24], z[24], count
    get_mapname(map, charsmax(map))
    formatex(path, charsmax(path), "addons/amxmodx/configs/mm_football/%s.ini", map)
    new file = fopen(path, "rt")
    if (!file) return false
    while (!feof(file) && count < 5)
    {
        fgets(file, line, charsmax(line)); trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#') continue
        if (parse(line, x, charsmax(x), y, charsmax(y), z, charsmax(z)) != 3) continue
        if (!count) {g_spawn[0] = str_to_float(x); g_spawn[1] = str_to_float(y); g_spawn[2] = str_to_float(z);}
        else if (count < 3) {g_goal[count-1][0] = str_to_float(x); g_goal[count-1][1] = str_to_float(y); g_goal[count-1][2] = str_to_float(z);}
        else if (count == 3) {g_pitch_min[0] = str_to_float(x); g_pitch_min[1] = str_to_float(y);}
        else {g_pitch_max[0] = str_to_float(x); g_pitch_max[1] = str_to_float(y);}
        count++
    }
    fclose(file)
    g_bounds_ready = count == 5 && g_pitch_min[0] < g_spawn[0] && g_pitch_max[0] > g_spawn[0] && g_pitch_min[1] < g_spawn[1] && g_pitch_max[1] > g_spawn[1]
    return count >= 3
}

mm_loadout(id)
{
    rg_remove_all_items(id, false)
    give_item(id, "weapon_knife")
    set_user_health(id, 100)
    cs_set_user_armor(id, 0, CS_ARMOR_NONE)
    cs_set_user_defuse(id, 0)
    set_user_maxspeed(id, MM_FB_PLAYER_SPEED)
}
public mm_reset_speed_post(id)
{
    if (g_enabled && mm_active() && is_user_alive(id)) set_user_maxspeed(id, MM_FB_PLAYER_SPEED)
    return HAM_IGNORED
}
public mm_spawn_post(id)
{
    remove_task(MM_FB_LOADOUT + id)
    if (g_enabled && mm_active() && is_user_alive(id)) set_task(0.1, "mm_spawn_loadout", MM_FB_LOADOUT + id)
    return HAM_IGNORED
}
public mm_spawn_loadout(task)
{
    new id = task - MM_FB_LOADOUT
    if (g_enabled && mm_active() && is_user_alive(id) && mm_playing(id)) mm_loadout(id)
}
public mm_killed_post(id, attacker, gib)
{
    if (g_carrier == id) mm_release_ball()
    if (g_enabled && mm_active() && mm_playing(id))
    {
        remove_task(MM_FB_RESPAWN + id)
        set_task(1.0, "mm_respawn", MM_FB_RESPAWN + id)
    }
    return HAM_IGNORED
}
public mm_respawn(task)
{
    new id = task - MM_FB_RESPAWN
    if (g_enabled && mm_active() && mm_playing(id) && !is_user_alive(id)) ExecuteHamB(Ham_CS_RoundRespawn, id)
}
public mm_damage_pre(victim, inflictor, attacker, Float:damage, bits) {return mm_active() ? HAM_SUPERCEDE : HAM_IGNORED;}
public mm_default_items(id) {return mm_active() ? HC_SUPERCEDE : HC_CONTINUE;}
public mm_world_touch(entity, id) {return mm_active() && mm_playing(id) ? HAM_SUPERCEDE : HAM_IGNORED;}
public mm_map_use(entity, caller, activator, use_type, Float:value) {return mm_active() ? HAM_SUPERCEDE : HAM_IGNORED;}
public mm_buy_weapon(id, WeaponIdType:weapon)
{
    if (!mm_active()) return HC_CONTINUE
    SetHookChainReturn(ATYPE_INTEGER, 0); return HC_SUPERCEDE
}
public mm_buy_ammo(id, weapon, bool:blink)
{
    if (!mm_active()) return HC_CONTINUE
    SetHookChainReturn(ATYPE_BOOL, false); return HC_SUPERCEDE
}
public mm_buy_item(id, slot) {return mm_active() ? HC_SUPERCEDE : HC_CONTINUE;}
public mm_block_command(id) {return mm_active() ? PLUGIN_HANDLED : PLUGIN_CONTINUE;}

public mm_command(id, command, seed)
{
    if (!g_enabled || !mm_active() || !is_user_alive(id)) return FMRES_IGNORED
    new buttons = get_uc(command, UC_Buttons), old = pev(id, pev_oldbuttons)
    if (!g_paused && is_valid_ent(g_ball))
    {
        if ((buttons & (IN_USE | IN_ATTACK)) && !(old & (IN_USE | IN_ATTACK))) mm_kick(id, get_pcvar_float(g_shot_power) * mm_power_scale(id, false), false)
        else if ((buttons & (IN_RELOAD | IN_ATTACK2)) && !(old & (IN_RELOAD | IN_ATTACK2))) mm_kick(id, get_pcvar_float(g_pass_power) * mm_power_scale(id, true), true)
    }
    set_uc(command, UC_Buttons, buttons & ~(IN_ATTACK | IN_ATTACK2))
    return FMRES_HANDLED
}

mm_kick(id, Float:power, bool:low)
{
    if (!mm_playing(id) || (g_carrier && g_carrier != id)) return
    if (!mm_restart_allows(cs_get_user_team(id), get_gametime())) return
    if (get_gametime() - g_last_manual[id] < 0.25) return
    new Float:pos[3], Float:ball[3], Float:angles[3], Float:aim_dir[3], Float:velocity[3]
    pev(id, pev_origin, pos); pev(g_ball, pev_origin, ball)
    if (get_distance_f(pos, ball) > 100.0) return
    pos[2] += 16.0
    new trace = create_tr2()
    engfunc(EngFunc_TraceLine, pos, ball, IGNORE_MONSTERS, id, trace)
    new Float:fraction; get_tr2(trace, TR_flFraction, fraction)
    new hit = get_tr2(trace, TR_pHit)
    free_tr2(trace)
    if (fraction < 0.98 && hit != g_ball) return
    pev(id, pev_v_angle, angles)
    if (low) angles[0] = 0.0
    angle_vector(angles, ANGLEVECTOR_FORWARD, aim_dir)
    mm_shot_velocity(aim_dir, power, low, velocity)
    mm_release_ball()
    set_pev(g_ball, pev_velocity, velocity)
    g_last_motion = get_gametime(); g_last_touch = id; g_touch_time = g_last_motion
    g_last_manual[id] = g_last_motion
    g_player_pickup_after[id] = g_last_motion + 0.65
    mm_shot_trail(cs_get_user_team(id))
    emit_sound(g_ball, CHAN_BODY, BOUNCE_SOUND, 0.5, ATTN_NORM, 0, PITCH_NORM)
}

mm_shot_velocity(const Float:aim_dir[3], Float:power, bool:low, Float:velocity[3])
{
    velocity[0] = aim_dir[0]*power
    velocity[1] = aim_dir[1]*power
    velocity[2] = low ? 100.0 : floatmax(140.0, aim_dir[2]*power)
    // Looking almost vertically upward should produce a true straight-up shot.
    if (!low && aim_dir[2] >= 0.98)
    {
        velocity[0] = 0.0; velocity[1] = 0.0; velocity[2] = power
    }
}

public mm_ball_touch(ball, other)
{
    if (!g_enabled || g_paused || g_carrier || ball != g_ball || !mm_active()) return
    if (other >= 1 && other <= MaxClients && is_user_alive(other)) mm_try_possession()
    else if (get_gametime() - g_last_bounce > 0.15)
    {
        emit_sound(ball, CHAN_BODY, BOUNCE_SOUND, 0.35, ATTN_NORM, 0, PITCH_NORM)
        g_last_bounce = get_gametime()
    }
}

// Possession is explicit: the ball follows the feet instead of repeatedly
// applying touch impulses. Keep it non-solid while held so it cannot trip players.
mm_ball_glow(CsTeams:team)
{
    new Float:color[3] = {255.0, 255.0, 255.0}
    if (team == CS_TEAM_CT) {color[0] = 40.0; color[1] = 100.0;}
    else if (team == CS_TEAM_T) {color[1] = 40.0; color[2] = 40.0;}
    set_pev(g_ball, pev_renderfx, kRenderFxGlowShell)
    set_pev(g_ball, pev_rendermode, kRenderNormal)
    set_pev(g_ball, pev_renderamt, 24.0)
    set_pev(g_ball, pev_rendercolor, color)
}

mm_clear_trail()
{
    if (g_trail_team == CS_TEAM_UNASSIGNED) return
    if (is_valid_ent(g_ball))
    {
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_KILLBEAM)
        write_short(g_ball)
        message_end()
    }
    g_trail_team = CS_TEAM_UNASSIGNED
}

mm_shot_trail(CsTeams:team)
{
    mm_clear_trail()
    if (team != CS_TEAM_CT && team != CS_TEAM_T) return
    g_trail_team = team
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMFOLLOW)
    write_short(g_ball)
    write_short(g_trail_sprite)
    write_byte(8) // Each trail segment fades in 0.8 seconds.
    write_byte(4) // Width in tenths of a unit.
    write_byte(team == CS_TEAM_T ? 255 : 40)
    write_byte(team == CS_TEAM_CT ? 100 : 40)
    write_byte(team == CS_TEAM_CT ? 255 : 40)
    write_byte(180)
    message_end()
}

mm_release_ball()
{
    g_carrier = 0; g_carrier_team = CS_TEAM_UNASSIGNED
    if (!is_valid_ent(g_ball)) return
    mm_clear_trail()
    entity_set_int(g_ball, EV_INT_movetype, MOVETYPE_BOUNCE)
    entity_set_int(g_ball, EV_INT_solid, SOLID_BBOX)
    entity_set_int(g_ball, EV_INT_flags, entity_get_int(g_ball, EV_INT_flags) & ~FL_ONGROUND)
    mm_ball_glow(CS_TEAM_UNASSIGNED)
    g_pickup_after = get_gametime() + 0.18
    g_releases++
}

bool:mm_carrier_valid()
{
    return mm_playing(g_carrier) && is_user_alive(g_carrier) && cs_get_user_team(g_carrier) == g_carrier_team
}

mm_try_possession()
{
    new Float:now = get_gametime()
    if (now < g_pickup_after) return
    new best, Float:nearest = g_carrier ? MM_FB_TACKLE_DISTANCE : MM_FB_PICKUP_DISTANCE, Float:ball[3], Float:feet[3], Float:mins[3]
    pev(g_ball, pev_origin, ball)
    new trace = create_tr2()
    for (new id = 1; id <= MaxClients; id++)
    {
        if (id == g_carrier || !mm_playing(id) || !is_user_alive(id) || now < g_player_pickup_after[id]) continue
        if (!mm_restart_allows(cs_get_user_team(id), now)) continue
        pev(id, pev_origin, feet); pev(id, pev_mins, mins)
        feet[2] += mins[2] + 18.0
        if (floatabs(feet[2] - ball[2]) > 44.0) continue
        new Float:dx = feet[0]-ball[0], Float:dy = feet[1]-ball[1]
        new Float:distance = floatsqroot(dx*dx+dy*dy)
        if (distance >= nearest) continue
        engfunc(EngFunc_TraceLine, feet, ball, IGNORE_MONSTERS, id, trace)
        new Float:fraction; get_tr2(trace, TR_flFraction, fraction)
        if (fraction < 0.98 && get_tr2(trace, TR_pHit) != g_ball) continue
        best = id; nearest = distance
    }
    free_tr2(trace)
    if (!best) return
    mm_clear_trail()
    if (best != g_last_touch)
    {
        g_assist = mm_playing(g_last_touch) && cs_get_user_team(g_last_touch) == cs_get_user_team(best) && now-g_touch_time <= 10.0 ? g_last_touch : 0
    }
    g_touch_time = now
    g_carrier = best; g_carrier_team = cs_get_user_team(best); g_last_touch = best
    g_restart_team = CS_TEAM_UNASSIGNED; g_restart_until = 0.0
    g_pickup_after = now + 0.35
    entity_set_int(g_ball, EV_INT_solid, SOLID_NOT)
    entity_set_int(g_ball, EV_INT_movetype, MOVETYPE_NONE)
    entity_set_vector(g_ball, EV_VEC_velocity, Float:{0.0,0.0,0.0})
    mm_ball_glow(g_carrier_team)
    mm_shot_trail(g_carrier_team)
    mm_notice(g_carrier_team, best, false)
    g_pickups++
}

// Packet-only player highlight automatically disappears on release or mode exit.
public mm_carrier_glow(packet, e, entity, host, host_flags, player, pset)
{
    if (!g_enabled || !mm_active() || !player || entity != g_carrier || !mm_carrier_valid()) return FMRES_IGNORED
    set_es(packet, ES_RenderFx, kRenderFxGlowShell)
    set_es(packet, ES_RenderMode, kRenderNormal)
    set_es(packet, ES_RenderAmt, 18)
    if (g_carrier_team == CS_TEAM_CT) set_es(packet, ES_RenderColor, {40,100,255})
    else set_es(packet, ES_RenderColor, {255,40,40})
    return FMRES_IGNORED
}

mm_notice(CsTeams:team, id, bool:goal)
{
    set_hudmessage(team == CS_TEAM_T ? 255 : 60, team == CS_TEAM_CT ? 130 : 60, team == CS_TEAM_CT ? 255 : 60, -1.0, 0.18, 0, 0.0, 3.0, 0.1, 0.3)
    if (!goal) ShowSyncHudMsg(0, g_notice_hud, "%n now has the ball", id)
    else if (!mm_playing(id)) ShowSyncHudMsg(0, g_notice_hud, "%s scored a goal", team == CS_TEAM_T ? "Terrorists" : "CTs")
    else if (cs_get_user_team(id) != team) ShowSyncHudMsg(0, g_notice_hud, "%n scored an own goal", id)
    else ShowSyncHudMsg(0, g_notice_hud, "%n has scored a goal", id)
}

public mm_player_postthink(id)
{
    if (!g_enabled || g_paused || id != g_carrier || !is_valid_ent(g_ball)) return FMRES_IGNORED
    mm_follow_carrier()
    return FMRES_IGNORED
}

mm_follow_carrier()
{
    if (!mm_carrier_valid()) {mm_release_ball(); return;}
    new Float:feet[3], Float:target[3], Float:mins[3], Float:angles[3], Float:direction[3], Float:old[3]
    pev(g_carrier, pev_origin, feet); pev(g_carrier, pev_mins, mins)
    feet[2] += mins[2] + 18.0
    pev(g_carrier, pev_v_angle, angles); angles[0] = 0.0; angles[2] = 0.0
    angle_vector(angles, ANGLEVECTOR_FORWARD, direction)
    for (new axis = 0; axis < 3; axis++) target[axis] = feet[axis] + direction[axis]*MM_FB_CARRY_DISTANCE
    new trace = create_tr2()
    engfunc(EngFunc_TraceHull, feet, target, IGNORE_MONSTERS, HULL_HEAD, g_carrier, trace)
    if (get_tr2(trace, TR_StartSolid) || get_tr2(trace, TR_AllSolid))
    {free_tr2(trace); mm_release_ball(); return;}
    get_tr2(trace, TR_vecEndPos, target)
    free_tr2(trace)
    pev(g_ball, pev_origin, old)
    if (get_distance_f(old, target) > 160.0)
    {
        // Never drag the ball through the field when its carrier is teleported.
        mm_release_ball(); return;
    }
    entity_set_origin(g_ball, target)
    g_last_motion = get_gametime()
}

// GoldSrc bounce friction does not provide rolling resistance. Apply a real
// time-based deceleration on the turf, retaining vertical bounce/gravity.
mm_roll_resistance(Float:velocity[3], Float:elapsed)
{
    new Float:speed = floatsqroot(velocity[0]*velocity[0] + velocity[1]*velocity[1])
    new Float:next_speed = floatmax(0.0, speed - MM_FB_ROLL_DECEL*elapsed)
    if (speed <= 0.0) return
    velocity[0] *= next_speed/speed; velocity[1] *= next_speed/speed
}

mm_slow_loose_ball(const Float:pos[3], Float:elapsed)
{
    new Float:bottom[3], Float:velocity[3], Float:normal[3]
    for (new axis = 0; axis < 3; axis++) bottom[axis] = pos[axis]
    bottom[2] -= 14.0
    new trace = create_tr2()
    engfunc(EngFunc_TraceLine, pos, bottom, IGNORE_MONSTERS, g_ball, trace)
    new Float:fraction; get_tr2(trace, TR_flFraction, fraction)
    get_tr2(trace, TR_vecPlaneNormal, normal)
    free_tr2(trace)
    pev(g_ball, pev_velocity, velocity)
    if (fraction < 1.0 && normal[2] > 0.7 && velocity[2] <= 30.0)
    {
        mm_roll_resistance(velocity, elapsed)
        entity_set_vector(g_ball, EV_VEC_velocity, velocity)
    }
}

mm_reset_ball()
{
    if (!is_valid_ent(g_ball)) return
    mm_place_ball(g_spawn, CS_TEAM_UNASSIGNED)
}

bool:mm_restart_allows(CsTeams:team, Float:now)
{
    return mm_restart_permission(team, g_restart_team, g_restart_until, now)
}

bool:mm_restart_permission(CsTeams:team, CsTeams:reserved_team, Float:until, Float:now)
{
    return now >= until || reserved_team == CS_TEAM_UNASSIGNED || team == reserved_team
}

mm_place_ball(const Float:point[3], CsTeams:team)
{
    mm_release_ball()
    entity_set_origin(g_ball, point)
    entity_set_vector(g_ball, EV_VEC_velocity, Float:{0.0,0.0,0.0})
    entity_set_int(g_ball, EV_INT_flags, entity_get_int(g_ball, EV_INT_flags) & ~FL_ONGROUND)
    for (new i = 0; i < 3; i++) g_previous[i] = point[i]
    g_assist = 0; g_last_touch = 0; g_last_motion = get_gametime(); g_last_tick = g_last_motion
    g_restart_team = team
    g_restart_until = team == CS_TEAM_UNASSIGNED ? 0.0 : get_gametime() + MM_FB_RESTART_WINDOW
}

mm_kickoff_position(CsTeams:team, Float:point[3])
{
    for (new axis = 0; axis < 3; axis++) point[axis] = g_spawn[axis]
    // Map data lists the T goal first (positive X on SoccerJam), then CT.
    if (team == CS_TEAM_T || team == CS_TEAM_CT)
    {
        new goal = team == CS_TEAM_T ? 0 : 1
        point[0] += (g_goal[goal][0] - g_spawn[0])*0.275
        if (g_bounds_ready) point[0] = floatclamp(point[0], g_pitch_min[0]+MM_FB_RESTART_INSET, g_pitch_max[0]-MM_FB_RESTART_INSET)
    }
}
public mm_kickoff()
{
    if (!g_enabled || !mm_active() || !is_valid_ent(g_ball)) return
    g_paused = false
    new Float:point[3]
    mm_kickoff_position(g_next_kickoff, point)
    mm_place_ball(point, g_next_kickoff)
    log_amx("Football kickoff team=%d position=%.0f,%.0f,%.0f first-pickup=%.1fs", _:g_next_kickoff, point[0], point[1], point[2], g_next_kickoff == CS_TEAM_UNASSIGNED ? 0.0 : MM_FB_RESTART_WINDOW)
    for (new id = 1; id <= MaxClients; id++)
        if (mm_playing(id)) ExecuteHamB(Ham_CS_RoundRespawn, id)
    emit_sound(g_ball, CHAN_AUTO, WHISTLE_SOUND, 0.7, ATTN_NONE, 0, PITCH_NORM)
    if (g_next_kickoff != CS_TEAM_UNASSIGNED)
        client_print_color(0, g_next_kickoff == CS_TEAM_T ? print_team_red : print_team_blue, "^4[Football]^1 Kickoff for ^3%s^1 in their own half. First pickup reserved for 2 seconds.", g_next_kickoff == CS_TEAM_T ? "Terrorists" : "CTs")
    g_next_kickoff = CS_TEAM_UNASSIGNED
}

bool:mm_outside_pitch(const Float:point[3])
{
    if (!g_bounds_ready) return false
    // A goal mouth extends a few units beyond the painted end line. Allow the
    // ball to reach the goal volume; live goal detection always runs first.
    for (new goal = 0; goal < 2; goal++)
        if (floatabs(point[1]-g_goal[goal][1]) <= 145.0 && floatabs(point[2]-g_goal[goal][2]) <= 55.0 && floatabs(point[0]-g_goal[goal][0]) <= 60.0) return false
    return point[0] < g_pitch_min[0]-MM_FB_BALL_RADIUS || point[0] > g_pitch_max[0]+MM_FB_BALL_RADIUS || point[1] < g_pitch_min[1]-MM_FB_BALL_RADIUS || point[1] > g_pitch_max[1]+MM_FB_BALL_RADIUS
}

mm_boundary_restart_point(const Float:start[3], const Float:finish[3], Float:point[3])
{
    new Float:first = 1.0
    for (new axis = 0; axis < 2; axis++)
    {
        new Float:delta = finish[axis]-start[axis], Float:t = 1.0
        if (delta < -0.001 && finish[axis] < g_pitch_min[axis]-MM_FB_BALL_RADIUS) t = (g_pitch_min[axis]-MM_FB_BALL_RADIUS-start[axis])/delta
        else if (delta > 0.001 && finish[axis] > g_pitch_max[axis]+MM_FB_BALL_RADIUS) t = (g_pitch_max[axis]+MM_FB_BALL_RADIUS-start[axis])/delta
        if (t >= 0.0 && t < first) first = t
    }
    for (new axis = 0; axis < 2; axis++) point[axis] = floatclamp(start[axis]+(finish[axis]-start[axis])*first, g_pitch_min[axis]+MM_FB_RESTART_INSET, g_pitch_max[axis]-MM_FB_RESTART_INSET)
    point[2] = g_spawn[2]
}

mm_out_of_play(const Float:pos[3])
{
    new Float:point[3], restart_name[24]
    new CsTeams:last_team = mm_playing(g_last_touch) ? cs_get_user_team(g_last_touch) : CS_TEAM_UNASSIGNED
    new CsTeams:restart_team = mm_restart_position(g_previous, pos, last_team, point, restart_name, charsmax(restart_name))
    mm_place_ball(point, restart_team)
    g_out_count++
    log_amx("Football out restart team=%d position=%.0f,%.0f,%.0f", _:restart_team, point[0], point[1], point[2])
    emit_sound(g_ball, CHAN_AUTO, WHISTLE_SOUND, 0.7, ATTN_NONE, 0, PITCH_NORM)
    if (restart_team == CS_TEAM_UNASSIGNED) client_print_color(0, print_team_grey, "^4[Football]^3 Ball out! Restart just inside the line.")
    else client_print_color(0, restart_team == CS_TEAM_T ? print_team_red : print_team_blue, "^4[Football]^1 %s for ^3%s^1; first pickup reserved for 2 seconds.", restart_name, restart_team == CS_TEAM_T ? "Terrorists" : "CTs")
}

bool:mm_segment_goal(const Float:start[3], const Float:finish[3], goal)
{
    new Float:lo = 0.0, Float:hi = 1.0
    for (new axis = 0; axis < 3; axis++)
    {
        new Float:extent = axis == 0 ? 25.0 : (axis == 1 ? 145.0 : 55.0)
        new Float:min_value = g_goal[goal][axis] - extent, Float:max_value = g_goal[goal][axis] + extent
        new Float:delta = finish[axis] - start[axis]
        if (floatabs(delta) < 0.001) {if (start[axis] < min_value || start[axis] > max_value) return false;}
        else
        {
            new Float:a = (min_value-start[axis])/delta, Float:b = (max_value-start[axis])/delta
            if (a > b) {new Float:temp = a; a = b; b = temp;}
            if (a > lo) lo = a
            if (b < hi) hi = b
            if (lo > hi) return false
        }
    }
    return true
}

public mm_tick()
{
    if (!g_enabled || !mm_active() || !is_valid_ent(g_ball)) return
    new Float:pos[3], Float:velocity[3], Float:now = get_gametime()
    new Float:elapsed = floatclamp(now - g_last_tick, 0.0, 0.2)
    g_last_tick = now
    if (g_carrier && !g_paused) mm_follow_carrier()
    pev(g_ball, pev_origin, pos); pev(g_ball, pev_velocity, velocity)
    if (!g_paused)
    {
        if (now-g_match_started >= float(clamp(get_pcvar_num(g_minutes), 1, 60)*60)) {mm_finish(); return;}
        if (get_distance_f(pos, g_spawn) > 6500.0 || pos[2] < g_spawn[2]-500.0 || engfunc(EngFunc_PointContents, pos) == CONTENTS_SOLID)
        {mm_reset_ball(); return;}
        if (vector_length(velocity) > 20.0) g_last_motion = now
        if (now - g_last_motion > 30.0) {mm_reset_ball(); return;}
        for (new goal = 0; goal < 2; goal++)
            if (mm_segment_goal(g_previous, pos, goal)) {mm_goal(1-goal); return;}
        if (mm_outside_pitch(pos)) {mm_out_of_play(pos); return;}
        for (new axis = 0; axis < 3; axis++) g_previous[axis] = pos[axis]
        if (!g_carrier) mm_slow_loose_ball(pos, elapsed)
        if (!g_carrier && vector_length(velocity) < 15.0) mm_clear_trail()
        mm_try_possession()
    }
    if (now - g_last_hud >= 0.5)
    {
        set_hudmessage(80, 220, 120, -1.0, 0.10, 0, 0.0, 0.6, 0.0, 0.0)
        ShowSyncHudMsg(0, g_hud, "FOOTBALL | T %d : %d CT | %d:%02d left^nE / Left click: SHOOT | R / Right click: PASS", g_score[0], g_score[1], max(0, clamp(get_pcvar_num(g_minutes), 1, 60)*60-floatround(now-g_match_started))/60, max(0, clamp(get_pcvar_num(g_minutes), 1, 60)*60-floatround(now-g_match_started))%60)
        g_last_hud = now
    }
}

mm_goal(team)
{
    mm_goal_light(team)
    g_paused = true
    mm_release_ball()
    entity_set_int(g_ball, EV_INT_movetype, MOVETYPE_NONE)
    mm_notice(team == 0 ? CS_TEAM_T : CS_TEAM_CT, g_last_touch, true)
    g_score[team]++
    if (mm_playing(g_last_touch) && cs_get_user_team(g_last_touch) == (team == 0 ? CS_TEAM_T : CS_TEAM_CT))
    {
        g_goals[g_last_touch]++
        if (g_assist != g_last_touch && mm_playing(g_assist) && cs_get_user_team(g_assist) == cs_get_user_team(g_last_touch) && get_gametime()-g_touch_time <= 10.0) g_assists[g_assist]++
    }
    entity_set_vector(g_ball, EV_VEC_velocity, Float:{0.0,0.0,0.0})
    new chat_team = team == 0 ? print_team_red : print_team_blue
    g_next_kickoff = team == 0 ? CS_TEAM_CT : CS_TEAM_T
    if (mm_playing(g_last_touch)) client_print_color(0, chat_team, "^4[Football]^1 GOAL for ^3%s^1! Last touch: ^3%n^1. T %d : %d CT", team == 0 ? "Terrorists" : "CTs", g_last_touch, g_score[0], g_score[1])
    else client_print_color(0, chat_team, "^4[Football]^1 GOAL for ^3%s^1! T %d : %d CT", team == 0 ? "Terrorists" : "CTs", g_score[0], g_score[1])
    if (g_score[team] >= clamp(get_pcvar_num(g_goal_limit), 1, 30))
    {
        client_print_color(0, chat_team, "^4[Football]^1 ^3%s^1 win the match! Get ready for kickoff.", team == 0 ? "Terrorists" : "CTs")
        mm_finish()
    }
    else set_task(3.0, "mm_kickoff", MM_FB_RESET)
}
public mm_new_match()
{
    new bool:counted = task_exists(MM_FB_COUNTDOWN) != 0
    remove_task(MM_FB_COUNTDOWN); g_restart_seconds = 0
    if (counted && mm_active())
    {
        set_dhudmessage(100, 235, 160, -1.0, 0.72, 0, 0.0, 1.5, 0.0, 0.2)
        show_dhudmessage(0, "NEW MATCH - GO!")
    }
    arrayset(g_score, 0, sizeof g_score)
    arrayset(g_goals, 0, sizeof g_goals); arrayset(g_assists, 0, sizeof g_assists)
    g_match_started = get_gametime(); g_assist = 0
    g_next_kickoff = CS_TEAM_UNASSIGNED
    mm_kickoff()
}
public mm_admin_reset(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    if (!mm_active()) return PLUGIN_HANDLED
    remove_task(MM_FB_RESET)
    mm_new_match()
    return PLUGIN_HANDLED
}
Float:mm_power_scale(id, bool:pass)
{
    new setting = g_power[id][pass ? 1 : 0]
    return setting == 1 ? 0.8 : (setting == 2 ? 1.15 : 1.0)
}
public mm_power_menu(id, menu, item)
{
    menu_destroy(menu)
    if (item >= 0 && item < 2 && is_user_connected(id) && mm_active())
    {
        g_power[id][item] = (g_power[id][item]+1)%3
        mm_help(id)
    }
    return PLUGIN_HANDLED
}
public mm_help(id)
{
    if (!mm_active()) return PLUGIN_HANDLED
    new menu = menu_create("Football: shot / pass strength", "mm_power_menu")
    new label[64]
    formatex(label, charsmax(label), "Shot: %s (click to cycle)", g_power[id][0] == 0 ? "Normal 100%" : (g_power[id][0] == 1 ? "Soft 80%" : "Strong 115%"))
    menu_additem(menu, label)
    formatex(label, charsmax(label), "Pass: %s (click to cycle)", g_power[id][1] == 0 ? "Normal 100%" : (g_power[id][1] == 1 ? "Soft 80%" : "Strong 115%"))
    menu_additem(menu, label)
    menu_display(id, menu)
    client_print_color(id, print_team_grey, "^4[Football]^3 Run over the ball to carry it. ^4E/left click^3 shoots; ^4R/right click^3 passes. Glow: CT blue, T red, free ball white. First to ^4%d^3 goals.", clamp(get_pcvar_num(g_goal_limit), 1, 30))
    return PLUGIN_HANDLED
}
public mm_status()
{
    server_print("[Football Burst] explosions=%d radius=480 outline_brightness=255 outline_width=20", g_goal_explosions)
    server_print("[Football Lights] enabled=%d bursts=%d pulses=%d remaining=%d", get_pcvar_num(g_goal_lights), g_light_bursts, g_light_pulses, g_light_ticks)
    server_print("[Football] clock_seconds_left=%d goal_target=%d reset_pending=%d countdown=%d", max(0, clamp(get_pcvar_num(g_minutes),1,60)*60-floatround(get_gametime()-g_match_started)), get_pcvar_num(g_goal_limit), task_exists(MM_FB_RESET), g_restart_seconds)
    server_print("[Football] version=%s active=%d ready=%d ball=%d paused=%d score=%d:%d extra_spawns=%d", PLUGIN_VERSION, mm_active(), g_field_ready, is_valid_ent(g_ball), g_paused, g_score[0], g_score[1], g_added_spawns)
    if (is_valid_ent(g_ball))
    {
        new Float:velocity[3], Float:color[3]
        pev(g_ball, pev_velocity, velocity); pev(g_ball, pev_rendercolor, color)
        server_print("[Football] carrier=%d team=%d glow=%.0f,%.0f,%.0f speed=%.1f pickups=%d releases=%d trail_team=%d", g_carrier, _:g_carrier_team, color[0], color[1], color[2], vector_length(velocity), g_pickups, g_releases, _:g_trail_team)
        server_print("[Football] player_speed=%.0f sv_maxspeed=%.0f carrier_glow=%d notices=1", MM_FB_PLAYER_SPEED, get_pcvar_float(g_sv_maxspeed), mm_carrier_valid())
        server_print("[Football] boundaries=%d x=%.0f..%.0f y=%.0f..%.0f outs=%d restart_team=%d reserved=%.1f", g_bounds_ready, g_pitch_min[0], g_pitch_max[0], g_pitch_min[1], g_pitch_max[1], g_out_count, _:g_restart_team, floatmax(0.0, g_restart_until-get_gametime()))
        new Float:point[3]; pev(g_ball, pev_origin, point)
        server_print("[Football] ball_position=%.0f,%.0f,%.0f", point[0], point[1], point[2])
    }
}

mm_expand_spawns(const classname[])
{
    new entities[32], count, entity
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", classname)) > 0)
        if (count < sizeof entities) entities[count++] = entity
    new original = count
    if (!original || count >= 16) return
    new Float:origin[3], Float:point[3], Float:bottom[3], Float:floor[3], Float:angles[3]
    new Float:normal[3]
    new trace = create_tr2()
    for (new i = 0; i < original && count < 16; i++)
    {
        pev(entities[i], pev_origin, origin); pev(entities[i], pev_angles, angles)
        for (new direction = 0; direction < 8 && count < 16; direction++)
        {
            point[0] = origin[0] + floatcos(float(direction) * 45.0, degrees) * 72.0
            point[1] = origin[1] + floatsin(float(direction) * 45.0, degrees) * 72.0
            point[2] = origin[2] + 32.0
            bottom[0] = point[0]; bottom[1] = point[1]; bottom[2] = origin[2] - 4096.0
            engfunc(EngFunc_TraceLine, point, bottom, IGNORE_MONSTERS, 0, trace)
            new Float:fraction; get_tr2(trace, TR_flFraction, fraction)
            if (fraction >= 1.0 || get_tr2(trace, TR_StartSolid)) continue
            get_tr2(trace, TR_vecPlaneNormal, normal)
            if (normal[2] < 0.75) continue
            get_tr2(trace, TR_vecEndPos, floor); floor[2] += 37.0
            if (engfunc(EngFunc_PointContents, floor) != CONTENTS_EMPTY) continue
            engfunc(EngFunc_TraceHull, floor, floor, IGNORE_MONSTERS, HULL_HUMAN, 0, trace)
            if (get_tr2(trace, TR_StartSolid) || get_tr2(trace, TR_AllSolid)) continue
            new bool:near
            for (new j = 0; j < count; j++)
            {
                pev(entities[j], pev_origin, bottom)
                if (get_distance_f(floor, bottom) < 64.0) {near = true; break;}
            }
            if (near) continue
            new added = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, classname))
            if (!pev_valid(added)) continue
            engfunc(EngFunc_SetOrigin, added, floor); set_pev(added, pev_angles, angles)
            dllfunc(DLLFunc_Spawn, added)
            entities[count++] = added; g_added_spawns++
        }
    }
    free_tr2(trace)
    log_amx("Football spawn capacity %s: %d (original %d).", classname, count, original)
}


// Read-only geometry checks exercise the same detector used by live goals.
public mm_selftest()
{
    if (!g_field_ready) {server_print("[Football Test] No field data on current map."); return;}
    new red, green, blue, color_checks
    mm_goal_light_color(0, red, green, blue)
    if (red == 255 && green == 55 && blue == 55) color_checks++
    mm_goal_light_color(1, red, green, blue)
    if (red == 55 && green == 120 && blue == 255) color_checks++
    server_print("[Football Test] Goal light colors passed %d/2 (T red, CT blue).", color_checks)
    new passed, Float:start[3], Float:finish[3]
    for (new goal = 0; goal < 2; goal++)
    {
        for (new axis = 0; axis < 3; axis++) {start[axis] = g_goal[goal][axis]; finish[axis] = g_goal[goal][axis];}
        start[0] -= 100.0; finish[0] += 100.0
        if (mm_segment_goal(start, finish, goal)) passed++
        start[1] += 200.0; finish[1] += 200.0
        if (!mm_segment_goal(start, finish, goal)) passed++
        start[1] -= 200.0; finish[1] -= 200.0; start[2] += 150.0; finish[2] += 150.0
        if (!mm_segment_goal(start, finish, goal)) passed++
    }
    server_print("[Football Test] Goal segment checks passed %d/6 (crossing, wide, over crossbar).", passed)
    new Float:velocity[3] = {600.0, 800.0, 0.0}, stopped, reversed
    for (new i = 0; i < 100; i++)
    {
        mm_roll_resistance(velocity, 0.05)
        if (velocity[0] < 0.0 || velocity[1] < 0.0) reversed++
    }
    if (vector_length(velocity) < 0.01) stopped = 1
    new Float:one_step[3] = {600.0, 800.0, 0.0}, Float:two_steps[3] = {600.0, 800.0, 0.0}
    mm_roll_resistance(one_step, 0.1)
    mm_roll_resistance(two_steps, 0.05); mm_roll_resistance(two_steps, 0.05)
    server_print("[Football Test] Rolling stops=%d reversals=%d tick_invariant=%d", stopped, reversed, get_distance_f(one_step, two_steps) < 0.01)
    new Float:shot[3], shot_checks
    mm_shot_velocity(Float:{0.0,0.0,1.0}, 1100.0, false, shot)
    if (shot[0] == 0.0 && shot[1] == 0.0 && shot[2] == 1100.0) shot_checks++
    mm_shot_velocity(Float:{0.01,0.0,0.99995}, 1100.0, false, shot)
    if (shot[0] == 0.0 && shot[1] == 0.0 && shot[2] == 1100.0) shot_checks++
    mm_shot_velocity(Float:{1.0,0.0,0.0}, 1100.0, false, shot)
    if (shot[0] == 1100.0 && shot[1] == 0.0 && shot[2] == 140.0) shot_checks++
    mm_shot_velocity(Float:{0.0,1.0,0.0}, 650.0, true, shot)
    if (shot[0] == 0.0 && shot[1] == 650.0 && shot[2] == 100.0) shot_checks++
    server_print("[Football Test] Shot directions passed %d/4 (vertical, near-vertical, forward, pass).", shot_checks)
    if (g_bounds_ready)
    {
        new boundary_checks, Float:point[3], Float:restart[3]
        for (new axis = 0; axis < 3; axis++) point[axis] = g_spawn[axis]
        if (!mm_outside_pitch(point)) boundary_checks++
        for (new axis = 0; axis < 2; axis++)
        {
            for (new coordinate = 0; coordinate < 3; coordinate++) point[coordinate] = g_spawn[coordinate]
            if (axis == 0) point[1] += 300.0 // End-line cases outside the goal mouth.
            point[axis] = g_pitch_min[axis]-MM_FB_BALL_RADIUS-1.0
            if (mm_outside_pitch(point)) boundary_checks++
            point[axis] = g_pitch_max[axis]+MM_FB_BALL_RADIUS+1.0
            if (mm_outside_pitch(point)) boundary_checks++
            point[axis] = g_spawn[axis]
        }
        point[1] = g_pitch_max[1]+MM_FB_BALL_RADIUS-1.0
        if (!mm_outside_pitch(point)) boundary_checks++
        point[1] = g_spawn[1]
        for (new goal = 0; goal < 2; goal++)
        {
            for (new axis = 0; axis < 3; axis++) point[axis] = g_goal[goal][axis]
            if (!mm_outside_pitch(point)) boundary_checks++
            point[2] += 100.0
            if (mm_outside_pitch(point)) boundary_checks++
        }
        mm_boundary_restart_point(g_spawn, point, restart)
        if (!mm_outside_pitch(restart) && restart[0] >= g_pitch_min[0]+MM_FB_RESTART_INSET && restart[0] <= g_pitch_max[0]-MM_FB_RESTART_INSET) boundary_checks++
        server_print("[Football Test] Pitch boundary checks passed %d/11 (edges, whole ball, goal mouths, high shots, safe restart).", boundary_checks)
    }
    if (g_bounds_ready)
    {
        new checks, label[24], Float:out[3], Float:point[3]
        for (new axis=0; axis<3; axis++) out[axis] = g_spawn[axis]
        out[1] = g_pitch_max[1]+30.0
        if (mm_restart_position(g_spawn, out, CS_TEAM_T, point, label, charsmax(label)) == CS_TEAM_CT && equal(label, "Throw-in")) checks++
        if (mm_restart_position(g_spawn, out, CS_TEAM_CT, point, label, charsmax(label)) == CS_TEAM_T && equal(label, "Throw-in")) checks++
        for (new goal=0; goal<2; goal++)
        {
            out[0] = g_goal[goal][0] > g_spawn[0] ? g_pitch_max[0]+30.0 : g_pitch_min[0]-30.0
            out[1] = g_spawn[1]+400.0
            new CsTeams:defender = goal == 0 ? CS_TEAM_T : CS_TEAM_CT
            new CsTeams:attacker = defender == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T
            if (mm_restart_position(g_spawn, out, defender, point, label, charsmax(label)) == attacker && equal(label, "Corner") && !mm_outside_pitch(point)) checks++
            if (mm_restart_position(g_spawn, out, attacker, point, label, charsmax(label)) == defender && equal(label, "Goal kick") && !mm_outside_pitch(point)) checks++
        }
        server_print("[Football Test] Restart classification passed %d/6 (throw-ins, corners, goal kicks).", checks)
    }
    new restart_checks, Float:t_kickoff[3], Float:ct_kickoff[3]
    mm_kickoff_position(CS_TEAM_T, t_kickoff); mm_kickoff_position(CS_TEAM_CT, ct_kickoff)
    if (get_distance_f(t_kickoff, g_goal[0]) < get_distance_f(g_spawn, g_goal[0])) restart_checks++
    if (get_distance_f(ct_kickoff, g_goal[1]) < get_distance_f(g_spawn, g_goal[1])) restart_checks++
    if (mm_restart_permission(CS_TEAM_CT, CS_TEAM_CT, 13.0, 10.0)) restart_checks++
    if (!mm_restart_permission(CS_TEAM_T, CS_TEAM_CT, 13.0, 10.0)) restart_checks++
    if (mm_restart_permission(CS_TEAM_T, CS_TEAM_CT, 13.0, 13.0)) restart_checks++
    if (mm_restart_permission(CS_TEAM_CT, CS_TEAM_UNASSIGNED, 13.0, 10.0)) restart_checks++
    server_print("[Football Test] Restart checks passed %d/6 (own-half positions, receiving team, opponents, expiry, neutral).", restart_checks)
}


mm_finish()
{
    g_paused = true; mm_release_ball()
    if (is_valid_ent(g_ball)) {entity_set_int(g_ball, EV_INT_movetype, MOVETYPE_NONE); entity_set_vector(g_ball, EV_VEC_velocity, Float:{0.0,0.0,0.0});}
    new points[33], deaths[33], ranked[32], count, detail[128]
    for (new id=1; id<=MaxClients; id++) points[id] = g_goals[id]*3+g_assists[id]
    mm_rank_scores(points, deaths, ranked, count)
    formatex(detail, charsmax(detail), "T %d : %d CT | Get ready for kickoff", g_score[0], g_score[1])
    mm_show_results(MM_MODE_FOOTBALL, count ? ranked[0] : 0, count>1 ? ranked[1] : 0, count>2 ? ranked[2] : 0, g_score[0] == g_score[1] ? "FULL TIME: DRAW" : (g_score[0]>g_score[1] ? "TERRORISTS WIN!" : "CTS WIN!"), detail)
    remove_task(MM_FB_RESET); remove_task(MM_FB_COUNTDOWN)
    g_restart_seconds = 6
    mm_restart_countdown()
    set_task(1.0, "mm_restart_countdown", MM_FB_COUNTDOWN, "", 0, "b")
    set_task(6.0, "mm_new_match", MM_FB_RESET)
}
public mm_top(id)
{
    if (!mm_active()) return PLUGIN_HANDLED
    new points[33], deaths[33], ranked[32], count
    for (new player=1; player<=MaxClients; player++) points[player] = g_goals[player]*3+g_assists[player]
    mm_rank_scores(points, deaths, ranked, count)
    for (new i=0; i<min(count,3); i++) client_print_color(id, ranked[i], "^4[Football]^1 #%d ^3%n^1: ^4%d^1 goals, ^4%d^1 assists", i+1, ranked[i], g_goals[ranked[i]], g_assists[ranked[i]])
    return PLUGIN_HANDLED
}

CsTeams:mm_restart_position(const Float:start[3], const Float:pos[3], CsTeams:last_team, Float:point[3], restart_name[], length)
{
    new CsTeams:restart_team = last_team == CS_TEAM_T ? CS_TEAM_CT : (last_team == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_UNASSIGNED)
    copy(restart_name, length, "Throw-in")
    mm_boundary_restart_point(start, pos, point)
    new bool:end_line = point[0] <= g_pitch_min[0]+MM_FB_RESTART_INSET+0.1 || point[0] >= g_pitch_max[0]-MM_FB_RESTART_INSET-0.1
    if (end_line)
    {
        new goal = floatabs(point[0]-g_goal[0][0]) < floatabs(point[0]-g_goal[1][0]) ? 0 : 1
        new CsTeams:defender = goal == 0 ? CS_TEAM_T : CS_TEAM_CT
        if (last_team == defender)
        {
            copy(restart_name, length, "Corner")
            restart_team = defender == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T
            point[1] = pos[1] < g_spawn[1] ? g_pitch_min[1]+MM_FB_RESTART_INSET : g_pitch_max[1]-MM_FB_RESTART_INSET
        }
        else
        {
            copy(restart_name, length, "Goal kick")
            restart_team = defender
            point[0] = g_goal[goal][0] > g_spawn[0] ? g_pitch_max[0]-240.0 : g_pitch_min[0]+240.0
            point[1] = g_spawn[1]
        }
    }
    return restart_team
}

public mm_restart_countdown()
{
    if (!mm_active() || !g_enabled || !g_paused || g_restart_seconds <= 0) {remove_task(MM_FB_COUNTDOWN); return;}
    set_dhudmessage(255, 210, 60, -1.0, 0.72, 0, 0.0, 1.1, 0.0, 0.0)
    show_dhudmessage(0, "NEW MATCH IN %d", g_restart_seconds--)
}

// Scoring team owns the color; the illuminated goal belongs to the conceding side.
mm_goal_light(team)
{
    remove_task(MM_FB_GOAL_LIGHT); g_light_ticks = 0
    if (!g_enabled || !mm_active() || !g_field_ready || !get_pcvar_num(g_goal_lights) || team < 0 || team > 1) return
    g_light_team = team; g_light_ticks = 6; g_light_bursts++
    new Float:corners[4][3], red, green, blue
    mm_goal_light_color(team, red, green, blue)
    mm_goal_explosion(team, red, green, blue)
    for (new i=0; i<4; i++)
    {
        corners[i][0] = g_goal[1-team][0] + (g_goal[1-team][0] > g_spawn[0] ? -8.0 : 8.0)
        corners[i][1] = g_goal[1-team][1] + (i == 0 || i == 3 ? -145.0 : 145.0)
        corners[i][2] = g_goal[1-team][2] + (i < 2 ? -50.0 : 55.0)
    }
    // A visible outline also works for clients with dynamic lighting disabled.
    for (new i=0; i<4; i++)
    {
        new next = (i+1)%4
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_BEAMPOINTS)
        for (new axis=0; axis<3; axis++) write_coord_f(corners[i][axis])
        for (new axis=0; axis<3; axis++) write_coord_f(corners[next][axis])
        write_short(g_trail_sprite)
        write_byte(0); write_byte(0); write_byte(26); write_byte(20); write_byte(0)
        write_byte(red); write_byte(green); write_byte(blue); write_byte(255); write_byte(0)
        message_end()
    }
    mm_goal_light_pulse()
    set_task(0.4, "mm_goal_light_pulse", MM_FB_GOAL_LIGHT, "", 0, "b")
}
mm_goal_light_color(team, &red, &green, &blue)
{
    red = team == 0 ? 255 : 55
    green = team == 0 ? 55 : 120
    blue = team == 0 ? 55 : 255
}
public mm_goal_light_pulse()
{
    if (!g_enabled || !mm_active() || !g_field_ready || !get_pcvar_num(g_goal_lights) || g_light_ticks <= 0)
    {remove_task(MM_FB_GOAL_LIGHT); g_light_ticks = 0; return;}
    new red, green, blue, goal = 1-g_light_team
    mm_goal_light_color(g_light_team, red, green, blue)
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_DLIGHT)
    write_coord_f(g_goal[goal][0] + (g_goal[goal][0] > g_spawn[0] ? -24.0 : 24.0))
    write_coord_f(g_goal[goal][1]); write_coord_f(g_goal[goal][2]+10.0)
    write_byte(48); write_byte(red); write_byte(green); write_byte(blue)
    write_byte(9); write_byte(24)
    message_end()
    g_light_pulses++; g_light_ticks--
    if (!g_light_ticks) remove_task(MM_FB_GOAL_LIGHT)
}
public mm_light_test()
{
    if (!g_enabled || !mm_active() || !g_field_ready) {server_print("[Football Lights] Preview requires the active football pitch."); return;}
    new arg[8]; read_argv(1, arg, charsmax(arg))
    if (!equali(arg,"t") && !equali(arg,"ct")) {server_print("[Football Lights] Usage: mm_football_light_test <t|ct>"); return;}
    mm_goal_light(equali(arg,"ct") ? 1 : 0)
    server_print("[Football Lights] Preview emitted; scores and possession unchanged.")
}

// Purely visual temporary entities: no damage, force or change to ball physics.
mm_goal_explosion(team, red, green, blue)
{
    new Float:origin[3], goal = 1-team
    for (new axis=0; axis<3; axis++) origin[axis] = g_goal[goal][axis]
    origin[0] += origin[0] > g_spawn[0] ? -24.0 : 24.0
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_EXPLOSION)
    for (new axis=0; axis<3; axis++) write_coord_f(origin[axis])
    write_short(g_explosion_sprite)
    write_byte(12); write_byte(20)
    write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND)
    message_end()
    // Team-colored expanding shockwave behind the initial explosion.
    origin[2] -= 45.0
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMCYLINDER)
    for (new axis=0; axis<3; axis++) write_coord_f(origin[axis])
    write_coord_f(origin[0]); write_coord_f(origin[1]); write_coord_f(origin[2]+360.0)
    write_short(g_trail_sprite)
    write_byte(0); write_byte(0); write_byte(6); write_byte(24); write_byte(0)
    write_byte(red); write_byte(green); write_byte(blue); write_byte(255); write_byte(0)
    message_end()
    g_goal_explosions++
}
