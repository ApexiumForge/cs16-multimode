#if defined _mm_mode_api_included
    #endinput
#endif
#define _mm_mode_api_included

enum MmMode
{
    MM_MODE_CLASSIC = 0,
    MM_MODE_DEATHMATCH,
    MM_MODE_ARMS_RACE,
    MM_MODE_AWP_ONLY,
    MM_MODE_HE_BATTLE,
    MM_MODE_KNIFE,
    MM_MODE_FOOTBALL,
    MM_MODE_COUNT
}

enum MmClassicFormat
{
    MM_FORMAT_1V1 = 0,
    MM_FORMAT_2V2,
    MM_FORMAT_3V3,
    MM_FORMAT_4V4,
    MM_FORMAT_5V5,
    MM_FORMAT_1V2,
    MM_FORMAT_2V3,
    MM_FORMAT_3V4,
    MM_FORMAT_4V5,
    MM_FORMAT_COUNT
}

enum MmTransitionState
{
    MM_TRANSITION_IDLE = 0,
    MM_TRANSITION_RESETTING,
    MM_TRANSITION_APPLYING,
    MM_TRANSITION_FAILED
}

enum MmRequestResult
{
    MM_REQUEST_FAILED = 0,
    MM_REQUEST_ACCEPTED,
    MM_REQUEST_DUPLICATE,
    MM_REQUEST_BUSY,
    MM_REQUEST_INVALID,
    MM_REQUEST_UNAUTHORIZED
}

native MmMode:mm_get_active_mode()
native MmMode:mm_get_requested_mode()
native MmTransitionState:mm_get_transition_state()
native MmClassicFormat:mm_get_classic_format()
native mm_get_mode_name(MmMode:mode, output[], output_length)
native mm_get_classic_format_name(MmClassicFormat:format, output[], output_length)
native MmRequestResult:mm_request_mode(MmMode:mode, requester)
native MmRequestResult:mm_request_classic_format(MmClassicFormat:format, requester)

// Forwards emitted by mm_mode_manager:
// mm_mode_transition_started(old_mode, requested_mode)
// mm_mode_changed(old_mode, new_mode)
// mm_classic_format_changed(old_format, new_format)
