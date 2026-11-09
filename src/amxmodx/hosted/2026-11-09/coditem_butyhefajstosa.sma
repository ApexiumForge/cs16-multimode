#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Buty Hefajstosa"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Feather Boots"
#define DESCRIPTION "No fall damage and +%s condition."
#define RANDOM_MIN  20
#define RANDOM_MAX  25
#define UPGRADE_MIN -2
#define UPGRADE_MAX 4
#define VALUE_MAX   100

new itemActive, itemValue[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);
}

public cod_item_enabled(id, value)
{
	set_bit(id, itemActive);

	itemValue[id] = value;

	cod_add_user_bonus_condition(id, itemValue[id]);
}

public cod_item_disabled(id)
{
	rem_bit(id, itemActive);

	cod_add_user_bonus_condition(id, -itemValue[id]);
}

public cod_item_upgrade(id)
{
	cod_add_user_bonus_condition(id, -itemValue[id]);

	cod_random_upgrade(itemValue[id], UPGRADE_MIN, UPGRADE_MAX, .valueMax = VALUE_MAX);

	cod_add_user_bonus_condition(id, itemValue[id]);
}

public cod_damage_pre(attacker, victim, weapon, Float:damage, damageBits, hitPlace)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return;
	if (damageBits == DMG_FALL && get_bit(victim, itemActive)) {
		damage = COD_BLOCK;
	}
}

public cod_item_value(id)
	return itemValue[id];