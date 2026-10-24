# Shared process identification. A stale PID file never establishes ownership.
function Test-ProjectServerProcess($ProcessInfo, [string]$ProjectRoot) {
    $serverExe = Join-Path $ProjectRoot 'runtime\shadnet.exe'
    if ($ProcessInfo.Name -ieq 'shadnet.exe') {
        return [string]::Equals($ProcessInfo.ExecutablePath, $serverExe, [StringComparison]::OrdinalIgnoreCase)
    }
    if ($ProcessInfo.Name -notin @('python.exe','pythonw.exe')) { return $false }
    $backend = Join-Path $ProjectRoot 'backend\bb_dummy_server.py'
    $pattern = '(?i)(?:^|["\s])' + [regex]::Escape($backend) + '(?=["\s]|$)'
    return [string]$ProcessInfo.CommandLine -match $pattern
}

function Get-ProjectServerProcesses([string]$ProjectRoot) {
    Get-CimInstance Win32_Process -Filter "Name = 'shadnet.exe' OR Name = 'python.exe' OR Name = 'pythonw.exe'" |
        Where-Object { Test-ProjectServerProcess $_ $ProjectRoot }
}
