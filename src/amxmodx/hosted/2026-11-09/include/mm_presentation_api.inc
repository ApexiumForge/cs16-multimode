#if defined _mm_presentation_api_included
    #endinput
#endif
#define _mm_presentation_api_included
#include <mm_mode_api>
#include <cstrike>

native bool:mm_show_results(MmMode:mode, first, second, third, const title[], const detail[])

stock mm_rank_scores(const points[], const deaths[], output[32], &count)
{
    count = 0
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id)) continue
        new CsTeams:team = cs_get_user_team(id)
        if (team != CS_TEAM_CT && team != CS_TEAM_T) continue
        output[count++] = id
    }
    for (new a = 0; a < count; a++)
        for (new b = a+1; b < count; b++)
            if (points[output[b]] > points[output[a]] || (points[output[b]] == points[output[a]] && deaths[output[b]] < deaths[output[a]]))
            {new temp = output[a]; output[a] = output[b]; output[b] = temp;}
}
