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

// Adapted for Torbeshi multimode: scoped lifecycle, pitch boxes, controls and rounds.
new const PLUGIN_NAME[] = "Multi-Mode Football"
new const PLUGIN_VERSION[] = "1.0.1"
new const PLUGIN_AUTHOR[] = "CSB / Torbeshi"
new const BALL_CLASS[] = "mm_football_ball"
new const BALL_MODEL[] = "models/kickball/ball.mdl"
new const BOUNCE_SOUND[] = "kickball/bounce.wav"
new const WHISTLE_SOUND[] = "kickball/whistle.wav"
#define MM_FB_TICK 897000
#define MM_FB_RESET 897001
#define MM_FB_RESPAWN 897100
#define MM_FB_LOADOUT 897200
new g_ball, g_last_touch, g_score[2], g_hud, g_goal_limit, g_added_spawns
new bool:g_enabled, bool:g_field_ready, bool:g_paused
new bool:g_resources_ready
new Float:g_spawn[3], Float:g_goal[2][3], Float:g_previous[3]
new Float:g_last_manual[33]
new Float:g_last_kick, Float:g_last_bounce, Float:g_last_motion, Float:g_last_hud

public plugin_precache()
{
    if (!file_exists(BALL_MODEL) || !file_exists("sound/kickball/bounce.wav") || !file_exists("sound/kickball/whistle.wav"))
    {
        log_amx("Football resources missing; install ball model and sounds before activating Football.")
        return
    }
    precache_model(BALL_MODEL)
    precache_sound(BOUNCE_SOUND)
    precache_sound(WHISTLE_SOUND)
    g_resources_ready = true
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    RegisterHam(Ham_Spawn, "player", "mm_spawn_post", 1)
    RegisterHam(Ham_Killed, "player", "mm_killed_post", 1)
    RegisterHam(Ham_TakeDamage, "player", "mm_damage_pre")
    RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "mm_speed_post", 1)
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
    new const commands[][] = {"buy","buyequip","autobuy","rebuy","cl_autobuy","cl_rebuy","buyammo1","buyammo2","drop"}
    for (new i = 0; i < sizeof commands; i++) register_clcmd(commands[i], "mm_block_command")
    register_clcmd("say /football", "mm_help")
    register_clcmd("say_team /football", "mm_help")
    register_clcmd("say /soccer", "mm_help")
    register_concmd("mm_football_reset", "mm_admin_reset", ADMIN_CFG, "Reset football scores and kickoff")
    register_srvcmd("mm_football_status", "mm_status")
    register_srvcmd("mm_football_selftest", "mm_selftest")
    g_goal_limit = register_cvar("mm_football_goal_limit", "5")
    g_hud = CreateHudSyncObj()
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
    if (!g_resources_ready) return
    g_enabled = true
    arrayset(g_score, 0, sizeof g_score)
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
    client_print_color(0, print_team_default, "^4[Football]^1 First to ^4%d^1 goals! Touch to dribble; ^4E/left click^1 shoot, ^4R/right click^1 pass. ^4/football^1 for help.", clamp(get_pcvar_num(g_goal_limit), 1, 30))
}

mm_shutdown()
{
    new bool:was_enabled = g_enabled
    g_enabled = false
    remove_task(MM_FB_TICK); remove_task(MM_FB_RESET)
    for (new id = 1; id <= MaxClients; id++)
    {
        remove_task(MM_FB_RESPAWN + id); remove_task(MM_FB_LOADOUT + id)
        if (was_enabled && is_user_alive(id)) rg_reset_maxspeed(id)
    }
    if (is_valid_ent(g_ball)) remove_entity(g_ball)
    g_ball = 0; g_enabled = false; g_paused = false; g_last_touch = 0
    ClearSyncHud(0, g_hud)
}
public plugin_end() mm_shutdown()
public client_disconnected(id)
{
    remove_task(MM_FB_RESPAWN + id); remove_task(MM_FB_LOADOUT + id)
    if (g_last_touch == id) g_last_touch = 0
    g_last_manual[id] = 0.0
}

