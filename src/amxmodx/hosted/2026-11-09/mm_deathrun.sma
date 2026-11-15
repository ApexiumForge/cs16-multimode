#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <mm_mode_api>

new const PLUGIN_NAME[] = "Multi-Mode Deathrun"
new const PLUGIN_VERSION[] = "1.3.1"
new const PLUGIN_AUTHOR[] = "Torbeshi"
const TASK_OPERATOR_CHECK = 904500
const TEAM_MENU_CT = 2
const USP_RESERVE_AMMO = 24
const TASK_KNIFE_HEAL = 904501
const TASK_JOIN_KNIFE_MENU = 904600
const KNIFE_HEAL_CAP = 75
const KNIFE_HEAL_AMOUNT = 3

enum
{
    KNIFE_STANDARD,
    KNIFE_MACHETE,
    KNIFE_BAK,
    KNIFE_POCKET,
    KNIFE_BUTCHER,
    KNIFE_COUNT
}

new const KNIFE_LABELS[KNIFE_COUNT][] =
{
    "Default Knife | Health regeneration",
    "Machete | Double damage, slower movement",
    "Bak Knife | No fall damage",
    "Pocket Knife | High speed",
    "Butcher Knife | Low gravity"
}
new const KNIFE_MODELS[KNIFE_COUNT][] = {"knife", "machete", "bak", "pocket", "butcher"}
new const Float:KNIFE_GRAVITY_SCALE[KNIFE_COUNT] = {1.0, 1.0, 1.0, 1.0, 0.65625}
new const Float:KNIFE_SPEED_SCALE[KNIFE_COUNT] = {1.0, 0.68, 1.0, 1.36, 1.0}
new g_view_model[KNIFE_COUNT], g_player_model[KNIFE_COUNT]
new const GROUND_CVARS[][] = {"sv_accelerate", "sv_friction", "sv_stopspeed"}
new const Float:GROUND_PRESET[] = {8.0, 3.5, 60.0}
new const Float:GROUND_DEFAULT[] = {5.0, 4.0, 75.0}
new const AIR_CVARS[][] = {"sv_airaccelerate", "sv_maxvelocity"}
new const Float:AIR_PRESET[] = {125.0, 8192.0}

new bool:g_active
new g_autobhop
new g_operator
new g_turns[33]
new g_previous_roundover
new g_knife[33]
new bool:g_join_menu_shown[33]
new Float:g_previous_gravity[33]
new Float:g_knife_gravity[33]
new g_ground_cvar[sizeof GROUND_CVARS]
new Float:g_old_ground[sizeof GROUND_CVARS]
new g_air_cvar[sizeof AIR_CVARS]
new Float:g_old_air[sizeof AIR_CVARS]
new bool:g_rules_think
new bool:g_jump_held[33], bool:g_check_landing[33], bool:g_was_grounded[33]
new Float:g_punch_roll[33]
new bool:g_saved_hop[33], bool:g_old_auto[33], bool:g_old_mega[33]

bool:deathrun_map_active()
{
    new map[32]
    get_mapname(map, charsmax(map))
    return mm_get_active_mode() == MM_MODE_DEATHRUN && equali(map, "deathrun_", 9)
}

