#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <reapi>
#include <cod>
#include <mm_mode_api>
#define PLUGIN_VERSION "2.0.0"

#define PLUGIN "CoD Class Lowca"
#define AUTHOR "O'Zone"

#define NAME "Hunter"
#define DESCRIPTION "AK47 + FiveSeven + selectable crossbow: 10 bolts, 3 seconds between shots, no reload. /bow selects it. Two mines."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_AK47)|(1<<CSW_FIVESEVEN)|(1<<CSW_SG550)
#define HEALTH       15
#define INTELLIGENCE 0
#define STRENGTH     10
#define STAMINA      20
#define CONDITION    5
#define FLAG NONE

#define BELTS        10

new const classModels[][] = { "models/CoDMod/crossbow.mdl", "models/CoDMod/crossbow2.mdl", "models/CoDMod/belt.mdl" };

enum { V_CROSSBOW, P_CROSSBOW, BELT };

new crossbowBelts[MAX_PLAYERS + 1], crossbowActive, classActive;
new Float:lastCrossbowBelt[MAX_PLAYERS + 1];
new mmShots;

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION, FLAG);

	register_touch("belt", "*" , "touch_belt");
	register_think("belt","expire_belt");

	register_forward(FM_EmitSound, "sound_emit");
	RegisterHam(Ham_Weapon_PrimaryAttack,"weapon_sg550","mm_bow_primary");
	RegisterHam(Ham_Weapon_SecondaryAttack,"weapon_sg550","mm_bow_block");
	RegisterHam(Ham_Weapon_Reload,"weapon_sg550","mm_bow_block");
	RegisterHam(Ham_Item_Deploy,"weapon_sg550","mm_bow_deploy",1);
	RegisterHam(Ham_Killed,"player","mm_bow_killed",1);
	register_clcmd("cod_crossbow","mm_select_bow",0,"- select Hunter crossbow");
	register_clcmd("say /bow","mm_select_bow",0,"- select Hunter crossbow");
	register_clcmd("say_team /bow","mm_select_bow");
	register_srvcmd("mm_cod_hunter_status","mm_hunter_status");
	register_forward(FM_UpdateClientData, "mm_crossbow_client", 1);
}

public plugin_precache()
{
	for (new i = 0; i < sizeof(classModels); i++) {
		precache_model(classModels[i]);
	}
}

public client_disconnected(id)
{
	cod_remove_ents(id, "belt");
	rem_bit(id, classActive); rem_bit(id, crossbowActive);
	lastCrossbowBelt[id] = 0.0;

}

public cod_class_enabled(id, promotion)
{
	cod_set_user_mines(id, 2, CLASS);

	set_bit(id, classActive);

	crossbowBelts[id] = BELTS;
	lastCrossbowBelt[id] = 0.0;

}

public cod_class_disabled(id)
{
	cod_remove_ents(id,"belt");
	rem_bit(id, classActive);
	rem_bit(id, crossbowActive);

	crossbowBelts[id] = 0;
}

public cod_class_spawned(id, respawn)
{
	rem_bit(id, crossbowActive);

	if (is_user_alive(id)) {
		crossbowBelts[id] = BELTS;
		lastCrossbowBelt[id] = 0.0;
	
	}
}

public cod_class_skill_used(id)
	cod_use_user_mine(id);

public cod_new_round()
	cod_remove_ents(0, "belt");

public cod_weapon_deploy(id,weapon,ent)
{
	rem_bit(id,crossbowActive);
	if(get_bit(id,classActive) && weapon==CSW_SG550)set_bit(id,crossbowActive);
}

public shoot_belt(id, weapon)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return ;
	if (!is_user_alive(id)) return;

	if (!crossbowBelts[id]) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "You have used all bolts this life!");

		return;
	}

	if (!get_bit(id, crossbowActive)) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "Select your crossbow or type /bow.");

		return;
	}

	if (lastCrossbowBelt[id] > get_gametime()) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "You can fire one bolt every 3 seconds!");

		return;
	}


	new Float:origin[3], Float:angle[3], Float:velocity[3];

	entity_get_vector(id, EV_VEC_v_angle, angle);
	entity_get_vector(id, EV_VEC_origin, origin);
	new Float:view[3],Float:direction[3];pev(id,pev_view_ofs,view);
	angle_vector(angle,ANGLEVECTOR_FORWARD,direction);
	for(new i=0;i<3;i++)origin[i]+=view[i]+direction[i]*24.0;

	new ent = create_entity("info_target");
	if(!is_valid_ent(ent))return;
	lastCrossbowBelt[id] = get_gametime() + 3.0;
	crossbowBelts[id]--;mmShots++;
	set_member(weapon,m_Weapon_iClip,crossbowBelts[id]);
	set_pev(id,pev_weaponanim,4);
	message_begin(MSG_ONE_UNRELIABLE,SVC_WEAPONANIM,_,id);write_byte(4);write_byte(pev(id,pev_body));message_end();

	entity_set_string(ent, EV_SZ_classname, "belt");
	entity_set_model(ent, classModels[BELT]);

	angle[0] *= -1.0;

	entity_set_origin(ent, origin);
	entity_set_vector(ent, EV_VEC_angles, angle);
	entity_set_int(ent, EV_INT_effects, 2);
	entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
	entity_set_size(ent,Float:{-1.0,-1.0,-1.0},Float:{1.0,1.0,1.0});
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
	entity_set_edict(ent, EV_ENT_owner, id);
	set_pev(ent,pev_nextthink,get_gametime()+10.0);

	set_rendering(ent, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 56);

	VelocityByAim(id, 1500, velocity);

	entity_set_vector(ent, EV_VEC_velocity, velocity);

	cod_emit_sound(id, SOUND_DEPLOY, VOLUME_NORMAL, CHAN_ITEM);
}

