#include <amxmodx>
#include <amxmisc>
#include <mm_mode_api>
#include <zombieplague>

#define MAX_AMMO_PACKS 1000000

public plugin_init()
{
    register_plugin("Classic ZP Ammo Administration", "1.0.0", "ApexiumForge")
    if (mm_get_active_mode() != MM_MODE_ZOMBIE) return
    register_concmd("amx_ammo", "give_ammo", ADMIN_RCON, "<name|#userid> <amount> - Give Zombie ammo packs")
    register_concmd("amx_setammo", "set_ammo", ADMIN_RCON, "<name|#userid> <amount> - Set Zombie ammo packs")
}

public give_ammo(id, level, cid) return change_ammo(id, level, cid, false)
public set_ammo(id, level, cid) return change_ammo(id, level, cid, true)

change_ammo(id, level, cid, bool:replace)
{
    if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
    if (mm_get_active_mode() != MM_MODE_ZOMBIE)
    {
        console_print(id, "[ZP] This command is only available in Zombie Plague.")
        return PLUGIN_HANDLED
    }
    new target_arg[32], amount_arg[32]
    read_argv(1, target_arg, charsmax(target_arg))
    read_argv(2, amount_arg, charsmax(amount_arg))
    new length = strlen(amount_arg)
    if (!length || length > 7 || !is_str_num(amount_arg))
    {
        console_print(id, "[ZP] Amount must be a whole number from 0 to %d.", MAX_AMMO_PACKS)
        return PLUGIN_HANDLED
    }
    new amount = str_to_num(amount_arg)
    if (amount > MAX_AMMO_PACKS || (!replace && amount == 0))
    {
        console_print(id, "[ZP] Give: 1-%d. Set: 0-%d.", MAX_AMMO_PACKS, MAX_AMMO_PACKS)
        return PLUGIN_HANDLED
    }
    new target = cmd_target(id, target_arg, CMDTARGET_ALLOW_SELF)
    if (!target) return PLUGIN_HANDLED
    new old_balance = zp_get_user_ammo_packs(target)
    if (!replace && (old_balance < 0 || old_balance > MAX_AMMO_PACKS - amount))
    {
        console_print(id, "[ZP] Resulting balance cannot exceed %d ammo packs.", MAX_AMMO_PACKS)
        return PLUGIN_HANDLED
    }
    new balance = replace ? amount : old_balance + amount
    zp_set_user_ammo_packs(target, balance)
    new target_name[32], admin_name[32]
    get_user_name(target, target_name, charsmax(target_name))
    if (id) get_user_name(id, admin_name, charsmax(admin_name))
    else copy(admin_name, charsmax(admin_name), "Server Console")
    console_print(id, "[ZP] %s: ammo packs %d -> %d.", target_name, old_balance, balance)
    client_print_color(target, print_team_default, "^4[^1ZP^4]^1 Admin ^3%s^1 %s your ammo packs. Balance: ^3%d^1.", admin_name, replace ? "set" : "increased", balance)
    if (id && id != target)
        client_print_color(id, print_team_default, "^4[^1ZP^4]^1 Updated ^3%s^1: ^3%d^1 ammo packs.", target_name, balance)
    log_amx("%s changed %s (#%d) ammo packs: %d -> %d (set=%d)", admin_name, target_name, get_user_userid(target), old_balance, balance, replace)
    return PLUGIN_HANDLED
}
