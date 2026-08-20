param(
    [Parameter(Mandatory=$true)][string]$Version
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $root "build\release\oddspot-$Version-linux-amd64"
$archive = "$stage.tar.gz"
$previousCgo = $env:CGO_ENABLED
$previousGoos = $env:GOOS
$previousGoarch = $env:GOARCH
if (-not $stage.StartsWith((Join-Path $root 'build\release\'))) { throw 'Unsafe release stage path' }
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'bin'), (Join-Path $stage 'admin'), (Join-Path $stage 'deploy') | Out-Null

Push-Location (Join-Path $root 'server')
try {
    Remove-Item Env:GOOS, Env:GOARCH, Env:CGO_ENABLED -ErrorAction SilentlyContinue
    go test -count=1 ./...
    if ($LASTEXITCODE -ne 0) { throw 'Go tests failed' }
    $env:CGO_ENABLED='0'; $env:GOOS='linux'; $env:GOARCH='amd64'
    go build -trimpath -ldflags "-s -w" -o (Join-Path $stage 'bin\oddspot-api') ./cmd/api
    if ($LASTEXITCODE -ne 0) { throw 'API build failed' }
    go build -trimpath -ldflags "-s -w" -o (Join-Path $stage 'bin\oddspot-worker') ./cmd/worker
    if ($LASTEXITCODE -ne 0) { throw 'Worker build failed' }
    go build -trimpath -ldflags "-s -w" -o (Join-Path $stage 'bin\oddspot-migrate') ./cmd/migrate
    if ($LASTEXITCODE -ne 0) { throw 'Migration build failed' }
} finally {
    Pop-Location
    if ($null -eq $previousCgo) { Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue } else { $env:CGO_ENABLED = $previousCgo }
    if ($null -eq $previousGoos) { Remove-Item Env:GOOS -ErrorAction SilentlyContinue } else { $env:GOOS = $previousGoos }
    if ($null -eq $previousGoarch) { Remove-Item Env:GOARCH -ErrorAction SilentlyContinue } else { $env:GOARCH = $previousGoarch }
}

Copy-Item -Path (Join-Path $root 'admin\*') -Destination (Join-Path $stage 'admin') -Recurse
Copy-Item -Path (Join-Path $root 'docs\ai_spot_difference_solution\deploy\*') -Destination (Join-Path $stage 'deploy') -Recurse
Set-Content -LiteralPath (Join-Path $stage 'VERSION') -Value $Version -Encoding ascii

if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
$archiveName = Split-Path -Leaf $archive
Push-Location (Split-Path -Parent $stage)
try { tar -czf $archiveName (Split-Path -Leaf $stage) } finally { Pop-Location }
Write-Output $archive
