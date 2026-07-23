param(
    [Parameter(Mandatory=$true)][string]$Version
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $root "build\release\oddspot-$Version-linux-amd64"
$archive = "$stage.tar.gz"
if (-not $stage.StartsWith((Join-Path $root 'build\release\'))) { throw 'Unsafe release stage path' }
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'bin'), (Join-Path $stage 'admin'), (Join-Path $stage 'deploy') | Out-Null

Push-Location (Join-Path $root 'server')
try {
    go test ./...
    if ($LASTEXITCODE -ne 0) { throw 'Go tests failed' }
    $env:CGO_ENABLED='0'; $env:GOOS='linux'; $env:GOARCH='amd64'
    go build -trimpath -ldflags "-s -w" -o (Join-Path $stage 'bin\oddspot-api') ./cmd/api
    if ($LASTEXITCODE -ne 0) { throw 'API build failed' }
    go build -trimpath -ldflags "-s -w" -o (Join-Path $stage 'bin\oddspot-worker') ./cmd/worker
    if ($LASTEXITCODE -ne 0) { throw 'Worker build failed' }
    go build -trimpath -ldflags "-s -w" -o (Join-Path $stage 'bin\oddspot-migrate') ./cmd/migrate
    if ($LASTEXITCODE -ne 0) { throw 'Migration build failed' }
} finally { Pop-Location }

Copy-Item -Path (Join-Path $root 'admin\*') -Destination (Join-Path $stage 'admin') -Recurse
Copy-Item -Path (Join-Path $root 'docs\ai_spot_difference_solution\deploy\*') -Destination (Join-Path $stage 'deploy') -Recurse
Set-Content -LiteralPath (Join-Path $stage 'VERSION') -Value $Version -Encoding ascii

if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
Push-Location (Split-Path -Parent $stage)
try { tar -czf $archive (Split-Path -Leaf $stage) } finally { Pop-Location }
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
$line = "$hash  $(Split-Path -Leaf $archive)"
Set-Content -LiteralPath "$archive.sha256" -Value $line -Encoding ascii
Write-Output $archive
