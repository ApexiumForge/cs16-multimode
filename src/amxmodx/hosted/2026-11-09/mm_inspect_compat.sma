#include <amxmodx>
#include <cstrike>
#include <reapi>
#include <fakemeta>
new g_calls
public plugin_natives()
{
    register_library("mm_inspect_compat")
    register_native("mm_inspect_actual_weapon", "mm_actual_weapon")
}
public plugin_init()
{
    register_plugin("Weapon Inspector Inventory Compatibility", "1.0.0", "Torbeshi")
    register_srvcmd("mm_inspect_compat_status", "mm_status")
    log_amx("Inspector uses real active inventory instead of the custom-crosshair HUD weapon ID.")
}
public mm_actual_weapon(plugin,params)
{
    g_calls++
    new id=get_param(1),weapon,clip,ammo
    if (id>=1 && id<=MaxClients && is_user_alive(id))
    {
        new item=get_member(id,m_pActiveItem)
        if (!is_nullent(item))
        {
            weapon=get_member(item,m_iId);clip=get_member(item,m_Weapon_iClip)
            if (weapon>0 && weapon<=CSW_P90 && weapon!=CSW_KNIFE) ammo=cs_get_user_bpammo(id,weapon)
        }
    }
    if (params>=2) set_param_byref(2,clip)
    if (params>=3) set_param_byref(3,ammo)
    return weapon
}
public mm_status()
{
    server_print("[Inspect Compat] version=1.0.0 real_weapon_queries=%d",g_calls)
    for(new id=1;id<=MaxClients;id++)
    {
        if(!is_user_alive(id))continue
        new item=get_member(id,m_pActiveItem),model[96]
        pev(id,pev_viewmodel2,model,charsmax(model))
        server_print("[Inspect Compat] client=%d hud_weapon=%d actual_weapon=%d model=%s",id,get_user_weapon(id),is_nullent(item)?0:get_member(item,m_iId),model)
    }
}
