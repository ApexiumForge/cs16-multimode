# Optional firearm viewmodels

`optional/mm_weapon_models.sma` replaces 24 firearm viewmodels on deployment. Butterfly, grenades, world models and gameplay remain independently managed. `mm_weapon_models 0` disables subsequent replacements; switch weapons to restore the default viewmodel.

Prepare a separately obtained manual-inspect pack using `scripts/prepare-weapon-models.ps1 -PackDir <pack> -OutputDir <new-staging-directory>`. It verifies GoldSrc version-10 model headers, rejects external texture/sequence dependencies, normalizes animation sound references into hashed names, and creates a sound manifest. Missing sounds are reported and their animation events disabled in the staged copy. Original files are untouched.

Compile the optional source with AMXX, install the staged models/sound directories under cstrike, and register mm_weapon_models.amxx once. Resources must be installed before plugin loading. No stock files are replaced. The plugin fails closed if its sound manifest is missing/incomplete.

Rollback: comment the plugin registration and reload the map at a safe time. Leave resources available for connected clients. Game-server downloads are used initially; public FastDL/Git publication of third-party media is pending redistribution rights. The 24 models occupy approximately 125 MB uncompressed, so first connections can take time.
