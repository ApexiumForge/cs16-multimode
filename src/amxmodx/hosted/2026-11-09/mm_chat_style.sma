#include <amxmodx>
#include <reapi>

new const PLUGIN_NAME[] = "Multi-Mode Chat Tag Style"
new const PLUGIN_VERSION[] = "1.2.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
new MessageHook:g_hook = INVALID_MESSAGEHOOK
new g_seen, g_changed

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    // Engine-level capture includes messages sent directly by AMXX/CromChat.
    if (is_rehlds()) g_hook = RegisterMessage(get_user_msgid("SayText"), "mm_saytext_pre")
    else register_message(get_user_msgid("SayText"), "mm_amxx_saytext")
    register_srvcmd("mm_chat_style_status", "mm_status")
    register_srvcmd("mm_chat_style_selftest", "mm_selftest")
    log_amx("%s v%s initialized; ReHLDS message API: %d.", PLUGIN_NAME, PLUGIN_VERSION, is_rehlds())
}
public plugin_end()
{
    if (g_hook != INVALID_MESSAGEHOOK) UnregisterMessage(g_hook)
}

bool:mm_color(character) {return character >= 1 && character <= 4;}

mm_style_admin_body(const input[], start, output[], maxlen)
{
    new content = start
    while (mm_color(input[content]) || input[content] == ' ') content++
    if (equali(input[content], "ADMIN:", 6))
    {
        formatex(output, maxlen, "^1 ADMIN:^4%s", input[content + 6])
        return
    }
    if (equali(input[content], "ADMIN ", 6))
    {
        new name[40], length, end = content + 6
        while (input[end] && input[end] != ':' && length < charsmax(name))
        {
            if (!mm_color(input[end])) name[length++] = input[end]
            end++
        }
        if (input[end] == ':' && length)
        {
            name[length] = 0
            formatex(output, maxlen, "^3 %s^1:^4%s", name, input[end + 1])
            return
        }
    }
    // Preserve notices that already start with a team or green color.
    if (input[start] == 3 || input[start] == 4) copy(output, maxlen, input[start])
    else formatex(output, maxlen, "^4 %s", input[content])
}

bool:mm_style_prefix(const input[], output[], maxlen)
{
    new start, color = 1
    while (mm_color(input[start])) color = input[start++]
    if (input[start] != '[') return false
    new label[65], length, close = start+1
    while (input[close] && input[close] != ']')
    {
        if (mm_color(input[close])) color = input[close]
        else
        {
            if (length >= charsmax(label)) return false
            label[length++] = input[close]
        }
        close++
    }
    if (input[close] != ']' || !length) return false
    label[length] = 0
    new next = close+1
    while (mm_color(input[next])) next++
    // Don't treat a player's [Clan]Name as a command/plugin tag.
    if (input[next] && input[next] != ' ' && input[next] != ':' && input[next] != '^t') return false
    if (equali(label, "AMXX") || equali(label, "Apexium") || equali(label, "Ban") || equali(label, "Bans"))
    {
        new body[192]
        mm_style_admin_body(input, close+1, body, charsmax(body))
        formatex(output, maxlen, "^1[^4%s^1]%s", label, body)
    }
    else if (mm_color(input[close+1])) formatex(output, maxlen, "^1[^4%s^1]%s", label, input[close+1])
    else formatex(output, maxlen, "^1[^4%s^1]%c%s", label, color, input[close+1])
    // Native CS formatted SayText reserves four bytes for sender and "%s".
    if (strlen(output) > 187)
    {
        new cut = 187
        while (cut > 0 && (output[cut] & 0xC0) == 0x80) cut--
        output[cut] = 0
    }
    return true
}

