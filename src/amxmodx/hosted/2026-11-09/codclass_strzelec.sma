#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Strzelec"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Rifleman"
#define DESCRIPTION "10% lethal AK/M4 chance and one mine."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_M4A1)|(1<<CSW_AK47)|(1<<CSW_GLOCK18)
#define HEALTH       10
#define INTELLIGENCE 0
#define STRENGTH     10
#define STAMINA      20
#define CONDITION    -30

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_enabled(id, promotion)
	cod_set_user_mines(id, 1, CLASS);

public cod_class_skill_used(id)
	cod_use_user_mine(id);

public cod_class_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if ((weapon == CSW_M4A1 || weapon == CSW_AK47) && damageBits & DMG_BULLET && cod_percent_chance(10)) {
        damage = cod_kill_player(attacker, victim, damageBits);
    }
}
