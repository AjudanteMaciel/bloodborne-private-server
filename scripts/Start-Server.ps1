param(
    [System.Net.IPAddress]$ServerAddress,
    [string]$MsysPrefix = 'C:\msys64\ucrt64',
    [switch]$TraceSummons
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
. (Join-Path $PSScriptRoot 'Server-Processes.ps1')
$runtime = Join-Path $root 'runtime'
$exe = Join-Path $runtime 'shadnet.exe'
if (!(Test-Path -LiteralPath $exe)) { throw 'Build the server first with scripts\Build-Server.ps1.' }
$config = Join-Path $runtime 'shadnet.cfg'
if (!$ServerAddress) {
    $saved = if (Test-Path -LiteralPath $config) {
        Select-String -LiteralPath $config -Pattern '^Host=(.+)$' | Select-Object -First 1
    }
    if ($saved) { $ServerAddress = [System.Net.IPAddress]::Parse($saved.Matches[0].Groups[1].Value.Trim()) }
    else { $ServerAddress = [System.Net.IPAddress]::Parse((Read-Host 'Server Tailscale IPv4 address')) }
}
if ($ServerAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
    $ServerAddress.ToString() -eq '0.0.0.0') { throw 'Enter the local IPv4 address used by the server.' }
$ip = $ServerAddress.ToString()
if (!(Get-NetIPAddress -AddressFamily IPv4 -IPAddress $ip -ErrorAction SilentlyContinue)) {
    throw 'The server address is not available on this PC. Connect Tailscale, then try again.'
}
if (!(Test-Path -LiteralPath $config)) {
    $bytes = New-Object byte[] 24
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $key = [Convert]::ToBase64String($bytes)
    $text = "[General]`nHost=$ip`nUnsecuredPort=31313`nMatching2Enabled=true`nMatchingUdpPort=31314`nWebApiPort=31315`nBloodborneSeamlessCoop=false`nStatsEnabled=false`nEmailValidated=false`nRegistrationSecretKey=$key`n"
    [IO.File]::WriteAllText($config,$text,[Text.UTF8Encoding]::new($false))
} elseif (!(Select-String -LiteralPath $config -Pattern "^Host=$([regex]::Escape($ip))$" -Quiet)) {
    throw 'The Host in runtime/shadnet.cfg differs from the supplied IP. Update it with the server stopped.'
}
$oldPath = $env:PATH
$oldOath = $env:SHADNET_BLOODBORNE_NEUTRAL_OATH_COOP
$oldTrace = $env:SHADNET_BLOODBORNE_RE_TRACE
try {
    $env:PATH = (Join-Path $MsysPrefix 'bin') + ';' + $oldPath
    $env:SHADNET_BLOODBORNE_NEUTRAL_OATH_COOP = '1'
    $env:SHADNET_BLOODBORNE_RE_TRACE = if ($TraceSummons) { '1' } else { '0' }
    $existing = @(Get-ProjectServerProcesses $root)
    if (!($existing | Where-Object { $_.Name -ieq 'shadnet.exe' })) {
        $p = Start-Process -FilePath $exe -WorkingDirectory $runtime -WindowStyle Hidden -PassThru -RedirectStandardOutput "$runtime\shadnet.stdout.log" -RedirectStandardError "$runtime\shadnet.stderr.log"
        $p.Id | Set-Content "$runtime\shadnet.pid"
    }
    $backend = Join-Path $root 'backend\bb_dummy_server.py'
    $running = $existing | Where-Object { $_.Name -in @('python.exe','pythonw.exe') }
    if (!$running) {
        $python = (Get-Command python.exe -ErrorAction Stop | Select-Object -First 1).Source
        $arguments = '-u "{0}" --address {1} --port 31316 --shadnet-webapi http://{1}:31315 --store "{2}"' -f $backend,$ip,"$runtime\content.sqlite"
        $p = Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $runtime -WindowStyle Hidden -PassThru -RedirectStandardOutput "$runtime\backend.stdout.log" -RedirectStandardError "$runtime\backend.stderr.log"
        $p.Id | Set-Content "$runtime\backend.pid"
    }
} finally {
    $env:PATH = $oldPath
    foreach ($entry in @{SHADNET_BLOODBORNE_NEUTRAL_OATH_COOP=$oldOath;SHADNET_BLOODBORNE_RE_TRACE=$oldTrace}.GetEnumerator()) {
        if ($null -eq $entry.Value) { Remove-Item -LiteralPath "Env:\$($entry.Key)" -ErrorAction SilentlyContinue }
        else { Set-Item -LiteralPath "Env:\$($entry.Key)" -Value $entry.Value }
    }
}
Write-Host "Server processes started or already running. WebAPI: http://${ip}:31315/status; game services: http://${ip}:31316"
