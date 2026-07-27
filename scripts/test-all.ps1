$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = 'D:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe'

Push-Location (Join-Path $root 'server')
try {
    gofmt -w .
    go test ./...
    if ($LASTEXITCODE -ne 0) { throw 'Go tests failed' }
    go vet ./...
    if ($LASTEXITCODE -ne 0) { throw 'Go vet failed' }
} finally {
    Pop-Location
}

& $godot --headless --path (Join-Path $root 'client') --editor --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $godot --headless --path (Join-Path $root 'client') --script 'res://tests/run_smoke.gd'
if ($LASTEXITCODE -ne 0) { throw 'Godot smoke tests failed' }
& $godot --headless --path (Join-Path $root 'client') --script 'res://tests/run_unit_tests.gd'
if ($LASTEXITCODE -ne 0) { throw 'Godot unit tests failed' }

Write-Output 'All local checks passed.'
