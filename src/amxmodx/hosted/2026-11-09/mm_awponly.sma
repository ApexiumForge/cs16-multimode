#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <mm_mode_api>
#include <reapi>
#include <mm_voting_api>
#include <mm_presentation_api>

#define PLUGIN_NAME    "Multi-Mode Network AWP Only"
#define PLUGIN_VERSION "0.5.1"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"

#define TASK_RESPAWN_BASE    61000
#define TASK_PROTECTION_BASE 62000
#define TASK_LOADOUT_BASE    63000
#define TASK_HUD             64000
#define TASK_RESTORE_MODE    64001
#define TASK_WEAPON_VOTE     64002
#define TASK_MATCH_RESET     64003
#define TASK_INVENTORY       64004

new g_kills[33]
new g_deaths[33]
new bool:g_protected[33]
new bool:g_gameplay_enabled
new g_respawn_delay_cvar
new g_spawn_protection_cvar
new g_awp_ammo_cvar
new g_change_map_cvar
new g_preferred_map_cvar
new g_fallback_map_cvar
new g_pending_restore_cvar
new g_hud_sync
new g_sniper = CSW_AWP, g_scout_ammo, g_scoped, g_spawn_health, g_spawn_armor, g_kill_limit
new bool:g_selecting, bool:g_finished, bool:g_choice_made, g_vote_attempts
new Float:g_scope_notice[33]
new const MM_SNIPER_SETTINGS[] = "addons/amxmodx/configs/mm_awponly_settings.cfg"

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_clcmd("say /awp", "command_status")
    register_clcmd("say_team /awp", "command_status")
    register_clcmd("say /awptop", "command_leaderboard")
    register_clcmd("say_team /awptop", "command_leaderboard")

    register_clcmd("buy", "command_block_inventory")
    register_clcmd("buyequip", "command_block_inventory")
    register_clcmd("cl_autobuy", "command_block_inventory")
    register_clcmd("cl_rebuy", "command_block_inventory")
    register_clcmd("autobuy", "command_block_inventory")
    register_clcmd("rebuy", "command_block_inventory")
    register_clcmd("buyammo1", "command_block_inventory")
    register_clcmd("buyammo2", "command_block_inventory")
    register_clcmd("drop", "command_block_inventory")

    RegisterHam(Ham_Killed, "player", "player_killed_post", 1)
    RegisterHam(Ham_Spawn, "player", "player_spawned_post", 1)
    RegisterHam(Ham_Touch, "weaponbox", "block_weapon_pickup")
    RegisterHam(Ham_Touch, "armoury_entity", "block_weapon_pickup")
    RegisterHam(Ham_Use, "game_player_equip", "mm_block_equipment")
    RegisterHam(Ham_Use, "player_weaponstrip", "mm_block_equipment")
    RegisterHam(Ham_Touch, "game_player_equip", "block_weapon_pickup")
    RegisterHam(Ham_TakeDamage, "player", "mm_match_damage")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_awp", "mm_scope_guard")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_scout", "mm_scope_guard")
    RegisterHookChain(RG_CBasePlayer_GiveDefaultItems, "mm_default_items", false)
    RegisterHookChain(RG_BuyWeaponByWeaponID, "mm_buy_weapon", false)
    RegisterHookChain(RG_BuyGunAmmo, "mm_buy_ammo", false)
    RegisterHookChain(RG_BuyItem, "mm_buy_item", false)
    register_forward(FM_CmdStart, "forward_command_start")

    g_respawn_delay_cvar = register_cvar("mm_awp_respawn_delay", "1.0")
    g_spawn_protection_cvar = register_cvar("mm_awp_spawn_protection", "2.0")
    g_awp_ammo_cvar = register_cvar("mm_awp_reserve_ammo", "30")
    g_scout_ammo = register_cvar("mm_scout_reserve_ammo", "90")
    g_scoped = register_cvar("mm_awp_scoped_only", "0")
    g_spawn_health = register_cvar("mm_awp_spawn_health", "100")
    g_spawn_armor = register_cvar("mm_awp_spawn_armor", "0")
    g_kill_limit = register_cvar("mm_awp_kill_limit", "20")
    register_srvcmd("mm_awponly_status", "mm_status")
    g_change_map_cvar = register_cvar("mm_awp_change_map", "1")
    g_preferred_map_cvar = register_cvar("mm_awp_preferred_map", "awp_india")
    g_fallback_map_cvar = register_cvar("mm_awp_fallback_map", "awp_map")
    g_pending_restore_cvar = register_cvar("mm_awp_pending_restore", "0")
    g_hud_sync = CreateHudSyncObj()

    for (new id = 1; id <= MaxClients; id++) reset_player(id)

    if (get_pcvar_num(g_pending_restore_cvar) == 1)
    {
        set_task(1.0, "task_restore_mode_after_map", TASK_RESTORE_MODE)
    }
    else if (mm_get_active_mode() == MM_MODE_AWP_ONLY)
    {
        activate_awponly()
    }

    log_amx("%s AWP Only v%s initialized.", PROJECT_NAME, PLUGIN_VERSION)
}
public plugin_cfg()
{
    if (file_exists(MM_SNIPER_SETTINGS)) {server_cmd("exec %s", MM_SNIPER_SETTINGS); server_exec();}
}

