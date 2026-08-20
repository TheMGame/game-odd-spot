param(
    [ValidateSet('windows', 'linux', 'all')]
    [string]$TargetOS = 'all',
    [ValidateSet('amd64', 'arm64')]
    [string]$Arch = 'amd64',
    [string]$Version = 'dev',
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $root 'build\cross'
$targets = if ($TargetOS -eq 'all') { @('windows', 'linux') } else { @($TargetOS) }
$previousCgo = $env:CGO_ENABLED
$previousGoos = $env:GOOS
$previousGoarch = $env:GOARCH

try {
    Remove-Item Env:GOOS, Env:GOARCH, Env:CGO_ENABLED -ErrorAction SilentlyContinue
    if (-not $SkipTests) {
        Push-Location (Join-Path $root 'server')
        try {
            go test -count=1 ./...
            if ($LASTEXITCODE -ne 0) { throw 'Go tests failed' }
        } finally {
            Pop-Location
        }
    }

    foreach ($os in $targets) {
        $packageName = "oddspot-$Version-$os-$Arch"
        $stage = Join-Path $buildRoot $packageName
        $resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot)
        $resolvedStage = [IO.Path]::GetFullPath($stage)
        if (-not $resolvedStage.StartsWith($resolvedBuildRoot + [IO.Path]::DirectorySeparatorChar)) {
            throw "Unsafe build path: $resolvedStage"
        }
        if (Test-Path -LiteralPath $stage) {
            Remove-Item -LiteralPath $stage -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path `
            (Join-Path $stage 'bin'), `
            (Join-Path $stage 'admin'), `
            (Join-Path $stage 'storage\content') | Out-Null

        $extension = if ($os -eq 'windows') { '.exe' } else { '' }
        Push-Location (Join-Path $root 'server')
        try {
            $env:CGO_ENABLED = '0'
            $env:GOOS = $os
            $env:GOARCH = $Arch
            foreach ($command in @('api', 'worker', 'migrate')) {
                $output = Join-Path $stage "bin\oddspot-$command$extension"
                go build -trimpath -ldflags '-s -w' -o $output "./cmd/$command"
                if ($LASTEXITCODE -ne 0) { throw "$command build failed for $os/$Arch" }
            }
        } finally {
            Pop-Location
        }

        Copy-Item -Path (Join-Path $root 'admin\*') -Destination (Join-Path $stage 'admin') -Recurse
        $envExample = if ($os -eq 'windows') { 'windows.env.example' } else { 'linux.env.example' }
        Copy-Item -LiteralPath (Join-Path $root "server\configs\$envExample") -Destination (Join-Path $stage 'oddspot.env.example')
        Set-Content -LiteralPath (Join-Path $stage 'VERSION') -Value $Version -Encoding ascii

        if ($os -eq 'windows') {
            $archive = Join-Path $buildRoot "$packageName.zip"
            if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
            Compress-Archive -LiteralPath $stage -DestinationPath $archive
        } else {
            $archiveName = "$packageName.tar.gz"
            $archive = Join-Path $buildRoot $archiveName
            if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
            Push-Location $buildRoot
            try { tar -czf $archiveName $packageName } finally { Pop-Location }
        }
        Write-Output $archive
    }
} finally {
    if ($null -eq $previousCgo) { Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue } else { $env:CGO_ENABLED = $previousCgo }
    if ($null -eq $previousGoos) { Remove-Item Env:GOOS -ErrorAction SilentlyContinue } else { $env:GOOS = $previousGoos }
    if ($null -eq $previousGoarch) { Remove-Item Env:GOARCH -ErrorAction SilentlyContinue } else { $env:GOARCH = $previousGoarch }
}
