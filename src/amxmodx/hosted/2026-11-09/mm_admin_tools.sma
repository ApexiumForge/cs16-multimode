#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <nvault>

new const PLUGIN_NAME[] = "Multi-Mode Admin Tools"
new const PLUGIN_VERSION[] = "1.1.7"
new const PLUGIN_AUTHOR[] = "Torbeshi"
const GAG_ACCESS = ADMIN_KICK
const FUN_ACCESS = ADMIN_SLAY
const TASK_UBERSLAP = 905200
const TASK_TRAIL_MOTION = 905300
const UBERSLAP_HITS = 99
enum { ACTION_GAG, ACTION_UNGAG, ACTION_GLOW, ACTION_TRAIL }
new const COLOR_NAMES[][] = {"off", "red", "blue", "green", "yellow", "purple", "cyan", "white", "orange"}
new const COLORS[][3] = {{0,0,0}, {255,32,32}, {32,96,255}, {32,255,64}, {255,220,32}, {200,32,255}, {32,255,255}, {255,255,255}, {255,128,32}}
new const GAG_MINUTES[] = {5, 10, 30, 60, 0}
new g_gag_until[33], g_reason[33][96], g_key[33][64]
new g_glow[33], g_trail[33], g_sprite, g_vault
new bool:g_godmode[33]
new Float:g_trail_origin[33][3], bool:g_trail_sampled[33]

public plugin_precache()
{
    g_sprite = precache_model("sprites/laserbeam.spr")
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_concmd("amx_gag", "command_gag", GAG_ACCESS, "<player> [minutes=10, 0=permanent] [reason]")
    register_concmd("amx_ungag", "command_ungag", GAG_ACCESS, "<player>")
    register_concmd("amx_gagmenu", "command_menu", GAG_ACCESS, "- gag a player")
    register_concmd("amx_ungagmenu", "command_menu", GAG_ACCESS, "- ungag a player")
    register_concmd("amx_glow", "command_effect", FUN_ACCESS, "<player> <off|red|blue|green|yellow|purple|cyan|white|orange>")
    register_concmd("amx_trail", "command_effect", FUN_ACCESS, "<player> <off|red|blue|green|yellow|purple|cyan|white|orange>")
    register_concmd("amx_glowmenu", "command_menu", FUN_ACCESS, "- choose a player and glow")
    register_concmd("amx_trailmenu", "command_menu", FUN_ACCESS, "- choose a player and trail")
    register_concmd("amx_disarm", "command_disarm", FUN_ACCESS, "<player> - remove weapons and give a knife")
    register_concmd("amx_givemoney", "command_money", FUN_ACCESS, "<player> <amount> - add money")
    register_concmd("amx_giveweapon", "command_weapon", FUN_ACCESS, "<player> <weapon name, e.g. ak47>")
    register_concmd("amx_heal", "command_heal", FUN_ACCESS, "<player> - restore health to at least 100")
    register_concmd("amx_uberslap", "command_uberslap", FUN_ACCESS, "<player> - 99 slaps, minimum 1 HP")
    register_concmd("amx_godmode", "command_godmode", FUN_ACCESS, "<player> [on|off] - toggle damage immunity")
    register_srvcmd("mm_admin_tools_status", "tools_status")
    register_clcmd("amx_say", "say_chat_command", ADMIN_CHAT)
    register_concmd("amx_psay", "private_message", ADMIN_CHAT, "<name or #userid> <message>")
    register_clcmd("say", "block_chat")
    register_clcmd("say_team", "block_chat")
    register_clcmd("say_team", "say_to_admins")
    register_forward(FM_Voice_SetClientListening, "block_voice")
    register_forward(FM_AddToFullPack, "fullpack_post", true)
    RegisterHam(Ham_Spawn, "player", "spawn_post", true)
    RegisterHam(Ham_Killed, "player", "killed_post", true)
    RegisterHam(Ham_TakeDamage, "player", "damage_pre")
    set_task(0.15, "track_trail_motion", TASK_TRAIL_MOTION, _, _, "b")
    g_vault = nvault_open("mm_admin_gags")
    if (g_vault == INVALID_HANDLE) set_fail_state("Cannot open admin gag storage")
    log_amx("%s v%s initialized.", PLUGIN_NAME, PLUGIN_VERSION)
}

