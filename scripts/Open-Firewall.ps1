[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][System.Net.IPAddress]$ServerAddress)
$ErrorActionPreference = 'Stop'
if ($ServerAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'Use a Tailscale IPv4 address.' }
$bytes = $ServerAddress.GetAddressBytes()
if ($bytes[0] -ne 100 -or $bytes[1] -lt 64 -or $bytes[1] -gt 127) { throw 'The IP must be within the Tailscale range 100.64.0.0/10.' }
$ip = $ServerAddress.ToString()
foreach ($rule in @(
    @{Protocol='TCP';Ports=@(31313,31315,31316)},
    @{Protocol='UDP';Ports=@(31314,3658)}
)) {
    foreach ($port in $rule.Ports) {
        $name = "Bloodborne private $ip $($rule.Protocol) $port"
        if (!(Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue) -and $PSCmdlet.ShouldProcess($name,'Allow inbound traffic only on the Tailscale interface')) {
            New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Allow -Protocol $rule.Protocol -LocalAddress $ip -LocalPort $port -RemoteAddress '100.64.0.0/10' -Profile Any | Out-Null
        }
    }
}
