#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Licznik Zycia"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Health Scanner"
#define DESCRIPTION "Show the remaining HP of enemies you hit."

new itemActive;

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	set_bit(id, itemActive);

public cod_item_disabled(id)
	rem_bit(id, itemActive);

public cod_damage_post(attacker, victim, weapon, Float:damage, damageBits, hitPlace)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return;
	if (get_bit(attacker, itemActive) && is_user_alive(victim)) {
		static name[32];

		get_user_name(victim, name, charsmax(name));

		cod_show_hud(attacker, TYPE_DHUD, 0, 255, 0, -1.0, 0.55, 0, 0.0, 2.0, 0.0, 0.0, "Pozostale HP %s: %d", name, get_user_health(victim));
	}
}
