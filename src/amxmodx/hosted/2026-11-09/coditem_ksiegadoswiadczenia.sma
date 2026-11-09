#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Ksiega Doswiadczenia"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Experience Book"
#define DESCRIPTION "Gain %s extra XP per kill."
#define RANDOM_MIN  80
#define RANDOM_MAX  100
#define UPGRADE_MIN -4
#define UPGRADE_MAX 7
#define VALUE_MAX   200

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
	cod_random_upgrade(itemValue[id], UPGRADE_MIN, UPGRADE_MAX, .valueMax = VALUE_MAX);

public cod_item_kill(killer, victim, hitPlace)
	cod_set_user_exp(killer, itemValue[killer], 1);