#include <amxmodx>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Item Ciemne Okulary"
#define PLUGIN_VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME "Dark Glasses"
#define DESCRIPTION "Flash immunity and two flashbangs."

new itemActive;

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);

	register_message(get_user_msgid("ScreenFade"), "message_screen_fade");
}

public cod_item_enabled(id, value)
{
	cod_give_weapon(id, CSW_FLASHBANG, 2);

	set_bit(id, itemActive);
}

public cod_item_spawned(id, respawn)
{
	if (!respawn) {
		cod_give_weapon(id, CSW_FLASHBANG, 2);
	}
}

public cod_item_disabled(id)
	rem_bit(id, itemActive);

public message_screen_fade(msgType, msgID, id)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return PLUGIN_CONTINUE;
	if (get_bit(id, itemActive) && get_msg_arg_int(4) == 255 && get_msg_arg_int(5) == 255 && get_msg_arg_int(6) == 255) {
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}