public client_putinserver(id)
{
    reset_player(id)
    if (awponly_active() && !g_choice_made && !g_selecting && !is_user_bot(id))
    {
        g_vote_attempts = 0; remove_task(TASK_WEAPON_VOTE)
        set_task(2.0, "mm_begin_weapon_vote", TASK_WEAPON_VOTE)
    }
}

public client_disconnected(id)
{
    clear_player_tasks(id)
    g_protected[id] = false
    reset_player(id)
}

public mm_mode_transition_started(old_mode, requested_mode)
{
    if (MmMode:old_mode == MM_MODE_AWP_ONLY && MmMode:requested_mode != MM_MODE_AWP_ONLY)
    {
        disable_awponly()
    }
}

public mm_mode_changed(old_mode, new_mode)
{
    if (MmMode:new_mode == MM_MODE_AWP_ONLY) activate_awponly()
}

public task_restore_mode_after_map()
{
    set_pcvar_num(g_pending_restore_cvar, 0)

    if (mm_get_active_mode() == MM_MODE_AWP_ONLY)
    {
        activate_awponly()
        return
    }

    new MmRequestResult:result = mm_request_mode(MM_MODE_AWP_ONLY, 0)
    if (result != MM_REQUEST_ACCEPTED && result != MM_REQUEST_DUPLICATE)
    {
        log_amx("AWP Only could not be restored after map change (request result %d).", _:result)
    }
}

public player_killed_post(victim, attacker, should_gib)
{
    if (!awponly_active() || g_finished || g_selecting || !is_user_connected(victim)) return HAM_IGNORED

    remove_spawn_protection(victim)
    g_deaths[victim]++

    if (is_valid_enemy_kill(victim, attacker))
    {
        g_kills[attacker]++
        replenish_awp_ammunition(attacker)
        if (get_pcvar_num(g_kill_limit) > 0 && g_kills[attacker] >= get_pcvar_num(g_kill_limit)) mm_finish_match(attacker)
    }

    if (g_finished) return HAM_IGNORED
    remove_task(TASK_RESPAWN_BASE + victim)
    set_task(get_pcvar_float(g_respawn_delay_cvar), "task_respawn_player", TASK_RESPAWN_BASE + victim)
    return HAM_IGNORED
}

public task_respawn_player(task_id)
{
    new id = task_id - TASK_RESPAWN_BASE
    if (!awponly_active() || g_finished || !is_user_connected(id) || is_user_alive(id) || !is_playing_team(id)) return
    ExecuteHamB(Ham_CS_RoundRespawn, id)
}

public player_spawned_post(id)
{
    if (!awponly_active() || !is_user_alive(id) || !is_playing_team(id)) return HAM_IGNORED

    enable_spawn_protection(id)
    remove_task(TASK_LOADOUT_BASE + id)
    set_task(0.1, "task_apply_loadout", TASK_LOADOUT_BASE + id)
    return HAM_IGNORED
}

public task_apply_loadout(task_id)
{
    new id = task_id - TASK_LOADOUT_BASE
    if (!awponly_active() || !is_user_alive(id)) return
    apply_awp_loadout(id)
}

public forward_command_start(id, command_handle, random_seed)
{
    if (!awponly_active() || !g_protected[id] || !is_user_alive(id)) return FMRES_IGNORED

    new buttons = get_uc(command_handle, UC_Buttons)
    new item = get_member(id, m_pActiveItem)
    new weapon = is_nullent(item) ? CSW_NONE : get_member(item, m_iId)
    if ((buttons & IN_ATTACK) || (weapon == CSW_KNIFE && (buttons & IN_ATTACK2))) remove_spawn_protection(id)
    return FMRES_IGNORED
}