public plugin_precache()
{
    if (!deathrun_map_active()) return

    for (new choice = 0; choice < KNIFE_COUNT; choice++)
    {
        new view[80], player[80]
        if (choice == KNIFE_STANDARD)
        {
            copy(view, charsmax(view), "models/v_knife.mdl")
            copy(player, charsmax(player), "models/p_knife.mdl")
        }
        else
        {
            formatex(view, charsmax(view), "models/multimode/deathrun/v_%s.mdl", KNIFE_MODELS[choice])
            formatex(player, charsmax(player), "models/multimode/deathrun/p_%s.mdl", KNIFE_MODELS[choice])
            if (!file_exists(view) || !file_exists(player))
            {
                log_amx("Deathrun knife model pair missing for %s. Using the default model.", KNIFE_MODELS[choice])
                continue
            }
        }
        precache_model(view)
        precache_model(player)
        g_view_model[choice] = engfunc(EngFunc_AllocString, view)
        g_player_model[choice] = engfunc(EngFunc_AllocString, player)
    }
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    g_autobhop = create_cvar("mm_deathrun_autobhop", "1", .description = "Hold jump to bunnyhop in Deathrun", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
    hook_cvar_change(g_autobhop, "autobhop_changed")
    register_srvcmd("mm_deathrun_status", "deathrun_status")

    new map[32]
    get_mapname(map, charsmax(map))
    g_active = deathrun_map_active()
    if (!g_active) return

    g_previous_roundover = get_cvar_num("mp_roundover")
    set_cvar_num("mp_roundover", 2) // A timeout is a win for the trap operator.
    RegisterHookChain(RG_HandleMenu_ChooseTeam, "choose_team_pre")
    RegisterHookChain(RG_CSGameRules_RestartRound, "restart_round_pre")
    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "spawn_equip_pre")
    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "spawn_equip_post", true)
    RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "reset_speed_post", true)
    RegisterHam(Ham_TakeDamage, "player", "knife_damage_pre")
    RegisterHookChain(RG_PM_Move, "move_pre")
    RegisterHookChain(RG_PM_Move, "move_post", true)
    RegisterHookChain(RG_PM_Jump, "bunnyhop_pre")
    RegisterHookChain(RG_PM_Jump, "bunnyhop_post", true)
    RegisterHookChain(RG_CSGameRules_Think, "rules_pre")
    RegisterHookChain(RG_CSGameRules_Think, "rules_post", true)
    RegisterHookChain(RH_Cvar_DirectSet, "ground_cvar_pre")
    register_forward(FM_CmdStart, "read_jump_input")
    register_clcmd("say /knife", "knife_menu")
    register_clcmd("say_team /knife", "knife_menu")
    register_clcmd("chooseteam", "block_team_menu")
    register_clcmd("kill", "block_suicide")
    set_task(1.0, "check_operator", TASK_OPERATOR_CHECK, _, _, "b")
    set_task(4.0, "heal_default_knife", TASK_KNIFE_HEAL, _, _, "b")
    log_amx("Deathrun initialized on %s.", map)
}

public plugin_cfg()
{
    if (!g_active) return
    for (new i = 0; i < sizeof AIR_CVARS; i++)
    {
        g_air_cvar[i] = get_cvar_pointer(AIR_CVARS[i])
        g_old_air[i] = get_pcvar_float(g_air_cvar[i])
        set_pcvar_float(g_air_cvar[i], AIR_PRESET[i])
    }
    for (new i = 0; i < sizeof GROUND_CVARS; i++)
    {
        g_ground_cvar[i] = get_cvar_pointer(GROUND_CVARS[i])
        g_old_ground[i] = get_pcvar_float(g_ground_cvar[i])
        set_pcvar_float(g_ground_cvar[i], GROUND_PRESET[i])
    }
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
    g_rules_think = false
    set_cvar_num("mp_roundover", g_previous_roundover)
    remove_task(TASK_OPERATOR_CHECK)
    remove_task(TASK_KNIFE_HEAL)
    for (new i = 0; i < sizeof AIR_CVARS; i++)
        if (g_air_cvar[i]) set_pcvar_float(g_air_cvar[i], g_old_air[i])
    for (new i = 0; i < sizeof GROUND_CVARS; i++)
        if (g_ground_cvar[i]) set_pcvar_float(g_ground_cvar[i], g_old_ground[i])
    for (new id = 1; id <= MaxClients; id++)
    {
        remove_task(TASK_JOIN_KNIFE_MENU + id)
        if (is_user_connected(id)) restore_hop_flags(id)
        if (!is_user_alive(id)) continue
        restore_gravity(id)
        rg_reset_maxspeed(id)
    }
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
    restore_gravity(id)
    rg_remove_all_items(id)
    SetHookChainArg(2, ATYPE_BOOL, false)
    return HC_CONTINUE
}