public say_to_admins(id)
{
    new marker[2]
    read_argv(1, marker, charsmax(marker))
    if (marker[0] != '@') return PLUGIN_CONTINUE

    new message[192], name[32], authid[32], players[32], count
    read_args(message, charsmax(message))
    remove_quotes(message)
    trim(message[1])
    if (!message[1]) return PLUGIN_HANDLED

    get_user_name(id, name, charsmax(name))
    get_user_authid(id, authid, charsmax(authid))
    log_amx("Chat: ^"%s<%d><%s><>^" chat ^"%s^"", name, get_user_userid(id), authid, message[1])
    log_message("^"%s<%d><%s><>^" triggered ^"amx_chat^" (text ^"%s^")", name, get_user_userid(id), authid, message[1])
    get_players(players, count, "ch")
    for (new i = 0; i < count; i++)
    {
        new viewer = players[i]
        if (viewer == id || (get_user_flags(viewer) & ADMIN_CHAT))
            client_print_color(viewer, print_team_grey, "^1[^4To Admins^1] ^4%s:^3 %s", name, message[1])
    }
    return PLUGIN_HANDLED
}

public client_authorized(id, const authid[])
{
    if (is_user_bot(id) || is_user_hltv(id)) return
    if (equal(authid, "STEAM_ID_LAN") || equal(authid, "VALVE_ID_LAN") || equal(authid, "STEAM_ID_PENDING"))
        get_user_ip(id, g_key[id], charsmax(g_key[]), true)
    else copy(g_key[id], charsmax(g_key[]), authid)
    new record[128], expiry[16]
    if (nvault_get(g_vault, g_key[id], record, charsmax(record)))
    {
        strtok(record, expiry, charsmax(expiry), g_reason[id], charsmax(g_reason[]), '|')
        g_gag_until[id] = str_to_num(expiry)
        is_gagged(id)
    }
}

bool:is_gagged(id)
{
    if (!g_gag_until[id]) return false
    if (g_gag_until[id] > 0 && g_gag_until[id] <= get_systime())
    {
        g_gag_until[id] = 0
        nvault_remove(g_vault, g_key[id])
        return false
    }
    return true
}

public block_chat(id)
{
    if (!is_gagged(id)) return PLUGIN_CONTINUE
    client_print_color(id, print_team_red, "^4[^1AMXX^4]^1 You are ^3gagged^1. Reason: ^4%s", g_reason[id])
    return PLUGIN_HANDLED
}

public say_chat_command(id, level, cid)
{
    new message[192]
    read_args(message, charsmax(message))
    remove_quotes(message)
    trim(message)
    if (message[0] != '/' || !message[1] || message[1] == ' ') return PLUGIN_CONTINUE
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED

    amxclient_cmd(id, "say", message)
    return PLUGIN_HANDLED
}

public private_message(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED

    new args[192], name[32], sender[32], authid[32], target_authid[32]
    read_args(args, charsmax(args))
    new offset = argparse(args, 0, name, charsmax(name))
    if (offset < 0) return PLUGIN_HANDLED
    trim(args[offset])
    remove_quotes(args[offset])
    if (!args[offset]) return PLUGIN_HANDLED

    new target = cmd_target(id, name, 0)
    if (!target) return PLUGIN_HANDLED
    get_user_name(target, name, charsmax(name))
    get_user_authid(target, target_authid, charsmax(target_authid))
    if (id)
    {
        get_user_name(id, sender, charsmax(sender))
        get_user_authid(id, authid, charsmax(authid))
    }
    else copy(sender, charsmax(sender), "SERVER")

    client_print_color(target, print_team_grey, "^4pm from %s:^3 %s", sender, args[offset])
    if (id && id != target)
        client_print_color(id, print_team_grey, "^4pm to %s:^3 %s", name, args[offset])
    console_print(id, "pm to %s: %s", name, args[offset])

    new sender_userid = id ? get_user_userid(id) : 0, target_userid = get_user_userid(target)
    log_amx("Chat: ^"%s<%d><%s><>^" psay ^"%s<%d><%s><>^" ^"%s^"", sender, sender_userid, authid, name, target_userid, target_authid, args[offset])
    log_message("^"%s<%d><%s><>^" triggered ^"amx_psay^" against ^"%s<%d><%s><>^" (text ^"%s^")", sender, sender_userid, authid, name, target_userid, target_authid, args[offset])
    return PLUGIN_HANDLED
}

