#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <mm_mode_api>

#define MM_MAX_POINTS 640
#define MM_GRID_STEP 128.0
#define MM_BUILD_TASK 873100
#define MM_SPAWN_TASK 873200
#define MM_MIN_PLAYER_DISTANCE 384.0

new const PLUGIN_NAME[] = "Torbeshi Distributed Spawns"
new const PLUGIN_VERSION[] = "1.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new Float:g_points[MM_MAX_POINTS][3], Float:g_angles[MM_MAX_POINTS][3]
new g_count, g_next, g_enabled, g_moves, g_rejected, g_hazards[128], g_hazard_count, g_seeds
new bool:g_ready
new const Float:MM_OFFSETS[8][2] = {
    {MM_GRID_STEP,0.0}, {-MM_GRID_STEP,0.0}, {0.0,MM_GRID_STEP}, {0.0,-MM_GRID_STEP},
    {MM_GRID_STEP,MM_GRID_STEP}, {-MM_GRID_STEP,MM_GRID_STEP}, {MM_GRID_STEP,-MM_GRID_STEP}, {-MM_GRID_STEP,-MM_GRID_STEP}
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    g_enabled = register_cvar("mm_random_spawns", "1")
    RegisterHam(Ham_Spawn, "player", "mm_spawn_post", 1)
    register_srvcmd("mm_spawn_status", "mm_spawn_status")
}

public plugin_cfg()
{
    new entity
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "trigger_hurt")) > 0)
        if (g_hazard_count < sizeof(g_hazards)) g_hazards[g_hazard_count++] = entity
    mm_seed("info_player_start")
    mm_seed("info_player_deathmatch")
    g_seeds = g_count
    set_task(0.1, "mm_expand_points", MM_BUILD_TASK, "", 0, "b")
}

mm_seed(const classname[])
{
    new entity, Float:point[3], Float:angle[3], Float:floor_point[3]
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", classname)) > 0)
    {
        pev(entity, pev_origin, point)
        pev(entity, pev_angles, angle)
        if (mm_floor(point, floor_point) && !mm_duplicate(floor_point)) mm_add_point(floor_point, angle)
    }
}

public mm_expand_points()
{
    new Float:point[3], Float:floor_point[3]
    // Bound work per tick; expand from both teams' starts into adjacent areas.
    for (new processed = 0; processed < 6 && g_next < g_count && g_count < MM_MAX_POINTS; processed++, g_next++)
    {
        for (new direction = 0; direction < sizeof(MM_OFFSETS) && g_count < MM_MAX_POINTS; direction++)
        {
            point[0] = g_points[g_next][0] + MM_OFFSETS[direction][0]
            point[1] = g_points[g_next][1] + MM_OFFSETS[direction][1]
            point[2] = g_points[g_next][2]
            if (mm_duplicate(point) || !mm_floor(point, floor_point) || mm_duplicate(floor_point)) continue
            if (!mm_connected(g_points[g_next], floor_point)) continue
            mm_add_point(floor_point, g_angles[g_next])
        }
    }
    if (g_next >= g_count || g_count >= MM_MAX_POINTS)
    {
        remove_task(MM_BUILD_TASK)
        g_ready = g_count > 0
        log_amx("Distributed spawn scan complete: %d grounded points. DM/Arms Race only.", g_count)
    }
}

bool:mm_duplicate(const Float:point[3])
{
    for (new i = 0; i < g_count; i++)
        if (get_distance_f(point, g_points[i]) < 80.0) return true
    return false
}

mm_add_point(const Float:point[3], const Float:angle[3])
{
    if (g_count >= MM_MAX_POINTS) return
    for (new axis = 0; axis < 3; axis++)
    {
        g_points[g_count][axis] = point[axis]
        g_angles[g_count][axis] = angle[axis]
    }
    g_count++
}

bool:mm_hazard(const Float:point[3])
{
    new Float:minimum[3], Float:maximum[3]
    for (new i = 0; i < g_hazard_count; i++)
    {
        if (!pev_valid(g_hazards[i])) continue
        pev(g_hazards[i], pev_absmin, minimum)
        pev(g_hazards[i], pev_absmax, maximum)
        if (point[0] + 20.0 > minimum[0] && point[0] - 20.0 < maximum[0]
            && point[1] + 20.0 > minimum[1] && point[1] - 20.0 < maximum[1]
            && point[2] + 38.0 > minimum[2] && point[2] - 38.0 < maximum[2]) return true
    }
    return false
}

bool:mm_clear(const Float:point[3], id, bool:players)
{
    if (engfunc(EngFunc_PointContents, point) != CONTENTS_EMPTY || mm_hazard(point)) return false
    new trace = create_tr2()
    engfunc(EngFunc_TraceHull, point, point, players ? DONT_IGNORE_MONSTERS : IGNORE_MONSTERS, HULL_HUMAN, id, trace)
    new bool:clear = !get_tr2(trace, TR_StartSolid) && !get_tr2(trace, TR_AllSolid)
    free_tr2(trace)
    return clear
}

