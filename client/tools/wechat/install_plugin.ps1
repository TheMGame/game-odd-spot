[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$clientDir = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$cacheDir = Join-Path $clientDir ".cache\godot-minigame"
$targetDir = Join-Path $clientDir "addons\godot-minigame"
$lockPath = Join-Path $scriptDir "godot-minigame.lock"
$repository = "https://github.com/godothub/godot-minigame.git"

if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
    throw "Lock file not found: $lockPath"
}

$lockLine = Get-Content -LiteralPath $lockPath | Where-Object { $_ -match '^GODOT_MINIGAME_COMMIT=' } | Select-Object -First 1
$commit = $lockLine -replace '^GODOT_MINIGAME_COMMIT=', ''
if ($commit -notmatch '^[0-9a-fA-F]{40}$') {
    throw "godot-minigame.lock must contain a full 40-character commit SHA."
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cacheDir) | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $cacheDir ".git"))) {
    git clone --recurse-submodules $repository $cacheDir
} else {
    git -C $cacheDir remote set-url origin $repository
}

git -C $cacheDir fetch --tags origin $commit
git -C $cacheDir checkout --detach $commit
git -C $cacheDir submodule update --init --recursive

$actualCommit = (git -C $cacheDir rev-parse HEAD).Trim()
if ($actualCommit -ne $commit) {
    throw "Checked out $actualCommit, expected $commit."
}

$scons = Get-Command scons -ErrorAction SilentlyContinue
if ($null -eq $scons) {
    $pythonScripts = (& python -c "import sysconfig; print(sysconfig.get_path('scripts', 'nt_user'))").Trim()
    $sconsExecutable = Join-Path $pythonScripts "scons.exe"
    if (Test-Path -LiteralPath $sconsExecutable -PathType Leaf) {
        $env:PATH = "$pythonScripts$([System.IO.Path]::PathSeparator)$env:PATH"
    } else {
        throw "SCons is required. Install it with: python -m pip install --user scons"
    }
}

Push-Location $cacheDir
try {
    & (Join-Path $cacheDir "build_win.bat")
    if ($LASTEXITCODE -ne 0) {
        throw "godot-minigame Windows build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$sourceDir = Join-Path $cacheDir "demo\addons\godot-minigame"
if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
    throw "Built plugin directory not found: $sourceDir"
}

if (Test-Path -LiteralPath $targetDir) {
    $resolvedTarget = [System.IO.Path]::GetFullPath($targetDir)
    $resolvedClient = [System.IO.Path]::GetFullPath($clientDir) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTarget.StartsWith($resolvedClient, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to replace plugin outside the client directory: $resolvedTarget"
    }
    Remove-Item -LiteralPath $targetDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetDir) | Out-Null
Copy-Item -LiteralPath $sourceDir -Destination $targetDir -Recurse

$requiredFiles = @(
    (Join-Path $targetDir "plugin.cfg"),
    (Join-Path $targetDir "plugin.gd"),
    (Join-Path $targetDir "godot-minigame.gdextension")
)
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required plugin file not found: $requiredFile"
    }
}

$windowsBinaries = Get-ChildItem -LiteralPath (Join-Path $targetDir "bin") -Recurse -File |
    Where-Object { $_.FullName -match '[\\/]windows[\\/]' }
if ($windowsBinaries.Count -eq 0) {
    throw "No Windows plugin binaries were produced."
}

Write-Output "GODOT_MINIGAME_PLUGIN_OK commit=$commit"