public block_voice(receiver, sender, bool:listen)
{
    if (sender < 1 || sender > MaxClients || !is_gagged(sender)) return FMRES_IGNORED
    engfunc(EngFunc_SetClientListening, receiver, sender, false)
    return FMRES_SUPERCEDE
}

target_from_argument(id)
{
    new argument[32]
    read_argv(1, argument, charsmax(argument))
    return cmd_target(id, argument, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_ALLOW_SELF)
}

public command_gag(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new target = target_from_argument(id)
    if (!target || is_user_bot(target)) return PLUGIN_HANDLED
    new value[16], minutes = 10, reason[96]
    if (read_argc() > 2)
    {
        read_argv(2, value, charsmax(value))
        if (!is_str_num(value) || strlen(value) > 6 || str_to_num(value) > 525600)
        {
            console_print(id, "[AMXX] Minutes must be between 0 and 525600.")
            return PLUGIN_HANDLED
        }
        minutes = str_to_num(value)
    }
    for (new arg = 3; arg < read_argc(); arg++)
    {
        new word[96]
        read_argv(arg, word, charsmax(word))
        if (reason[0]) add(reason, charsmax(reason), " ")
        add(reason, charsmax(reason), word)
    }
    if (!reason[0]) copy(reason, charsmax(reason), "Chat / voice abuse")
    apply_gag(id, target, minutes, reason)
    return PLUGIN_HANDLED
}

apply_gag(id, target, minutes, const reason[])
{
    g_gag_until[target] = minutes ? get_systime() + minutes * 60 : -1
    copy(g_reason[target], charsmax(g_reason[]), reason)
    new record[128]
    formatex(record, charsmax(record), "%d|%s", g_gag_until[target], reason)
    if (g_key[target][0]) nvault_set(g_vault, g_key[target], record)
    announce(id, target, "gagged")
    if (minutes) client_print_color(0, print_team_default, "^4[^1AMXX^4]^1 Duration: ^4%d minutes^1. Reason: ^3%s", minutes, reason)
    else client_print_color(0, print_team_default, "^4[^1AMXX^4]^1 Duration: ^4permanent^1. Reason: ^3%s", reason)
}

public command_ungag(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new target = target_from_argument(id)
    if (target) ungag(id, target)
    return PLUGIN_HANDLED
}

ungag(id, target)
{
    g_gag_until[target] = 0
    if (g_key[target][0]) nvault_remove(g_vault, g_key[target])
    announce(id, target, "ungagged")
}

public command_effect(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
    new target = target_from_argument(id), command[24], color[24], choice = -1
    if (!target) return PLUGIN_HANDLED
    read_argv(0, command, charsmax(command))
    read_argv(2, color, charsmax(color))
    for (new i = 0; i < sizeof COLOR_NAMES; i++)
        if (equali(color, COLOR_NAMES[i])) choice = i
    if (choice < 0) console_print(id, "[AMXX] Colors: off, red, blue, green, yellow, purple, cyan, white, orange.")
    else apply_effect(id, target, equali(command, "amx_glow") ? ACTION_GLOW : ACTION_TRAIL, choice)
    return PLUGIN_HANDLED
}

public command_menu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    if (!id) { console_print(id, "[AMXX] Open this menu from the game."); return PLUGIN_HANDLED; }
    new command[24], action
    read_argv(0, command, charsmax(command))
    if (equali(command, "amx_ungagmenu")) action = ACTION_UNGAG
    else if (equali(command, "amx_glowmenu")) action = ACTION_GLOW
    else if (equali(command, "amx_trailmenu")) action = ACTION_TRAIL
    new title[64]
    formatex(title, charsmax(title), "\yAdmin Tools\w^n%s - Choose player", command)
    new menu = menu_create(title, "player_selected")
    for (new target = 1; target <= MaxClients; target++)
    {
        if (!is_user_connected(target) || is_user_hltv(target) || is_user_bot(target)) continue
        if (target != id && (get_user_flags(target) & ADMIN_IMMUNITY)) continue
        if (action == ACTION_UNGAG && !is_gagged(target)) continue
        new name[32], data[32]
        get_user_name(target, name, charsmax(name))
        formatex(data, charsmax(data), "%d %d", action, get_user_userid(target))
        menu_additem(menu, name, data)
    }
    if (!menu_items(menu))
    {
        menu_destroy(menu)
        client_print_color(id, print_team_default, "^4[^1AMXX^4]^1 No eligible players.")
        return PLUGIN_HANDLED
    }
    menu_display(id, menu)
    return PLUGIN_HANDLED
}

