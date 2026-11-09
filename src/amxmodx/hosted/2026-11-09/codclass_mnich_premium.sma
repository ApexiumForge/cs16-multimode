#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Mnich"
#define PLUGIN_VERSION "1.1.1"
#define AUTHOR "O'Zone"

#define NAME "Monk"
#define DESCRIPTION "Silent footsteps and three teleports, with a 15-second teleport cooldown."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_AK47)|(1<<CSW_USP)
#define HEALTH       10
#define INTELLIGENCE 0
#define STRENGTH     10
#define STAMINA      20
#define CONDITION    10
#define FLAG NONE

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION, FLAG);
}

public cod_class_enabled(id, promotion)
{
	cod_set_user_teleports(id, 3, CLASS);
	cod_set_user_footsteps(id, true, CLASS)
}

public cod_class_skill_used(id)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return;
	cod_use_user_teleport(id);
}
