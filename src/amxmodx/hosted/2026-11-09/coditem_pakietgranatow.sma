#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Pakiet Granatow"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Grenade Pack"
#define DESCRIPTION "Receive a complete grenade set."

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
{
	cod_give_weapon(id, CSW_FLASHBANG, 2);
	cod_give_weapon(id, CSW_HEGRENADE, 1);
	cod_give_weapon(id, CSW_SMOKEGRENADE, 1);
}

public cod_item_respawn(id, respawn)
{
	cod_give_weapon(id, CSW_FLASHBANG, 2);
	cod_give_weapon(id, CSW_HEGRENADE, 1);
	cod_give_weapon(id, CSW_SMOKEGRENADE, 1);
}