public task_remove_spawn_protection(task_id)
{
    remove_spawn_protection(task_id - TASK_PROTECTION_BASE)
}

public block_weapon_pickup(entity, id)
{
    if (!awponly_active() || id < 1 || id > MaxClients || !is_user_connected(id)) return HAM_IGNORED
    return HAM_SUPERCEDE
}

public command_block_inventory(id)
{
    if (!awponly_active()) return PLUGIN_CONTINUE
    client_print(id, print_center, "Only AWP and Knife are available in AWP Only")
    return PLUGIN_HANDLED
}

public command_status(id)
{
    if (!awponly_active()) return awponly_inactive_message(id)
    client_print_color(id, print_team_grey, "^4[Sniper Arena]^3 ^4%s^3 | %s | Kills ^4%d^3 / Deaths ^4%d^3 | First to ^4%d", g_sniper == CSW_AWP ? "AWP" : "Scout", get_pcvar_num(g_scoped) ? "Scoped shots only" : "No-scopes allowed", g_kills[id], g_deaths[id], get_pcvar_num(g_kill_limit))
    if (get_user_flags(id) & ADMIN_CFG)
    {
        new menu = menu_create("Sniper Arena Options", "mm_options_handler"), label[64]
        menu_additem(menu, "Start AWP / Scout vote", "vote")
        formatex(label, charsmax(label), "Scoped-only shots: %s (toggle)", get_pcvar_num(g_scoped) ? "ON" : "OFF")
        menu_additem(menu, label, "scope")
        menu_display(id, menu)
    }
    return PLUGIN_HANDLED
}

public command_leaderboard(id)
{
    if (!awponly_active()) return awponly_inactive_message(id)

    new leaders[32], count
    collect_sorted_players(leaders, count)
    client_print_color(id, print_team_grey, "^4[%s]^3 AWP Only leaderboard:", PROJECT_NAME)

    new limit = min(count, 5)
    for (new rank = 0; rank < limit; rank++)
    {
        new player = leaders[rank]
        client_print_color(id, player, "^4[AMXX]^1 #%d ^3%n^1 - %d kills / %d deaths", rank + 1, player, g_kills[player], g_deaths[player])
    }
    return PLUGIN_HANDLED
}

public task_update_hud()
{
    if (!awponly_active()) return

    new leader = find_leader()
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || is_user_bot(id)) continue

        set_hudmessage(80, 180, 255, 0.02, 0.18, 0, 0.0, 1.1, 0.0, 0.0)
        if (g_selecting) ShowSyncHudMsg(id, g_hud_sync, "SNIPER ARENA | AWP or Scout vote^nChoose in the vote menu | Match starts after selection")
        else if (leader)
        {
            ShowSyncHudMsg(id, g_hud_sync, "SNIPER ARENA | %s | First to %d^n%s | Kills %d | Deaths %d^nLeader %n (%d)", g_sniper == CSW_AWP ? "AWP" : "Scout", get_pcvar_num(g_kill_limit), get_pcvar_num(g_scoped) ? "SCOPED ONLY" : "No-scopes allowed", g_kills[id], g_deaths[id], leader, g_kills[leader])
        }
        else
        {
            ShowSyncHudMsg(id, g_hud_sync, "AWP Only | Kills: %d | Deaths: %d^nWaiting for players", g_kills[id], g_deaths[id])
        }
    }
}

