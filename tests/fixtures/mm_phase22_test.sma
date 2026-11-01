#include <amxmodx>
#include <mm_mode_api>

public plugin_init()
{
    register_plugin("MM Phase 2.2 Runtime Test", "1.0", "Multi-Mode Network")
    set_task(0.5, "test_unauthorized_request")
    set_task(1.0, "test_switch_to_deathmatch")
    set_task(2.0, "test_duplicate_switch")
    set_task(3.0, "test_invalid_mode")
    set_task(4.0, "test_classic_format")
    set_task(5.0, "test_switch_to_classic")
    set_task(6.0, "test_final_state")
}

public test_unauthorized_request()
{
    log_amx("TEST unauthorized result=%d", mm_request_mode(MM_MODE_AWP_ONLY, 1))
}

public test_switch_to_deathmatch()
{
    log_amx("TEST switch_deathmatch result=%d", mm_request_mode(MM_MODE_DEATHMATCH, 0))
}

public test_duplicate_switch()
{
    log_amx("TEST duplicate_deathmatch result=%d active=%d", mm_request_mode(MM_MODE_DEATHMATCH, 0), mm_get_active_mode())
}

public test_invalid_mode()
{
    log_amx("TEST invalid_mode result=%d", mm_request_mode(MmMode:99, 0))
}

public test_classic_format()
{
    log_amx("TEST format_2v3 result=%d", mm_request_classic_format(MM_FORMAT_2V3, 0))
}

public test_switch_to_classic()
{
    log_amx("TEST switch_classic result=%d", mm_request_mode(MM_MODE_CLASSIC, 0))
}

public test_final_state()
{
    log_amx("TEST final active=%d requested=%d transition=%d format=%d", mm_get_active_mode(), mm_get_requested_mode(), mm_get_transition_state(), mm_get_classic_format())
}
