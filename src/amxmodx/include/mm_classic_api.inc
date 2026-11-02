#if defined _mm_classic_api_included
    #endinput
#endif
#define _mm_classic_api_included

// True while changing mode or map would interrupt an active Classic match.
native bool:mm_classic_change_blocked()

enum MmClassicState
{
    MM_CLASSIC_WAITING = 0,
    MM_CLASSIC_WARMUP,
    MM_CLASSIC_READY,
    MM_CLASSIC_LIVE,
    MM_CLASSIC_HALFTIME,
    MM_CLASSIC_PAUSED,
    MM_CLASSIC_FINISHED
}

enum MmClassicAdminResult
{
    MM_CLASSIC_ADMIN_FAILED = 0,
    MM_CLASSIC_ADMIN_OK,
    MM_CLASSIC_ADMIN_INACTIVE,
    MM_CLASSIC_ADMIN_INVALID_STATE,
    MM_CLASSIC_ADMIN_TEAMS_INCOMPLETE,
    MM_CLASSIC_ADMIN_UNAUTHORIZED
}

native MmClassicState:mm_classic_get_state()
native mm_classic_get_status(output[], output_length)
native mm_classic_get_ready_count()
native mm_classic_get_required_count()
native bool:mm_classic_team_has_capacity(team)
native MmClassicAdminResult:mm_classic_force_ready_humans(requester)
native MmClassicAdminResult:mm_classic_force_unready_humans(requester)
native MmClassicAdminResult:mm_classic_admin_warmup(requester)
native MmClassicAdminResult:mm_classic_admin_restart(requester)
native MmClassicAdminResult:mm_classic_admin_stop(requester)
