#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cod>
#include <reapi>
#include <mm_mode_api>
#define PLUGIN_VERSION "2.0.2"

#define PLUGIN "CoD Class Czolgista"
#define AUTHOR "O'Zone"

#define NAME "Tank"
#define DESCRIPTION "Extra jump and bazooka with ten missiles; reload while holding knife."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_GALIL)|(1<<CSW_GLOCK18)
#define HEALTH       10
#define INTELLIGENCE 0
#define STRENGTH     10
#define STAMINA      0
#define CONDITION    10

#define MISSILES     10

new const classModels[][] = { "models/CoDMod/bazooka.mdl", "models/CoDMod/bazooka2.mdl", "models/CoDMod/missile.mdl" };
new const classSprites[][] = { "sprites/smoke.spr", "sprites/CoDMod/steam1.spr", "sprites/CoDMod/explosion.spr" };

enum _:models { V_BAZOOKA, P_BAZOOKA, MISSILE };
enum _:sprites { TRAIL, SMOKE, EXPLOSION }

new bazookaMissiles[MAX_PLAYERS + 1], sprite[sprites], bazookaActive, classActive;
new Float:lastBazookaMissile[MAX_PLAYERS + 1];
new g_shots,g_hits,g_lastButtons[33];

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);

	register_touch("missile", "*" , "touch_missile");
	register_think("missile","expire_missile");
	register_srvcmd("mm_cod_tank_status","mm_tank_status");

	register_forward(FM_EmitSound, "sound_emit");
	register_forward(FM_CmdStart,"bazooka_buttons",1);
	register_clcmd("cod_bazooka","bazooka_command",0,"- Tank: equip/holster bazooka");
	register_clcmd("say /bazooka","bazooka_command");
	register_clcmd("say_team /bazooka","bazooka_command");
}

public plugin_precache()
{
	for (new i = 0; i < sizeof(classModels); i++) {
		precache_model(classModels[i]);
	}

	for (new i = 0; i < sizeof(classSprites); i++) {
		sprite[i] = precache_model(classSprites[i]);
	}
}

public client_disconnected(id)
	cod_remove_ents(id, "missile");

public cod_class_enabled(id, promotion)
{
	cod_set_user_multijumps(id, 1, CLASS);

	set_bit(id, classActive);

	g_lastButtons[id]=0;
	bazookaMissiles[id] = MISSILES;
	lastBazookaMissile[id] = -3.0;
}

public cod_class_disabled(id)
{
	cod_remove_ents(id,"missile");
	rem_bit(id, classActive);
	rem_bit(id, bazookaActive);

	bazookaMissiles[id] = 0;
}

public cod_class_spawned(id, respawn)
{
	g_lastButtons[id]=0;
	rem_bit(id, bazookaActive);

	if (!respawn) {
		bazookaMissiles[id] = MISSILES;
		lastBazookaMissile[id] = -3.0;
	}
}

public cod_new_round()
	cod_remove_ents(0, "missile");

public cod_weapon_deploy(id, weapon, ent)
	rem_bit(id, bazookaActive);

public cod_cmd_start(id, button, oldButton, flags, playerState)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return;
	if (!get_bit(id, classActive)) return;
	oldButton=g_lastButtons[id];
	g_lastButtons[id]=button;

	if (button & IN_RELOAD && !(oldButton & IN_RELOAD) && cod_get_user_weapon(id) == CSW_KNIFE) {
		if(get_bit(id,bazookaActive))holster_bazooka(id);
		else equip_bazooka(id);
	}

	if (get_bit(id, bazookaActive) && button & IN_ATTACK && !(oldButton & IN_ATTACK)) {
		shoot_missile(id);
	}
}

