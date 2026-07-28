$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = 'D:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe'
$outputDir = Join-Path $root 'build\web'
$output = Join-Path $outputDir 'index.html'

if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot console executable not found: $godot"
}
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
& $godot --headless --path (Join-Path $root 'client') --export-release 'Web' $output
if ($LASTEXITCODE -ne 0) {
    throw 'Godot Web export failed'
}
$pack = Join-Path $outputDir 'index.pck'
if (-not (Test-Path -LiteralPath $pack)) {
    throw 'Godot Web export did not produce index.pck'
}
$packVersion = (Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash.Substring(0, 16).ToLowerInvariant()
$versionedPackName = "index.$packVersion.pck"
$versionedPack = Join-Path $outputDir $versionedPackName
Copy-Item -LiteralPath $pack -Destination $versionedPack -Force

$html = [IO.File]::ReadAllText($output)
if (-not $html.Contains('__ODDSPOT_PCK_VERSION__')) {
    throw 'Web shell is missing the PCK cache-busting marker'
}
$html = $html.Replace('__ODDSPOT_PCK_VERSION__', $packVersion)
[IO.File]::WriteAllText($output, $html, [Text.UTF8Encoding]::new($false))
Write-Output "PCK cache key: $versionedPackName"
Write-Output $outputDir
