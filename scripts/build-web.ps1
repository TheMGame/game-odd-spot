$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = 'D:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe'
$outputDir = Join-Path $root 'build\web'
$output = Join-Path $outputDir 'index.html'
$projectFile = Join-Path $root 'client\project.godot'
$projectContents = $null
$minigameExtension = Join-Path $root 'client\addons\godot-minigame\godot-minigame.gdextension'
$disabledMinigameExtension = "$minigameExtension.web-disabled"
$extensionDisabled = $false

if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot console executable not found: $godot"
}
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
try {
    # godot-minigame is needed by the WeChat exporter, but its RefCounted engine
    # singletons crash Godot 4.7 during Web exporter shutdown. Keep it out of
    # this export process and always restore the project file afterwards.
    $projectContents = [IO.File]::ReadAllText($projectFile)
    $webProjectContents = $projectContents.Replace(
        'enabled=PackedStringArray("res://addons/godot-minigame/plugin.cfg")',
        'enabled=PackedStringArray()'
    )
    if ($webProjectContents -eq $projectContents) {
        throw 'Could not temporarily disable the godot-minigame editor plugin'
    }
    [IO.File]::WriteAllText($projectFile, $webProjectContents, [Text.UTF8Encoding]::new($false))
    if (Test-Path -LiteralPath $disabledMinigameExtension) {
        throw "Temporary extension path already exists: $disabledMinigameExtension"
    }
    Move-Item -LiteralPath $minigameExtension -Destination $disabledMinigameExtension
    $extensionDisabled = $true

    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $godot --headless --path (Join-Path $root 'client') --export-release 'Web' $output
    $exportExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorPreference
    if ($exportExitCode -ne 0) {
        throw "Godot Web export failed with exit code $exportExitCode"
    }
} finally {
    if ($extensionDisabled) {
        Move-Item -LiteralPath $disabledMinigameExtension -Destination $minigameExtension
    }
    if ($null -ne $projectContents) {
        [IO.File]::WriteAllText($projectFile, $projectContents, [Text.UTF8Encoding]::new($false))
    }
}
$pack = Join-Path $outputDir 'index.pck'
if (-not (Test-Path -LiteralPath $pack)) {
    throw 'Godot Web export did not produce index.pck'
}
$packVersion = (Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash.Substring(0, 16).ToLowerInvariant()
$versionedPackName = "index.$packVersion.pck"
$versionedPack = Join-Path $outputDir $versionedPackName
Copy-Item -LiteralPath $pack -Destination $versionedPack -Force

# Keep deploy directories clean: stale cache-keyed packs may contain resources
# from older export filters, and crash leftovers must never be uploaded.
$resolvedOutputDir = (Resolve-Path -LiteralPath $outputDir).Path
Get-ChildItem -LiteralPath $outputDir -File | Where-Object {
    ($_.Name -like 'index.*.pck' -and $_.Name -ne $versionedPackName) -or $_.Extension -eq '.tmp'
} | ForEach-Object {
    if ([IO.Path]::GetDirectoryName($_.FullName) -ne $resolvedOutputDir) {
        throw "Refusing to remove build artifact outside Web output: $($_.FullName)"
    }
    Remove-Item -LiteralPath $_.FullName -Force
}

$html = [IO.File]::ReadAllText($output)
if (-not $html.Contains('__ODDSPOT_PCK_VERSION__')) {
    throw 'Web shell is missing the PCK cache-busting marker'
}
$html = $html.Replace('__ODDSPOT_PCK_VERSION__', $packVersion)
[IO.File]::WriteAllText($output, $html, [Text.UTF8Encoding]::new($false))
Write-Output "PCK cache key: $versionedPackName"
Write-Output $outputDir
