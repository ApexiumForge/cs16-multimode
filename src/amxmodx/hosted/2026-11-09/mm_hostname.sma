#include <amxmodx>
#include <mm_mode_api>

new g_hostname, g_base_name;

public plugin_init()
{
    register_plugin("Mode Hostname", "1.0.0", "Torbeshi");
    g_hostname = get_cvar_pointer("hostname");
    g_base_name = register_cvar("mm_hostname_base", "Torbeshi");
}

public plugin_cfg()
{
    // Apply after the map's startup configs have run.
    set_task(1.0, "refresh_hostname");
}

public mm_mode_changed(old_mode, new_mode)
{
    refresh_hostname();
}

public refresh_hostname()
{
    new base[64], mode[32], hostname[96];
    get_pcvar_string(g_base_name, base, charsmax(base));
    new MmMode:active_mode = mm_get_active_mode();
    switch (active_mode)
    {
        case MM_MODE_ARMS_RACE: copy(mode, charsmax(mode), "GunGame");
        case MM_MODE_SURF: copy(mode, charsmax(mode), "Surf");
        default: mm_get_mode_name(active_mode, mode, charsmax(mode));
    }
    formatex(hostname, charsmax(hostname), "%s [%s]", base, mode);
    set_pcvar_string(g_hostname, hostname);
}
