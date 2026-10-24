$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root '.sources\shadnet'
$commit = '5a849a192fd4450593c57b10697316ac324c856e'
$gitExe = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
function Invoke-Git([string[]]$Arguments, [switch]$PassThru, [switch]$AllowFailure) {
    # Windows PowerShell 5 treats redirected native stderr as error records.
    # Git progress and an expected negative apply check must use the exit code.
    $previousAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $gitExe @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousAction }
    if ($AllowFailure) { return $exitCode }
    if ($exitCode -ne 0) { throw "Git failed (exit code ${exitCode}): $($output -join [Environment]::NewLine)" }
    if ($PassThru) { return ($output -join [Environment]::NewLine) }
    foreach ($line in $output) { Write-Host ([string]$line) }
}
if (!(Test-Path -LiteralPath $source)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $source) -Force | Out-Null
    Invoke-Git -Arguments @('clone','https://github.com/Wozzardman/shadnet-p2p.git',$source)
    Invoke-Git -Arguments @('-C',$source,'checkout','--detach',$commit)
}
$head = (Invoke-Git -Arguments @('-C',$source,'rev-parse','HEAD') -PassThru).Trim()
if ($head -ne $commit) {
    throw 'The shadNet checkout is not at the expected commit. Use a new directory to preserve local changes.'
}
Invoke-Git -Arguments @('-C',$source,'submodule','update','--init','--recursive')
$patch = Join-Path $root 'patches\shadnet-bloodborne.patch'
$alreadyApplied = Invoke-Git -Arguments @('-C',$source,'apply','--reverse','--check',$patch) -AllowFailure
if ($alreadyApplied -eq 0) { Write-Host 'The patch is already applied.'; return }
Invoke-Git -Arguments @('-C',$source,'apply','--check',$patch)
Invoke-Git -Arguments @('-C',$source,'apply',$patch)
Write-Host 'Sources prepared at the pinned commit with the patch applied.'
