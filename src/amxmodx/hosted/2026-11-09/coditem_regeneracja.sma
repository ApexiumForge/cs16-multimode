#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Regeneracja"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Regeneration"
#define DESCRIPTION "Regenerate %s HP every three seconds."
#define RANDOM_MIN  4
#define RANDOM_MAX  6

new itemValue[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);
}

public cod_item_enabled(id, value)
{
	itemValue[id] = value;

	cod_repeat_damage(id, id, float(itemValue[id]), 3.0, 0, HEAL, 0);
}

public cod_item_disabled(id)
	cod_repeat_damage(id, id);

public cod_item_spawned(id, respawn)
	cod_repeat_damage(id, id, float(itemValue[id]), 3.0, 0, HEAL, 0);

public cod_item_value(id)
	return itemValue[id];

public cod_item_upgrade(id)
{
	cod_repeat_damage(id, id);

	cod_random_upgrade(itemValue[id]);

	cod_repeat_damage(id, id, float(itemValue[id]), 3.0, 0, HEAL, 0);
}
