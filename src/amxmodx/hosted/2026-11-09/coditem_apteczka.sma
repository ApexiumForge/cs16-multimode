#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Apteczka"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "First Aid"
#define DESCRIPTION "Fully heal once per life."

new itemUsed;

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	rem_bit(id, itemUsed);

public cod_item_spawned(id, respawn)
{
	if (!respawn) {
		rem_bit(id, itemUsed);
	}
}

public cod_item_skill_used(id)
{
	if (get_bit(id, itemUsed)) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.42, 0, 0.0, 2.0, 0.0, 0.0, "Apteczki mozesz uzyc tylko raz na runde!");

		return;
	}

	if (cod_get_user_health(id, 1) == cod_get_user_max_health(id)) return;

	cod_set_user_health(id, cod_get_user_max_health(id));

	set_bit(id, itemUsed);
}