bool:mm_load_field()
{
    new map[32], path[192], line[128], x[24], y[24], z[24], count
    get_mapname(map, charsmax(map))
    formatex(path, charsmax(path), "addons/amxmodx/configs/mm_football/%s.ini", map)
    new file = fopen(path, "rt")
    if (!file) return false
    while (!feof(file) && count < 3)
    {
        fgets(file, line, charsmax(line)); trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#') continue
        if (parse(line, x, charsmax(x), y, charsmax(y), z, charsmax(z)) != 3) continue
        if (!count) {g_spawn[0] = str_to_float(x); g_spawn[1] = str_to_float(y); g_spawn[2] = str_to_float(z);}
        else {g_goal[count-1][0] = str_to_float(x); g_goal[count-1][1] = str_to_float(y); g_goal[count-1][2] = str_to_float(z);}
        count++
    }
    fclose(file)
    if (count != 3) return false
    return get_distance_f(g_goal[0], g_goal[1]) > 300.0
        && engfunc(EngFunc_PointContents, g_spawn) != CONTENTS_SOLID
}

mm_loadout(id)
{
    rg_remove_all_items(id, false)
    give_item(id, "weapon_knife")
    set_user_health(id, 100)
    cs_set_user_armor(id, 0, CS_ARMOR_NONE)
    cs_set_user_defuse(id, 0)
    set_user_maxspeed(id, 300.0)
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
    if (g_enabled && mm_active() && mm_get_transition_state() == MM_TRANSITION_IDLE && mm_playing(id) && !is_user_alive(id)) ExecuteHamB(Ham_CS_RoundRespawn, id)
}
public mm_speed_post(id)
{
    if (g_enabled && mm_active() && is_user_alive(id)) set_user_maxspeed(id, 300.0)
    return HAM_IGNORED
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
        if ((buttons & (IN_USE | IN_ATTACK)) && !(old & (IN_USE | IN_ATTACK))) mm_kick(id, 1100.0, false)
        else if ((buttons & (IN_RELOAD | IN_ATTACK2)) && !(old & (IN_RELOAD | IN_ATTACK2))) mm_kick(id, 650.0, true)
    }
    set_uc(command, UC_Buttons, buttons & ~(IN_ATTACK | IN_ATTACK2))
    return FMRES_HANDLED
}

mm_kick(id, Float:power, bool:low)
{
    if (!mm_playing(id)) return
    new bool:manual = power >= 650.0
    if (manual ? (get_gametime() - g_last_manual[id] < 0.25) : (get_gametime() - g_last_kick < 0.18)) return
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
    pev(id, pev_v_angle, angles); angle_vector(angles, ANGLEVECTOR_FORWARD, aim_dir)
    new Float:horizontal = floatsqroot(aim_dir[0]*aim_dir[0] + aim_dir[1]*aim_dir[1])
    if (horizontal < 0.1) return
    velocity[0] = aim_dir[0]/horizontal * power
    velocity[1] = aim_dir[1]/horizontal * power
    velocity[2] = low ? 100.0 : floatclamp(aim_dir[2] * power + 180.0, 140.0, 650.0)
    set_pev(g_ball, pev_velocity, velocity)
    g_last_kick = get_gametime(); g_last_motion = g_last_kick; g_last_touch = id
    if (manual) g_last_manual[id] = g_last_kick
    emit_sound(g_ball, CHAN_BODY, BOUNCE_SOUND, 0.5, ATTN_NORM, 0, PITCH_NORM)
}

public mm_ball_touch(ball, other)
{
    if (!g_enabled || g_paused || ball != g_ball || !mm_active()) return
    if (other >= 1 && other <= MaxClients && is_user_alive(other)) mm_kick(other, 420.0, true)
    else if (get_gametime() - g_last_bounce > 0.15)
    {
        emit_sound(ball, CHAN_BODY, BOUNCE_SOUND, 0.35, ATTN_NORM, 0, PITCH_NORM)
        g_last_bounce = get_gametime()
    }
}

