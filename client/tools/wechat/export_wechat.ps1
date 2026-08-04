[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$clientDir = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$repoRoot = (Resolve-Path (Join-Path $clientDir "..")).Path
$outputDir = Join-Path $repoRoot "build\wechat"
$pluginDir = Join-Path $clientDir "addons\godot-minigame"
$presetName = [string]::Concat([char]0x5C0F, [char]0x6E38, [char]0x620F)

function Find-Godot {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        if (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf) {
            return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
        }
        throw "GODOT_BIN does not point to a file: $env:GODOT_BIN"
    }
    foreach ($name in @("godot", "godot4")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }
    throw "Godot 4.7 not found. Set GODOT_BIN or add godot/godot4 to PATH."
}

function Find-Godot46 {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT46_BIN)) {
        if (Test-Path -LiteralPath $env:GODOT46_BIN -PathType Leaf) {
            return (Resolve-Path -LiteralPath $env:GODOT46_BIN).Path
        }
        throw "GODOT46_BIN does not point to a file: $env:GODOT46_BIN"
    }
    $repoCandidate = Join-Path $repoRoot ".tmp\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe"
    if (Test-Path -LiteralPath $repoCandidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $repoCandidate).Path
    }
    foreach ($name in @("godot46", "godot4.6")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }
    throw "Godot 4.6.2 is required to create a PCK compatible with the current WeChat runtime. Set GODOT46_BIN."
}

function Invoke-Godot {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $stdout = [System.IO.Path]::GetTempFileName()
    $stderr = [System.IO.Path]::GetTempFileName()
    try {
        $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $stdoutLines = @(Get-Content -LiteralPath $stdout)
        $stderrLines = @(Get-Content -LiteralPath $stderr)
        $script:lastGodotOutput = ($stdoutLines + $stderrLines) -join [Environment]::NewLine
        if (Test-Path -LiteralPath $stdout) {
            $stdoutLines | ForEach-Object { Write-Host $_ }
        }
        if (Test-Path -LiteralPath $stderr) {
            $stderrLines | ForEach-Object { [Console]::Error.WriteLine($_) }
        }
        return [int]$process.ExitCode
    } finally {
        Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
    }
}

function Test-CompletedExportBeforeShutdownCrash {
    param([Parameter(Mandatory = $true)][int]$ExitCode)
    if ($ExitCode -ne -1073741819) {
        return $false
    }
    $packCompleted = $script:lastGodotOutput -match '(?s)savepack.*\[ DONE \]'
    $requiredFiles = @(
        (Join-Path $outputDir "game.js"),
        (Join-Path $outputDir "game.json"),
        (Join-Path $outputDir "engine\godot.js")
    )
    return $packCompleted -and -not ($requiredFiles | Where-Object {
        -not (Test-Path -LiteralPath $_ -PathType Leaf)
    })
}

function Test-CompletedImportBeforeShutdownCrash {
    param([Parameter(Mandatory = $true)][int]$ExitCode)
    if ($ExitCode -ne -1073741819) {
        return $false
    }
    return (
        $script:lastGodotOutput -match '(?s)loading_editor_layout.*\[ DONE \]' -and
        $script:lastGodotOutput -notmatch '(?m)^(SCRIPT ERROR|ERROR):'
    )
}

$godot = Find-Godot
$godot46 = Find-Godot46
$versionStdout = [System.IO.Path]::GetTempFileName()
$versionStderr = [System.IO.Path]::GetTempFileName()
try {
    $versionProcess = Start-Process -FilePath $godot -ArgumentList "--version" -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $versionStdout -RedirectStandardError $versionStderr
    $version = (Get-Content -LiteralPath $versionStdout -Raw).Trim()
} finally {
    Remove-Item -LiteralPath $versionStdout, $versionStderr -Force -ErrorAction SilentlyContinue
}
if ($versionProcess.ExitCode -ne 0 -or $version -notmatch '^4\.7(?:\.|$)') {
    throw "Godot 4.7 is required; found: $version"
}
if (-not (Test-Path -LiteralPath (Join-Path $pluginDir "plugin.cfg") -PathType Leaf)) {
    throw "godot-minigame is not installed. Run install_plugin.ps1 first."
}
if (-not (Test-Path -LiteralPath (Join-Path $scriptDir "godot-minigame.lock") -PathType Leaf)) {
    throw "godot-minigame.lock is missing."
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$importExit = Invoke-Godot -Executable $godot -Arguments @("--headless", "--editor", "--path", $clientDir, "--quit")
if (($importExit | Select-Object -Last 1) -ne 0 -and -not (Test-CompletedImportBeforeShutdownCrash -ExitCode $importExit)) {
    throw "Godot project import/plugin load failed."
}
if (($importExit | Select-Object -Last 1) -ne 0) {
    Write-Warning "Godot crashed during plugin shutdown after project import completed; continuing."
}

$exportPath = Join-Path $outputDir "oddspot-pck.bin"
$exportExit = Invoke-Godot -Executable $godot -Arguments @("--headless", "--path", $clientDir, "--export-release", $presetName, $exportPath)
if (($exportExit | Select-Object -Last 1) -ne 0 -and -not (Test-CompletedExportBeforeShutdownCrash -ExitCode $exportExit)) {
    Write-Warning "The first export attempt failed; retrying once after the editor process settles."
    Start-Sleep -Seconds 2
    $exportExit = Invoke-Godot -Executable $godot -Arguments @("--headless", "--path", $clientDir, "--export-release", $presetName, $exportPath)
    if (($exportExit | Select-Object -Last 1) -ne 0 -and -not (Test-CompletedExportBeforeShutdownCrash -ExitCode $exportExit)) {
        throw "WeChat minigame export failed after retry."
    }
}
if (($exportExit | Select-Object -Last 1) -ne 0) {
    Write-Warning "Godot crashed during plugin shutdown after savepack completed; continuing with verified export files."
}

python (Join-Path $scriptDir "finalize_export.py") $outputDir
if ($LASTEXITCODE -ne 0) {
    throw "WeChat export finalization failed with exit code $LASTEXITCODE."
}

& (Join-Path $scriptDir "export_compat_pack.ps1") -Godot46 $godot46 -OutputDir $outputDir
if ($LASTEXITCODE -ne 0) {
    throw "Godot 4.6 compatibility PCK export failed with exit code $LASTEXITCODE."
}

python (Join-Path $scriptDir "verify_export.py") $outputDir
if ($LASTEXITCODE -ne 0) {
    throw "WeChat export verification failed with exit code $LASTEXITCODE."
}