public player_selected(id, menu, item)
{
    if (item < 0) { menu_destroy(menu); return PLUGIN_HANDLED; }
    new access, data[32], label[64], callback, action_text[4], userid[16]
    menu_item_getinfo(menu, item, access, data, charsmax(data), label, charsmax(label), callback)
    menu_destroy(menu)
    parse(data, action_text, charsmax(action_text), userid, charsmax(userid))
    new action = str_to_num(action_text), target = menu_target(id, action, userid)
    if (!target) return PLUGIN_HANDLED
    if (action == ACTION_UNGAG) { ungag(id, target); return PLUGIN_HANDLED; }
    new title[80]
    formatex(title, charsmax(title), "\y%s\w^nChoose %s", label, action == ACTION_GAG ? "gag duration" : "color")
    menu = menu_create(title, "option_selected")
    new count = action == ACTION_GAG ? sizeof GAG_MINUTES : sizeof COLOR_NAMES
    for (new choice = 0; choice < count; choice++)
    {
        formatex(data, charsmax(data), "%d %s %d", action, userid, choice)
        if (action == ACTION_GAG)
        {
            if (GAG_MINUTES[choice]) formatex(label, charsmax(label), "%d minutes", GAG_MINUTES[choice])
            else copy(label, charsmax(label), "Permanent")
        }
        else copy(label, charsmax(label), COLOR_NAMES[choice])
        menu_additem(menu, label, data)
    }
    menu_display(id, menu)
    return PLUGIN_HANDLED
}

menu_target(id, action, const userid[])
{
    new access = action <= ACTION_UNGAG ? GAG_ACCESS : FUN_ACCESS
    if (!is_user_connected(id) || !(get_user_flags(id) & access)) return 0
    new argument[20]
    formatex(argument, charsmax(argument), "#%s", userid)
    return cmd_target(id, argument, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_ALLOW_SELF)
}

public option_selected(id, menu, item)
{
    if (item < 0) { menu_destroy(menu); return PLUGIN_HANDLED; }
    new access, data[32], label[64], callback, action_text[4], userid[16], option[4]
    menu_item_getinfo(menu, item, access, data, charsmax(data), label, charsmax(label), callback)
    menu_destroy(menu)
    parse(data, action_text, charsmax(action_text), userid, charsmax(userid), option, charsmax(option))
    new action = str_to_num(action_text), choice = str_to_num(option), target = menu_target(id, action, userid)
    if (!target) return PLUGIN_HANDLED
    if (action == ACTION_GAG) apply_gag(id, target, GAG_MINUTES[choice], "Chat / voice abuse")
    else apply_effect(id, target, action, choice)
    return PLUGIN_HANDLED
}

apply_effect(id, target, action, choice)
{
    if (action == ACTION_GLOW) g_glow[target] = choice
    else
    {
        g_trail[target] = choice
        g_trail_sampled[target] = false
    }
    new description[64]
    formatex(description, charsmax(description), "set %s %s for", action == ACTION_GLOW ? "glow" : "trail", COLOR_NAMES[choice])
    announce(id, target, description)
}

public fullpack_post(es, e, entity, host, flags, player, pset)
{
    if (!player || !g_glow[entity] || !is_user_alive(entity) || !get_orig_retval()) return FMRES_IGNORED
    // Keep mode-owned invisibility intact.
    if (get_es(es, ES_RenderMode) != kRenderNormal && get_es(es, ES_RenderAmt) == 0) return FMRES_IGNORED
    set_es(es, ES_RenderFx, kRenderFxGlowShell)
    set_es(es, ES_RenderColor, COLORS[g_glow[entity]])
    if (get_es(es, ES_RenderMode) == kRenderNormal) set_es(es, ES_RenderAmt, 16)
    return FMRES_IGNORED
}

