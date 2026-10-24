param([string]$MsysPrefix = 'C:\msys64\ucrt64', [int]$Jobs = 4)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (!(Test-Path -LiteralPath "$root\.sources\shadnet\CMakeLists.txt")) {
    throw 'Run scripts\Prepare-Sources.ps1 first.'
}
$env:PATH = (Join-Path $MsysPrefix 'bin') + ';' + $env:PATH
& cmake -S $root -B "$root\build" -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_PREFIX_PATH=$MsysPrefix"
if ($LASTEXITCODE) { throw 'Build configuration failed.' }
& cmake --build "$root\build" --target shadnet shadnet-sample test_bloodborne_summon_broker -j $Jobs
if ($LASTEXITCODE) { throw 'Compilation failed.' }
& ctest --test-dir "$root\build" --output-on-failure
if ($LASTEXITCODE) { throw 'Matchmaking tests failed.' }
New-Item -ItemType Directory -Path "$root\runtime" -Force | Out-Null
$exe = "$root\runtime\shadnet.exe"
if (Get-Process shadnet -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }) {
    throw 'This project server is running. Stop it before updating the executable.'
}
Copy-Item -LiteralPath "$root\build\upstream\shadnet.exe" -Destination $exe -Force
foreach ($name in 'worlds.cfg','scoreboards.cfg') {
    Copy-Item -LiteralPath "$root\.sources\shadnet\$name" -Destination "$root\runtime\$name" -Force
}
Write-Host 'Build and tests completed. The runtime uses libraries from the specified MSYS2 installation.'
