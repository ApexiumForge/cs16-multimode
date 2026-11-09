#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

new const CAMERA_MODEL[] = "models/rpgrocket.mdl"
new bool:g_thirdperson[33]
new g_camera[33], g_camera_trace
new g_hidden_frames[33]

public plugin_precache()
{
    precache_model(CAMERA_MODEL)
}
public plugin_init()
{
    register_plugin("Multi-Mode Player Camera", "1.1.1", "ApexiumForge")
    g_camera_trace = create_tr2()
    register_clcmd("say /thirdperson", "toggle_camera")
    register_clcmd("say_team /thirdperson", "toggle_camera")
    register_clcmd("say /firstperson", "firstperson")
    register_clcmd("say_team /firstperson", "firstperson")
    register_clcmd("say /tp", "toggle_camera")
    register_clcmd("say_team /tp", "toggle_camera")
    register_clcmd("say /fp", "firstperson")
    register_clcmd("say_team /fp", "firstperson")
    register_clcmd("mm_thirdperson", "toggle_camera")
    register_clcmd("mm_firstperson", "firstperson")
    register_srvcmd("mm_camera_status", "camera_status")
    register_forward(FM_AddToFullPack, "camera_player_packet", 1)
    RegisterHam(Ham_Spawn, "player", "spawn_post", 1)
    RegisterHam(Ham_Killed, "player", "killed_post", 1)
}
public client_putinserver(id)
{
    g_thirdperson[id] = false
    g_hidden_frames[id] = 0
}
public client_disconnected(id)
{
    g_thirdperson[id] = false
    remove_camera(id)
}
public toggle_camera(id)
{
    if (!is_user_alive(id))
    {
        client_print_color(id, print_team_default, "^4[^1Camera^4]^1 You must be alive to change your view.")
        return PLUGIN_HANDLED
    }
    if (g_thirdperson[id])
    {
        g_thirdperson[id] = false
        reset_camera(id)
    }
    else if (!start_camera(id))
    {
        client_print_color(id, print_team_default, "^4[^1Camera^4]^1 Third person is unavailable.")
        return PLUGIN_HANDLED
    }
    else g_thirdperson[id] = true
    client_print_color(id, print_team_default, "^4[^1Camera^4]^1 View: ^3%s^1. Use ^3/thirdperson^1 to toggle.", g_thirdperson[id] ? "Third person" : "First person")
    return PLUGIN_HANDLED
}
public firstperson(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED
    g_thirdperson[id] = false
    reset_camera(id)
    client_print_color(id, print_team_default, "^4[^1Camera^4]^1 View: ^3First person^1.")
    return PLUGIN_HANDLED
}
public spawn_post(id)
{
    if (is_user_alive(id) && g_thirdperson[id] && !start_camera(id))
        g_thirdperson[id] = false
    return HAM_IGNORED
}
public killed_post(id)
{
    if (g_camera[id]) reset_camera(id)
    return HAM_IGNORED
}
public plugin_end()
{
    for (new id = 1; id <= MaxClients; id++)
        if (g_camera[id]) reset_camera(id)
    free_tr2(g_camera_trace)
}

bool:start_camera(id)
{
    if (!g_camera[id])
    {
        new camera = create_entity("info_target")
        if (!camera) return false

        // Attaching our own camera avoids set_view's forced player opacity.
        entity_set_string(camera, EV_SZ_classname, "mm_player_camera")
        entity_set_model(camera, CAMERA_MODEL)
        entity_set_int(camera, EV_INT_movetype, MOVETYPE_NOCLIP)
        entity_set_int(camera, EV_INT_solid, SOLID_NOT)
        entity_set_edict(camera, EV_ENT_owner, id)
        entity_set_int(camera, EV_INT_rendermode, kRenderTransColor)
        entity_set_float(camera, EV_FL_renderamt, 0.0)
        g_camera[id] = camera
    }
    client_PostThink(id)
    return true
}

reset_camera(id)
{
    if (is_user_connected(id)) attach_view(id, id)
    remove_camera(id)
}

remove_camera(id)
{
    new camera = g_camera[id]
    g_camera[id] = 0
    if (camera && is_valid_ent(camera)) remove_entity(camera)
}

public client_PostThink(id)
{
    new camera = g_camera[id]
    if (!camera) return

    new Float:eye[3], Float:offset[3], Float:angles[3], Float:punch[3]
    new Float:aim[3], Float:forward_vector[3], Float:target[3]
    pev(id, pev_origin, eye)
    pev(id, pev_view_ofs, offset)
    pev(id, pev_v_angle, angles)
    pev(id, pev_punchangle, punch)
    for (new axis = 0; axis < 3; axis++)
    {
        eye[axis] += offset[axis]
        aim[axis] = angles[axis] + punch[axis]
    }

    engfunc(EngFunc_MakeVectors, aim)
    global_get(glb_v_forward, forward_vector)
    for (new axis = 0; axis < 3; axis++)
        target[axis] = eye[axis] - forward_vector[axis] * 128.0

    engfunc(EngFunc_TraceLine, eye, target, IGNORE_MONSTERS, id, g_camera_trace)
    get_tr2(g_camera_trace, TR_vecEndPos, target)
    entity_set_origin(camera, target)
    entity_set_vector(camera, EV_VEC_angles, angles)
    attach_view(id, camera)
}

public camera_player_packet(packet, entity_index, entity, viewer, flags, player, visibility)
{
    if (!player || entity != viewer || !g_camera[viewer] || !get_orig_retval())
        return FMRES_IGNORED

    // GoldSrc may still draw its local player with a zero alpha.
    // Suppress both studio models in this client's own entity state.
    new Float:opacity
    pev(viewer, pev_renderamt, opacity)
    if (pev(viewer, pev_rendermode) != kRenderNormal && opacity <= 0.0)
    {
        set_es(packet, ES_Effects, get_es(packet, ES_Effects) | EF_NODRAW)
        set_es(packet, ES_ModelIndex, 0)
        set_es(packet, ES_WeaponModel, 0)
        g_hidden_frames[viewer]++
    }
    return FMRES_IGNORED
}

public camera_status()
{
    new cameras
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!g_camera[id]) continue
        new Float:opacity
        pev(id, pev_renderamt, opacity)
        server_print("[Camera] client=%d weapon=%d render_mode=%d opacity=%.0f hidden_frames=%d",
            id, get_user_weapon(id), pev(id, pev_rendermode), opacity, g_hidden_frames[id])
        cameras++
    }
    server_print("[Camera] Third-person cameras active=%d", cameras)
}