public spawn_post(id)
{
    g_trail_sampled[id] = false
}

public track_trail_motion()
{
    new Float:origin[3]
    for (new id = 1; id <= MaxClients; id++)
    {
        new color = g_trail[id]
        if (!color || !is_user_alive(id)) continue

        pev(id, pev_origin, origin)
        origin[2] -= 12.0
        if (g_trail_sampled[id])
        {
            new Float:distance = get_distance_f(origin, g_trail_origin[id])
            if (distance < 2.0) continue
            // Skip long gaps, such as a map teleport.
            if (distance <= 512.0) draw_trail_segment(g_trail_origin[id], origin, color)
        }
        for (new axis = 0; axis < sizeof origin; axis++) g_trail_origin[id][axis] = origin[axis]
        g_trail_sampled[id] = true
    }
}

draw_trail_segment(const Float:start[3], const Float:finish[3], color)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, finish, 0)
    write_byte(TE_BEAMPOINTS)
    for (new axis = 0; axis < 3; axis++) engfunc(EngFunc_WriteCoord, start[axis])
    for (new axis = 0; axis < 3; axis++) engfunc(EngFunc_WriteCoord, finish[axis])
    write_short(g_sprite)
    write_byte(0)   // Start frame
    write_byte(0)   // Frame rate
    write_byte(8)   // Life in tenths of a second
    write_byte(25)  // Width
    write_byte(0)   // Noise
    write_byte(COLORS[color][0])
    write_byte(COLORS[color][1])
    write_byte(COLORS[color][2])
    write_byte(180)
    write_byte(0)   // Scroll speed
    message_end()
}

public killed_post(id)
{
    remove_task(TASK_UBERSLAP + id)
    g_trail_sampled[id] = false
}

public mm_mode_transition_started(old_mode, new_mode)
{
    for (new id = 1; id <= MaxClients; id++)
    {
        g_godmode[id] = false
        remove_task(TASK_UBERSLAP + id)
        g_glow[id] = 0
        g_trail[id] = 0
        g_trail_sampled[id] = false
    }
}

public command_disarm(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new target = target_from_argument(id)
    if (!target || !is_user_alive(target)) return PLUGIN_HANDLED
    rg_remove_all_items(target)
    rg_give_item(target, "weapon_knife")
    announce(id, target, "disarmed")
    return PLUGIN_HANDLED
}

public command_money(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
    new target = target_from_argument(id), value[16]
    if (!target) return PLUGIN_HANDLED
    read_argv(2, value, charsmax(value))
    if (!is_str_num(value) || strlen(value) > 5 || str_to_num(value) < 1 || str_to_num(value) > 16000)
    {
        console_print(id, "[AMXX] Amount must be between 1 and 16000.")
        return PLUGIN_HANDLED
    }
    rg_add_account(target, str_to_num(value), AS_ADD)
    new description[64]
    formatex(description, charsmax(description), "gave $%d to", str_to_num(value))
    announce(id, target, description)
    return PLUGIN_HANDLED
}

public command_weapon(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
    new target = target_from_argument(id), input[32], weapon[32]
    if (!target || !is_user_alive(target)) return PLUGIN_HANDLED
    read_argv(2, input, charsmax(input))
    strtolower(input)
    if (equal(input, "weapon_", 7)) copy(weapon, charsmax(weapon), input)
    else formatex(weapon, charsmax(weapon), "weapon_%s", input)
    new weaponid = get_weaponid(weapon)
    if (!weaponid || weaponid == CSW_C4)
    {
        console_print(id, "[AMXX] Use a CS weapon name such as ak47, m4a1, awp, usp, or hegrenade.")
        return PLUGIN_HANDLED
    }
    new entity = rg_find_weapon_bpack_by_name(target, weapon)
    if (entity <= 0) entity = rg_give_item(target, weapon, GT_APPEND)
    if (entity <= 0) { console_print(id, "[AMXX] Could not give that weapon."); return PLUGIN_HANDLED; }
    new clip = rg_get_weapon_info(weaponid, WI_GUN_CLIP_SIZE)
    if (clip > 0)
    {
        rg_set_user_ammo(target, WeaponIdType:weaponid, clip)
        new reserve = rg_get_weapon_info(weaponid, WI_MAX_ROUNDS)
        if (reserve > 0) rg_set_user_bpammo(target, WeaponIdType:weaponid, reserve)
    }
    new description[64]
    formatex(description, charsmax(description), "gave %s to", weapon)
    announce(id, target, description)
    return PLUGIN_HANDLED
}

