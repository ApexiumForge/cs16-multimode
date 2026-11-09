#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include "mm_bans.inc"

new const BAN_FILE[] = "addons/amxmodx/configs/banned_players.ini";
new const BAN_TEMP[] = "addons/amxmodx/configs/banned_players.ini.tmp";
new const SEPARATOR[] = " > ";
new const TEST_NAME[] = "Ban Test Bot";
new const TEST_STEAM[] = "VALVE_9:9:2147483647";
new const TEST_IP[] = "192.0.2.123";

enum _:Ban {
    BanName[32],
    BanSteam[40],
    BanMinutes,
    BanReason[MM_BAN_REASON_MAX + 1],
    BanExpires,
    BanIp[16]
};

new Array:g_bans;
new g_selected[33][Ban];
new bool:g_fileReady;
new g_testBot, g_testEnabled, g_testAttempts, g_testBlocked;
new bool:g_reportedBlock;

public plugin_natives()
{
    register_library("mm_bans");
    register_native("mm_ban_player", "nativeBanPlayer");
    register_native("mm_ban_identity", "nativeBanIdentity");
    register_native("mm_unban_identity", "nativeUnban");
    register_native("mm_is_ban_test_bot", "nativeIsTestBot");
}

public plugin_init()
{
    register_plugin("Torbeshi Ban Manager", "1.2.0", "ApexiumForge");
    g_bans = ArrayCreate(Ban);
    register_clcmd("amx_unbanmenu", "cmdUnbanMenu", ADMIN_BAN, "- show active bans and reasons");
    register_srvcmd("mm_bans_status", "cmdStatus");
    g_testEnabled = register_cvar("mm_bantestbot", "1");
    register_concmd("amx_bantestbot", "cmdTestBot", ADMIN_RCON, "<0|1> - toggle the ban test bot");
}

public plugin_cfg()
{
    AddMenuItem("Unban Player", "amx_unbanmenu", ADMIN_BAN, "Torbeshi Ban Manager");
    reloadBans();
    set_task(8.0, "retryTestBot", .flags = "b");
}

public plugin_end()
{
    ArrayDestroy(g_bans);
}

bool:validSteam(const steam[])
{
    if (!equali(steam, "STEAM_", 6) && !equali(steam, "VALVE_", 6))
        return false;

    new fields[3][16];
    return explode_string(steam[6], ":", fields, sizeof fields, charsmax(fields[]), true) == 3
        && is_str_num(fields[0]) && is_str_num(fields[1]) && is_str_num(fields[2]);
}

bool:validIp(const ip[])
{
    new parts[4][16];
    if (explode_string(ip, ".", parts, sizeof parts, charsmax(parts[]), true) != 4)
        return false;
    for (new i; i < sizeof parts; i++)
        if (!is_str_num(parts[i]) || strlen(parts[i]) > 3 || str_to_num(parts[i]) > 255)
            return false;
    return true;
}

cleanField(value[])
{
    for (new i; value[i]; i++)
        if ((value[i] > 0 && value[i] < 32) || value[i] == '>' || value[i] == 92 || value[i] == '"' || value[i] == ';')
            value[i] = ' ';
    trim(value);
}

formatDuration(minutes, output[], size)
{
    if (minutes)
        formatex(output, size, "%d min", minutes);
    else
        copy(output, size, "Permanent");
}

