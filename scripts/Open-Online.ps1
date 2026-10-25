param(
    [Parameter(Mandatory)][ValidateSet('Public','Private')][string]$Mode,
    [switch]$Configure
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'client.local.json'
if (Get-Process Bloodborne,bb-probe,shadps4 -ErrorAction SilentlyContinue) {
    throw 'Close the game and launcher before switching profiles.'
}
$config = if (Test-Path -LiteralPath $configPath) {
    Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} else { [pscustomobject]@{} }
function Set-ClientSetting($Name,$Value) {
    $config | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}
if ($Configure -or !$config.install_dir) {
    $path = (Read-Host 'Port folder containing Play Bloodborne.exe (for example C:\Games\bbport-windows)').Trim().Trim('"')
    Set-ClientSetting 'install_dir' $path
}
$install = (Resolve-Path -LiteralPath $config.install_dir).Path
if (!(Test-Path -LiteralPath (Join-Path $install 'Play Bloodborne.exe') -PathType Leaf)) {
    throw 'Invalid port folder. Run again with -Configure to change the saved settings.'
}
$arguments = @{Mode=$Mode;InstallDir=$install;OpenLauncher=$true}
if ($Mode -eq 'Private') {
    if ($Configure -or !$config.server_address -or !$config.npid -or !$config.protected_password) {
        $address = [System.Net.IPAddress]::Parse((Read-Host 'Private server Tailscale IPv4 address'))
        if ($address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or $address.ToString() -eq '0.0.0.0') {
            throw 'Enter the private server IPv4 address.'
        }
        $npid = (Read-Host 'Your private server NPID (not your Discord account)').Trim()
        if (!$npid) { throw 'Enter your registered private NPID.' }
        $password = Read-Host 'Your private server password' -AsSecureString
        if (!$password.Length) { throw 'Enter your private account password.' }
        Set-ClientSetting 'server_address' $address.ToString()
        Set-ClientSetting 'npid' $npid
        # Windows DPAPI: only this Windows user on this PC can decrypt it.
        Set-ClientSetting 'protected_password' (ConvertFrom-SecureString $password)
    }
    try { $password = ConvertTo-SecureString $config.protected_password }
    catch { throw 'Cannot read the saved password. Run scripts\Open-Online.ps1 -Mode Private -Configure on this PC.' }
    $arguments.ServerAddress = [System.Net.IPAddress]::Parse($config.server_address)
    $arguments.PrivateCredential = [Management.Automation.PSCredential]::new($config.npid,$password)
}
& (Join-Path $PSScriptRoot 'Set-OnlineProfile.ps1') @arguments
[IO.File]::WriteAllText($configPath,($config | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
