#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Aimer"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Aimer"
#define DESCRIPTION "20% chance for a lethal headshot."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_M4A1)|(1<<CSW_P228)
#define HEALTH       10
#define INTELLIGENCE 0
#define STRENGTH     10
#define STAMINA      5
#define CONDITION    5

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (damageBits & DMG_BULLET && hitPlace == HIT_HEAD && cod_percent_chance(20)) {
        damage = cod_kill_player(attacker, victim, damageBits);
    }
}