bool:parseBan(const line[], entry[Ban])
{
    new fields[6][MM_BAN_REASON_MAX + 1];
    if (explode_string(line, SEPARATOR, fields, sizeof fields, charsmax(fields[]), true) != sizeof fields)
        return false;

    for (new i; i < sizeof fields; i++)
        trim(fields[i]);

    if (equal(fields[2], "Permanent"))
        entry[BanMinutes] = 0;
    else
    {
        new suffix = contain(fields[2], " min");
        if (suffix < 1 || !equal(fields[2][suffix], " min"))
            return false;
        fields[2][suffix] = 0;
        if (!is_str_num(fields[2]))
            return false;
        entry[BanMinutes] = str_to_num(fields[2]);
    }
    if (!is_str_num(fields[4]))
        return false;
    entry[BanExpires] = str_to_num(fields[4]);
    if (entry[BanMinutes] < 0 || entry[BanExpires] < 0 || (!entry[BanMinutes] != !entry[BanExpires]))
        return false;

    if (!equal(fields[1], "-") && !validSteam(fields[1]))
        return false;
    if (!equal(fields[5], "-") && !validIp(fields[5]))
        return false;
    if (equal(fields[1], "-") && equal(fields[5], "-"))
        return false;

    copy(entry[BanName], charsmax(entry[BanName]), fields[0]);
    copy(entry[BanSteam], charsmax(entry[BanSteam]), fields[1]);
    copy(entry[BanReason], charsmax(entry[BanReason]), fields[3]);
    copy(entry[BanIp], charsmax(entry[BanIp]), fields[5]);
    cleanField(entry[BanName]);
    cleanField(entry[BanReason]);
    return true;
}

bool:reloadBans()
{
    new file = fopen(BAN_FILE, "rt");
    if (!file)
        return g_fileReady = false;

    new Array:loaded = ArrayCreate(Ban), entry[Ban], line[384], now = get_systime();
    new bool:valid = true;
    while (fgets(file, line, charsmax(line)))
    {
        trim(line);
        if (!line[0] || line[0] == ';')
            continue;
        if (!parseBan(line, entry))
        {
            valid = false;
            break;
        }
        if (!entry[BanExpires] || entry[BanExpires] > now)
            ArrayPushArray(loaded, entry);
    }
    fclose(file);

    if (!valid)
    {
        ArrayDestroy(loaded);
        if (g_fileReady)
            log_amx("Invalid row in %s. Retaining the last valid ban list.", BAN_FILE);
        return g_fileReady = false;
    }
    ArrayDestroy(g_bans);
    g_bans = loaded;
    return g_fileReady = true;
}

bool:saveBans()
{
    new file = fopen(BAN_TEMP, "wt");
    if (!file)
        return false;
    new bool:ok = fprintf(file, "; Name > SteamID > Duration > Reason > Expiry (Unix UTC) > IP filter^n; Delete a whole row and save to unban. Zero expiry means permanent.^n; A dash in the final column means the ban is enforced by SteamID.^n") > 0;
    new entry[Ban], duration[24];
    for (new i, count = ArraySize(g_bans); ok && i < count; i++)
    {
        ArrayGetArray(g_bans, i, entry);
        formatDuration(entry[BanMinutes], duration, charsmax(duration));
        ok = fprintf(file, "%s > %s > %s > %s > %d > %s^n", entry[BanName], entry[BanSteam],
            duration, entry[BanReason], entry[BanExpires], entry[BanIp]) > 0;
    }
    if (fflush(file) != 0)
        ok = false;
    fclose(file);
    if (ok && rename_file(BAN_TEMP, BAN_FILE, 1))
        return true;
    delete_file(BAN_TEMP);
    return false;
}

banKey(const entry[Ban], key[], size)
{
    if (equal(entry[BanIp], "-"))
        copy(key, size, entry[BanSteam]);
    else
        copy(key, size, entry[BanIp]);
}

findBan(const identity[])
{
    new entry[Ban], key[40];
    for (new i, count = ArraySize(g_bans); i < count; i++)
    {
        ArrayGetArray(g_bans, i, entry);
        banKey(entry, key, charsmax(key));
        if (equali(key, identity))
            return i;
    }
    return -1;
}

