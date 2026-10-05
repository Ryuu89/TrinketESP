param([string]$LuauPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (!$LuauPath) { $LuauPath = Join-Path $projectRoot '.tools\luau-0.737\luau.exe' }
if (!(Test-Path -LiteralPath $LuauPath -PathType Leaf)) { throw 'Luau CLI not found.' }
foreach ($module in @('TrinketESP', 'ManaOverlay', 'Proximity', 'WorldESP', 'Rogue')) {
    $source = Get-Content -LiteralPath (Join-Path $projectRoot "$module.lua") -Raw
    $tests = Get-Content -LiteralPath (Join-Path $PSScriptRoot "$module.spec.luau") -Raw
    if (!$tests.Contains('@@SOURCE@@')) { throw "Test source marker missing in $module." }
    $generated = Join-Path $PSScriptRoot "generated-$module.luau"
    [IO.File]::WriteAllText($generated, $tests.Replace('@@SOURCE@@', $source), [Text.UTF8Encoding]::new($false))
    & $LuauPath $generated
    if ($LASTEXITCODE -ne 0) { throw "$module tests failed with exit code $LASTEXITCODE." }
}