public touch_belt(ent,other)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return ;
	if (!is_valid_ent(ent)) return;
	if(other==entity_get_edict(ent,EV_ENT_owner))return;

	new owner = entity_get_edict(ent, EV_ENT_owner), entList[33], playersFound = find_sphere_class(ent, "player", 15.0, entList, 32), player;

	for (new i = 0; i < playersFound; i++) {
		player = entList[i];

		if (!is_user_alive(player) || get_user_team(owner) == get_user_team(player)) continue;

		cod_kill_player(owner, player, DMG_CODSKILL);
	}

	remove_entity(ent);
}

public sound_emit(ent, channel, const sample[])
{
	if(mm_get_active_mode()!=MM_MODE_COD)return FMRES_IGNORED;
	if (!is_user_alive(ent) || !get_bit(ent, classActive)) return FMRES_IGNORED;

	static modelName[32];

	entity_get_string(ent, EV_SZ_viewmodel, modelName, charsmax(modelName));

	if (equal(modelName, classModels[V_CROSSBOW])) {
		if (equal(sample,"weapons/knife_slash1.wav")) return FMRES_SUPERCEDE;
		if (equal(sample,"weapons/knife_slash2.wav")) return FMRES_SUPERCEDE;
		if (equal(sample,"weapons/knife_deploy1.wav")) return FMRES_SUPERCEDE;
		if (equal(sample,"weapons/knife_hitwall1.wav")) return FMRES_SUPERCEDE;
		if (equal(sample,"weapons/knife_hit1.wav")) return FMRES_SUPERCEDE;
		if (equal(sample,"weapons/knife_hit2.wav")) return FMRES_SUPERCEDE;
		if (equal(sample,"weapons/knife_hit3.wav")) return FMRES_SUPERCEDE;
		if (equal(sample,"weapons/knife_hit4.wav")) return FMRES_SUPERCEDE;
		if (equal(sample,"weapons/knife_stab.wav")) return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}
public expire_belt(ent){if(is_valid_ent(ent))remove_entity(ent);}


public mm_bow_deploy(weapon)
{
	new id=get_member(weapon,m_pPlayer);
	if(mm_get_active_mode()!=MM_MODE_COD || !is_user_alive(id) || !get_bit(id,classActive))return HAM_IGNORED;
	set_bit(id,crossbowActive);
	set_pev(id,pev_viewmodel2,classModels[V_CROSSBOW]);set_pev(id,pev_weaponmodel2,classModels[P_CROSSBOW]);
	set_member(weapon,m_Weapon_iClip,crossbowBelts[id]);mm_bow_reserve(id);
	return HAM_IGNORED;
}
public mm_bow_primary(weapon)
{
	new id=get_member(weapon,m_pPlayer);
	if(mm_get_active_mode()!=MM_MODE_COD || !is_user_alive(id) || !get_bit(id,classActive))return HAM_IGNORED;
	set_member(weapon,m_Weapon_flNextPrimaryAttack,0.2);
	if(lastCrossbowBelt[id]<=get_gametime())shoot_belt(id,weapon);
	return HAM_SUPERCEDE;
}
public mm_bow_block(weapon)
{
	new id=get_member(weapon,m_pPlayer);
	return mm_get_active_mode()==MM_MODE_COD && is_user_alive(id) && get_bit(id,classActive)?HAM_SUPERCEDE:HAM_IGNORED;
}
public mm_crossbow_client(id,sendweapons,cd)
{
	if(mm_get_active_mode()==MM_MODE_COD && is_user_alive(id) && get_bit(id,classActive) && cod_get_user_weapon(id)==CSW_SG550){
		set_cd(cd,CD_flNextAttack,get_gametime()+0.001);
		set_pev(id,pev_viewmodel2,classModels[V_CROSSBOW]);set_pev(id,pev_weaponmodel2,classModels[P_CROSSBOW]);mm_bow_reserve(id);
	}
	return FMRES_IGNORED;
}
public mm_select_bow(id)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return PLUGIN_CONTINUE;
	if(is_user_alive(id) && get_bit(id,classActive))engclient_cmd(id,"weapon_sg550");
	return PLUGIN_HANDLED;
}
public mm_bow_killed(id,killer,gib){cod_remove_ents(id,"belt");rem_bit(id,crossbowActive);}
public mm_mode_transition_started(oldmode,newmode){if(MmMode:oldmode==MM_MODE_COD){cod_remove_ents(0,"belt");crossbowActive=0;}}
public mm_hunter_status(){server_print("[CoD Hunter] class=%d standalone_bow=1 carrier=SG550 loadout=AK47/FiveSeven/Crossbow bolts=10 interval=3 reload=0 shots=%d",cod_get_class_id("Hunter"),mmShots);}

stock mm_bow_reserve(id)
{
	// SG550 shares 5.56 reserve with expert/perk rifles; never erase their ammo.
	new shared=(1<<CSW_AUG)|(1<<CSW_SG552)|(1<<CSW_M4A1)|(1<<CSW_FAMAS)|(1<<CSW_GALIL);
	if(!(pev(id,pev_weapons)&shared))cs_set_user_bpammo(id,CSW_SG550,0);
}
