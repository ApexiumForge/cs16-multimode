#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Medyk"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Medic"
#define DESCRIPTION "Three healing kits and magazine refill on kill."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_UMP45)|(1<<CSW_GLOCK18)
#define HEALTH       20
#define INTELLIGENCE 0
#define STRENGTH     10
#define STAMINA      10
#define CONDITION    0

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_enabled(id, promotion)
	cod_set_user_medkits(id, 3, CLASS);

public cod_class_skill_used(id)
	cod_use_user_medkit(id);

public cod_class_kill(killer, victim, hitPlace)
	cod_refill_ammo(killer);