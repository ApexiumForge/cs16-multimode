#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Pulkownik"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Colonel"
#define DESCRIPTION "M249 damage rises as ammo falls; one mine and rocket."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_M249)|(1<<CSW_GLOCK18)
#define HEALTH       20
#define INTELLIGENCE 0
#define STRENGTH     0
#define STAMINA      5
#define CONDITION    5

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_enabled(id, promotion)
{
	cod_set_user_mines(id, 1, CLASS);
	cod_set_user_rockets(id, 1, CLASS);
}

public cod_class_skill_used(id)
{
	if (cod_get_user_mines(id)) {
		cod_use_user_mine(id);
	} else {
		cod_use_user_rocket(id);
	}
}

public cod_class_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (weapon == CSW_M249 && damageBits & DMG_BULLET) {
		cod_inflict_damage(attacker, victim, (100 - cs_get_weapon_ammo(get_pdata_cbase(attacker, 373))) * 0.2, 0.0, damageBits);
	}
}
