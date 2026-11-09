#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Bezlik Amunicji"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Endless Ammo"
#define DESCRIPTION "Unlimited ammunition."

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	cod_set_user_unlimited_ammo(id, true, ITEM);