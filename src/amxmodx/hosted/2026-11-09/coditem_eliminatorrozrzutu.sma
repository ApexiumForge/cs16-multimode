#include <amxmodx>
#include <cod>
#include <fakemeta>
#include <reapi>
#include <mm_mode_api>

#define PLUGIN "CoD Item Eliminator Rozrzutu"
#define PLUGIN_VERSION "1.2.0"
#define AUTHOR "O'Zone"

#define NAME "No Recoil"
#define DESCRIPTION "Remove weapon recoil, camera kick and screen shake; 25% less remaining spread."

new bool:mmActive[33];

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
	register_message(get_user_msgid("ScreenShake"), "mm_block_shake");
	register_forward(FM_PlayerPreThink, "mm_clear_camera", 1);
	register_forward(FM_PlayerPostThink, "mm_clear_camera", 1);
	RegisterHookChain(RG_CBasePlayerWeapon_KickBack, "mm_block_kick", false);
	RegisterHookChain(RG_CBaseEntity_FireBullets3, "mm_tighten_bullets", false);
	RegisterHookChain(RG_CBaseEntity_FireBuckshots, "mm_tighten_pellets", false);
}

public cod_item_enabled(id, value)
{
	mmActive[id] = true;
	cod_set_user_recoil_eliminator(id, true, ITEM);
	if (is_user_alive(id)) set_pev(id, pev_punchangle, Float:{0.0, 0.0, 0.0});
	// Cancel any shake already running when the perk is received.
	message_begin(MSG_ONE, get_user_msgid("ScreenShake"), _, id);
	write_short(0); write_short(0); write_short(0); message_end();
}
public cod_item_disabled(id) { mmActive[id] = false; }
public client_connect(id) { mmActive[id] = false; }
public client_disconnected(id) { mmActive[id] = false; }
public mm_clear_camera(id)
{
	if (mm_get_active_mode() == MM_MODE_COD && mmActive[id] && is_user_alive(id))
		set_pev(id, pev_punchangle, Float:{0.0, 0.0, 0.0});
	return FMRES_IGNORED;
}
public mm_block_shake(message, destination, id)
{
	if (mm_get_active_mode() != MM_MODE_COD) return PLUGIN_CONTINUE;
	if (id > 0 && id <= MaxClients)
		return mmActive[id] && is_user_alive(id) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
	// Broadcast shake: defer a copy for each connected recipient so the
	// perk can suppress only its holder without changing anyone else's view.
	new data[35];
	data[0] = get_msg_arg_int(1); data[1] = get_msg_arg_int(2); data[2] = get_msg_arg_int(3);
	for (new player = 1; player <= MaxClients; player++)
		if (is_user_connected(player)) data[player + 2] = get_user_userid(player);
	set_task(0.01, "mm_deliver_shake", 0, data, sizeof data);
	return PLUGIN_HANDLED;
}
public mm_deliver_shake(data[])
{
	for (new id = 1; id <= MaxClients; id++) {
		if (!data[id + 2] || !is_user_connected(id) || data[id + 2] != get_user_userid(id)) continue;
		if (mm_get_active_mode() == MM_MODE_COD && mmActive[id] && is_user_alive(id)) continue;
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenShake"), _, id);
		write_short(data[0]); write_short(data[1]); write_short(data[2]); message_end();
	}
}
bool:mm_holder(id)
{
	return id>0 && id<=MaxClients && mm_get_active_mode()==MM_MODE_COD && mmActive[id] && is_user_alive(id);
}
public mm_block_kick(weapon)
{
	if(!is_entity(weapon))return HC_CONTINUE;
	new id=get_member(weapon,m_pPlayer);
	if(!mm_holder(id))return HC_CONTINUE;
	set_pev(id,pev_punchangle,Float:{0.0,0.0,0.0});
	return HC_SUPERCEDE;
}
public mm_tighten_bullets(id,Float:source[3],Float:direction[3],Float:spread)
{
	if(mm_holder(id))SetHookChainArg(4,ATYPE_FLOAT,spread*0.75);
	return HC_CONTINUE;
}
public mm_tighten_pellets(id,shots,Float:source[3],Float:direction[3],Float:spread[3])
{
	if(!mm_holder(id))return HC_CONTINUE;
	new Float:tighter[3];for(new i=0;i<3;i++)tighter[i]=spread[i]*0.75;
	SetHookChainArg(5,ATYPE_VECTOR,tighter);
	return HC_CONTINUE;
}