public spawn_equip_post(id, bool:add_default, bool:equip_game)
{
    if (!g_active || !is_user_alive(id)) return
    if (!user_has_weapon(id, CSW_KNIFE)) rg_give_item(id, "weapon_knife")
    if (!is_deathrun_player(id))
    {
        restore_hop_flags(id)
        return
    }
    if (!g_saved_hop[id])
    {
        g_old_auto[id] = bool:get_member(id, m_bAutoBunnyHopping)
        g_old_mega[id] = bool:get_member(id, m_bMegaBunnyJumping)
        g_saved_hop[id] = true
    }
    set_member(id, m_bAutoBunnyHopping, get_pcvar_num(g_autobhop) != 0)
    set_member(id, m_bMegaBunnyJumping, true)
    if (get_member(id, m_iTeam) == TEAM_CT)
    {
        if (!user_has_weapon(id, CSW_USP)) rg_give_item(id, "weapon_usp")
        if (user_has_weapon(id, CSW_USP)) rg_set_user_bpammo(id, WEAPON_USP, USP_RESERVE_AMMO)
    }
    if (!g_join_menu_shown[id] && !is_user_bot(id))
    {
        remove_task(TASK_JOIN_KNIFE_MENU + id)
        set_task(0.5, "join_knife_menu", TASK_JOIN_KNIFE_MENU + id)
    }
}

public autobhop_changed(pointer, const old_value[], const new_value[])
{
    if (!g_active) return
    new bool:enabled = str_to_num(new_value) != 0
    for (new id = 1; id <= MaxClients; id++)
        if (g_saved_hop[id] && is_deathrun_player(id))
            set_member(id, m_bAutoBunnyHopping, enabled)
}

public join_knife_menu(task)
{
    new id = task - TASK_JOIN_KNIFE_MENU
    if (!g_active || !is_deathrun_player(id) || !is_user_alive(id) || g_join_menu_shown[id]) return

    new menu, newmenu
    if (get_member(id, m_iJoiningState) != JOINED || player_menu_info(id, menu, newmenu))
    {
        set_task(0.5, "join_knife_menu", task)
        return
    }
    knife_menu(id)
}

bool:is_deathrun_player(id)
{
    if (id < 1 || id > MaxClients || !is_user_connected(id)) return false
    new TeamName:team = TeamName:get_member(id, m_iTeam)
    return team == TEAM_CT || team == TEAM_TERRORIST
}

restore_hop_flags(id)
{
    if (!g_saved_hop[id]) return
    set_member(id, m_bAutoBunnyHopping, g_old_auto[id])
    set_member(id, m_bMegaBunnyJumping, g_old_mega[id])
    g_saved_hop[id] = false
    g_jump_held[id] = false
    g_check_landing[id] = false
}

bool:can_hop(id)
{
    return g_active && is_deathrun_player(id) && is_user_alive(id)
        && get_pmove(pm_movetype) == MOVETYPE_WALK && get_pmove(pm_waterlevel) < 2
        && Float:get_pmove(pm_waterjumptime) <= 0.0
}

public read_jump_input(id, command, seed)
{
    if (g_active) g_jump_held[id] = bool:(get_uc(command, UC_Buttons) & IN_JUMP)
    return FMRES_IGNORED
}

// Use the native jump and preserve the pre-landing view roll.
public move_pre(player)
{
    new id = get_pmove(pm_player_index) + 1
    if (!can_hop(id)) return HC_CONTINUE

    set_pmove(pm_fuser2, 0.0)
    g_check_landing[id] = g_jump_held[id]
    if (g_check_landing[id])
    {
        new Float:punch[3]
        get_pmove(pm_punchangle, punch)
        g_punch_roll[id] = punch[2]
        g_was_grounded[id] = get_pmove(pm_onground) != -1
    }
    return HC_CONTINUE
}

