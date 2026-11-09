#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Kapitan"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Captain"
#define DESCRIPTION "Block the first three bullets each life."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_M4A1)|(1<<CSW_USP)
#define HEALTH       20
#define INTELLIGENCE 0
#define STRENGTH     0
#define STAMINA      5
#define CONDITION    5

#define BULLETS      3

new itemUse[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_enabled(id, promotion)
	itemUse[id] = BULLETS;

public cod_class_spawned(id, respawn)
{
	if (!respawn) {
        itemUse[id] = BULLETS;
    }
}

public cod_class_damage_victim(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (--itemUse[victim] > NONE) {
        damage = COD_BLOCK;
    }
}
