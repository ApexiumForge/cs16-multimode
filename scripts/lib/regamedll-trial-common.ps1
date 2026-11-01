Set-StrictMode -Version Latest

function Get-MmFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.Path]::GetFullPath($Path)
}

function Assert-MmDifferentPath {
    param(
        [Parameter(Mandatory = $true)][string]$First,
        [Parameter(Mandatory = $true)][string]$Second,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ([string]::Equals((Get-MmFullPath $First).TrimEnd('\'), (Get-MmFullPath $Second).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
        throw $Message
    }
}

function Assert-MmPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $resolvedPath = (Get-MmFullPath $Path).TrimEnd('\')
    $resolvedRoot = (Get-MmFullPath $Root).TrimEnd('\') + '\'
    if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw $Message
    }
}

function Assert-MmPathOutside {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $resolvedPath = (Get-MmFullPath $Path).TrimEnd('\')
    $resolvedRoot = (Get-MmFullPath $Root).TrimEnd('\')
    if ([string]::Equals($resolvedPath, $resolvedRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $resolvedPath.StartsWith($resolvedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw $Message
    }
}

function Get-MmSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file is missing: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Assert-MmServerStopped {
    param([Parameter(Mandatory = $true)][string]$ServerDir)

    $expectedExe = Get-MmFullPath (Join-Path $ServerDir 'hlds.exe')
    $running = Get-CimInstance Win32_Process -Filter "Name='hlds.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and [string]::Equals((Get-MmFullPath $_.ExecutablePath), $expectedExe, [StringComparison]::OrdinalIgnoreCase) } |
        Select-Object -First 1
    if ($running) { throw "HLDS is running from $ServerDir (PID $($running.ProcessId)). Stop it manually before continuing." }
}

function Read-MmTrialManifest {
    param([Parameter(Mandatory = $true)][string]$StateDir)

    $manifestPath = Join-Path (Get-MmFullPath $StateDir) 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Trial manifest is missing: $manifestPath. Run new-regamedll-trial.ps1 first."
    }
    return Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
}

function Assert-MmManifestPaths {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$TrialDir,
        [Parameter(Mandatory = $true)][string]$StateDir
    )

    $expectedTrial = Get-MmFullPath $TrialDir
    $expectedState = Get-MmFullPath $StateDir
    if (-not [string]::Equals((Get-MmFullPath $Manifest.TrialDir), $expectedTrial, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest trial path does not match: $expectedTrial"
    }
    if (-not [string]::Equals((Get-MmFullPath $Manifest.StateDir), $expectedState, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest state path does not match: $expectedState"
    }

    Assert-MmDifferentPath -First $Manifest.SourceDir -Second $expectedTrial -Message 'Production and trial paths must remain different.'
}

function Assert-MmProductionUnchanged {
    param([Parameter(Mandatory = $true)]$Manifest)

    $sourceGameDll = Join-Path $Manifest.SourceDir 'cstrike\dlls\mp.dll'
    $actualHash = Get-MmSha256 $sourceGameDll
    if ($actualHash -ne $Manifest.SourceGameDllSha256) {
        throw "Production GameDLL hash changed. Expected $($Manifest.SourceGameDllSha256), found $actualHash."
    }
}

function Get-MmTrialPidPath {
    param([Parameter(Mandatory = $true)][string]$StateDir)
    return Join-Path (Get-MmFullPath $StateDir) 'hlds.pid.json'
}
