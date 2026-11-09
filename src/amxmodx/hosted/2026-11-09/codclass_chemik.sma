#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Chemik"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Chemist"
#define DESCRIPTION "Two poison clouds and 10% poison chance on hit."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_M4A1)|(1<<CSW_DEAGLE)
#define HEALTH       20
#define INTELLIGENCE 10
#define STRENGTH     0
#define STAMINA      0
#define CONDITION    0

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_enabled(id, promotion)
	cod_set_user_poisons(id, 2, CLASS);

public cod_class_skill_used(id)
	cod_use_user_poison(id);

public cod_class_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (damageBits & DMG_BULLET && cod_percent_chance(10)) {
		cod_repeat_damage(attacker, victim, 3.0 + cod_get_user_intelligence(attacker) * 0.02, 0.5, 10, POISON);
	}
}
