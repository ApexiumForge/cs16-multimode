#if defined _mm_voting_api_included
    #endinput
#endif
#define _mm_voting_api_included

#include <mm_mode_api>

enum MmVotingAdminResult
{
    MM_VOTING_ADMIN_FAILED = 0,
    MM_VOTING_ADMIN_OK,
    MM_VOTING_ADMIN_INVALID_MODE,
    MM_VOTING_ADMIN_INVALID_MAP,
    MM_VOTING_ADMIN_UNAUTHORIZED
}

native bool:mm_voting_is_active()
native bool:mm_voting_has_decision()
native MmVotingAdminResult:mm_voting_admin_cancel(requester)
native MmVotingAdminResult:mm_voting_admin_change(MmMode:mode, const map_name[], requester)
