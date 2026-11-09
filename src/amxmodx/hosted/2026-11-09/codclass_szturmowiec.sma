#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Szturmowiec"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Assault"
#define DESCRIPTION "Bonus M4 damage, one rocket and silent footsteps."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_M4A1)|(1<<CSW_DEAGLE)
#define HEALTH       0
#define INTELLIGENCE 0
#define STRENGTH     0
#define STAMINA      10
#define CONDITION    20

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_enabled(id, promotion)
{
	cod_set_user_footsteps(id, true, CLASS);
	cod_set_user_rockets(id, 1, CLASS);
}

public cod_class_skill_used(id)
	cod_use_user_rocket(id);

public cod_class_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (weapon == CSW_M4A1 && damageBits & DMG_BULLET) {
        damage += (3.0 + 0.05 * cod_get_user_intelligence(attacker));
    }
}
