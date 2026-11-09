#include <amxmodx>
#include <cstrike>
#include <nvault>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <reapi>
#include <mm_mode_api>
#include <mm_presentation_api>

#define PLUGIN_NAME    "Multi-Mode Network Deathmatch"
#define PLUGIN_VERSION "0.6.1"
#define PLUGIN_AUTHOR  "Multi-Mode Network"
#define PROJECT_NAME   "Multi-Mode Network"

#define TASK_RESPAWN_BASE    41000
#define TASK_PROTECTION_BASE 42000
#define TASK_LOADOUT_BASE    43000
#define TASK_PREFERENCES     44000
#define TASK_DM_HUD          45000
#define TASK_DM_RESET        45001

enum PrimaryWeapon
{
    PRIMARY_AK47 = 0,
    PRIMARY_M4A1,
    PRIMARY_AWP,
    PRIMARY_MP5,
    PRIMARY_M249,
    PRIMARY_COUNT
}

enum SecondaryWeapon
{
    SECONDARY_DEAGLE = 0,
    SECONDARY_USP,
    SECONDARY_GLOCK,
    SECONDARY_COUNT
}

new const PRIMARY_NAMES[PRIMARY_COUNT][] = { "AK-47", "M4A1", "AWP", "MP5 Navy", "M249" }
new const PRIMARY_ENTITIES[PRIMARY_COUNT][] = { "weapon_ak47", "weapon_m4a1", "weapon_awp", "weapon_mp5navy", "weapon_m249" }
new const PRIMARY_IDS[PRIMARY_COUNT] = { CSW_AK47, CSW_M4A1, CSW_AWP, CSW_MP5NAVY, CSW_M249 }
new const PRIMARY_AMMO[PRIMARY_COUNT] = { 90, 90, 30, 120, 200 }

new const SECONDARY_NAMES[SECONDARY_COUNT][] = { "Desert Eagle", "USP", "Glock 18" }
new const SECONDARY_ENTITIES[SECONDARY_COUNT][] = { "weapon_deagle", "weapon_usp", "weapon_glock18" }
new const SECONDARY_IDS[SECONDARY_COUNT] = { CSW_DEAGLE, CSW_USP, CSW_GLOCK18 }
new const SECONDARY_AMMO[SECONDARY_COUNT] = { 35, 100, 120 }

new PrimaryWeapon:g_primary[33]
new SecondaryWeapon:g_secondary[33]
new g_kills[33]
new g_deaths[33]
new bool:g_protected[33]
new g_spawn_protection_cvar
new g_vault = INVALID_HANDLE
new bool:g_preferences_loaded[33]
new g_respawn_delay_cvar
new g_identity[33][40], g_pref_attempts[33], bool:g_chosen[33]
new g_hud, g_kill_limit, bool:g_finished

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_forward(FM_AddToFullPack, "mm_protection_glow", 1)
    register_clcmd("say /dm", "command_weapon_menu")
    register_clcmd("say_team /dm", "command_weapon_menu")
    register_clcmd("say /reuse", "mm_reuse")
    register_clcmd("say_team /reuse", "mm_reuse")
    register_srvcmd("mm_deathmatch_status", "mm_status")
    register_clcmd("say /top", "command_top")
    register_clcmd("say_team /top", "command_top")

    RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "mm_death_weapon_drop", false)
    RegisterHam(Ham_Killed, "player", "player_killed_post", 1)
    RegisterHam(Ham_Spawn, "player", "player_spawned_post", 1)
    RegisterHam(Ham_TakeDamage, "player", "mm_finished_damage")
    register_forward(FM_CmdStart, "forward_command_start")

    g_spawn_protection_cvar = register_cvar("mm_dm_spawn_protection", "2.0")
    g_respawn_delay_cvar = register_cvar("mm_dm_respawn_delay", "1.0")
    g_kill_limit = register_cvar("mm_dm_kill_limit", "50")
    g_hud = CreateHudSyncObj()
    set_task(1.0, "mm_dm_hud", TASK_DM_HUD, _, _, "b")

    g_vault = nvault_open("mm_dm_loadouts")
    if (g_vault == INVALID_HANDLE) log_amx("Could not open loadout preferences vault.")
    for (new id = 1; id <= MaxClients; id++) reset_player(id)
    if (deathmatch_active()) activate_deathmatch()
    log_amx("%s Deathmatch v%s initialized.", PROJECT_NAME, PLUGIN_VERSION)
}

