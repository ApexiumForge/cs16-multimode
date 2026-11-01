Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'regamedll-trial-common.ps1')

$script:MmReGameVersion = '5.30.0.814'
$script:MmReGameArchiveSha256 = '457F5C96A4D10280FCAD47F106CBD5BE86363A47DF1CCAB91C514E9D1BC6FD18'
$script:MmReGameSignatureSha256 = '7A674DA4EE0B67F9013E99190609F1295A82F05FE5030C12786D527F731C172C'
$script:MmManagedPlugins = @('mm_core', 'mm_mode_manager', 'mm_arcade_rounds', 'mm_modes', 'mm_classic', 'mm_deathmatch', 'mm_armsrace', 'mm_awponly')
$script:MmObsoleteDevelopmentPlugins = @('mm_classic_test', 'mm_sounds_test')
$script:MmGameDllFiles = @('cstrike\dlls\mp.dll', 'cstrike\game.cfg', 'cstrike\game_init.cfg', 'cstrike\delta.lst')
$script:MmPreservedFiles = @(
    'hlds.exe',
    'cstrike\liblist.gam',
    'cstrike\addons\metamod\plugins.ini',
    'cstrike\addons\amxmodx\configs\users.ini',
    'cstrike\addons\amxmodx\configs\admins_simple.ini',
    'cstrike\addons\amxmodx\configs\amxx.cfg',
    'cstrike\server.cfg'
)

function Get-MmProductionMigrationDir {
    param(
        [Parameter(Mandatory = $true)][string]$StateDir,
        [Parameter(Mandatory = $true)][string]$MigrationId
    )

    if ($MigrationId -notmatch '^\d{8}-\d{6}$') { throw "Invalid migration ID: $MigrationId" }
    $migrationDir = Join-Path (Get-MmFullPath $StateDir) $MigrationId
    Assert-MmPathWithin -Path $migrationDir -Root $StateDir -Message 'Migration directory must remain inside StateDir.'
    return $migrationDir
}

function Read-MmProductionManifest {
    param(
        [Parameter(Mandatory = $true)][string]$StateDir,
        [Parameter(Mandatory = $true)][string]$MigrationId
    )

    $manifestPath = Join-Path (Get-MmProductionMigrationDir -StateDir $StateDir -MigrationId $MigrationId) 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Migration manifest is missing: $manifestPath" }
    return Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
}

function Write-MmProductionManifest {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$StateDir,
        [Parameter(Mandatory = $true)][string]$MigrationId
    )

    $manifestPath = Join-Path (Get-MmProductionMigrationDir -StateDir $StateDir -MigrationId $MigrationId) 'manifest.json'
    $Manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

function Read-MmValidatedTrialInstall {
    param(
        [Parameter(Mandatory = $true)][string]$TrialDir,
        [Parameter(Mandatory = $true)][string]$TrialStateDir
    )

    $TrialDir = Get-MmFullPath $TrialDir
    $TrialStateDir = Get-MmFullPath $TrialStateDir
    $trialManifest = Read-MmTrialManifest -StateDir $TrialStateDir
    Assert-MmManifestPaths -Manifest $trialManifest -TrialDir $TrialDir -StateDir $TrialStateDir

    $installPath = Join-Path $TrialStateDir 'install.json'
    if (-not (Test-Path -LiteralPath $installPath -PathType Leaf)) { throw "Trial install record is missing: $installPath" }
    $install = Get-Content -LiteralPath $installPath -Raw | ConvertFrom-Json
    if ($install.Status -ne 'installed' -or $install.Version -ne $script:MmReGameVersion) {
        throw "Trial must contain ReGameDLL_CS $($script:MmReGameVersion) with installed status."
    }
    if ($install.ArchiveSha256 -ne $script:MmReGameArchiveSha256 -or $install.SignatureSha256 -ne $script:MmReGameSignatureSha256) {
        throw 'Trial install record does not match the pinned official release hashes.'
    }
    foreach ($record in $install.InstalledFiles) {
        $source = Join-Path $TrialDir $record.RelativePath
        if ((Get-MmSha256 $source) -ne $record.Sha256) { throw "Trial ReGameDLL file failed verification: $($record.RelativePath)" }
    }
    foreach ($name in $script:MmManagedPlugins) {
        $plugin = Join-Path $TrialDir "cstrike\addons\amxmodx\plugins\$name.amxx"
        if (-not (Test-Path -LiteralPath $plugin -PathType Leaf)) { throw "Managed plugin is missing from the validated trial: $name.amxx" }
    }
    return $install
}