public shoot_missile(id)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return;
	if (!is_user_alive(id)) return;

	if (!bazookaMissiles[id]) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "You have used all bazooka missiles this life!");

		return;
	}

	if (lastBazookaMissile[id] + 3.0 > get_gametime()) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.35, 0, 0.0, 1.25, 0.0, 0.0, "You can fire a missile once every 3 seconds!");

		return;
	}

	lastBazookaMissile[id] = get_gametime();
	bazookaMissiles[id]--;

	new Float:origin[3], Float:angle[3], Float:velocity[3];

	pev(id, pev_origin, origin);
	pev(id, pev_v_angle, angle);

	new Float:view[3],Float:direction[3];pev(id,pev_view_ofs,view);
	for(new i=0;i<3;i++)origin[i]+=view[i];
	angle_vector(angle,ANGLEVECTOR_FORWARD,direction);
	for(new i=0;i<3;i++)origin[i]+=direction[i]*24.0;
	new ent = create_entity("info_target");
	if(!is_valid_ent(ent))return;
	g_shots++;

	set_pev(ent, pev_classname, "missile");
	engfunc(EngFunc_SetModel, ent, classModels[MISSILE]);

	set_pev(ent, pev_solid, SOLID_BBOX);
	set_pev(ent, pev_movetype, MOVETYPE_FLY);
	set_pev(ent, pev_owner, id);
	set_pev(ent,pev_nextthink,get_gametime()+10.0);
	set_pev(ent, pev_mins, Float:{-1.0, -1.0, -1.0});
	set_pev(ent, pev_maxs, Float:{1.0, 1.0, 1.0});
	set_pev(ent, pev_gravity, 0.3);

	velocity_by_aim(id, 1250, velocity);

	angle[0] *= -1.0;

	engfunc(EngFunc_SetOrigin,ent,origin);
	set_pev(ent, pev_velocity, velocity);
	set_pev(ent, pev_angles, angle);

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(ent);
	write_short(sprite[TRAIL]);
	write_byte(6);
	write_byte(3);
	write_byte(224);
	write_byte(224);
	write_byte(255);
	write_byte(100);
	message_end();

	cod_emit_sound(id, SOUND_DEPLOY, VOLUME_NORMAL, CHAN_ITEM);
}

public touch_missile(ent,other)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return;
	if (!is_valid_ent(ent)) return;

	if(other==pev(ent,pev_owner))return;
	g_hits++;
	new origin[3];

	new Float:position[3];pev(ent,pev_origin,position);for(new i=0;i<3;i++)origin[i]=floatround(position[i]);

	origin[2] += 1;

	cod_make_explosion(ent, 0, 1, 250.0, 125.0, 0.5);

	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	write_coord(origin[0]);
	write_coord(origin[1]);
	write_coord(origin[2]);
	write_short(sprite[EXPLOSION]);
	write_byte(40);
	write_byte(30);
	write_byte(14);
	message_end();

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(5);
	write_coord(origin[0]);
	write_coord(origin[1]);
	write_coord(origin[2]);
	write_short(sprite[SMOKE]);
	write_byte(35);
	write_byte(5);
	message_end();

	remove_entity(ent);
}

public sound_emit(ent, channel, const sample[])
{
	if(mm_get_active_mode()!=MM_MODE_COD)return PLUGIN_CONTINUE;
	if (!is_user_alive(ent) || !get_bit(ent, classActive)) return FMRES_IGNORED;

	static modelName[32];

	entity_get_string(ent, EV_SZ_viewmodel, modelName, charsmax(modelName));

	if (equal(modelName, classModels[V_BAZOOKA])) {
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
public mm_tank_status(){server_print("[CoD Tank] shots=%d impacts=%d classname=missile registered_touch=missile",g_shots,g_hits);}

public expire_missile(ent){if(is_valid_ent(ent))remove_entity(ent);}

// This is a persistent alternate weapon in the knife slot. Switching guns holsters it.
equip_bazooka(id)
{
	if(cod_get_user_weapon(id)!=CSW_KNIFE)engclient_cmd(id,"weapon_knife");
	if(cod_get_user_weapon(id)!=CSW_KNIFE)return;
	set_bit(id,bazookaActive);
	entity_set_string(id,EV_SZ_viewmodel,classModels[V_BAZOOKA]);
	entity_set_string(id,EV_SZ_weaponmodel,classModels[P_BAZOOKA]);
}
holster_bazooka(id)
{
	rem_bit(id,bazookaActive);
	new item=get_member(id,m_pActiveItem);
	if(!is_nullent(item) && get_member(item,m_iId)==WEAPON_KNIFE)ExecuteHamB(Ham_Item_Deploy,item);
}
public bazooka_command(id)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return PLUGIN_CONTINUE;
	if(!is_user_alive(id) || !get_bit(id,classActive))return PLUGIN_HANDLED;
	if(get_bit(id,bazookaActive))holster_bazooka(id);
	else equip_bazooka(id);
	return PLUGIN_HANDLED;
}
public bazooka_buttons(id,uc,seed)
{
	if(mm_get_active_mode()!=MM_MODE_COD || !is_user_alive(id) || !get_bit(id,bazookaActive) || !get_bit(id,classActive))return FMRES_IGNORED;
	// The core already handled firing; prevent an invisible knife slash/stab.
	set_uc(uc,UC_Buttons,get_uc(uc,UC_Buttons) & ~(IN_ATTACK|IN_ATTACK2));
	return FMRES_IGNORED;
}
