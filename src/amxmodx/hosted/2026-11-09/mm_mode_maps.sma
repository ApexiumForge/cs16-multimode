#include <amxmodx>
#include <reapi>
#include <mm_mode_api>
#include <mm_voting_api>

new const PLUGIN_NAME[] = "Multi-Mode Dedicated Map Pools"
new const PLUGIN_VERSION[] = "1.3.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
#define MM_ROUTE_TASK 896000
new const FURIEN_DEFAULT_MAP[] = "de_dust2_2006"
new const MAP_POOLS[][] = {
    "addons/amxmodx/configs/mm_voting/maps_classic.ini",
    "addons/amxmodx/configs/mm_voting/maps_deathmatch.ini",
    "addons/amxmodx/configs/mm_voting/maps_armsrace.ini",
    "addons/amxmodx/configs/mm_voting/maps_awponly.ini",
    "addons/amxmodx/configs/mm_voting/maps_hebattle.ini",
    "addons/amxmodx/configs/mm_voting/maps_knife.ini",
    "addons/amxmodx/configs/mm_voting/maps_football.ini",
    "addons/amxmodx/configs/mm_voting/maps_surf.ini",
    "addons/amxmodx/configs/mm_voting/maps_cod.ini",
    "addons/amxmodx/configs/mm_voting/maps_zombie.ini",
    "addons/amxmodx/configs/mm_voting/maps_furien.ini",
    "addons/amxmodx/configs/mm_voting/maps_deathrun.ini"
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_srvcmd("mm_map_pool_status", "mm_status")
    RegisterHookChain(RG_CSGameRules_ChangeLevel, "mm_engine_changelevel", false)
    log_amx("Dedicated HE/Knife map routing initialized.")
}

public plugin_cfg()
{
    // A manual or host-driven map change can bypass the mode transition.
    if (mm_get_active_mode() == MM_MODE_FURIEN || mm_get_active_mode() == MM_MODE_DEATHRUN)
        set_task(0.5, "mm_route", MM_ROUTE_TASK)
}

public mm_engine_changelevel()
{
    if (mm_get_active_mode() == MM_MODE_DEATHRUN)
    {
        if (mm_voting_has_decision()) return HC_SUPERCEDE
        new next_map[32]
        if (!mm_next_deathrun_map(next_map, charsmax(next_map))) return HC_CONTINUE
        server_cmd("changelevel %s", next_map)
        return HC_SUPERCEDE
    }

    if (mm_get_active_mode() != MM_MODE_FURIEN || !is_map_valid(FURIEN_DEFAULT_MAP))
        return HC_CONTINUE

    // A committed vote has its own queued changelevel.
    if (!mm_voting_has_decision()) server_cmd("changelevel %s", FURIEN_DEFAULT_MAP)
    return HC_SUPERCEDE
}

bool:mm_dedicated(MmMode:mode) {return mode == MM_MODE_HE_BATTLE || mode == MM_MODE_KNIFE || mode == MM_MODE_FOOTBALL || mode == MM_MODE_SURF || mode == MM_MODE_COD || mode == MM_MODE_ZOMBIE || mode == MM_MODE_FURIEN || mode == MM_MODE_DEATHRUN;}

public mm_mode_transition_started(old_mode, new_mode) remove_task(MM_ROUTE_TASK)
public mm_mode_changed(old_mode, new_mode)
{
    if (mm_dedicated(MmMode:old_mode) || mm_dedicated(MmMode:new_mode)) set_task(0.3, "mm_route", MM_ROUTE_TASK)
}

bool:mm_safe(const map[])
{
    if (!map[0]) return false
    for (new i = 0; map[i]; i++) if (!isalnum(map[i]) && map[i] != '_' && map[i] != '-') return false
    return true
}

bool:mm_next_deathrun_map(chosen[], length)
{
    new current[32], map[32], count
    get_mapname(current, charsmax(current))
    new file = fopen(MAP_POOLS[_:MM_MODE_DEATHRUN], "rt")
    if (!file) return false
    while (!feof(file))
    {
        fgets(file, map, charsmax(map)); trim(map)
        if (!mm_safe(map) || !equali(map, "deathrun_", 9) || !is_map_valid(map)) continue
        if (equali(current, map))
        {
            if (!count) copy(chosen, length, map)
        }
        else if (random_num(1, ++count) == 1) copy(chosen, length, map)
    }
    fclose(file)
    return bool:chosen[0]
}

public mm_route()
{
    if (mm_voting_is_active() || mm_voting_has_decision()) return
    new mode = _:mm_get_active_mode(), current[32], map[32], chosen[32], count, bool:present
    if (mode < 0 || mode >= sizeof MAP_POOLS || mm_get_transition_state() != MM_TRANSITION_IDLE) return
    get_mapname(current, charsmax(current))
    new file = fopen(MAP_POOLS[mode], "rt")
    if (!file) {log_amx("Target mode map pool missing; routing cancelled."); return;}
    while (!feof(file))
    {
        fgets(file, map, charsmax(map)); trim(map)
        if (!mm_safe(map) || !is_map_valid(map)) continue
        if (equali(current, map)) present = true
        if (random_num(1, ++count) == 1) copy(chosen, charsmax(chosen), map)
    }
    fclose(file)
    if (present) return
    if (mode == _:MM_MODE_FURIEN && is_map_valid(FURIEN_DEFAULT_MAP))
    {
        copy(chosen, charsmax(chosen), FURIEN_DEFAULT_MAP)
        count = 1
    }
    if (!count) {log_amx("No installed maps for target mode; routing cancelled."); return;}
    new MmVotingAdminResult:result = mm_voting_admin_change(MmMode:mode, chosen, 0)
    log_amx("Dedicated map route: mode=%d map=%s result=%d", mode, chosen, _:result)
}

public mm_status()
{
    new mode = _:mm_get_active_mode(), map[32], count
    if (mode < 0 || mode >= sizeof MAP_POOLS) return
    server_print("[Map Pool] active_mode=%d dedicated=%d pool=%s", mode, mm_dedicated(MmMode:mode), MAP_POOLS[mode])
    new file = fopen(MAP_POOLS[mode], "rt")
    if (!file) return
    while (!feof(file))
    {
        fgets(file, map, charsmax(map)); trim(map)
        if (mm_safe(map) && is_map_valid(map)) {server_print("[Map Pool] %s", map); count++;}
    }
    fclose(file)
    server_print("[Map Pool] installed=%d", count)
}

public plugin_end() remove_task(MM_ROUTE_TASK)