public move_post(player)
{
    new id = get_pmove(pm_player_index) + 1
    if (!can_hop(id) || !g_check_landing[id]) return HC_CONTINUE
    g_check_landing[id] = false
    if (!g_was_grounded[id] && get_pmove(pm_onground) != -1)
    {
        new Float:punch[3]
        get_pmove(pm_punchangle, punch)
        punch[2] = g_punch_roll[id]
        set_pmove(pm_punchangle, punch)
    }
    return HC_CONTINUE
}

public bunnyhop_pre(player)
{
    new id = get_pmove(pm_player_index) + 1
    if (!can_hop(id)) return HC_CONTINUE
    set_pmove(pm_fuser2, 0.0)
    if (get_pmove(pm_onground) != -1)
    {
        new old_buttons = get_pmove(pm_oldbuttons)
        if (get_pcvar_num(g_autobhop)) set_pmove(pm_oldbuttons, old_buttons & ~IN_JUMP)
        else if (old_buttons & IN_JUMP) return HC_SUPERCEDE
    }
    return HC_CONTINUE
}

public bunnyhop_post(player)
{
    if (can_hop(get_pmove(pm_player_index) + 1)) set_pmove(pm_fuser2, 0.0)
    return HC_CONTINUE
}

public rules_pre()
{
    g_rules_think = g_active
    return HC_CONTINUE
}

public rules_post()
{
    g_rules_think = false
    return HC_CONTINUE
}

public ground_cvar_pre(pointer, const value[])
{
    if (!g_rules_think || !g_active) return HC_CONTINUE
    for (new i = 0; i < sizeof GROUND_CVARS; i++)
    {
        if (pointer == g_ground_cvar[i]
            && floatabs(str_to_float(value) - GROUND_DEFAULT[i]) < 0.001
            && floatabs(get_pcvar_float(pointer) - GROUND_PRESET[i]) < 0.001)
            return HC_SUPERCEDE
    }
    return HC_CONTINUE
}

public reset_speed_post(id)
{
    if (!g_active || !is_user_alive(id)) return

    new bool:holding_knife = is_deathrun_player(id) && has_knife_equipped(id)
    new choice = KNIFE_STANDARD
    if (holding_knife)
    {
        choice = g_knife[id]
        new model_choice = g_view_model[choice] ? choice : KNIFE_STANDARD
        if (g_view_model[model_choice])
        {
            set_pev_string(id, pev_viewmodel2, g_view_model[model_choice])
            set_pev_string(id, pev_weaponmodel2, g_player_model[model_choice])
        }
    }

    restore_gravity(id)
    if (KNIFE_GRAVITY_SCALE[choice] < 1.0)
    {
        g_previous_gravity[id] = Float:get_entvar(id, var_gravity)
        g_knife_gravity[id] = g_previous_gravity[id] * KNIFE_GRAVITY_SCALE[choice]
        set_entvar(id, var_gravity, g_knife_gravity[id])
    }
    new Float:speed = Float:get_entvar(id, var_maxspeed)
    if (speed > 1.0 && !get_member_game(m_bFreezePeriod))
        set_entvar(id, var_maxspeed, speed * KNIFE_SPEED_SCALE[choice])
}

bool:has_knife_equipped(id)
{
    new weapon = get_member(id, m_pActiveItem)
    return !is_nullent(weapon) && get_member(weapon, m_iId) == WEAPON_KNIFE
}

public heal_default_knife()
{
    if (!g_active || get_member_game(m_bFreezePeriod)) return
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_deathrun_player(id) || !is_user_alive(id) || g_knife[id] != KNIFE_STANDARD || !has_knife_equipped(id)) continue
        new Float:health = Float:get_entvar(id, var_health)
        if (health < float(KNIFE_HEAL_CAP))
            set_entvar(id, var_health, floatmin(health + float(KNIFE_HEAL_AMOUNT), float(KNIFE_HEAL_CAP)))
    }
}

