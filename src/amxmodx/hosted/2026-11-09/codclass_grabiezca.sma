#include <amxmodx>
#include <fakemeta>
#include <cod>
#include <mm_mode_api>

#define PLUGIN "CoD Class Grabiezca"
#define PLUGIN_VERSION "1.1.0"
#define AUTHOR "O'Zone"

#define NAME "Raider"
#define DESCRIPTION "25% chance to steal the victim's item; refill magazine on kill."
#define FRACTION "Standard Classes"
#define WEAPONS      (1<<CSW_FAMAS)|(1<<CSW_USP)
#define HEALTH       10
#define INTELLIGENCE 0
#define STRENGTH     5
#define STAMINA      0
#define CONDITION    15

public plugin_init()
{
	register_plugin(PLUGIN, PLUGIN_VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_kill(killer, victim, hitPlace)
{
	cod_refill_ammo(killer);

	if (!cod_get_user_resistance(victim) && cod_get_user_item(victim) && cod_get_user_item(killer) != cod_get_user_item(victim) && cod_percent_chance(25)) {
		show_question(killer, victim);
	}
}

public show_question(id, victim)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return;
	new menuTitle[64], itemName[64], tempId[12];

	cod_get_item_name(cod_get_user_item(victim), itemName, charsmax(itemName));

	num_to_str(get_user_userid(victim), tempId, charsmax(tempId));

	format(menuTitle, charsmax(menuTitle), "\ySteal perk: \r%s\y?", itemName);

	new menu = menu_create(menuTitle, "show_question_handle");

	menu_additem(menu, "Take perk", tempId);
	menu_setprop(menu, MPROP_EXITNAME, "Keep current perk");

	menu_display(id, menu);
}

public show_question_handle(id, menu, item)
{
	if(mm_get_active_mode()!=MM_MODE_COD)return;
	if (item) {
		cod_play_sound(id, SOUND_EXIT);

		menu_destroy(menu);

		return;
	}

	cod_play_sound(id, SOUND_SELECT);

	new itemData[12], victim, itemAccess, menuCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	victim = find_player("k",str_to_num(itemData));
	if(!victim || !is_user_connected(victim) || cod_get_user_resistance(victim)){menu_destroy(menu);return;}

	new itemValue, item = cod_get_user_item(victim, itemValue);

	menu_destroy(menu);

	if (!cod_get_user_item(victim) || cod_get_user_item(id) == cod_get_user_item(victim)) return;

	new thiefName[32];

	get_user_name(id, thiefName, charsmax(thiefName));

	cod_print_chat(victim, "Your perk was stolen by^3 %s^1.", thiefName);

	cod_set_user_item(victim);
	cod_set_user_item(id, item, itemValue, true);
}