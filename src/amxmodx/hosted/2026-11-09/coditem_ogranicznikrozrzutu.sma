#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Ogranicznik Rozrzutu"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Recoil Reducer"
#define DESCRIPTION "Weapon recoil reduced by half."

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	cod_set_user_recoil_reducer(id, true, ITEM);