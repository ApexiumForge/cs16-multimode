#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Rekawiczki Grabiezcy"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Raider Gloves"
#define DESCRIPTION "Heal %s HP and refill magazine on kill."
#define RANDOM_MIN  20
#define RANDOM_MAX  35
#define UPGRADE_MIN -3
#define UPGRADE_MAX 5
#define VALUE_MAX   100

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
{
	cod_refill_ammo(killer);

	cod_add_user_health(killer, itemValue[killer]);
}