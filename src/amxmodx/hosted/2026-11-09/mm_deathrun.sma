#include <amxmodx>
#include <reapi>
#include <mm_mode_api>

new const PLUGIN_NAME[] = "Multi-Mode Deathrun"
new const PLUGIN_VERSION[] = "1.0.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
const TASK_OPERATOR_CHECK = 904500
const TEAM_MENU_CT = 2

new bool:g_active
new g_operator
new g_turns[33]
new g_previous_roundover

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_srvcmd("mm_deathrun_status", "deathrun_status")

    new map[32]
    get_mapname(map, charsmax(map))
    g_active = mm_get_active_mode() == MM_MODE_DEATHRUN && equali(map, "deathrun_", 9)
    if (!g_active) return

    g_previous_roundover = get_cvar_num("mp_roundover")
    set_cvar_num("mp_roundover", 2) // A timeout is a win for the trap operator.
    RegisterHookChain(RG_HandleMenu_ChooseTeam, "choose_team_pre")
    RegisterHookChain(RG_CSGameRules_RestartRound, "restart_round_pre")
    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "spawn_equip_pre")
    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "spawn_equip_post", true)
    register_clcmd("chooseteam", "block_team_menu")
    register_clcmd("kill", "block_suicide")
    set_task(1.0, "check_operator", TASK_OPERATOR_CHECK, _, _, "b")
    log_amx("Deathrun initialized on %s.", map)
}

public mm_mode_transition_started(old_mode, new_mode)
{
    if (old_mode == _:MM_MODE_DEATHRUN) deactivate()
}

public plugin_end() deactivate()

deactivate()
{
    if (!g_active) return
    g_active = false
    set_cvar_num("mp_roundover", g_previous_roundover)
    remove_task(TASK_OPERATOR_CHECK)
}

public choose_team_pre(id, slot)
{
    if (!g_active || !is_user_connected(id) || is_user_hltv(id)) return HC_CONTINUE
    if (get_member(id, m_iTeam) == TEAM_UNASSIGNED || get_member(id, m_iTeam) == TEAM_SPECTATOR)
    {
        SetHookChainArg(2, ATYPE_INTEGER, TEAM_MENU_CT)
        return HC_CONTINUE
    }

    SetHookChainReturn(ATYPE_BOOL, false)
    return HC_SUPERCEDE
}

public spawn_equip_pre(id, bool:add_default, bool:equip_game)
{
    if (!g_active) return HC_CONTINUE
    // Clear weapons from the previous finish and skip the default spawn pistol.
    rg_remove_all_items(id)
    SetHookChainArg(2, ATYPE_BOOL, false)
    return HC_CONTINUE
}

public spawn_equip_post(id, bool:add_default, bool:equip_game)
{
    if (g_active && is_user_alive(id) && !user_has_weapon(id, CSW_KNIFE))
        rg_give_item(id, "weapon_knife")
}

public restart_round_pre()
{
    if (g_active) rotate_operator()
}

public check_operator()
{
    if (!g_active || get_member_game(m_bRoundTerminating)) return
    if (g_operator && is_user_connected(g_operator) && get_member(g_operator, m_iTeam) == TEAM_TERRORIST) return

    rotate_operator()
    if (g_operator && get_member(g_operator, m_iJoiningState) == JOINED)
        rg_round_respawn(g_operator)
}

rotate_operator()
{
    new previous = g_operator
    new count, choice, tied, least_turns = cellmax

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || is_user_hltv(id)) continue
        new TeamName:team = TeamName:get_member(id, m_iTeam)
        if (team != TEAM_CT && team != TEAM_TERRORIST) continue
        if (get_member(id, m_iJoiningState) != JOINED) continue
        count++
        if (id == previous || g_turns[id] > least_turns) continue
        if (g_turns[id] < least_turns)
        {
            least_turns = g_turns[id]
            tied = 0
        }
        if (random_num(1, ++tied) == 1) choice = id
    }

    g_operator = count >= 2 ? choice : 0
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id)) continue
        if (id != g_operator && get_member(id, m_iTeam) == TEAM_TERRORIST)
            rg_set_user_team(id, TEAM_CT)
    }
    if (!g_operator) return

    rg_set_user_team(g_operator, TEAM_TERRORIST)
    g_turns[g_operator]++

    new name[32]
    get_user_name(g_operator, name, charsmax(name))
    client_print_color(0, print_team_red, "^4[^1Deathrun^4]^3 %s ^1is operating the traps.", name)
}

public client_disconnected(id)
{
    g_turns[id] = 0
    if (g_operator == id) g_operator = 0
}

public block_suicide(id) return g_active ? PLUGIN_HANDLED : PLUGIN_CONTINUE

public block_team_menu(id)
{
    if (!g_active || !is_user_connected(id)) return PLUGIN_CONTINUE
    new TeamName:team = TeamName:get_member(id, m_iTeam)
    return (team == TEAM_CT || team == TEAM_TERRORIST) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public deathrun_status()
{
    server_print("[Deathrun] version=%s active=%d operator=%d", PLUGIN_VERSION, g_active, g_operator)
    return PLUGIN_HANDLED
}
