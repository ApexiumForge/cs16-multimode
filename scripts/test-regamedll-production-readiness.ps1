[CmdletBinding()]
param(
    [string]$ProductionDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$TrialDir = (Join-Path $PSScriptRoot '..\runtime\hlds-regamedll-trial'),
    [string]$TrialStateDir = (Join-Path $PSScriptRoot '..\.regamedll-trial')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\regamedll-production-common.ps1')

$ProductionDir = Get-MmFullPath $ProductionDir
$TrialDir = Get-MmFullPath $TrialDir
$TrialStateDir = Get-MmFullPath $TrialStateDir
Assert-MmDifferentPath -First $ProductionDir -Second $TrialDir -Message 'Production and trial paths must be different.'
Assert-MmServerStopped -ServerDir $ProductionDir
$install = Read-MmValidatedTrialInstall -TrialDir $TrialDir -TrialStateDir $TrialStateDir

$requiredProductionFiles = @('hlds.exe', 'cstrike\dlls\mp.dll', 'cstrike\liblist.gam', 'cstrike\addons\metamod\plugins.ini', 'cstrike\addons\amxmodx\configs\plugins.ini')
foreach ($relativePath in $requiredProductionFiles) {
    $path = Join-Path $ProductionDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Production prerequisite is missing: $path" }
}

$pluginsIni = Join-Path $ProductionDir 'cstrike\addons\amxmodx\configs\plugins.ini'
$pluginComparison = foreach ($name in $script:MmManagedPlugins) {
    $productionPlugin = Join-Path $ProductionDir "cstrike\addons\amxmodx\plugins\$name.amxx"
    $trialPlugin = Join-Path $TrialDir "cstrike\addons\amxmodx\plugins\$name.amxx"
    [pscustomobject]@{
        Plugin = "$name.amxx"
        Production = if (Test-Path -LiteralPath $productionPlugin -PathType Leaf) { Get-MmSha256 $productionPlugin } else { 'MISSING' }
        Trial = Get-MmSha256 $trialPlugin
    }
}

[pscustomobject]@{
    Ready = $true
    ProductionDir = $ProductionDir
    ProductionPort = 27015
    TrialDir = $TrialDir
    TrialPort = 27016
    ReGameDllVersion = $install.Version
    ProductionGameDllSha256 = Get-MmSha256 (Join-Path $ProductionDir 'cstrike\dlls\mp.dll')
    TrialGameDllSha256 = $install.InstalledGameDllSha256
    ObsoleteDevelopmentPluginsEnabled = @($script:MmObsoleteDevelopmentPlugins | Where-Object { Test-MmPluginRegistration -PluginsIni $pluginsIni -PluginName $_ }) -join ', '
    ManagedPluginDifferences = @($pluginComparison | Where-Object { $_.Production -ne $_.Trial }).Count
    MetamodConfigurationMatchesTrial = (Get-MmSha256 (Join-Path $ProductionDir 'cstrike\addons\metamod\plugins.ini')) -eq (Get-MmSha256 (Join-Path $TrialDir 'cstrike\addons\metamod\plugins.ini'))
} | Format-List

$pluginComparison | Format-Table -AutoSize
Write-Host 'Readiness checks passed. No production file was changed.'
