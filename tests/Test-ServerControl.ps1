$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('bloodborne-control-test-' + [guid]::NewGuid().ToString('N') + ' with spaces')
New-Item -ItemType Directory -Path "$fixture\scripts","$fixture\runtime","$fixture\backend" -Force | Out-Null
foreach ($name in 'Start-Server.ps1','Stop-Server.ps1','Server-Processes.ps1') {
    Copy-Item -LiteralPath "$project\scripts\$name" -Destination "$fixture\scripts\$name"
}
New-Item -ItemType File -Path "$fixture\runtime\shadnet.exe","$fixture\backend\bb_dummy_server.py" | Out-Null
[IO.File]::WriteAllText("$fixture\runtime\content.sqlite",'database-sentinel')
$controlState = @{ Started=0; Stopped=@(); PromptCount=0; Inventory=@() }
$controlState.Stopped = @()
$controlState.PromptCount = 0
$controlState.Inventory = @(
    [pscustomobject]@{Name='python.exe';ProcessId=801;ExecutablePath='C:\Python\python.exe';CommandLine='python unrelated.py';CreationDate=[datetime]'2026-01-01'},
    [pscustomobject]@{Name='shadnet.exe';ProcessId=802;ExecutablePath='C:\Other\runtime\shadnet.exe';CommandLine='';CreationDate=[datetime]'2026-01-01'},
    [pscustomobject]@{Name='python.exe';ProcessId=803;ExecutablePath='C:\Python\python.exe';CommandLine="python `"$fixture\backend\bb_dummy_server.py.backup`"";CreationDate=[datetime]'2026-01-01'}
)
function Get-NetIPAddress { param($AddressFamily,$IPAddress,$ErrorAction) [pscustomobject]@{IPAddress=$IPAddress} }
function Read-Host { param($Prompt) $controlState.PromptCount++; '127.0.0.1' }
function Get-Command { param($Name,$ErrorAction) [pscustomobject]@{Source='C:\Python\python.exe'} }
function Get-CimInstance {
    param($ClassName,$Filter)
    if ($Filter -match '^ProcessId = (\d+)$') {
        $controlState.Inventory | Where-Object ProcessId -eq ([int]$Matches[1])
    } else { $controlState.Inventory }
}
function Start-Process {
    param($FilePath,$WorkingDirectory,$WindowStyle,[switch]$PassThru,$RedirectStandardOutput,$RedirectStandardError,$ArgumentList)
    $controlState.Started++
    $idValue = 900 + $controlState.Started
    $controlState.Inventory += [pscustomobject]@{
        Name=[IO.Path]::GetFileName($FilePath);ProcessId=$idValue;ExecutablePath=$FilePath
        CommandLine=($FilePath+' '+$ArgumentList);CreationDate=[datetime]'2026-01-02'
    }
    [pscustomobject]@{Id=$idValue}
}
function Stop-Process {
    param($Id,$ErrorAction)
    $controlState.Stopped += $Id
    $controlState.Inventory = @($controlState.Inventory | Where-Object ProcessId -ne $Id)
}
function Wait-Process { param($Id,$Timeout,$ErrorAction) }
try {
    & "$fixture\scripts\Start-Server.ps1"
    if ($controlState.Started -ne 2 -or $controlState.PromptCount -ne 1) { throw 'First startup did not start both services and request the IP once.' }
    $configHash = (Get-FileHash "$fixture\runtime\shadnet.cfg").Hash
    & "$fixture\scripts\Start-Server.ps1"
    if ($controlState.Started -ne 2 -or $controlState.PromptCount -ne 1) { throw 'Repeated startup launched duplicates or prompted again.' }
    if ((Get-FileHash "$fixture\runtime\shadnet.cfg").Hash -ne $configHash) { throw 'Registration configuration changed.' }
    # A stale record pointing at an unrelated Python process must not kill it.
    Set-Content "$fixture\runtime\backend.pid" 801
    & "$fixture\scripts\Stop-Server.ps1" -WhatIf
    if ($controlState.Stopped.Count) { throw 'WhatIf stopped a process.' }
    & "$fixture\scripts\Stop-Server.ps1"
    if ($controlState.Stopped.Count -ne 2 -or 801 -in $controlState.Stopped -or 802 -in $controlState.Stopped -or 803 -in $controlState.Stopped) { throw 'Stop targeted an unrelated process.' }
    if ($controlState.Inventory.Count -ne 3) { throw 'Unrelated inventory changed.' }
    if (Test-Path "$fixture\runtime\backend.pid") { throw 'Stale process record was not removed.' }
    if ([IO.File]::ReadAllText("$fixture\runtime\content.sqlite") -ne 'database-sentinel') { throw 'Database changed.' }
    & "$fixture\scripts\Stop-Server.ps1"
    if ($controlState.Stopped.Count -ne 2) { throw 'Repeated stop affected another process.' }
    Write-Host 'PASS: first/repeated startup, saved IP, no duplicate processes, dry run, stale PID safety, unrelated process isolation, and data preservation.'
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or
        !(Split-Path -Leaf $resolved).StartsWith('bloodborne-control-test-')) { throw 'Unexpected fixture directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
