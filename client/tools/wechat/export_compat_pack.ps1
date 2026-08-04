[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Godot46,
    [Parameter(Mandatory = $true)][string]$OutputDir
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$clientDir = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$repoRoot = (Resolve-Path (Join-Path $clientDir "..")).Path
$resolvedOutput = (Resolve-Path -LiteralPath $OutputDir).Path
$targetDir = Join-Path $resolvedOutput "subpackages\project"
$targetPack = Join-Path $targetDir "demo-pck.bin"

if (-not (Test-Path -LiteralPath $Godot46 -PathType Leaf)) {
    throw "Godot 4.6 executable not found: $Godot46"
}
$version = (& $Godot46 --version 2>&1 | Select-Object -First 1).ToString().Trim()
if ($version -notmatch '^4\.6(?:\.|$)') {
    throw "Godot 4.6 is required for the WeChat runtime PCK; found: $version"
}

$compatDir = Join-Path $repoRoot ".tmp\client-wechat-46"
$temporaryPack = Join-Path $compatDir "oddspot-wechat.pck"
if (-not (Test-Path -LiteralPath (Join-Path $compatDir ".godot") -PathType Container)) {
    throw "The validated Godot 4.6 compatibility project is missing: $compatDir"
}
try {
    foreach ($directory in @("assets", "i18n", "scenes", "scripts")) {
        Copy-Item -LiteralPath (Join-Path $clientDir $directory) -Destination $compatDir -Recurse -Force
    }
    # Copy-Item merges into the persistent compatibility project. Remove font
    # files retired from the source project so they cannot remain in the PCK.
    foreach ($retiredFont in @(
        "NotoSansSC-Game.ttf",
        "NotoSansSC-Game.ttf.import",
        "NotoSansCJKsc-Regular.otf",
        "NotoSansCJKsc-Regular.otf.import",
        "game-font-with-fallback.tres",
        "game-font-with-fallback.tres.import"
    )) {
        $retiredFontPath = Join-Path $compatDir "assets\fonts\$retiredFont"
        if (Test-Path -LiteralPath $retiredFontPath) {
            Remove-Item -LiteralPath $retiredFontPath -Force
        }
    }
    Copy-Item -LiteralPath (Join-Path $clientDir "project.godot") -Destination (Join-Path $compatDir "project.godot") -Force

    $projectPath = Join-Path $compatDir "project.godot"
    $project = Get-Content -LiteralPath $projectPath -Raw -Encoding utf8
    $project = $project.Replace('config/features=PackedStringArray("4.7")', 'config/features=PackedStringArray("4.6")')
    $project = $project.Replace('enabled=PackedStringArray("godot-minigame")', 'enabled=PackedStringArray()')
    [IO.File]::WriteAllText($projectPath, $project, [Text.UTF8Encoding]::new($false))

    # This compatibility directory is persistent to retain expensive 4.6
    # imports, but exported scripts must never come from a previous build.
    # Removing only generated script/scene export caches keeps font imports
    # intact while forcing Godot to compile the current API configuration.
    $exportCache = Join-Path $compatDir ".godot\exported"
    if (Test-Path -LiteralPath $exportCache -PathType Container) {
        Remove-Item -LiteralPath $exportCache -Recurse -Force
    }

    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $Godot46 --headless --editor --path $compatDir --quit
    $importExitCode = $LASTEXITCODE
    # This local 4.6.2 build can crash while shutting the headless editor down;
    # the export and load smoke test below are the authoritative checks.

    & $Godot46 --headless --path $compatDir --export-pack Web $temporaryPack
    $exportExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorPreference
    # Godot 4.6.2 on Windows can crash during shutdown after savepack has
    # completed. Accept the artifact only after a real 4.6 load smoke test.
    if (-not (Test-Path -LiteralPath $temporaryPack -PathType Leaf)) {
        throw "Godot 4.6 did not produce the compatibility PCK."
    }
    if ((Get-Item -LiteralPath $temporaryPack).Length -lt 1MB) {
        throw "Godot 4.6 compatibility PCK is unexpectedly small."
    }
    if ($exportExitCode -ne 0 -and $exportExitCode -ne -1073741819) {
        throw "Godot 4.6 compatibility PCK export failed with exit code $exportExitCode."
    }

    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $smokeOutput = & $Godot46 --headless --main-pack $temporaryPack --quit-after 3 2>&1
    $smokeExit = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorPreference
    $smokeOutput | ForEach-Object { Write-Host $_ }
    if ($smokeExit -ne 0 -or (($smokeOutput | Out-String) -match '(?m)^ERROR:')) {
        throw "Godot 4.6 could not load the generated compatibility PCK."
    }

    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Copy-Item -LiteralPath $temporaryPack -Destination $targetPack -Force
    Write-Output "WECHAT_COMPAT_PACK_OK version=4.6 path=$targetPack"
} finally {
    # Keep the validated 4.6 import cache; recreating it with 4.7 metadata can
    # produce a PCK whose imported fonts cannot be resolved by the 4.6 runtime.
    $null = $compatDir
}