bool:mm_floor(const Float:point[3], Float:output[3])
{
    new Float:top[3], Float:bottom[3], Float:normal[3], Float:fraction
    for (new axis = 0; axis < 3; axis++) top[axis] = bottom[axis] = point[axis]
    top[2] += 64.0
    bottom[2] -= 112.0
    new trace = create_tr2()
    engfunc(EngFunc_TraceLine, top, bottom, IGNORE_MONSTERS, 0, trace)
    get_tr2(trace, TR_flFraction, fraction)
    get_tr2(trace, TR_vecPlaneNormal, normal)
    get_tr2(trace, TR_vecEndPos, output)
    new bool:valid = fraction < 1.0 && !get_tr2(trace, TR_StartSolid) && normal[2] >= 0.75
    free_tr2(trace)
    if (!valid) return false
    output[2] += 37.0
    return mm_clear(output, 0, false)
}

bool:mm_connected(const Float:from[3], const Float:to[3])
{
    if (floatabs(from[2] - to[2]) > 64.0) return false
    new Float:middle[3], Float:ground[3], Float:start[3], Float:finish[3], Float:fraction
    for (new axis = 0; axis < 3; axis++)
    {
        middle[axis] = (from[axis] + to[axis]) * 0.5
        start[axis] = from[axis]
        finish[axis] = to[axis]
    }
    if (!mm_floor(middle, ground) || floatabs(ground[2] - middle[2]) > 64.0) return false
    start[2] = finish[2] = floatmax(from[2], to[2]) + 18.0
    new trace = create_tr2()
    engfunc(EngFunc_TraceHull, start, finish, IGNORE_MONSTERS, HULL_HUMAN, 0, trace)
    get_tr2(trace, TR_flFraction, fraction)
    new bool:clear = fraction >= 1.0 && !get_tr2(trace, TR_StartSolid)
    free_tr2(trace)
    return clear
}

bool:mm_target_mode()
{
    if (!get_pcvar_num(g_enabled) || mm_get_transition_state() != MM_TRANSITION_IDLE) return false
    new MmMode:mode = mm_get_active_mode()
    return mode == MM_MODE_DEATHMATCH || mode == MM_MODE_ARMS_RACE
}

public mm_spawn_post(id)
{
    remove_task(MM_SPAWN_TASK + id)
    if (is_user_alive(id) && mm_target_mode()) set_task(0.1, "mm_place_player", MM_SPAWN_TASK + id)
}

public mm_place_player(task)
{
    new id = task - MM_SPAWN_TASK
    if (!is_user_alive(id) || !g_ready || !mm_target_mode()) return
    new players[32], count, Float:others[32][3], Float:point[3], Float:nearest, Float:score, Float:best = -1.0
    get_players(players, count, "ah")
    for (new i = 0; i < count; i++) pev(players[i], pev_origin, others[i])
    new candidate = -1, start = random_num(0, g_count - 1)
    for (new offset = 0; offset < g_count; offset++)
    {
        new index = (start + offset) % g_count
        for (new axis = 0; axis < 3; axis++) point[axis] = g_points[index][axis]
        if (!mm_clear(point, id, true)) continue
        nearest = 100000.0
        for (new i = 0; i < count; i++)
        {
            if (players[i] == id) continue
            new Float:distance = get_distance_f(point, others[i])
            if (distance < nearest) nearest = distance
        }
        if (nearest < 80.0) continue
        score = nearest
        if (score > best) {best = score; candidate = index;}
        if (nearest >= MM_MIN_PLAYER_DISTANCE) break
    }
    if (candidate == -1) {g_rejected++; return;}
    engfunc(EngFunc_SetOrigin, id, g_points[candidate])
    set_pev(id, pev_velocity, Float:{0.0,0.0,0.0})
    set_pev(id, pev_angles, g_angles[candidate])
    set_pev(id, pev_v_angle, g_angles[candidate])
    set_pev(id, pev_fixangle, 1)
    g_moves++
}

public mm_mode_transition_started(old_mode, new_mode)
{
    for (new id = 1; id <= MaxClients; id++) remove_task(MM_SPAWN_TASK + id)
}

public client_disconnected(id) {remove_task(MM_SPAWN_TASK + id);}
public mm_spawn_status()
{
    new distributed, Float:nearest
    for (new point = g_seeds; point < g_count; point++)
    {
        nearest = 100000.0
        for (new seed = 0; seed < g_seeds; seed++)
        {
            new Float:distance = get_distance_f(g_points[point], g_points[seed])
            if (distance < nearest) nearest = distance
        }
        if (nearest >= 256.0) distributed++
    }
    server_print("[Spawn] points=%d seeds=%d away_from_base=%d ready=%d enabled=%d active=%d moved=%d fallback=%d", g_count, g_seeds, distributed, g_ready, get_pcvar_num(g_enabled), mm_target_mode(), g_moves, g_rejected)
}
public plugin_end()
{
    remove_task(MM_BUILD_TASK)
    for (new id = 1; id <= MaxClients; id++) remove_task(MM_SPAWN_TASK + id)
}