public client_connect(id)
{
    reset_player(id)
    g_preferences_loaded[id] = false
    g_identity[id][0] = 0; g_pref_attempts[id] = 0; g_chosen[id] = false
}
public client_putinserver(id)
{
    mm_load_preferences(id)
    if (!g_preferences_loaded[id]) set_task(1.0, "mm_retry_preferences", TASK_PREFERENCES+id)
}

public client_disconnected(id)
{
    if (g_preferences_loaded[id]) mm_save_preferences(id)
    remove_task(TASK_PREFERENCES+id)
    g_identity[id][0] = 0; g_preferences_loaded[id] = false
    clear_player_tasks(id)
    g_protected[id] = false
}

public mm_mode_transition_started(old_mode, requested_mode)
{
    if (MmMode:old_mode == MM_MODE_DEATHMATCH && MmMode:requested_mode != MM_MODE_DEATHMATCH)
    {
        disable_deathmatch()
    }
}

public mm_mode_changed(old_mode, new_mode)
{
    if (MmMode:new_mode == MM_MODE_DEATHMATCH)
    {
        activate_deathmatch()
    }
}

public player_killed_post(victim, attacker, should_gib)
{
    if (!deathmatch_active() || g_finished || !is_user_connected(victim)) return HAM_IGNORED

    remove_spawn_protection(victim)
    g_deaths[victim]++

    if (attacker >= 1 && attacker <= MaxClients && attacker != victim && is_user_connected(attacker))
    {
        g_kills[attacker]++
        replenish_ammunition(attacker)
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
    if (!deathmatch_active() || g_finished || !is_user_connected(id) || is_user_alive(id) || !is_playing_team(id)) return
    ExecuteHamB(Ham_CS_RoundRespawn, id)
}

public player_spawned_post(id)
{
    if (!deathmatch_active() || g_finished || !is_user_alive(id) || !is_playing_team(id)) return HAM_IGNORED

    enable_spawn_protection(id)
    remove_task(TASK_LOADOUT_BASE + id)
    set_task(0.1, "task_apply_loadout", TASK_LOADOUT_BASE + id)
    return HAM_IGNORED
}

public task_apply_loadout(task_id)
{
    new id = task_id - TASK_LOADOUT_BASE
    if (!deathmatch_active() || !is_user_alive(id)) return
    apply_loadout(id)
    cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM)
}

public forward_command_start(id, command_handle, random_seed)
{
    if (!deathmatch_active() || !g_protected[id] || !is_user_alive(id)) return FMRES_IGNORED

    new buttons = get_uc(command_handle, UC_Buttons)
    if (buttons & (IN_ATTACK | IN_ATTACK2)) remove_spawn_protection(id)
    return FMRES_IGNORED
}

public task_remove_spawn_protection(task_id)
{
    remove_spawn_protection(task_id - TASK_PROTECTION_BASE)
}

