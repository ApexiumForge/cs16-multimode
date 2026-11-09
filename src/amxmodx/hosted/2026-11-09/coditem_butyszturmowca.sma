#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Buty Szturmowca"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Assault Boots"
#define DESCRIPTION "Silent footsteps and +%s strength."
#define RANDOM_MIN  20
#define RANDOM_MAX  30
#define UPGRADE_MIN -2
#define UPGRADE_MAX 4
#define VALUE_MAX 100

new itemValue[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);
}

public cod_item_enabled(id, value)
{
	itemValue[id] = value;

	cod_add_user_bonus_strength(id, itemValue[id]);

	cod_set_user_footsteps(id, true, ITEM);
}

public cod_item_disabled(id)
	cod_add_user_bonus_strength(id, -itemValue[id]);

public cod_item_upgrade(id)
{
	cod_add_user_bonus_strength(id, -itemValue[id]);

	cod_random_upgrade(itemValue[id], UPGRADE_MIN, UPGRADE_MAX, .valueMax = VALUE_MAX);

	cod_add_user_bonus_strength(id, itemValue[id]);
}

public cod_item_value(id)
	return itemValue[id];