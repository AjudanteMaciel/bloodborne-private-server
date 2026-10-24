[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Public','Private')][string]$Mode,
    [Parameter(Mandatory)][string]$InstallDir,
    [System.Net.IPAddress]$ServerAddress,
    [switch]$OpenLauncher
)
$ErrorActionPreference = 'Stop'
$install = (Resolve-Path -LiteralPath $InstallDir).Path.TrimEnd('\')
$launcher = Join-Path $install 'Play Bloodborne.exe'
if (!(Test-Path -LiteralPath $launcher)) { throw 'Invalid launcher directory.' }
# Also block elevated game processes whose executable paths cannot be read.
if (Get-Process Bloodborne,bb-probe,shadps4 -ErrorAction SilentlyContinue) {
    throw 'Close the game and launcher before switching profiles.'
}
if ($Mode -eq 'Private' -and (!$ServerAddress -or $ServerAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork)) {
    throw 'Provide -ServerAddress with the private server IPv4 address.'
}
$settingsPath = Join-Path $env:APPDATA 'bbport-launcher\settings.json'
$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$userDir = if ([string]::IsNullOrWhiteSpace($settings.user_dir)) { Join-Path $install 'user' } else { [string]$settings.user_dir }
if (!(Test-Path -LiteralPath $userDir -PathType Container)) { throw 'User directory not found.' }
if (!$PSCmdlet.ShouldProcess($userDir,"Select the $Mode profile")) { return }
$custom = Join-Path $userDir 'host_overrides.custom.json'
$generated = Join-Path $userDir 'host_overrides.json'
$disabled = Join-Path $userDir 'host_overrides.custom.disabled.json'
$before = @{}
foreach ($path in @($settingsPath,$custom,$generated,$disabled)) {
    $before[$path] = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllBytes($path) } else { $null }
}
function Set-Preference($Name,$Value) { $settings | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force }
$utf8 = [Text.UTF8Encoding]::new($false)
try {
    Set-Preference 'online' $true
    if ($settings.PSObject.Properties['extra_env']) {
        $routes = 'BB_NET_BACKEND|BB_COMMUNITY_SERVER|BB_THD_SERVER|BB_THD_AUTH|BB_SHADNET_SERVER|BB_SHADNET_WEBAPI|SHADPS4_HTTP_HOST_OVERRIDES_JSON'
        Set-Preference 'extra_env' ((@(([string]$settings.extra_env -split '\s+') | Where-Object { $_ -and $_ -notmatch "^($routes)=" })) -join ' ')
    }
    if ($Mode -eq 'Private') {
        $ip = $ServerAddress.ToString()
        $base = "http://${ip}:31316"
        Set-Preference 'online_pool' 'shadnet'
        Set-Preference 'online_custom_servers' $true
        Set-Preference 'online_community' $base
        Set-Preference 'online_server' "${ip}:31313"
        Set-Preference 'online_webapi' "http://${ip}:31315"
        Set-Preference 'online_upnp' $false
        $map = [ordered]@{
            'https://ss4.scej-network.jp:20443'=$base
            '*.scej-network.jp'=$base
            'ss4.scej-network.jp'=$base
            'thehuntersdream.com'=$base
            'thehuntersdream.com:18671'=$base
            'https://bb-playlog-prod.s3.amazonaws.com:443'=$base
            'https://bb-playlog-test.s3.amazonaws.com:443'=$base
            'bb-playlog-prod.s3.amazonaws.com'=$base
            'bb-playlog-test.s3.amazonaws.com'=$base
        }
        [IO.File]::WriteAllText($custom,($map | ConvertTo-Json),$utf8)
    } else {
        Set-Preference 'online_pool' 'huntersdream'
        Set-Preference 'online_custom_servers' $false
        Set-Preference 'online_community' 'https://thehuntersdream.com'
        Set-Preference 'online_server' 'srv.shadps4.net:31313'
        Set-Preference 'online_webapi' ''
        if (Test-Path -LiteralPath $custom) {
            [IO.File]::WriteAllBytes($disabled,[IO.File]::ReadAllBytes($custom))
            Remove-Item -LiteralPath $custom
        }
        $map = [ordered]@{
            '*.scej-network.jp'='https://thehuntersdream.com'
            'bb-playlog-prod.s3.amazonaws.com'='https://thehuntersdream.com:18671'
            'bb-playlog-test.s3.amazonaws.com'='https://thehuntersdream.com:18671'
        }
    }
    [IO.File]::WriteAllText($generated,($map | ConvertTo-Json),$utf8)
    [IO.File]::WriteAllText($settingsPath,($settings | ConvertTo-Json -Depth 100),$utf8)
} catch {
    $failure = $_
    foreach ($path in $before.Keys) {
        if ($null -ne $before[$path]) { [IO.File]::WriteAllBytes($path,$before[$path]) }
        elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    throw $failure
}
Write-Host "$Mode profile selected. Accounts, saves, and trophies were preserved."
if ($OpenLauncher) { Start-Process -FilePath $launcher -WorkingDirectory $install -WindowStyle Hidden }
