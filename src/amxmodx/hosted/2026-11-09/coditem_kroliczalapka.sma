#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Krolicza Lapka"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Rabbit Foot"
#define DESCRIPTION "Automatic bunnyhop while holding jump."

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	cod_set_user_bunnyhop(id, true, ITEM);
