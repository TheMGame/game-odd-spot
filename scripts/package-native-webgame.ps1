param(
    [ValidatePattern('^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$')]
    [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'webgame'
$buildRoot = Join-Path $root 'build'
$output = Join-Path $buildRoot 'webgame'
$packageRoot = Join-Path $buildRoot 'packages'
$bundleRoot = Join-Path $buildRoot '.webgame-bundle'

if (-not $Version) {
    $package = Get-Content -LiteralPath (Join-Path $source 'package.json') -Raw | ConvertFrom-Json
    $Version = [string]$package.version
}
if ($Version -notmatch '^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$') {
    throw "Invalid package version: $Version"
}

Push-Location $source
try {
    if (-not (Test-Path -LiteralPath (Join-Path $source 'node_modules\.bin\esbuild.cmd'))) {
        npm ci
        if ($LASTEXITCODE -ne 0) { throw 'Could not install native Web build dependencies' }
    }
    npm run check
    if ($LASTEXITCODE -ne 0) { throw 'Native Web game checks failed' }
} finally {
    Pop-Location
}

$resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot)
$resolvedOutput = [IO.Path]::GetFullPath($output)
if ([IO.Path]::GetDirectoryName($resolvedOutput) -ne $resolvedBuildRoot -or [IO.Path]::GetFileName($resolvedOutput) -ne 'webgame') {
    throw "Unsafe native Web output path: $resolvedOutput"
}
if (Test-Path -LiteralPath $resolvedOutput) {
    Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

foreach ($file in @('index.html', 'styles.css', 'service-worker.js')) {
    $path = Join-Path $source $file
    if (-not (Test-Path -LiteralPath $path)) { throw "Native Web runtime file is missing: $file" }
    Copy-Item -LiteralPath $path -Destination (Join-Path $resolvedOutput $file)
}
foreach ($file in @('app.bundle.js', 'app.bundle.js.map')) {
    $path = Join-Path $bundleRoot $file
    if (-not (Test-Path -LiteralPath $path)) { throw "Native Web bundle is missing: $file" }
    Copy-Item -LiteralPath $path -Destination (Join-Path $resolvedOutput $file)
}
Copy-Item -LiteralPath (Join-Path $source 'assets') -Destination (Join-Path $resolvedOutput 'assets') -Recurse

$utf8 = [Text.UTF8Encoding]::new($false)
$htmlPath = Join-Path $resolvedOutput 'index.html'
$html = [IO.File]::ReadAllText($htmlPath)
$html = [regex]::Replace($html, '(styles\.css\?v=)[^"'']+', ('${1}' + $Version))
$html = [regex]::Replace($html, '(app\.bundle\.js\?v=)[^"'']+', ('${1}' + $Version))
[IO.File]::WriteAllText($htmlPath, $html, $utf8)

$workerPath = Join-Path $resolvedOutput 'service-worker.js'
$worker = [IO.File]::ReadAllText($workerPath)
$worker = [regex]::Replace($worker, "const CACHE = 'oddspot-webgame-[^']+'", "const CACHE = 'oddspot-webgame-$Version'")
[IO.File]::WriteAllText($workerPath, $worker, $utf8)
[IO.File]::WriteAllText((Join-Path $resolvedOutput 'VERSION'), "$Version`n", $utf8)

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
$archiveName = "oddspot-native-webgame-$Version.tar.gz"
$archive = Join-Path $packageRoot $archiveName
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
Push-Location $buildRoot
try {
    tar -czf (Join-Path 'packages' $archiveName) 'webgame'
    if ($LASTEXITCODE -ne 0) { throw 'Could not create native Web game archive' }
} finally {
    Pop-Location
}

Write-Output "Native Web output: $resolvedOutput"
Write-Output "Package: $archive"
