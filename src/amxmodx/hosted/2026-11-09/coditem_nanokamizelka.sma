#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Nano Kamizelka"
#define PLUGIN_VERSION "1.1.0"
#define AUTHOR "O'Zone"

#define NAME "SWAT Shield"
#define DESCRIPTION "Blocks instant-kill effects and harmful CoD abilities. Ordinary weapon damage still applies."

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	cod_set_user_resistance(id, true, ITEM);