kickBanned(id, const entry[Ban])
{
    new userid = get_user_userid(id);
    if (userid <= 0)
        return;
    new duration[24];
    formatDuration(entry[BanMinutes], duration, charsmax(duration));
    new chunk[61];
    new end = mm_reason_chunk(entry[BanReason], 0, chunk, charsmax(chunk));
    if (entry[BanReason][end] && is_user_connected(id) && !is_user_bot(id))
    {
        console_print(id, "[Ban] Full reason:");
        for (new offset; entry[BanReason][offset]; )
        {
            offset = mm_reason_chunk(entry[BanReason], offset, chunk, charsmax(chunk));
            console_print(id, "%s", chunk);
        }
        end = mm_reason_chunk(entry[BanReason], 0, chunk, charsmax(chunk));
    }
    server_cmd("kick #%d ^"Banned (%s): %s%s^"", userid, duration, chunk, entry[BanReason][end] ? "..." : "");
}

public client_authorized(id, const authid[])
{
    if (is_user_bot(id) || is_user_hltv(id))
        return;
    new ip[16], entry[Ban];
    get_user_ip(id, ip, charsmax(ip), 1);
    if (checkBan(authid, ip, entry))
        kickBanned(id, entry);
}

bool:checkBan(const steam[], const ip[], entry[Ban])
{
    reloadBans();
    new index = findBan(steam);
    if (index < 0)
        index = findBan(ip);
    if (index < 0)
        return false;
    ArrayGetArray(g_bans, index, entry);
    return !entry[BanExpires] || entry[BanExpires] > get_systime();
}

public client_disconnected(id)
{
    if (id == g_testBot)
        g_testBot = 0;
}

removeTestBot()
{
    if (g_testBot && is_user_connected(g_testBot))
        server_cmd("kick #%d", get_user_userid(g_testBot));
}

public cmdTestBot(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
        return PLUGIN_HANDLED;
    new value[8];
    read_argv(1, value, charsmax(value));
    if (!equal(value, "0") && !equal(value, "1"))
    {
        console_print(id, "Usage: amx_bantestbot <0|1>");
        return PLUGIN_HANDLED;
    }
    set_pcvar_num(g_testEnabled, str_to_num(value));
    retryTestBot();
    console_print(id, "[Bans] Ban Test Bot %s.", get_pcvar_num(g_testEnabled) ? "enabled" : "disabled");
    return PLUGIN_HANDLED;
}

public retryTestBot()
{
    if (!get_pcvar_num(g_testEnabled))
    {
        removeTestBot();
        return;
    }
    if (g_testBot)
        return;

    g_testAttempts++;
    new entry[Ban];
    // Fake clients have no Steam authentication. Use the same lookup as a real join.
    if (checkBan(TEST_STEAM, TEST_IP, entry))
    {
        g_testBlocked++;
        if (!g_reportedBlock)
            server_print("[Bans] Ban Test Bot blocked by the active ban. Retrying every 8 seconds.");
        g_reportedBlock = true;
        return;
    }

    // Leave the final open slot available for a human connection.
    if (get_playersnum(1) >= MaxClients - 1 || find_player("a", TEST_NAME))
        return;
    new bot = engfunc(EngFunc_CreateFakeClient, TEST_NAME);
    if (bot < 1 || bot > MaxClients)
        return;

    g_testBot = bot;
    engfunc(EngFunc_FreeEntPrivateData, bot);
    new rejected[128];
    if (!dllfunc(DLLFunc_ClientConnect, bot, TEST_NAME, "127.0.0.1", rejected))
    {
        server_cmd("kick ^"%s^"", TEST_NAME);
        g_testBot = 0;
        return;
    }
    dllfunc(DLLFunc_ClientPutInServer, bot);
    set_pev(bot, pev_flags, pev(bot, pev_flags) | FL_FAKECLIENT);
    // Leave the bot unassigned so it cannot spawn, fight or count toward a team.
    g_reportedBlock = false;
    server_print("[Bans] Ban Test Bot joined.");
}

public nativeIsTestBot(plugin, params)
{
    return g_testBot && get_param(1) == g_testBot;
}