public knife_damage_pre(victim, inflictor, attacker, Float:damage, damage_bits)
{
    if (!g_active) return HAM_IGNORED

    if ((damage_bits & DMG_FALL) && is_deathrun_player(victim) && g_knife[victim] == KNIFE_BAK && has_knife_equipped(victim))
    {
        SetHamReturnInteger(0)
        return HAM_SUPERCEDE
    }

    if (attacker != inflictor || !is_deathrun_player(attacker) || g_knife[attacker] != KNIFE_MACHETE
        || !has_knife_equipped(attacker) || !is_deathrun_player(victim) || get_member(victim, m_iTeam) == get_member(attacker, m_iTeam))
        return HAM_IGNORED

    SetHamParamFloat(4, damage * 2.0)
    return HAM_HANDLED
}

restore_gravity(id)
{
    if (!g_knife_gravity[id]) return
    if (Float:get_entvar(id, var_gravity) == g_knife_gravity[id])
        set_entvar(id, var_gravity, g_previous_gravity[id])
    g_knife_gravity[id] = 0.0
}

public knife_menu(id)
{
    if (!g_active) return PLUGIN_CONTINUE
    if (!is_deathrun_player(id))
    {
        client_print_color(id, print_team_red, "^4[^1Deathrun^4]^1 Movement knives are for Deathrun players.")
        return PLUGIN_HANDLED
    }

    g_join_menu_shown[id] = true
    remove_task(TASK_JOIN_KNIFE_MENU + id)
    new menu = menu_create("Deathrun Knives", "knife_selected")
    for (new choice = 0; choice < KNIFE_COUNT; choice++)
    {
        new label[80]
        formatex(label, charsmax(label), "%s%s", KNIFE_LABELS[choice], g_knife[id] == choice ? " [selected]" : "")
        menu_additem(menu, label)
    }
    menu_display(id, menu)
    return PLUGIN_HANDLED
}

public knife_selected(id, menu, item)
{
    menu_destroy(menu)
    if (!g_active || item < 0 || item >= KNIFE_COUNT || !is_deathrun_player(id)) return PLUGIN_HANDLED

    g_knife[id] = item
    if (is_user_alive(id))
    {
        if (has_knife_equipped(id)) rg_reset_maxspeed(id)
        else
        {
            new knife = rg_find_weapon_bpack_by_name(id, "weapon_knife")
            if (knife > 0) rg_switch_weapon(id, knife)
        }
    }
    client_print_color(id, print_team_blue, "^4[^1Deathrun^4]^1 Selected ^3%s^1. Perks apply while holding your knife.", KNIFE_LABELS[item])
    return PLUGIN_HANDLED
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
    remove_task(TASK_JOIN_KNIFE_MENU + id)
    g_join_menu_shown[id] = false
    g_turns[id] = 0
    g_knife[id] = KNIFE_STANDARD
    g_knife_gravity[id] = 0.0
    g_saved_hop[id] = false
    g_jump_held[id] = false
    g_check_landing[id] = false
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
    new runners, usp_count, model_pairs, operator_hop, operator_knife
    for (new choice = KNIFE_MACHETE; choice < KNIFE_COUNT; choice++)
        if (g_view_model[choice] && g_player_model[choice]) model_pairs++
    if (g_active)
    {
        for (new id = 1; id <= MaxClients; id++)
        {
            if (!is_deathrun_player(id) || !is_user_alive(id)) continue
            if (get_member(id, m_iTeam) == TEAM_TERRORIST)
            {
                operator_hop = get_member(id, m_bAutoBunnyHopping)
                operator_knife = g_knife[id]
                continue
            }
            runners++
            if (user_has_weapon(id, CSW_USP)) usp_count++
        }
    }
    server_print("[Deathrun] version=%s active=%d operator=%d runners=%d runner_usps=%d knife_models=%d operator_hop=%d operator_knife=%d autobhop=%d", PLUGIN_VERSION, g_active, g_operator, runners, usp_count, model_pairs, operator_hop, operator_knife, get_pcvar_num(g_autobhop))
    return PLUGIN_HANDLED
}
