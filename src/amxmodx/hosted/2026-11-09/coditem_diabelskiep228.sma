#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Diabelskie P228"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Devil P228"
#define DESCRIPTION "1/%s lethal P228 chance and bonus damage."
#define RANDOM_MIN  5
#define RANDOM_MAX  7
#define VALUE_MIN   3

new itemValue[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);
}

public cod_item_enabled(id, value)
{
	cod_give_weapon(id, CSW_P228);

	itemValue[id] = value;
}

public cod_item_disabled(id)
	cod_take_weapon(id, CSW_P228);

public cod_item_value(id)
	return itemValue[id];

public cod_item_upgrade(id)
	cod_random_upgrade(itemValue[id], .valueMin = VALUE_MIN);

public cod_item_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (weapon != CSW_P228 || !(damageBits & DMG_BULLET)) return;

	if (random_num(1, itemValue[attacker]) == 1) {
		damage = cod_kill_player(attacker, victim, damageBits);
	} else {
		damage += 15.0;
	}
}