public command_heal(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new target = target_from_argument(id)
    if (!target || !is_user_alive(target)) return PLUGIN_HANDLED
    new Float:health = Float:get_entvar(target, var_health)
    if (health < 100.0) set_entvar(target, var_health, 100.0)
    announce(id, target, "healed")
    return PLUGIN_HANDLED
}

public command_uberslap(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new target = target_from_argument(id)
    if (!target || !is_user_alive(target)) return PLUGIN_HANDLED
    remove_task(TASK_UBERSLAP + target)
    set_task(0.1, "uberslap_tick", TASK_UBERSLAP + target, _, _, "a", UBERSLAP_HITS)
    announce(id, target, "uberslapped")
    return PLUGIN_HANDLED
}

public uberslap_tick(task)
{
    new target = task - TASK_UBERSLAP
    if (!is_user_alive(target))
    {
        remove_task(task)
        return
    }
    new Float:health = Float:get_entvar(target, var_health)
    if (health > 1.0 && !g_godmode[target])
        set_entvar(target, var_health, floatmax(1.0, health - 1.0))
    user_slap(target, 0)
}

public command_godmode(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new target = target_from_argument(id)
    if (!target) return PLUGIN_HANDLED
    new setting[8]
    read_argv(2, setting, charsmax(setting))
    if (!setting[0]) g_godmode[target] = !g_godmode[target]
    else if (equali(setting, "on") || equal(setting, "1")) g_godmode[target] = true
    else if (equali(setting, "off") || equal(setting, "0")) g_godmode[target] = false
    else
    {
        console_print(id, "[AMXX] Use on or off.")
        return PLUGIN_HANDLED
    }
    announce(id, target, g_godmode[target] ? "enabled godmode for" : "disabled godmode for")
    return PLUGIN_HANDLED
}

public damage_pre(victim, inflictor, attacker, Float:damage, bits)
{
    if (!g_godmode[victim] && !((bits & DMG_FALL) && task_exists(TASK_UBERSLAP + victim)))
        return HAM_IGNORED
    SetHamReturnInteger(0)
    return HAM_SUPERCEDE
}

announce(id, target, const action[])
{
    new admin[32], name[32]
    if (id) get_user_name(id, admin, charsmax(admin))
    else copy(admin, charsmax(admin), "SERVER")
    get_user_name(target, name, charsmax(name))
    client_print_color(0, target, "^4[^1AMXX^4]^3 %s ^4%s ^3%s^1.", admin, action, name)
    console_print(id, "[AMXX] %s %s %s.", admin, action, name)
    log_amx("Admin %s <%d> %s %s <%d>", admin, id ? get_user_userid(id) : 0, action, name, get_user_userid(target))
}

public client_disconnected(id)
{
    g_godmode[id] = false
    remove_task(TASK_UBERSLAP + id)
    g_trail[id] = 0
    g_trail_sampled[id] = false
    g_glow[id] = 0
    g_gag_until[id] = 0
    g_key[id][0] = 0
    g_reason[id][0] = 0
}

public plugin_end()
{
    remove_task(TASK_TRAIL_MOTION)
    for (new id = 1; id <= MaxClients; id++)
    {
        remove_task(TASK_UBERSLAP + id)
    }
    if (g_vault != INVALID_HANDLE) nvault_close(g_vault)
}

public tools_status()
{
    new gags, glows, trails
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id)) continue
        if (is_gagged(id)) gags++
        if (g_glow[id]) glows++
        if (g_trail[id]) trails++
    }
    server_print("[AMXX] Admin Tools %s running; gags=%d glows=%d trails=%d", PLUGIN_VERSION, gags, glows, trails)
}
