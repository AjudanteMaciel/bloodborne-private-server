$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('bloodborne-source-test-' + [guid]::NewGuid().ToString('N') + ' with spaces')
$source = Join-Path $fixture '.sources\shadnet'
New-Item -ItemType Directory -Path $source,"$fixture\patches","$fixture\scripts" -Force | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
try {
    & git -C $source init --quiet
    if ($LASTEXITCODE) { throw 'Fixture initialization failed.' }
    & git -C $source config core.autocrlf false
    [IO.File]::WriteAllText("$source\fixture.txt","before`n",$utf8)
    & git -C $source add fixture.txt
    & git -C $source -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit --quiet -m fixture
    if ($LASTEXITCODE) { throw 'Fixture commit failed.' }
    $commit = (& git -C $source rev-parse HEAD).Trim()
    [IO.File]::WriteAllText("$source\fixture.txt","after`n",$utf8)
    $patch = (& git -C $source diff -- fixture.txt) -join "`n"
    [IO.File]::WriteAllText("$fixture\patches\shadnet-bloodborne.patch",$patch+"`n",$utf8)
    [IO.File]::WriteAllText("$source\fixture.txt","before`n",$utf8)
    $prepare = [IO.File]::ReadAllText("$root\scripts\Prepare-Sources.ps1").Replace('5a849a192fd4450593c57b10697316ac324c856e',$commit)
    [IO.File]::WriteAllText("$fixture\scripts\Prepare-Sources.ps1",$prepare,$utf8)
    & "$fixture\scripts\Prepare-Sources.ps1"
    if ([IO.File]::ReadAllText("$source\fixture.txt") -ne "after`n") { throw 'First-run patch application failed.' }
    & "$fixture\scripts\Prepare-Sources.ps1"
    if ([IO.File]::ReadAllText("$source\fixture.txt") -ne "after`n") { throw 'Repeated preparation changed the patched source.' }
    Write-Host 'PASS: expected negative Git checks do not abort first-time setup; repeated setup preserves the applied patch.'
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or
        !(Split-Path -Leaf $resolved).StartsWith('bloodborne-source-test-')) { throw 'Unexpected fixture directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
