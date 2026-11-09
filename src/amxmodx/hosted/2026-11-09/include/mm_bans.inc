#if defined _mm_bans_included
    #endinput
#endif
#define _mm_bans_included

#define MM_BAN_REASON_MAX 220

native mm_ban_player(player, minutes, const reason[], bool:byIp = false);
native mm_ban_identity(const name[], const steam[], const ip[], minutes, const reason[], bool:byIp);
// Returns 1 on removal, 0 when absent, or -1 on a file error.
native mm_unban_identity(const identity[]);
native bool:mm_is_ban_test_bot(player);

stock mm_reason_chunk(const reason[], start, chunk[], limit)
{
    new end = start + min(strlen(reason[start]), limit);
    if (reason[end])
    {
        while (end > start && (reason[end] & 0xC0) == 0x80)
            end--;
        for (new i = end; i > start + limit / 2; i--)
        {
            if (reason[i] == ' ')
            {
                end = i;
                break;
            }
        }
    }
    copy(chunk, end - start, reason[start]);
    while (reason[end] == ' ')
        end++;
    return end;
}

stock bool:mm_read_command_reason(id, reason[], size)
{
    new args[512], token[64], rest[512];
    read_args(args, charsmax(args));
    argbreak(args, token, charsmax(token), rest, charsmax(rest));
    argbreak(rest, token, charsmax(token), args, charsmax(args));
    trim(args);
    remove_quotes(args);
    if (strlen(args) > size)
    {
        console_print(id, "[AMXX] Reason is too long (maximum %d bytes). Ban cancelled.", size);
        return false;
    }
    copy(reason, size, args);
    return true;
}

#if defined _adminstyle_included
stock mm_announce_ban(id, const player[], minutes, const reason[])
{
    new activity = get_cvar_num("amx_show_activity");
    if (activity < 1 || activity > 5)
        return;

    new admin[32], duration[32], players[32], count;
    get_user_name(id, admin, charsmax(admin));
    if (minutes)
        formatex(duration, charsmax(duration), "%d min", minutes);
    else
        copy(duration, charsmax(duration), "Permanent");

    new first[71];
    // Leave room for the activity prefix, both names and the color markers
    // before CromChat replaces the markers with single-byte codes.
    new firstLimit = min(charsmax(first), 82 - strlen(admin) - strlen(player) - strlen(duration));
    new offset = mm_reason_chunk(reason, 0, first, firstLimit);
    get_players(players, count, "ch");
    for (new i; i < count; i++)
    {
        new viewer = players[i];
        if (activity >= 4 && !_CC_IsActivityAdmin(viewer))
            continue;

        if (first[0])
            show_activity_id(viewer, id, admin, "&x01Banned &x03%s &x01for &x04%s &x01| Reason: %s", player, duration, first);
        else
            show_activity_id(viewer, id, admin, "&x01Banned &x03%s &x01for &x04%s", player, duration);

        for (new start = offset, chunk[121]; reason[start]; )
        {
            start = mm_reason_chunk(reason, start, chunk, charsmax(chunk));
            client_print_color(viewer, print_team_default, "^1%s", chunk);
        }
    }
}
#endif
