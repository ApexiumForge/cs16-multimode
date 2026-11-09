#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <cstrike>
#include <cod>
#include <mm_mode_api>
#define PLUGIN_VERSION "1.1.1"

#define PLUGIN "CoD Class Replikant"
#define AUTHOR "O'Zone"

#define NAME "Replicant"
#define DESCRIPTION "Three decoys reflect half bullet damage; one teleport and a third jump."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_AK47)|(1<<CSW_DEAGLE)
#define HEALTH       25
#define INTELLIGENCE 0
#define STRENGTH     0
#define STAMINA      10
#define CONDITION    15
#define FLAG NONE

#define REPLICAS     3

new itemLastUse[MAX_PLAYERS + 1], itemUse[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION, FLAG);

	RegisterHam(Ham_TakeDamage, "info_target", "take_damage");
}

public client_disconnected(id)
{
	cod_remove_ents(id, "replica");
}

public cod_class_enabled(id, promotion)
{
	cod_set_user_teleports(id, 1, CLASS);
	cod_set_user_multijumps(id, 1, CLASS);

	itemUse[id] = REPLICAS;
	itemLastUse[id] = -5;
}

public cod_class_disabled(id){cod_remove_ents(id,"replica");}

public cod_class_spawned(id, respawn)
{
	cod_remove_ents(id,"replica");
	itemLastUse[id] = -5;
	if (!respawn) {
		itemUse[id] = REPLICAS;
	}
}

public cod_new_round()
{
	cod_remove_ents(0, "replica");
}

public cod_class_skill_used(id)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return PLUGIN_CONTINUE;
	if (!itemUse[id]) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "You have used all decoys this life!");

		return PLUGIN_CONTINUE;
	}

	if (itemLastUse[id] + 5.0 > get_gametime()) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "You can place one decoy every 5 seconds!");

		return PLUGIN_CONTINUE;
	}

	if (!(pev(id, pev_flags) & FL_ONGROUND)) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "Stand on the ground to place a decoy.");

		return PLUGIN_CONTINUE;
	}

	new Float:entOrigin[3];

	if (!origin_in_distance(id, entOrigin, 45.0)) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "Move away from the obstacle to place a decoy.");

		return PLUGIN_CONTINUE;
	}

	new entModel[64], playerModel[32], Float:entAngle[3], entSequence = entity_get_int(id, EV_INT_gaitsequence);

	entSequence = (entSequence == 3 || entSequence == 4) ? 1 : entSequence;

	cs_get_user_model(id, playerModel, charsmax(playerModel));

	format(entModel, charsmax(entModel), "models/player/%s/%s.mdl", playerModel, playerModel);

	entity_get_vector(id, EV_VEC_angles, entAngle);

	entAngle[0] = 0.0;
	entOrigin[2] -= distance_to_floor(id, entOrigin);

	new ent = create_entity("info_target");
	if(!is_valid_ent(ent))return PLUGIN_CONTINUE;

	entity_set_string(ent, EV_SZ_classname, "replica");
	entity_set_model(ent, entModel);
	entity_set_vector(ent, EV_VEC_origin, entOrigin);
	entity_set_vector(ent, EV_VEC_angles, entAngle);
	entity_set_vector(ent, EV_VEC_v_angle, entAngle);
	entity_set_int(ent, EV_INT_sequence, entSequence);
	entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
	entity_set_float(ent, EV_FL_health, 300.0);
	entity_set_float(ent, EV_FL_takedamage, DAMAGE_YES);
	entity_set_size(ent, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0});
	entity_set_int(ent, EV_INT_iuser1, id);
	entity_set_edict(ent, EV_ENT_owner, id);

	if (!cod_is_enough_space(ent, 150.0)) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "You cannot block a passage with a decoy.");

		remove_entity(ent);

		return PLUGIN_CONTINUE;
	}

	itemLastUse[id] = floatround(get_gametime());
	itemUse[id]--;

	cod_emit_sound(id, SOUND_ACTIVATE, VOLUME_NORMAL, CHAN_WEAPON);

	return PLUGIN_CONTINUE;
}

public take_damage(victim, inflictor, attacker, Float:damage, damageBits)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return HAM_IGNORED;
	if (!is_user_alive(attacker)) return HAM_IGNORED;

	new className[32];

	entity_get_string(victim, EV_SZ_classname, className, charsmax(className));

	if (!equal(className, "replica")) return HAM_IGNORED;

	new owner = entity_get_int(victim, EV_INT_iuser1);

	if (!is_user_connected(owner)) return HAM_SUPERCEDE;

	if (get_user_team(owner) == get_user_team(attacker)) return HAM_SUPERCEDE;

	new itemName[32], bool:knifeUsed = cod_get_user_weapon(attacker) == CSW_KNIFE;

	cod_get_user_item_name(attacker, itemName, charsmax(itemName));

	if (equal(itemName, "Replica Slayer")) {
		damage *= 2;
	} else if (!knifeUsed) {
		cod_inflict_damage(owner, attacker, damage * 0.5, 0.0, damageBits);
	}

	if (damage > entity_get_float(victim, EV_FL_health)) {
		if (!knifeUsed) {
			cod_make_explosion(victim, 190, 1);
		} else {
			cod_make_explosion(victim, 190, 1, 190.0, 50.0, 0.0);
		}
	}

	return HAM_IGNORED;
}

stock origin_in_distance(id, Float:origin[3], Float:distance)
{
	new Float:playerAngle[3], Float:playerOrigin[3], trace;

	entity_get_vector(id, EV_VEC_origin, playerOrigin);
	entity_get_vector(id, EV_VEC_v_angle, playerAngle);

	playerAngle[0] *= -1;

	origin[0] = playerOrigin[0] + distance * floatcos(playerAngle[1], degrees);
	origin[1] = playerOrigin[1] + distance * floatsin(playerAngle[1], degrees);
	origin[2] = playerOrigin[2];

	engfunc(EngFunc_TraceHull, origin, origin, 0, (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, id, trace);

	if (engfunc(EngFunc_PointContents, origin) != CONTENTS_EMPTY || get_tr2(trace, TR_StartSolid) || get_tr2(trace, TR_AllSolid)) return false;

	return true;
}

stock Float:distance_to_floor(id, Float:origin[3])
{
	new Float:start[3], Float:end[3];

	start[0] = origin[0];
	start[1] = origin[1];
	start[2] = -8191.0;

	engfunc(EngFunc_TraceLine, origin, start, 1, 0, 0);

	get_tr2(0, TR_vecEndPos, end);

	start[2] = origin[2];

	return floatmax(0.0, origin[2] - end[2] - (pev(id, pev_flags) & FL_DUCKING ? 18.0 : 36.0));
}