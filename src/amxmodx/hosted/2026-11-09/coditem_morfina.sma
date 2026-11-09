#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Morfina"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Morphine"
#define DESCRIPTION "1/%s chance to respawn after death."
#define RANDOM_MIN  3
#define RANDOM_MAX  5
#define VALUE_MIN   2

new itemValue[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);
}

public cod_item_enabled(id, value)
	itemValue[id] = value;

public cod_item_value(id)
	return itemValue[id];

public cod_item_upgrade(id)
	cod_random_upgrade(itemValue[id], .valueMin = VALUE_MIN);

public cod_item_killed(killer, victim, hitPlace)
{
	if (random_num(1, itemValue[victim]) == 1) {
		cod_respawn_player(victim);
	}
}
