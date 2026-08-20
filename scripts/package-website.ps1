param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'website'
$packageRoot = Join-Path $root 'build\packages'
$stageName = "oddspot-site-$Version"
$stage = Join-Path $packageRoot $stageName
$archive = Join-Path $packageRoot "$stageName.tar.gz"

if (-not (Test-Path -LiteralPath (Join-Path $source 'index.html'))) {
    throw 'Website index.html is missing'
}
if (-not (Test-Path -LiteralPath (Join-Path $source 'assets'))) {
    throw 'Website assets directory is missing'
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
Copy-Item -Path (Join-Path $source '*') -Destination $stage -Recurse
Set-Content -LiteralPath (Join-Path $stage 'VERSION') -Value $Version -Encoding ascii

if (Test-Path -LiteralPath $archive) {
    Remove-Item -LiteralPath $archive -Force
}
$archiveName = Split-Path -Leaf $archive
Push-Location $packageRoot
try {
    tar -czf $archiveName $stageName
    if ($LASTEXITCODE -ne 0) { throw 'Website archive creation failed' }
} finally {
    Pop-Location
}
Write-Output $archive
