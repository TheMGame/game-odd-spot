param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$webOutput = Join-Path $root 'build\web'
$packageRoot = Join-Path $root 'build\packages'
$stageName = "oddspot-game-$Version"
$stage = Join-Path $packageRoot $stageName
$archive = Join-Path $packageRoot "$stageName.tar.gz"

& (Join-Path $PSScriptRoot 'build-web.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Godot Web build failed' }
foreach ($required in @('index.html', 'index.js', 'index.wasm', 'index.pck')) {
    if (-not (Test-Path -LiteralPath (Join-Path $webOutput $required))) {
        throw "Godot Web output is missing: $required"
    }
}
$resolvedStage = [IO.Path]::GetFullPath($stage)
$expectedParent = [IO.Path]::GetFullPath($packageRoot)
if ([IO.Path]::GetDirectoryName($resolvedStage) -ne $expectedParent) {
    throw "Unsafe package stage path: $resolvedStage"
}

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -Path (Join-Path $webOutput '*') -Destination $stage -Recurse
Set-Content -LiteralPath (Join-Path $stage 'VERSION') -Value $Version -Encoding ascii

if (Test-Path -LiteralPath $archive) {
    Remove-Item -LiteralPath $archive -Force
}
Push-Location $packageRoot
try {
    tar -czf $archive $stageName
    if ($LASTEXITCODE -ne 0) { throw 'Web game archive creation failed' }
} finally {
    Pop-Location
}
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$archive.sha256" -Value "$hash  $stageName.tar.gz" -Encoding ascii
Write-Output $archive
Write-Output "$archive.sha256"
