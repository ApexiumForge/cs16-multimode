#include <amxmodx>
#include <fakemeta>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Obronca"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Defender"
#define DESCRIPTION "See mines and invisible enemies."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_M249)|(1<<CSW_MAC10)|(1<<CSW_P228)
#define HEALTH       20
#define INTELLIGENCE 0
#define STRENGTH     5
#define STAMINA      0
#define CONDITION    5

new classActive;

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);

	register_forward(FM_AddToFullPack, "add_to_full_pack", 1);
}

public cod_class_enabled(id, promotion)
	set_bit(id, classActive);

public cod_class_disabled(id)
	rem_bit(id, classActive);

public add_to_full_pack(handle, e, ent, host, hostFlags, player, pSet)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return;
	if (!is_user_alive(host) || !get_bit(host, classActive)) return;

	if (is_user_alive(ent)) {
		set_es(handle, ES_RenderAmt, 255.0);
	} else {
		static className[5];

		pev(ent, pev_classname, className, charsmax(className));

		if (equal(className, "mine")) {
			set_es(handle, ES_RenderMode, kRenderTransAdd);
			set_es(handle, ES_RenderAmt, 120.0);
		}
	}
}
