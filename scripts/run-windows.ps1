param(
    [ValidateSet('api', 'worker', 'migrate')]
    [string]$Target = 'api',
    [string]$EnvFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'server\.env.windows')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resolvedEnv = (Resolve-Path -LiteralPath $EnvFile).Path

foreach ($line in Get-Content -LiteralPath $resolvedEnv -Encoding UTF8) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }
    $parts = $trimmed.Split('=', 2)
    if ($parts.Count -ne 2 -or $parts[0].Trim().Length -eq 0) {
        throw "Invalid environment line in ${resolvedEnv}: $line"
    }
    $name = $parts[0].Trim()
    $value = $parts[1].Trim()
    if (($value.StartsWith("'") -and $value.EndsWith("'")) -or ($value.StartsWith('"') -and $value.EndsWith('"'))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}

Push-Location (Join-Path $root 'server')
try {
    Write-Host "Starting Odd Spot $Target with $resolvedEnv"
    go run "./cmd/$Target"
    if ($LASTEXITCODE -ne 0) { throw "$Target exited with code $LASTEXITCODE" }
} finally {
    Pop-Location
}
