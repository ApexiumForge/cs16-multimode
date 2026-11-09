[CmdletBinding()]
param(
    [string]$CompilerPath = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy\cstrike\addons\amxmodx\scripting\amxxpc.exe')
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$CompilerPath = (Resolve-Path -LiteralPath $CompilerPath).Path
$source = Join-Path $repoRoot 'src\amxmodx\hosted\2026-11-09'
$standardIncludes = Join-Path (Split-Path -Parent $CompilerPath) 'include'
$projectIncludes = Join-Path $repoRoot 'src\amxmodx\include'
$output = Join-Path $repoRoot ('.runtime\hosted-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output | Out-Null

# Compile only: never edit a runtime, plugin list or server configuration.
$results = foreach ($file in Get-ChildItem -LiteralPath $source -File -Filter '*.sma') {
    $target = Join-Path $output ($file.BaseName + '.amxx')
    $messages = @(& $CompilerPath $file.FullName "-i$source\include" "-i$standardIncludes" "-i$projectIncludes" "-o$target" 2>&1)
    $compilerExit = $LASTEXITCODE
    $messages | Set-Content -LiteralPath (Join-Path $output ($file.BaseName + '.log'))
    [pscustomobject]@{
        Source = $file.Name
        ExitCode = $compilerExit
        OutputExists = Test-Path -LiteralPath $target -PathType Leaf
        Warnings = @($messages | Where-Object { $_ -match '\bwarning\s+\d+' }).Count
    }
}
$results | Export-Csv -LiteralPath (Join-Path $output 'results.csv') -NoTypeInformation
$failures = @($results | Where-Object { $_.ExitCode -ne 0 -or -not $_.OutputExists -or $_.Warnings -gt 0 })
$failures | Format-Table -AutoSize
Write-Host "Checked $($results.Count) sources; $($failures.Count) blocked/failed. Output: $output"
if ($failures.Count) { throw 'Recovered snapshot is not release-ready. Inspect the per-source compiler logs; do not deploy it.' }
