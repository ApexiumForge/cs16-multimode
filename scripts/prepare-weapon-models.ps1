[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackDir, [Parameter(Mandatory)][string]$OutputDir, [switch]$IncludeKnife)
$ErrorActionPreference = 'Stop'
$PackDir = (Resolve-Path -LiteralPath $PackDir).Path
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
if (Test-Path -LiteralPath $OutputDir) { throw 'Output must be a new directory.' }
$models = @('ak47','aug','awp','deagle','elite','famas','fiveseven','g3sg1','galil','glock18','m249','m3','m4a1','mac10','mp5','p228','p90','scout','sg550','sg552','tmp','ump45','usp','xm1014')
if ($IncludeKnife) { $models += 'knife' }
$modelDir = Join-Path $OutputDir 'models\multimode\csgo_inspect'
$soundDir = Join-Path $OutputDir 'sound\multimode\csgo_inspect'
New-Item -ItemType Directory -Path $modelDir,$soundDir -Force | Out-Null
$sounds = [Collections.Generic.HashSet[string]]::new()
foreach ($model in $models) {
    $source = Join-Path $PackDir "models\v_$model.mdl"
    $bytes = [IO.File]::ReadAllBytes($source)
    if ($bytes.Length -lt 244 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'IDST' -or [BitConverter]::ToInt32($bytes,4) -ne 10) { throw "Invalid GoldSrc model: $source" }
    if ([BitConverter]::ToInt32($bytes,72) -ne $bytes.Length) { throw "Model length mismatch: $source" }
    if ([BitConverter]::ToInt32($bytes,172) -gt 1 -or [BitConverter]::ToInt32($bytes,180) -eq 0) { throw "External model dependencies require separate review: $source" }
    $count = [BitConverter]::ToInt32($bytes,164)
    $offset = [BitConverter]::ToInt32($bytes,168)
    for ($i=0; $i -lt $count; $i++) {
        $seq = $offset + $i*176
        $eventCount = [BitConverter]::ToInt32($bytes,$seq+48)
        $eventOffset = [BitConverter]::ToInt32($bytes,$seq+52)
        for ($j=0; $j -lt $eventCount; $j++) {
            $event = $eventOffset + $j*76
            if ([BitConverter]::ToInt32($bytes,$event+4) -notin @(5004,1004)) { continue }
            $name = [Text.Encoding]::ASCII.GetString($bytes,$event+12,64).Split([char]0)[0].Replace('\','/').ToLowerInvariant()
            if ($name -notmatch '^weapons/[a-z0-9_ /.-]+\.wav$' -or $name.Contains('..')) { throw "Unsafe sound: $name" }
            $sound = Join-Path (Join-Path $PackDir 'sound') $name
            if (-not (Test-Path -LiteralPath $sound)) {
                Write-Warning "Disabling missing animation sound in v_${model}.mdl: $name"
                [Array]::Copy([BitConverter]::GetBytes([int]0),0,$bytes,$event+4,4)
                continue
            }
            $hash = (Get-FileHash -LiteralPath $sound -Algorithm SHA256).Hash.ToLowerInvariant()
            $newName = "multimode/csgo_inspect/$($hash.Substring(0,24)).wav"
            Copy-Item -LiteralPath $sound -Destination (Join-Path $OutputDir "sound/$newName") -Force
            [void]$sounds.Add($newName)
            [Array]::Clear($bytes,$event+12,64)
            $encoded = [Text.Encoding]::ASCII.GetBytes($newName)
            [Array]::Copy($encoded,0,$bytes,$event+12,$encoded.Length)
        }
    }
    [IO.File]::WriteAllBytes((Join-Path $modelDir "v_$model.mdl"),$bytes)
}
# Generated resource manifest, consumed only during map precache.
[IO.File]::WriteAllLines((Join-Path $modelDir 'sounds.ini'),[string[]]@($sounds | Sort-Object),[Text.Encoding]::ASCII)
Write-Host "Prepared $($models.Count) models and $($sounds.Count) sounds at $OutputDir. Original pack untouched."
