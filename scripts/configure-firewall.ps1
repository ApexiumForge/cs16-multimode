[CmdletBinding()]
param([int]$Port = 27015)

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator privileges are required because Windows Firewall rules are machine-wide. Reopen PowerShell as Administrator.'
}

$rules = @(
    @{ Name='Multi-Mode Network HLDS UDP'; Protocol='UDP' },
    @{ Name='Multi-Mode Network HLDS TCP'; Protocol='TCP' }
)
foreach ($rule in $rules) {
    if (-not (Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Action Allow -Protocol $rule.Protocol -LocalPort $Port -Profile Private | Out-Null
        Write-Host "Created Private-network rule: $($rule.Name), port $Port."
    } else {
        Write-Host "Firewall rule already exists: $($rule.Name)"
    }
}

