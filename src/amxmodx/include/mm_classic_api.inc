#if defined _mm_classic_api_included
    #endinput
#endif
#define _mm_classic_api_included

// True while changing mode or map would interrupt an active Classic match.
native bool:mm_classic_change_blocked()
