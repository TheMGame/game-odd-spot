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
Write-Output $outputDir
