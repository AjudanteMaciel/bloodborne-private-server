$ErrorActionPreference = 'Stop'
$script = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\Set-OnlineProfile.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('bloodborne-profile-test-' + [guid]::NewGuid().ToString('N'))
$app = Join-Path $fixture 'app'
$install = Join-Path $fixture 'install'
$userDir = Join-Path $fixture 'custom-user'
New-Item -ItemType Directory -Path "$app\bbport-launcher",$install,$userDir -Force | Out-Null
New-Item -ItemType File -Path "$install\Play Bloodborne.exe" | Out-Null
$settingsPath = "$app\bbport-launcher\settings.json"
@{user_dir=$userDir;game_dir='example-game';online_npid='example-account';online_password='fixture-password';thd_token='fixture-token';graphics='preserve';extra_env='BB_COMMUNITY_SERVER=http://old BB_GPU_LOG=info'} |
    ConvertTo-Json | Set-Content -LiteralPath $settingsPath
[IO.File]::WriteAllText("$userDir\save-sentinel",'unchanged')
$oldApp = $env:APPDATA
# Child scripts see this fixture-only process inventory.
function Get-Process { param($Name,$ErrorAction) }
try {
    $env:APPDATA = $app
    foreach ($mode in 'Private','Public','Private','Public') {
        & $script -Mode $mode -InstallDir $install -ServerAddress 127.0.0.1
        $s = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        if ($s.online_password -ne 'fixture-password' -or $s.thd_token -ne 'fixture-token' -or
            $s.user_dir -ne $userDir -or $s.game_dir -ne 'example-game' -or
            $s.graphics -ne 'preserve' -or $s.extra_env -ne 'BB_GPU_LOG=info') { throw 'Preference preservation failed.' }
        $text = Get-Content -LiteralPath "$userDir\host_overrides.json" -Raw
        if ($mode -eq 'Private') {
            if ($s.online_pool -ne 'shadnet' -or !(Test-Path "$userDir\host_overrides.custom.json") -or $text -notmatch '127.0.0.1:31316') { throw 'Private profile validation failed.' }
        } elseif ($s.online_pool -ne 'huntersdream' -or (Test-Path "$userDir\host_overrides.custom.json") -or $text -match '127.0.0.1') { throw 'Public profile validation failed.' }
    }
    if ([IO.File]::ReadAllText("$userDir\save-sentinel") -ne 'unchanged') { throw 'A file unrelated to network settings was modified.' }
    $hash = (Get-FileHash -LiteralPath $settingsPath).Hash
    function Get-Process { param($Name,$ErrorAction) [pscustomobject]@{ProcessName='bb-probe';Path=$null} }
    $blocked = $false
    try { & $script -Mode Private -InstallDir $install -ServerAddress 127.0.0.1 }
    catch { if ($_ -notmatch 'Close the game'){throw}; $blocked=$true }
    if (!$blocked -or (Get-FileHash -LiteralPath $settingsPath).Hash -ne $hash) { throw 'Switching was not blocked while the game was running.' }
    Write-Host 'PASS: four profile switches; data preserved; old routes removed; a process with no readable path blocks switching.'
} finally {
    $env:APPDATA = $oldApp
    # Delete only files in the exact fixture directory made above.
    $resolved = [IO.Path]::GetFullPath($fixture)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or
        !(Split-Path -Leaf $resolved).StartsWith('bloodborne-profile-test-')) { throw 'Unexpected test directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
