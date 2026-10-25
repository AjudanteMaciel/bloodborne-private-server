$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('bloodborne-shortcut-test-' + [guid]::NewGuid().ToString('N'))
$oldApp = $env:APPDATA
New-Item -ItemType Directory -Path "$fixture\scripts","$fixture\app\bbport-launcher","$fixture\port\user" -Force | Out-Null
Copy-Item -LiteralPath "$root\scripts\Open-Online.ps1","$root\scripts\Set-OnlineProfile.ps1" -Destination "$fixture\scripts"
New-Item -ItemType File -Path "$fixture\port\Play Bloodborne.exe" | Out-Null
$settingsPath = "$fixture\app\bbport-launcher\settings.json"
@{user_dir="$fixture\port\user";online_npid='old';online_password='old';thd_token='fixture-discord';game_dir='preserve-game'} |
    ConvertTo-Json | Set-Content -LiteralPath $settingsPath
function Get-Process { param($Name,$ErrorAction) }
function Start-Process { param($FilePath,$WorkingDirectory,$WindowStyle) }
$answers = New-Object 'System.Collections.Generic.Queue[string]'
$answers.Enqueue("$fixture\port")
$answers.Enqueue('127.0.0.1')
$answers.Enqueue('fixture-player')
function Read-Host {
    param($Prompt,[switch]$AsSecureString)
    if ($AsSecureString) { return (ConvertTo-SecureString 'fixture-password' -AsPlainText -Force) }
    if (!$answers.Count) { throw 'Unexpected setup prompt on repeated use.' }
    $answers.Dequeue()
}
try {
    $env:APPDATA = "$fixture\app"
    & "$fixture\scripts\Open-Online.ps1" -Mode Private
    $saved = Get-Content "$fixture\client.local.json" -Raw | ConvertFrom-Json
    if ($saved.protected_password -eq 'fixture-password' -or !$saved.protected_password) { throw 'Password was not protected.' }
    $s = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($s.online_npid -ne 'fixture-player' -or $s.online_password -ne 'fixture-password') { throw 'Private credentials were not applied.' }
    & "$fixture\scripts\Open-Online.ps1" -Mode Public
    $s = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($s.online_pool -ne 'huntersdream' -or $s.thd_token -ne 'fixture-discord') { throw 'Public profile or Discord preservation failed.' }
    $s.online_password = 'edited-in-launcher'
    $s | ConvertTo-Json | Set-Content $settingsPath
    & "$fixture\scripts\Open-Online.ps1" -Mode Private
    $s = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($s.online_password -ne 'fixture-password' -or $s.online_pool -ne 'shadnet' -or $s.game_dir -ne 'preserve-game') { throw 'Saved private profile was not restored.' }
    if ($answers.Count) { throw 'Initial setup did not consume all expected answers.' }
    Write-Host 'PASS: first setup, protected password, public Discord preservation, and private one-click reuse.'
} finally {
    $env:APPDATA = $oldApp
    $resolved = [IO.Path]::GetFullPath($fixture)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or
        !(Split-Path -Leaf $resolved).StartsWith('bloodborne-shortcut-test-')) { throw 'Unexpected test directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