public mm_saytext_pre(message, destination, recipient)
{
    if (GetMessageArgsNum() < 2 || GetMessageArgType(2) != ArgString) return HC_CONTINUE
    g_seen++
    new raw[192], styled[256], parameter = 2
    GetMessageData(MsgArg, parameter, raw, charsmax(raw))
    if (equal(raw, "%s") || equal(raw, "#Spec_PlayerItem"))
    {
        if (GetMessageArgsNum() < 3 || GetMessageArgType(3) != ArgString) return HC_CONTINUE
        parameter = 3
        GetMessageData(MsgArg, parameter, raw, charsmax(raw))
    }
    if (mm_style_prefix(raw, styled, charsmax(styled)) && !equal(raw, styled))
    {
        SetMessageData(MsgArg, parameter, styled)
        g_changed++
    }
    return HC_CONTINUE
}

public mm_status()
{
    server_print("[Chat Style] version=%s engine_hook=%d seen=%d changed=%d brackets=yellow labels=green", PLUGIN_VERSION, _:g_hook, g_seen, g_changed)
}

public mm_selftest()
{
    new passed, output[256], again[256]
    if (mm_style_prefix("^4[AMXX]^1 Message", output, charsmax(output)) && equal(output, "^1[^4AMXX^1]^4 Message")) passed++
    if (mm_style_prefix("^4[Arms Race]^1 ^3Player^1 level ^47", output, charsmax(output)) && equal(output, "^1[^4Arms Race^1]^1 ^3Player^1 level ^47")) passed++
    if (mm_style_prefix("[Football] GOAL", output, charsmax(output)) && equal(output, "^1[^4Football^1]^1 GOAL")) passed++
    if (mm_style_prefix("^4[Admin] Name^1 message", output, charsmax(output)) && equal(output, "^1[^4Admin^1]^4 Name^1 message")) passed++
    if (!mm_style_prefix("#Cstrike_Chat_All", output, charsmax(output))) passed++
    if (!mm_style_prefix("^3Player^1 : hello [test]", output, charsmax(output))) passed++
    if (!mm_style_prefix("^3[Clan]Name^1 : hello", output, charsmax(output))) passed++
    mm_style_prefix("^4[AMXX]^1 Message", output, charsmax(output))
    if (mm_style_prefix(output, again, charsmax(again)) && equal(output, again)) passed++
    if (mm_style_prefix("^4[AMXX]^1 ADMIN ^4Alex^1: kick ^3Player^1", output, charsmax(output)) && equal(output, "^1[^4AMXX^1]^3 Alex^1:^4 kick ^3Player^1")) passed++
    if (mm_style_prefix("^1[^4AMXX^1]^3 Alex ^4healed ^3Player^1.", output, charsmax(output)) && equal(output, "^1[^4AMXX^1]^3 Alex ^4healed ^3Player^1.")) passed++
    if (mm_style_prefix("^4[Deathrun]^3 CTs run the course. One T operates the traps.", output, charsmax(output)) && equal(output, "^1[^4Deathrun^1]^3 CTs run the course. One T operates the traps.")) passed++
    server_print("[Chat Style Test] Prefix checks passed %d/11 (tags, admin activity, body colors, player chat, clan names, idempotence).", passed)
}

public mm_amxx_saytext(message, destination, recipient)
{
    if (get_msg_args() < 2 || get_msg_argtype(2) != ARG_STRING) return PLUGIN_CONTINUE
    new raw[192], styled[256], parameter = 2
    get_msg_arg_string(parameter, raw, charsmax(raw))
    if (equal(raw, "%s") || equal(raw, "#Spec_PlayerItem"))
    {
        if (get_msg_args() < 3 || get_msg_argtype(3) != ARG_STRING) return PLUGIN_CONTINUE
        parameter = 3
        get_msg_arg_string(parameter, raw, charsmax(raw))
    }
    g_seen++
    if (mm_style_prefix(raw, styled, charsmax(styled)) && !equal(raw, styled))
    {
        set_msg_arg_string(parameter, styled)
        g_changed++
    }
    return PLUGIN_CONTINUE
}
