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
native bool:mm_voting_start_rematch(MmMode:mode)
native bool:mm_voting_start_sniper_vote()

// weapon is CSW_AWP or CSW_SCOUT; a cancelled selection resolves to AWP.
forward mm_sniper_selected(weapon)

forward mm_rematch_finished(mode, change_map)

native bool:mm_voting_start_cod_vote()
forward mm_cod_map_extended(minutes)