activate_awponly()
{
    g_gameplay_enabled = true
    g_finished = false; g_selecting = false; g_choice_made = false; g_vote_attempts = 0; g_sniper = CSW_AWP
    reset_all_scores()

    if (queue_preferred_map_change())
    {
        log_amx("AWP Only map change queued; gameplay activation will resume on the target map.")
        return
    }
    new map[32], path[160]
    get_mapname(map, charsmax(map))
    formatex(path, charsmax(path), "addons/amxmodx/configs/mm_awponly/%s.cfg", map)
    if (file_exists(path)) {server_cmd("exec %s", path); server_exec();}

    remove_task(TASK_HUD)
    set_task(1.0, "task_update_hud", TASK_HUD, _, _, "b")
    remove_task(TASK_WEAPON_VOTE); remove_task(TASK_INVENTORY)
    set_task(2.0, "mm_begin_weapon_vote", TASK_WEAPON_VOTE)
    set_task(0.3, "mm_inventory", TASK_INVENTORY, _, _, "b")

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || !is_playing_team(id)) continue
        if (is_user_alive(id)) player_spawned_post(id)
        else
        {
            remove_task(TASK_RESPAWN_BASE + id)
            set_task(0.2, "task_respawn_player", TASK_RESPAWN_BASE + id)
        }
    }

    client_print_color(0, print_team_grey, "^4[Sniper Arena]^3 Free-for-all active. ^4AWP/Scout vote^3 starts shortly; ^1/awp^3 for rules.")
    log_amx("AWP Only activated; transient scores reset.")
}

disable_awponly()
{
    remove_task(TASK_WEAPON_VOTE); remove_task(TASK_MATCH_RESET); remove_task(TASK_INVENTORY)
    g_selecting = false; g_finished = false
    g_gameplay_enabled = false
    set_pcvar_num(g_pending_restore_cvar, 0)
    remove_task(TASK_HUD)
    remove_task(TASK_RESTORE_MODE)

    for (new id = 1; id <= MaxClients; id++)
    {
        clear_player_tasks(id)
        remove_spawn_protection(id)
    }

    reset_all_scores()
    server_cmd("exec server.cfg")
    server_exec()
    log_amx("AWP Only disabled; tasks, protection, scores, and baseline cvars restored.")
}

bool:queue_preferred_map_change()
{
    if (get_pcvar_num(g_change_map_cvar) == 0) return false

    new preferred_map[32], fallback_map[32], target_map[32], current_map[32]
    get_pcvar_string(g_preferred_map_cvar, preferred_map, charsmax(preferred_map))
    get_pcvar_string(g_fallback_map_cvar, fallback_map, charsmax(fallback_map))
    get_mapname(current_map, charsmax(current_map))

    // Respect an installed AWP map selected by the authoritative vote controller.
    if (equali(current_map, "awp_", 4) && is_installed_map(current_map)) return false

    if (is_installed_map(preferred_map)) copy(target_map, charsmax(target_map), preferred_map)
    else if (is_installed_map(fallback_map)) copy(target_map, charsmax(target_map), fallback_map)
    else
    {
        log_amx("AWP Only map selection skipped: neither '%s' nor '%s' has an installed BSP.", preferred_map, fallback_map)
        return false
    }

    if (equali(current_map, target_map)) return false

    set_pcvar_num(g_pending_restore_cvar, 1)
    server_cmd("changelevel %s", target_map)
    log_amx("AWP Only changing map from %s to %s.", current_map, target_map)
    return true
}

bool:is_installed_map(const map_name[])
{
    if (!is_safe_map_name(map_name)) return false

    new map_path[64]
    formatex(map_path, charsmax(map_path), "maps/%s.bsp", map_name)
    return bool:file_exists(map_path)
}

bool:is_safe_map_name(const map_name[])
{
    if (!map_name[0]) return false

    for (new index = 0; map_name[index]; index++)
    {
        new character = map_name[index]
        if ((character >= 'a' && character <= 'z') ||
            (character >= 'A' && character <= 'Z') ||
            (character >= '0' && character <= '9') ||
            character == '_' || character == '-') continue
        return false
    }
    return true
}

apply_awp_loadout(id)
{
    rg_remove_all_items(id, false)
    give_item(id, "weapon_knife")
    give_item(id, g_sniper == CSW_AWP ? "weapon_awp" : "weapon_scout")
    engclient_cmd(id, g_sniper == CSW_AWP ? "weapon_awp" : "weapon_scout")
    set_user_health(id, clamp(get_pcvar_num(g_spawn_health), 1, 200))
    cs_set_user_armor(id, clamp(get_pcvar_num(g_spawn_armor), 0, 100), get_pcvar_num(g_spawn_armor) ? CS_ARMOR_VESTHELM : CS_ARMOR_NONE)
    replenish_awp_ammunition(id)
}

replenish_awp_ammunition(id)
{
    if (!is_user_connected(id)) return
    new reserve_ammo = clamp(get_pcvar_num(g_sniper == CSW_AWP ? g_awp_ammo_cvar : g_scout_ammo), 10, 90)
    cs_set_user_bpammo(id, g_sniper, reserve_ammo)
}

