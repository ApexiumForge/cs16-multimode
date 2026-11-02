// Explicitly compiled/registered only in the isolated Football test clone.
#include <amxmodx>
#include <engine>
#include <mm_mode_api>
new g_errors
public plugin_init()
{
    register_plugin("Football Isolated Runtime Checks", "1.0.0", "ApexiumForge")
    set_task(3.0, "step")
}
check(bool:condition, const label[])
{
    if (!condition) g_errors++
    log_amx("FOOTBALL_TEST %s %s", condition ? "PASS" : "FAIL", label)
}
public step()
{
    new value[16]
    get_localinfo("mm_fb_test_step", value, charsmax(value))
    new phase = str_to_num(value)
    if (phase == 0)
    {
        new baseline[16]
        get_cvar_string("mp_freeforall", baseline, charsmax(baseline)); set_localinfo("mm_fb_test_baseline", baseline)
        check(mm_request_mode(MM_MODE_FOOTBALL, 0) == MM_REQUEST_ACCEPTED, "request Football")
    }
    else if (phase == 1 || phase == 3)
    {
        check(mm_get_active_mode() == MM_MODE_FOOTBALL, "Football authoritative state")
        check(get_cvar_num("mp_freeforall") == 0, "Football team policy")
        check(get_cvar_num("mp_round_infinite") == 1, "Football continuous rounds")
        check(find_ent_by_class(-1, "mm_football_ball") > 0, "Football ball exists")
        new passed
        if (callfunc_begin("mm_selftest", "mm_football.amxx") == 1) passed = callfunc_end()
        check(passed == 6, "goal geometry six cases")
        mm_request_mode(phase == 1 ? MM_MODE_DEATHMATCH : MM_MODE_CLASSIC, 0)
    }
    else if (phase == 2)
    {
        check(mm_get_active_mode() == MM_MODE_DEATHMATCH, "Deathmatch authoritative state")
        check(get_cvar_num("mp_freeforall") == 1, "Deathmatch FFA restored")
        check(find_ent_by_class(-1, "mm_football_ball") == 0, "Football ball cleaned")
        mm_request_mode(MM_MODE_FOOTBALL, 0)
    }
    else
    {
        check(mm_get_active_mode() == MM_MODE_CLASSIC, "Classic authoritative state")
        check(find_ent_by_class(-1, "mm_football_ball") == 0, "Classic has no Football ball")
        get_localinfo("mm_fb_test_baseline", value, charsmax(value))
        check(get_cvar_num("mp_freeforall") == str_to_num(value), "Classic FFA baseline restored")
        check(get_cvar_num("mp_round_infinite") == 0, "Classic ordinary rounds restored")
        log_amx("FOOTBALL_TEST DONE")
        set_localinfo("mm_fb_test_step", "")
        server_cmd("quit")
        return
    }
    if (g_errors) { log_amx("FOOTBALL_TEST FAILURES=%d", g_errors); server_cmd("quit"); return; }
    num_to_str(phase + 1, value, charsmax(value)); set_localinfo("mm_fb_test_step", value)
    set_task(8.0, "step")
}