mm_reset_ball()
{
    if (!is_valid_ent(g_ball)) return
    entity_set_origin(g_ball, g_spawn)
    entity_set_vector(g_ball, EV_VEC_velocity, Float:{0.0,0.0,0.0})
    entity_set_int(g_ball, EV_INT_flags, entity_get_int(g_ball, EV_INT_flags) & ~FL_ONGROUND)
    for (new i = 0; i < 3; i++) g_previous[i] = g_spawn[i]
    g_last_touch = 0; g_last_kick = get_gametime(); g_last_motion = g_last_kick
}
public mm_kickoff()
{
    if (!g_enabled || !mm_active() || !is_valid_ent(g_ball)) return
    g_paused = false
    mm_reset_ball()
    for (new id = 1; id <= MaxClients; id++)
        if (mm_playing(id)) ExecuteHamB(Ham_CS_RoundRespawn, id)
    emit_sound(g_ball, CHAN_AUTO, WHISTLE_SOUND, 0.7, ATTN_NONE, 0, PITCH_NORM)
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
    pev(g_ball, pev_origin, pos); pev(g_ball, pev_velocity, velocity)
    if (!g_paused)
    {
        if (get_distance_f(pos, g_spawn) > 6500.0 || pos[2] < g_spawn[2]-500.0 || engfunc(EngFunc_PointContents, pos) == CONTENTS_SOLID)
        {mm_reset_ball(); return;}
        if (vector_length(velocity) > 20.0) g_last_motion = now
        if (now - g_last_motion > 30.0) {mm_reset_ball(); return;}
        for (new goal = 0; goal < 2; goal++)
            if (mm_segment_goal(g_previous, pos, goal)) {mm_goal(1-goal); return;}
        for (new axis = 0; axis < 3; axis++) g_previous[axis] = pos[axis]
    }
    if (now - g_last_hud >= 0.5)
    {
        set_hudmessage(80, 220, 120, -1.0, 0.10, 0, 0.0, 0.6, 0.0, 0.0)
        ShowSyncHudMsg(0, g_hud, "FOOTBALL | T %d : %d CT | First to %d^nE / Left click: SHOOT | R / Right click: PASS", g_score[0], g_score[1], clamp(get_pcvar_num(g_goal_limit), 1, 30))
        g_last_hud = now
    }
}

mm_goal(team)
{
    g_paused = true
    g_score[team]++
    entity_set_vector(g_ball, EV_VEC_velocity, Float:{0.0,0.0,0.0})
    if (mm_playing(g_last_touch)) client_print_color(0, print_team_default, "^4[Football]^1 GOAL for ^4%s^1! Last touch: ^4%n^1. T %d : %d CT", team == 0 ? "Terrorists" : "CTs", g_last_touch, g_score[0], g_score[1])
    else client_print_color(0, print_team_default, "^4[Football]^1 GOAL for ^4%s^1! T %d : %d CT", team == 0 ? "Terrorists" : "CTs", g_score[0], g_score[1])
    if (g_score[team] >= clamp(get_pcvar_num(g_goal_limit), 1, 30))
    {
        client_print_color(0, print_team_default, "^4[Football]^1 ^4%s^1 win the match! New match in 5 seconds.", team == 0 ? "Terrorists" : "CTs")
        set_task(5.0, "mm_new_match", MM_FB_RESET)
    }
    else set_task(3.0, "mm_kickoff", MM_FB_RESET)
}
public mm_new_match()
{
    arrayset(g_score, 0, sizeof g_score)
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
public mm_help(id)
{
    client_print_color(id, print_team_default, "^4[Football]^1 Touch to dribble. ^4E/left click^1 shoots; ^4R/right click^1 passes. Aim to lift your shot. First to ^4%d^1 goals wins. No player damage.", clamp(get_pcvar_num(g_goal_limit), 1, 30))
    return PLUGIN_HANDLED
}
public mm_status()
{
    server_print("[Football] version=%s active=%d ready=%d ball=%d paused=%d score=%d:%d extra_spawns=%d", PLUGIN_VERSION, mm_active(), g_field_ready, is_valid_ent(g_ball), g_paused, g_score[0], g_score[1], g_added_spawns)
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
    if (!g_field_ready) {server_print("[Football Test] No field data on current map."); return 0;}
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
    return passed
}