enable_spawn_protection(id)
{
    remove_task(TASK_PROTECTION_BASE + id)
    g_protected[id] = true
    set_user_godmode(id, 1)

    new Float:duration = get_pcvar_float(g_spawn_protection_cvar)
    if (duration <= 0.0) remove_spawn_protection(id)
    else set_task(duration, "task_remove_spawn_protection", TASK_PROTECTION_BASE + id)
}

remove_spawn_protection(id)
{
    if (id < 1 || id > MaxClients) return
    remove_task(TASK_PROTECTION_BASE + id)
    g_protected[id] = false
    if (is_user_connected(id)) set_user_godmode(id, 0)
}

bool:is_valid_enemy_kill(victim, attacker)
{
    if (attacker < 1 || attacker > MaxClients || attacker == victim || !is_user_connected(attacker)) return false
    if (!is_playing_team(victim) || !is_playing_team(attacker)) return false
    return true
}

collect_sorted_players(output[32], &count)
{
    count = 0
    for (new id = 1; id <= MaxClients; id++)
    {
        if (is_playing_team(id) && !is_user_hltv(id)) output[count++] = id
    }

    for (new left = 0; left < count; left++)
    {
        for (new right = left + 1; right < count; right++)
        {
            if (is_better_score(output[right], output[left]))
            {
                new temporary = output[left]
                output[left] = output[right]
                output[right] = temporary
            }
        }
    }
}

find_leader()
{
    new leader
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_playing_team(id) || is_user_hltv(id)) continue
        if (!leader || is_better_score(id, leader)) leader = id
    }
    return leader
}

bool:is_better_score(candidate, current)
{
    if (g_kills[candidate] != g_kills[current]) return g_kills[candidate] > g_kills[current]
    return g_deaths[candidate] < g_deaths[current]
}

clear_player_tasks(id)
{
    remove_task(TASK_RESPAWN_BASE + id)
    remove_task(TASK_PROTECTION_BASE + id)
    remove_task(TASK_LOADOUT_BASE + id)
}

reset_player(id)
{
    g_kills[id] = 0
    g_deaths[id] = 0
    g_protected[id] = false
}

reset_all_scores()
{
    for (new id = 1; id <= MaxClients; id++)
    {
        g_kills[id] = 0
        g_deaths[id] = 0
    }
}

awponly_inactive_message(id)
{
    client_print_color(id, print_team_red, "^4[%s]^3 NOTICE^1 | AWP Only commands are disabled while another mode is active.", PROJECT_NAME)
    return PLUGIN_HANDLED
}

