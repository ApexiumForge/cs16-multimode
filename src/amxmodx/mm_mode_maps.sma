#include <amxmodx>
#include <mm_mode_api>
#include <mm_voting_api>

new const PLUGIN_NAME[] = "Multi-Mode Dedicated Map Pools"
new const PLUGIN_VERSION[] = "1.2.0"
new const PLUGIN_AUTHOR[] = "Torbeshi"
#define MM_ROUTE_TASK 896000
new const MAP_POOLS[][] = {
    "addons/amxmodx/configs/mm_voting/maps_classic.ini",
    "addons/amxmodx/configs/mm_voting/maps_deathmatch.ini",
    "addons/amxmodx/configs/mm_voting/maps_armsrace.ini",
    "addons/amxmodx/configs/mm_voting/maps_awponly.ini",
    "addons/amxmodx/configs/mm_voting/maps_hebattle.ini",
    "addons/amxmodx/configs/mm_voting/maps_knife.ini",
    "addons/amxmodx/configs/mm_voting/maps_football.ini",
    "addons/amxmodx/configs/mm_voting/maps_surf.ini"
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_srvcmd("mm_map_pool_status", "mm_status")
    log_amx("Dedicated HE/Knife map routing initialized.")
}

bool:mm_dedicated(MmMode:mode) {return mode == MM_MODE_HE_BATTLE || mode == MM_MODE_KNIFE || mode == MM_MODE_FOOTBALL || mode == MM_MODE_SURF;}

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