bool:addBan(entry[Ban], bool:byIp)
{
    if (!validSteam(entry[BanSteam]))
        copy(entry[BanSteam], charsmax(entry[BanSteam]), "-");
    if (byIp)
    {
        if (!validIp(entry[BanIp]))
            return false;
    }
    else
    {
        if (equal(entry[BanSteam], "-"))
            return false;
        copy(entry[BanIp], charsmax(entry[BanIp]), "-");
    }
    new now = get_systime();
    if (entry[BanMinutes] < 0 || entry[BanMinutes] > (2147483647 - now) / 60 || !reloadBans())
        return false;

    if (entry[BanMinutes])
        entry[BanExpires] = now + 60 * entry[BanMinutes];
    cleanField(entry[BanName]);
    cleanField(entry[BanReason]);
    if (!entry[BanName][0])
        copy(entry[BanName], charsmax(entry[BanName]), "Unknown player");
    if (!entry[BanReason][0])
        copy(entry[BanReason], charsmax(entry[BanReason]), "No reason given");

    new key[40];
    banKey(entry, key, charsmax(key));
    new index = findBan(key);
    if (index < 0)
        ArrayPushArray(g_bans, entry);
    else
        ArraySetArray(g_bans, index, entry);
    if (!saveBans())
    {
        reloadBans();
        return false;
    }

    if (g_testBot && equali(key, byIp ? TEST_IP : TEST_STEAM))
        kickBanned(g_testBot, entry);

    new players[32], count, identity[40];
    get_players(players, count, "ch");
    for (new i; i < count; i++)
    {
        if (byIp)
            get_user_ip(players[i], identity, charsmax(identity), 1);
        else
            get_user_authid(players[i], identity, charsmax(identity));
        if (equali(identity, key))
            kickBanned(players[i], entry);
    }
    return true;
}

public nativeBanPlayer(plugin, params)
{
    new player = get_param(1), entry[Ban];
    if (!is_user_connected(player) || (is_user_bot(player) && player != g_testBot) || is_user_hltv(player))
        return false;
    if (player == g_testBot)
    {
        copy(entry[BanName], charsmax(entry[BanName]), TEST_NAME);
        copy(entry[BanSteam], charsmax(entry[BanSteam]), TEST_STEAM);
        copy(entry[BanIp], charsmax(entry[BanIp]), TEST_IP);
    }
    else
    {
        get_user_name(player, entry[BanName], charsmax(entry[BanName]));
        get_user_authid(player, entry[BanSteam], charsmax(entry[BanSteam]));
        get_user_ip(player, entry[BanIp], charsmax(entry[BanIp]), 1);
    }
    entry[BanMinutes] = get_param(2);
    get_string(3, entry[BanReason], charsmax(entry[BanReason]));
    return addBan(entry, bool:get_param(4) || !validSteam(entry[BanSteam]));
}

public nativeBanIdentity(plugin, params)
{
    new entry[Ban];
    get_string(1, entry[BanName], charsmax(entry[BanName]));
    get_string(2, entry[BanSteam], charsmax(entry[BanSteam]));
    get_string(3, entry[BanIp], charsmax(entry[BanIp]));
    entry[BanMinutes] = get_param(4);
    get_string(5, entry[BanReason], charsmax(entry[BanReason]));
    return addBan(entry, bool:get_param(6));
}

removeBan(index)
{
    ArrayDeleteItem(g_bans, index);
    if (saveBans())
        return 1;
    reloadBans();
    return -1;
}

public nativeUnban(plugin, params)
{
    new identity[40];
    get_string(1, identity, charsmax(identity));
    if (!reloadBans())
        return -1;
    new index = findBan(identity);
    return index < 0 ? 0 : removeBan(index);
}

public cmdStatus()
{
    new bool:ok = reloadBans();
    server_print("[Bans] %s | %d active", ok ? "File loaded" : "File unavailable or invalid", ArraySize(g_bans));
    server_print("[Bans] Ban Test Bot: enabled=%d, connected=%d, attempts=%d, blocked=%d",
        get_pcvar_num(g_testEnabled), g_testBot != 0, g_testAttempts, g_testBlocked);
}

public cmdUnbanMenu(id, level, cid)
{
    if (id && cmd_access(id, level, cid, 1))
        showBanList(id);
    return PLUGIN_HANDLED;
}