bool:is_playing_team(id)
{
    if (!is_user_connected(id)) return false
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

bool:awponly_active()
{
    return g_gameplay_enabled && mm_get_active_mode() == MM_MODE_AWP_ONLY
}

public mm_begin_weapon_vote()
{
    if (!awponly_active() || g_finished || g_selecting) return
    if (mm_voting_start_sniper_vote()) g_selecting = true
    else if (++g_vote_attempts < 6) set_task(5.0, "mm_begin_weapon_vote", TASK_WEAPON_VOTE)
}
public mm_sniper_selected(weapon)
{
    if (!awponly_active() || (weapon != CSW_AWP && weapon != CSW_SCOUT)) return
    g_sniper = weapon; g_selecting = false; g_choice_made = true
    reset_all_scores()
    for (new id = 1; id <= MaxClients; id++)
        if (is_user_alive(id) && is_playing_team(id)) apply_awp_loadout(id)
    client_print_color(0, print_team_grey, "^4[Sniper Arena]^3 This match uses ^4%s^3. ^4%s^3.", weapon == CSW_AWP ? "AWP" : "Scout", get_pcvar_num(g_scoped) ? "Scoped shots only" : "No-scopes allowed")
}
public mm_options_handler(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT || !awponly_active() || !is_user_connected(id) || !(get_user_flags(id) & ADMIN_CFG)) return PLUGIN_HANDLED
    if (!item) {g_vote_attempts = 0; mm_begin_weapon_vote();}
    else
    {
        set_pcvar_num(g_scoped, get_pcvar_num(g_scoped) ? 0 : 1)
        new file = fopen(MM_SNIPER_SETTINGS, "wt")
        if (file) {fprintf(file, "mm_awp_scoped_only %d^n", get_pcvar_num(g_scoped)); fclose(file);}
        client_print_color(0, print_team_grey, "^4[Sniper Arena]^3 Scoped-only shots: ^4%s^3.", get_pcvar_num(g_scoped) ? "ON" : "OFF")
    }
    return PLUGIN_HANDLED
}
public mm_scope_guard(item)
{
    if (!awponly_active()) return HAM_IGNORED
    new id = get_member(item, m_pPlayer)
    if (id < 1 || id > MaxClients || !is_user_alive(id)) return HAM_IGNORED
    if (g_selecting || g_finished) return HAM_SUPERCEDE
    if (get_pcvar_num(g_scoped) && (get_member(id, m_iFOV) >= 90 || get_member(id, m_iFOV) <= 0))
    {
        if (get_gametime() >= g_scope_notice[id])
        {
            client_print_color(id, print_team_grey, "^4[Sniper Arena]^3 Open your ^4scope^3 before firing. Scoped-only rules are active.")
            g_scope_notice[id] = get_gametime()+1.5
        }
        return HAM_SUPERCEDE
    }
    return HAM_IGNORED
}
public mm_match_damage(victim, inflictor, attacker, Float:damage, bits)
{
    return awponly_active() && (g_finished || g_selecting) ? HAM_SUPERCEDE : HAM_IGNORED
}
public mm_default_items(id) {return awponly_active() ? HC_SUPERCEDE : HC_CONTINUE;}
public mm_block_equipment(entity, caller, activator, use_type, Float:value) {return awponly_active() ? HAM_SUPERCEDE : HAM_IGNORED;}
public mm_buy_weapon(id, WeaponIdType:weapon)
{
    if (!awponly_active()) return HC_CONTINUE
    SetHookChainReturn(ATYPE_INTEGER, 0); return HC_SUPERCEDE
}
public mm_buy_ammo(id, item, bool:blink)
{
    if (!awponly_active()) return HC_CONTINUE
    SetHookChainReturn(ATYPE_BOOL, false); return HC_SUPERCEDE
}
public mm_buy_item(id, slot) {return awponly_active() ? HC_SUPERCEDE : HC_CONTINUE;}
public mm_inventory()
{
    if (!awponly_active() || g_finished) return
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id)) continue
        new weapons[32], count, name[32]
        get_user_weapons(id, weapons, count)
        for (new i = 0; i < count; i++)
            if (weapons[i] != CSW_KNIFE && weapons[i] != g_sniper && get_weaponname(weapons[i], name, charsmax(name))) rg_remove_item(id, name, true)
    }
}
mm_finish_match(winner)
{
    g_finished = true
    new leaders[32], count, detail[96]
    collect_sorted_players(leaders, count)
    formatex(detail, charsmax(detail), "%n wins with %d kills", winner, g_kills[winner])
    mm_show_results(MM_MODE_AWP_ONLY, winner, count > 1 ? leaders[1] : 0, count > 2 ? leaders[2] : 0, "SNIPER ARENA CHAMPION", detail)
    for (new id = 1; id <= MaxClients; id++) clear_player_tasks(id)
    set_task(6.0, "mm_restart_match", TASK_MATCH_RESET)
}
public mm_restart_match()
{
    if (!awponly_active()) return
    g_finished = false; g_choice_made = false; g_vote_attempts = 0
    reset_all_scores()
    for (new id = 1; id <= MaxClients; id++) if (is_user_connected(id) && is_playing_team(id)) ExecuteHamB(Ham_CS_RoundRespawn, id)
    set_task(1.0, "mm_begin_weapon_vote", TASK_WEAPON_VOTE)
}
public mm_status()
{
    server_print("[Sniper Arena] version=%s active=%d weapon=%s scoped_only=%d selecting=%d target=%d", PLUGIN_VERSION, awponly_active(), g_sniper == CSW_AWP ? "AWP" : "Scout", get_pcvar_num(g_scoped), g_selecting, get_pcvar_num(g_kill_limit))
}
public plugin_end()
{
    remove_task(TASK_HUD); remove_task(TASK_WEAPON_VOTE); remove_task(TASK_MATCH_RESET); remove_task(TASK_INVENTORY); remove_task(TASK_RESTORE_MODE)
    for (new id = 1; id <= MaxClients; id++) {clear_player_tasks(id); remove_spawn_protection(id);}
}