public command_weapon_menu(id)
{
    if (!deathmatch_active())
    {
        client_print_color(id, print_team_grey, "^4[%s]^3 /dm is available only in Deathmatch mode.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }
    if (!is_user_connected(id) || is_user_bot(id)) return PLUGIN_HANDLED

    new menu = menu_create("Deathmatch Loadout", "mm_loadout_menu")
    new label[128]
    formatex(label, charsmax(label), "Reuse saved: %s + %s", PRIMARY_NAMES[g_primary[id]], SECONDARY_NAMES[g_secondary[id]])
    menu_additem(menu, label, "reuse")
    menu_additem(menu, "Change weapons", "change")
    menu_display(id, menu)
    return PLUGIN_HANDLED
}
public mm_loadout_menu(id, menu, item)
{
    menu_destroy(menu)
    if (item == MENU_EXIT || !deathmatch_active() || !is_user_connected(id)) return PLUGIN_HANDLED
    if (!item) mm_reuse(id)
    else show_primary_menu(id)
    return PLUGIN_HANDLED
}
public mm_reuse(id)
{
    if (!deathmatch_active() || !is_user_connected(id) || g_finished) return PLUGIN_HANDLED
    if (is_user_alive(id)) apply_loadout(id)
    client_print_color(id, print_team_grey, "^4[Deathmatch]^3 Saved loadout: ^4%s + %s^3. It is remembered when you reconnect.", PRIMARY_NAMES[g_primary[id]], SECONDARY_NAMES[g_secondary[id]])
    return PLUGIN_HANDLED
}

show_primary_menu(id)
{
    new menu = menu_create("Deathmatch: Primary Weapon", "primary_menu_handler")
    new item_info[4]
    for (new PrimaryWeapon:weapon = PRIMARY_AK47; weapon < PRIMARY_COUNT; weapon++)
    {
        num_to_str(_:weapon, item_info, charsmax(item_info))
        menu_additem(menu, PRIMARY_NAMES[weapon], item_info)
    }
    menu_display(id, menu)
}

public primary_menu_handler(id, menu, item)
{
    if (item == MENU_EXIT || !deathmatch_active())
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new item_info[4], access, callback
    menu_item_getinfo(menu, item, access, item_info, charsmax(item_info), _, _, callback)
    g_primary[id] = PrimaryWeapon:str_to_num(item_info)
    g_chosen[id] = true
    mm_save_preferences(id)
    menu_destroy(menu)
    show_secondary_menu(id)
    return PLUGIN_HANDLED
}

show_secondary_menu(id)
{
    new menu = menu_create("Deathmatch: Secondary Weapon", "secondary_menu_handler")
    new item_info[4]
    for (new SecondaryWeapon:weapon = SECONDARY_DEAGLE; weapon < SECONDARY_COUNT; weapon++)
    {
        num_to_str(_:weapon, item_info, charsmax(item_info))
        menu_additem(menu, SECONDARY_NAMES[weapon], item_info)
    }
    menu_display(id, menu)
}

public secondary_menu_handler(id, menu, item)
{
    if (item == MENU_EXIT || !deathmatch_active())
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new item_info[4], access, callback
    menu_item_getinfo(menu, item, access, item_info, charsmax(item_info), _, _, callback)
    g_secondary[id] = SecondaryWeapon:str_to_num(item_info)
    g_chosen[id] = true
    menu_destroy(menu)

    mm_save_preferences(id)
    client_print_color(id, print_team_grey, "^4[%s]^3 Loadout selected: %s + %s.", PROJECT_NAME, PRIMARY_NAMES[g_primary[id]], SECONDARY_NAMES[g_secondary[id]])
    if (is_user_alive(id)) apply_loadout(id)
    return PLUGIN_HANDLED
}

public command_top(id)
{
    if (mm_get_active_mode() == MM_MODE_HE_BATTLE) return PLUGIN_CONTINUE
    if (!deathmatch_active())
    {
        client_print_color(id, print_team_grey, "^4[%s]^3 /top is available only in Deathmatch mode.", PROJECT_NAME)
        return PLUGIN_HANDLED
    }

    new leaders[32], count
    for (new player = 1; player <= MaxClients; player++)
    {
        if (is_user_connected(player) && !is_user_hltv(player)) leaders[count++] = player
    }

    for (new left = 0; left < count; left++)
    {
        for (new right = left + 1; right < count; right++)
        {
            if (is_better_score(leaders[right], leaders[left]))
            {
                new temporary = leaders[left]
                leaders[left] = leaders[right]
                leaders[right] = temporary
            }
        }
    }

    client_print_color(id, print_team_grey, "^4[%s]^3 Deathmatch leaderboard:", PROJECT_NAME)
    new limit = min(count, 5)
    for (new rank = 0; rank < limit; rank++)
    {
        new player = leaders[rank]
        client_print_color(id, player, "^4[AMXX]^1 #%d ^3%n^1 - %d kills / %d deaths", rank + 1, player, g_kills[player], g_deaths[player])
    }
    return PLUGIN_HANDLED
}

activate_deathmatch()
{
    g_finished = false
    remove_task(TASK_DM_RESET)
    reset_all_scores()
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
    client_print_color(0, print_team_grey, "^4[%s]^3 Free-for-all Deathmatch active. Use /dm for weapons and /top for scores.", PROJECT_NAME)
    log_amx("Deathmatch activated; transient scores reset.")
}

disable_deathmatch()
{
    remove_task(TASK_DM_RESET)
    g_finished = false
    for (new id = 1; id <= MaxClients; id++)
    {
        clear_player_tasks(id)
        remove_spawn_protection(id)
    }
    reset_all_scores()
    server_cmd("exec server.cfg")
    server_exec()
    log_amx("Deathmatch disabled; tasks, protection, scores, and baseline cvars restored.")
}

apply_loadout(id)
{
    new CsArmorType:armor_type
    new armor = cs_get_user_armor(id, armor_type)
    rg_remove_all_items(id, false)
    cs_set_user_armor(id, armor, armor_type)
    give_item(id, "weapon_knife")
    give_item(id, PRIMARY_ENTITIES[g_primary[id]])
    give_item(id, SECONDARY_ENTITIES[g_secondary[id]])
    replenish_ammunition(id)
}

replenish_ammunition(id)
{
    if (!is_user_connected(id)) return
    cs_set_user_bpammo(id, PRIMARY_IDS[g_primary[id]], PRIMARY_AMMO[g_primary[id]])
    cs_set_user_bpammo(id, SECONDARY_IDS[g_secondary[id]], SECONDARY_AMMO[g_secondary[id]])
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

clear_player_tasks(id)
{
    remove_task(TASK_RESPAWN_BASE + id)
    remove_task(TASK_PROTECTION_BASE + id)
    remove_task(TASK_LOADOUT_BASE + id)
}

reset_player(id)
{
    g_primary[id] = PRIMARY_AK47
    g_secondary[id] = SECONDARY_DEAGLE
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

bool:is_better_score(candidate, current)
{
    if (g_kills[candidate] != g_kills[current]) return g_kills[candidate] > g_kills[current]
    return g_deaths[candidate] < g_deaths[current]
}

bool:is_playing_team(id)
{
    if (!is_user_connected(id)) return false
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

bool:deathmatch_active()
{
    return mm_get_active_mode() == MM_MODE_DEATHMATCH
}

public client_authorized(id, const authid[])
{
    if (mm_stable_identity(authid)) copy(g_identity[id], charsmax(g_identity[]), authid)
    mm_load_preferences(id)
}

bool:mm_stable_identity(const authid[])
{
    return (contain(authid, "STEAM_") == 0 || contain(authid, "VALVE_") == 0) && contain(authid, "LAN") == -1 && contain(authid, "PENDING") == -1 && !equal(authid, "STEAM_ID_STOP_IGNORING_RETVALS")
}
public mm_retry_preferences(task)
{
    new id = task-TASK_PREFERENCES
    if (!is_user_connected(id) || g_preferences_loaded[id]) return
    mm_load_preferences(id)
    if (!g_preferences_loaded[id] && ++g_pref_attempts[id] < 20) set_task(1.0, "mm_retry_preferences", task)
}

bool:mm_preference_key(id, key[], length)
{
    if (g_identity[id][0]) {copy(key, length, g_identity[id]); return true;}
    get_user_authid(id, key, length)
    if (!is_user_bot(id) && mm_stable_identity(key)) {copy(g_identity[id], charsmax(g_identity[]), key); return true;}
    return false
}

mm_load_preferences(id)
{
    if (g_vault == INVALID_HANDLE || g_preferences_loaded[id]) return
    new key[40], value[32], primary[8], secondary[8]
    if (!mm_preference_key(id, key, charsmax(key))) return
    g_preferences_loaded[id] = true
    if (g_chosen[id]) {mm_save_preferences(id); return;}
    if (!nvault_get(g_vault, key, value, charsmax(value))) return
    if (parse(value, primary, charsmax(primary), secondary, charsmax(secondary)) != 2) return
    g_primary[id] = PrimaryWeapon:clamp(str_to_num(primary), 0, _:PRIMARY_COUNT - 1)
    g_secondary[id] = SecondaryWeapon:clamp(str_to_num(secondary), 0, _:SECONDARY_COUNT - 1)
    if (deathmatch_active() && is_user_alive(id) && !g_finished) apply_loadout(id)
}

mm_save_preferences(id)
{
    if (g_vault == INVALID_HANDLE) return
    new key[40], value[32]
    if (!mm_preference_key(id, key, charsmax(key))) return
    formatex(value, charsmax(value), "%d %d", g_primary[id], g_secondary[id])
    nvault_set(g_vault, key, value)
}

public plugin_end()
{
    remove_task(TASK_DM_HUD); remove_task(TASK_DM_RESET)
    for (new id = 1; id <= MaxClients; id++) remove_task(TASK_PREFERENCES+id)
    for (new id = 1; id <= MaxClients; id++)
        if (g_protected[id]) remove_spawn_protection(id)
    if (g_vault != INVALID_HANDLE) nvault_close(g_vault)
}

public mm_finished_damage(victim, inflictor, attacker, Float:damage, bits)
{
    return deathmatch_active() && g_finished ? HAM_SUPERCEDE : HAM_IGNORED
}
mm_finish_match(winner)
{
    g_finished = true
    new leaders[32], count, detail[96]
    mm_rank_scores(g_kills, g_deaths, leaders, count)
    formatex(detail, charsmax(detail), "%n wins with %d kills", winner, g_kills[winner])
    mm_show_results(MM_MODE_DEATHMATCH, count ? leaders[0] : 0, count > 1 ? leaders[1] : 0, count > 2 ? leaders[2] : 0, "DEATHMATCH CHAMPION", detail)
    for (new id = 1; id <= MaxClients; id++) clear_player_tasks(id)
    set_task(6.0, "mm_restart_match", TASK_DM_RESET)
}
public mm_restart_match()
{
    if (!deathmatch_active()) return
    g_finished = false
    reset_all_scores()
    for (new id = 1; id <= MaxClients; id++) if (is_user_connected(id) && is_playing_team(id)) ExecuteHamB(Ham_CS_RoundRespawn, id)
}
public mm_dm_hud()
{
    if (!deathmatch_active()) return
    new leaders[32], count
    mm_rank_scores(g_kills, g_deaths, leaders, count)
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || is_user_bot(id)) continue
        set_hudmessage(80, 220, 140, 0.02, 0.18, 0, 0.0, 1.1, 0.0, 0.0)
        if (count) ShowSyncHudMsg(id, g_hud, "DEATHMATCH | First to %d | FFA^nKills %d | Deaths %d | Leader %n (%d)^n/dm weapons | /reuse saved loadout", get_pcvar_num(g_kill_limit), g_kills[id], g_deaths[id], leaders[0], g_kills[leaders[0]])
    }
}
public mm_status()
{
    server_print("[Deathmatch] version=%s active=%d target=%d finished=%d", PLUGIN_VERSION, deathmatch_active(), get_pcvar_num(g_kill_limit), g_finished)
    for (new id = 1; id <= MaxClients; id++) if (is_user_connected(id)) server_print("[Deathmatch] client=%d saved_ready=%d primary=%s secondary=%s", id, g_preferences_loaded[id], PRIMARY_NAMES[g_primary[id]], SECONDARY_NAMES[g_secondary[id]])
}

// Packet-only effect: protection ending restores the normal model automatically.
public mm_protection_glow(packet, e, entity, host, host_flags, player, pset)
{
    if (!player || entity < 1 || entity > MaxClients || !is_user_alive(entity)) return FMRES_IGNORED
    if (deathmatch_active() && g_protected[entity])
    {
        set_es(packet, ES_RenderFx, kRenderFxGlowShell)
        set_es(packet, ES_RenderColor, {80, 220, 120})
        set_es(packet, ES_RenderAmt, 8)
        set_es(packet, ES_RenderMode, kRenderNormal)
    }
    return FMRES_IGNORED
}

public mm_death_weapon_drop(id)
{
    if (!deathmatch_active()) return HC_CONTINUE
    SetHookChainReturn(ATYPE_INTEGER, GR_PLR_DROP_GUN_NO)
    return HC_SUPERCEDE
}
