#include <amxmodx>
#include <fakemeta>
#include <cod>
#include <mm_mode_api>
new bool:g_active[33];
public plugin_init(){register_plugin("CoD Item Xray Vision","1.0.0","ApexiumForge");cod_register_item("Xray Vision","See invisible enemies normally. Does not see through walls; SWAT Shield counters it.");register_forward(FM_AddToFullPack,"mm_xray_packet",1);register_srvcmd("mm_cod_expert_status","mm_expert_status");}
public cod_item_enabled(id,value){g_active[id]=true;}
public cod_item_disabled(id){g_active[id]=false;}
public client_connect(id){g_active[id]=false;}
public client_disconnected(id){g_active[id]=false;}
public mm_xray_packet(es,e,ent,host,hostflags,player,pSet)
{
    if(!player || host<1 || host>MaxClients || ent<1 || ent>MaxClients || !g_active[host] || mm_get_active_mode()!=MM_MODE_COD || !get_orig_retval())return FMRES_IGNORED;
    if(!is_user_alive(host) || !is_user_alive(ent) || host==ent || get_user_team(host)==get_user_team(ent) || cod_get_user_resistance(ent))return FMRES_IGNORED;
    if(get_es(es,ES_RenderMode)!=kRenderNormal && get_es(es,ES_RenderAmt)<255)
    {
        set_es(es,ES_RenderMode,kRenderNormal);set_es(es,ES_RenderAmt,255);
    }
    return FMRES_IGNORED;
}

public mm_expert_status()
{
    new const names[][]={"Xray Vision","HE Expert","M4A1 Expert","AWP Expert","Scout Expert","No Recoil","AK47 Expert","Jetpack","Super Jetpack"};
    for(new i=0;i<sizeof names;i++)server_print("[CoD Expert] %s item_id=%d",names[i],cod_get_item_id(names[i]));
    server_print("[CoD Expert] rifle_chance=12 regular_lift=510 regular_cap=675 super_lift=690 super_cap=900 ground_only=1 cooldown=6 shield_counter=1");
}