showBanList(id)
{
    if (!reloadBans())
    {
        client_print_color(id, print_team_default, "^4[^1Bans^4]^1 Could not read the ban list.");
        return;
    }
    new count = ArraySize(g_bans);
    if (!count)
    {
        client_print_color(id, print_team_default, "^4[^1Bans^4]^1 There are no active bans.");
        return;
    }
    new menu = menu_create("\yUnban Player^n\dName > SteamID > Duration", "openDetails");
    new entry[Ban], key[40], duration[24], line[110], steam[40];
    for (new i; i < count; i++)
    {
        ArrayGetArray(g_bans, i, entry);
        banKey(entry, key, charsmax(key));
        formatDuration(entry[BanMinutes], duration, charsmax(duration));
        steamLabel(entry, steam, charsmax(steam));
        formatex(line, charsmax(line), "%s \d> \w%s \d> \y%s",
            entry[BanName], steam, duration);
        menu_additem(menu, line, key);
    }
    menu_setprop(menu, MPROP_PERPAGE, 5);
    menu_display(id, menu);
}

steamLabel(const entry[Ban], label[], size)
{
    if (equal(entry[BanSteam], "-"))
        copy(label, size, "Unavailable");
    else
        copy(label, size, entry[BanSteam]);
}

public openDetails(id, menu, item)
{
    new key[40], access, callback;
    if (item >= 0)
        menu_item_getinfo(menu, item, access, key, charsmax(key), .callback = callback);
    menu_destroy(menu);
    if (item < 0 || !(get_user_flags(id) & ADMIN_BAN) || !reloadBans())
        return PLUGIN_HANDLED;
    new index = findBan(key);
    if (index < 0)
    {
        showBanList(id);
        return PLUGIN_HANDLED;
    }
    new entry[Ban], duration[24], title[450], steam[40], chunk[41];
    ArrayGetArray(g_bans, index, entry);
    g_selected[id] = entry;
    formatDuration(entry[BanMinutes], duration, charsmax(duration));
    steamLabel(entry, steam, charsmax(steam));
    new length = formatex(title, charsmax(title), "\yBan Details^n^n\dName \w%s^n\dSteamID \w%s^n\dDuration \y%s^n^n\dReason^n\w",
        entry[BanName], steam, duration);
    for (new offset; entry[BanReason][offset]; )
    {
        offset = mm_reason_chunk(entry[BanReason], offset, chunk, charsmax(chunk));
        length += formatex(title[length], charsmax(title) - length, "%s^n", chunk);
    }
    new details = menu_create(title, "confirmUnban");
    menu_additem(details, "\rUnban this player");
    menu_additem(details, "Back to ban list");
    menu_display(id, details);
    return PLUGIN_HANDLED;
}

public confirmUnban(id, menu, item)
{
    menu_destroy(menu);
    if (item < 0 || !(get_user_flags(id) & ADMIN_BAN))
        return PLUGIN_HANDLED;
    if (item == 0 && reloadBans())
    {
        new key[40], entry[Ban], selected[Ban];
        selected = g_selected[id];
        banKey(selected, key, charsmax(key));
        new index = findBan(key);
        if (index >= 0)
        {
            ArrayGetArray(g_bans, index, entry);
            if (entry[BanExpires] == selected[BanExpires] && entry[BanMinutes] == selected[BanMinutes]
                && equal(entry[BanName], selected[BanName]) && equal(entry[BanReason], selected[BanReason]))
            {
                if (removeBan(index) == 1)
                {
                    log_amx("Unban menu: %n removed %s", id, key);
                    client_print_color(id, print_team_default, "^4[^1Bans^4]^1 Unbanned ^3%s^1.", entry[BanName]);
                }
                else
                    client_print_color(id, print_team_default, "^4[^1Bans^4]^1 Could not save the ban list.");
            }
        }
    }
    showBanList(id);
    return PLUGIN_HANDLED;
}
