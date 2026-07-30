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
        if (Test-Path -LiteralPath $stdout) {
            Get-Content -LiteralPath $stdout | ForEach-Object { Write-Host $_ }
        }
        if (Test-Path -LiteralPath $stderr) {
            Get-Content -LiteralPath $stderr | ForEach-Object { [Console]::Error.WriteLine($_) }
        }
        return [int]$process.ExitCode
    } finally {
        Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
    }
}

$godot = Find-Godot
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
if (($importExit | Select-Object -Last 1) -ne 0) {
    throw "Godot project import/plugin load failed."
}

$exportPath = Join-Path $outputDir "oddspot-pck.bin"
$exportExit = Invoke-Godot -Executable $godot -Arguments @("--headless", "--path", $clientDir, "--export-release", $presetName, $exportPath)
if (($exportExit | Select-Object -Last 1) -ne 0) {
    Write-Warning "The first export attempt failed; retrying once after the editor process settles."
    Start-Sleep -Seconds 2
    $exportExit = Invoke-Godot -Executable $godot -Arguments @("--headless", "--path", $clientDir, "--export-release", $presetName, $exportPath)
    if (($exportExit | Select-Object -Last 1) -ne 0) {
        throw "WeChat minigame export failed after retry."
    }
}

python (Join-Path $scriptDir "finalize_export.py") $outputDir
if ($LASTEXITCODE -ne 0) {
    throw "WeChat export finalization failed with exit code $LASTEXITCODE."
}

python (Join-Path $scriptDir "verify_export.py") $outputDir
if ($LASTEXITCODE -ne 0) {
    throw "WeChat export verification failed with exit code $LASTEXITCODE."
}
