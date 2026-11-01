[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("mm-phase1-regression-" + [guid]::NewGuid().ToString('N'))

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null

    # Regression: SteamCMD may return 7 even after its explicit success result.
    $steamDir = Join-Path $testRoot 'steam-success'
    New-Item -ItemType Directory -Path $steamDir | Out-Null
    $steamSuccessCommand = Join-Path $steamDir 'steamcmd.cmd'
    Set-Content -LiteralPath $steamSuccessCommand -Encoding ASCII -Value @'
@echo off
set "root=%~2"
echo %*>"%root%\steamcmd-args.txt"
mkdir "%root%\cstrike\dlls" 2>nul
echo fixture>"%root%\hlds.exe"
echo fixture>"%root%\swds.dll"
echo fixture>"%root%\cstrike\liblist.gam"
echo fixture>"%root%\cstrike\dlls\mp.dll"
mkdir "%root%\steamapps" 2>nul
echo "BetaKey" "steam_legacy">"%root%\steamapps\appmanifest_90.acf"
echo Success! App '90' fully installed.
exit /b 7
'@
    $installDir = Join-Path $testRoot 'hlds-success'
    & (Join-Path $repoRoot 'scripts\install-server.ps1') -InstallDir $installDir -SteamCmdDir $steamDir -SteamCmdExecutable $steamSuccessCommand
    Assert-True ($LASTEXITCODE -eq 7) 'The fixture must preserve SteamCMD exit code 7.'
    Assert-True (Test-Path -LiteralPath (Join-Path $installDir 'hlds.exe') -PathType Leaf) 'A confirmed installation must be accepted.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $installDir 'steamcmd-args.txt') -Raw) -match '-beta steam_legacy validate') 'The installer must request the steam_legacy branch.'

    # Regression: the same managed, non-empty installation can be validated again.
    & (Join-Path $repoRoot 'scripts\install-server.ps1') -InstallDir $installDir -SteamCmdDir $steamDir -SteamCmdExecutable $steamSuccessCommand
    Assert-True (Test-Path -LiteralPath (Join-Path $installDir 'cstrike\server.cfg') -PathType Leaf) 'A repeated invocation must complete safely.'

    # Negative check: required files alone do not excuse a nonzero result when SteamCMD did not report success.
    $failedSteamDir = Join-Path $testRoot 'steam-failure'
    New-Item -ItemType Directory -Path $failedSteamDir | Out-Null
    $steamFailureCommand = Join-Path $failedSteamDir 'steamcmd.cmd'
    Set-Content -LiteralPath $steamFailureCommand -Encoding ASCII -Value @'
@echo off
set "root=%~2"
mkdir "%root%\cstrike\dlls" 2>nul
echo fixture>"%root%\hlds.exe"
echo fixture>"%root%\swds.dll"
echo fixture>"%root%\cstrike\liblist.gam"
echo fixture>"%root%\cstrike\dlls\mp.dll"
mkdir "%root%\steamapps" 2>nul
echo "BetaKey" "steam_legacy">"%root%\steamapps\appmanifest_90.acf"
echo ERROR! App '90' state is invalid.
exit /b 7
'@
    $failureObserved = $false
    try {
        & (Join-Path $repoRoot 'scripts\install-server.ps1') -InstallDir (Join-Path $testRoot 'hlds-failure') -SteamCmdDir $failedSteamDir -SteamCmdExecutable $steamFailureCommand
    } catch {
        $failureObserved = $_.Exception.Message -match 'not confirmed after 3 passes'
    }
    Assert-True $failureObserved 'A nonzero SteamCMD failure without its success result must not be accepted.'

    # Regression: capture compiler exit 0 immediately and require the exact output file independently.
    $serverDir = Join-Path $testRoot 'compiler-success-server'
    $scriptingDir = Join-Path $serverDir 'cstrike\addons\amxmodx\scripting'
    $configsDir = Join-Path $serverDir 'cstrike\addons\amxmodx\configs'
    New-Item -ItemType Directory -Path $scriptingDir -Force | Out-Null
    New-Item -ItemType Directory -Path $configsDir -Force | Out-Null
    $compilerSuccessCommand = Join-Path $scriptingDir 'amxxpc.cmd'
    Set-Content -LiteralPath $compilerSuccessCommand -Encoding ASCII -Value @'
@echo off
set "output="
:find_output
if "%~1"=="" goto write_output
set "argument=%~1"
if "%argument:~0,2%"=="-o" set "output=%argument:~2%"
shift
goto find_output
:write_output
echo compiled fixture>"%output%"
echo Done.
exit /b 0
'@
    Set-Content -LiteralPath (Join-Path $configsDir 'plugins.ini') -Encoding ASCII -Value '; fixture'
    & (Join-Path $repoRoot 'scripts\build-plugins.ps1') -ServerDir $serverDir -CompilerPath $compilerSuccessCommand
    Assert-True (Test-Path -LiteralPath (Join-Path $serverDir 'cstrike\addons\amxmodx\plugins\mm_core.amxx') -PathType Leaf) 'Compiler output must be detected at the expected path.'
    Assert-True (Test-Path -LiteralPath (Join-Path $serverDir 'cstrike\addons\amxmodx\plugins\mm_mode_manager.amxx') -PathType Leaf) 'The mode manager plugin must be compiled.'
    Assert-True (Test-Path -LiteralPath (Join-Path $serverDir 'cstrike\addons\amxmodx\plugins\mm_modes.amxx') -PathType Leaf) 'The mode-menu plugin must be compiled.'
    Assert-True (Test-Path -LiteralPath (Join-Path $serverDir 'cstrike\addons\amxmodx\plugins\mm_classic.amxx') -PathType Leaf) 'The Classic gameplay plugin must be compiled.'
    Assert-True (Test-Path -LiteralPath (Join-Path $serverDir 'cstrike\addons\amxmodx\plugins\mm_deathmatch.amxx') -PathType Leaf) 'The Deathmatch gameplay plugin must be compiled.'
    Assert-True (Select-String -LiteralPath (Join-Path $configsDir 'plugins.ini') -Pattern '^mm_mode_manager\.amxx$' -Quiet) 'The mode manager plugin must be enabled.'
    Assert-True (Select-String -LiteralPath (Join-Path $configsDir 'plugins.ini') -Pattern '^mm_modes\.amxx$' -Quiet) 'The mode-menu plugin must be enabled.'
    Assert-True (Test-Path -LiteralPath (Join-Path $configsDir 'mm_modes\classic.cfg') -PathType Leaf) 'Mode configuration files must be deployed.'
    Assert-True (Test-Path -LiteralPath (Join-Path $configsDir 'mm_classic.cfg') -PathType Leaf) 'Classic match rules must be deployed.'

    # Negative check: exit 0 without the expected output must produce the accurate diagnostic.
    $missingServerDir = Join-Path $testRoot 'compiler-missing-server'
    $missingScriptingDir = Join-Path $missingServerDir 'cstrike\addons\amxmodx\scripting'
    $missingConfigsDir = Join-Path $missingServerDir 'cstrike\addons\amxmodx\configs'
    New-Item -ItemType Directory -Path $missingScriptingDir -Force | Out-Null
    New-Item -ItemType Directory -Path $missingConfigsDir -Force | Out-Null
    $compilerMissingCommand = Join-Path $missingScriptingDir 'amxxpc.cmd'
    Set-Content -LiteralPath $compilerMissingCommand -Encoding ASCII -Value "@echo off`r`necho Done.`r`nexit /b 0"
    Set-Content -LiteralPath (Join-Path $missingConfigsDir 'plugins.ini') -Encoding ASCII -Value '; fixture'
    $missingOutputObserved = $false
    try {
        & (Join-Path $repoRoot 'scripts\build-plugins.ps1') -ServerDir $missingServerDir -CompilerPath $compilerMissingCommand
    } catch {
        $missingOutputObserved = $_.Exception.Message -match 'exited successfully, but the expected output file was not created'
    }
    Assert-True $missingOutputObserved 'Exit 0 without output must be reported as an output-file failure.'

    Write-Host 'All Phase 1 regression checks passed.'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        [IO.Directory]::Delete($testRoot, $true)
    }
}