function Get-MmManagedTargetFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$TrialDir
    )

    $records = @()
    foreach ($relativePath in $script:MmGameDllFiles) {
        $records += [pscustomobject]@{ RelativePath = $relativePath; Source = (Join-Path $TrialDir $relativePath); Kind = 'GameDLL' }
    }
    foreach ($name in $script:MmManagedPlugins) {
        $relativePath = "cstrike\addons\amxmodx\plugins\$name.amxx"
        $records += [pscustomobject]@{ RelativePath = $relativePath; Source = (Join-Path $TrialDir $relativePath); Kind = 'Plugin' }
    }
    $configRoot = Join-Path $RepoRoot 'config\cstrike\addons\amxmodx\configs'
    $records += [pscustomobject]@{
        RelativePath = 'cstrike\addons\amxmodx\configs\mm_classic.cfg'
        Source = (Join-Path $configRoot 'mm_classic.cfg')
        Kind = 'Config'
    }
    Get-ChildItem -LiteralPath (Join-Path $configRoot 'mm_modes') -Filter '*.cfg' -File | Sort-Object Name | ForEach-Object {
        $records += [pscustomobject]@{
            RelativePath = "cstrike\addons\amxmodx\configs\mm_modes\$($_.Name)"
            Source = $_.FullName
            Kind = 'Config'
        }
    }
    $records += [pscustomobject]@{
        RelativePath = 'cstrike\addons\amxmodx\configs\plugins.ini'
        Source = $null
        Kind = 'PluginList'
    }
    return $records
}

function Get-MmFileRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $path = Join-Path $Root $RelativePath
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    return [pscustomobject]@{
        RelativePath = $RelativePath
        Existed = $exists
        Sha256 = if ($exists) { Get-MmSha256 $path } else { $null }
    }
}

function Assert-MmManifestBinding {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$ProductionDir,
        [Parameter(Mandatory = $true)][string]$TrialDir,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    foreach ($binding in @(
        @{ Actual = $Manifest.ProductionDir; Expected = $ProductionDir; Name = 'production' },
        @{ Actual = $Manifest.TrialDir; Expected = $TrialDir; Name = 'trial' },
        @{ Actual = $Manifest.RepoRoot; Expected = $RepoRoot; Name = 'repository' }
    )) {
        if (-not [string]::Equals((Get-MmFullPath $binding.Actual), (Get-MmFullPath $binding.Expected), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Manifest $($binding.Name) path does not match the requested path."
        }
    }
    Assert-MmDifferentPath -First $ProductionDir -Second $TrialDir -Message 'Production and trial paths must be different.'
}

function Assert-MmFilesMatchRecords {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)]$Records,
        [Parameter(Mandatory = $true)][string]$Context
    )

    foreach ($record in $Records) {
        $path = Join-Path $Root $record.RelativePath
        if ($record.Existed) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-MmSha256 $path) -ne $record.Sha256) {
                throw "$Context changed after the manifest was created: $($record.RelativePath)"
            }
        } elseif (Test-Path -LiteralPath $path) {
            throw "$Context appeared after the manifest was created: $($record.RelativePath)"
        }
    }
}

function Get-MmProductionPluginsIniContent {
    param([Parameter(Mandatory = $true)][string]$PluginsIni)

    $managedNames = @($script:MmManagedPlugins + $script:MmObsoleteDevelopmentPlugins) -join '|'
    $pattern = "^\s*(?:$managedNames)\.amxx(?:\s|;|$)"
    $existing = @(Get-Content -LiteralPath $PluginsIni | Where-Object {
        $_ -notmatch $pattern -and $_ -ne '; Multi-Mode Network'
    })
    while ($existing.Count -gt 0 -and [string]::IsNullOrWhiteSpace($existing[-1])) {
        if ($existing.Count -eq 1) { $existing = @(); break }
        $existing = @($existing[0..($existing.Count - 2)])
    }
    return @($existing + '' + '; Multi-Mode Network' + ($script:MmManagedPlugins | ForEach-Object { "${_}.amxx" }))
}

function Test-MmPluginRegistration {
    param(
        [Parameter(Mandatory = $true)][string]$PluginsIni,
        [Parameter(Mandatory = $true)][string]$PluginName
    )

    if (-not (Test-Path -LiteralPath $PluginsIni -PathType Leaf)) { return $false }
    return $null -ne (Select-String -LiteralPath $PluginsIni -Pattern "^\s*$([regex]::Escape($PluginName))\.amxx(?:\s|;|$)" | Select-Object -First 1)
}
