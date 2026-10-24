[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
. (Join-Path $PSScriptRoot 'Server-Processes.ps1')
$targets = @(Get-ProjectServerProcesses $root)
$count = 0
foreach ($target in $targets) {
    # Confirm both identity and creation time immediately before stopping.
    $current = Get-CimInstance Win32_Process -Filter "ProcessId = $($target.ProcessId)"
    if (!$current -or !(Test-ProjectServerProcess $current $root) -or
        $current.CreationDate -ne $target.CreationDate) { continue }
    if ($PSCmdlet.ShouldProcess("$($current.Name), PID $($current.ProcessId)", 'Stop this project server process')) {
        Stop-Process -Id $current.ProcessId -ErrorAction Stop
        Wait-Process -Id $current.ProcessId -Timeout 10 -ErrorAction SilentlyContinue
        $count++
    }
}
if ($WhatIfPreference) { return }
if (@(Get-ProjectServerProcesses $root).Count) { throw 'A server process is still running. Check its permissions and try again.' }
foreach ($name in 'shadnet.pid','backend.pid') {
    $path = Join-Path $root "runtime\$name"
    if ((Test-Path -LiteralPath $path) -and $PSCmdlet.ShouldProcess($path, 'Remove stale process record')) {
        Remove-Item -LiteralPath $path -ErrorAction Stop
    }
}
if ($count) { Write-Host "Server stopped ($count processes)." }
else { Write-Host 'The server is already stopped.' }
Write-Host 'The game, Tailscale, accounts, and databases were left unchanged.'
