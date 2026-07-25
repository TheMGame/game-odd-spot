param(
  [Parameter(Mandatory = $true)]
  [string]$ImporterPath,
  [Parameter(Mandatory = $true)]
  [string]$SeriesId,
  [Parameter(Mandatory = $true)]
  [string]$ExportDir,
  [string]$CredentialFile
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..\..")).Path
if (-not $CredentialFile) {
  $CredentialFile = Join-Path $repoRoot "server\production.local.env"
}
$credentialPath = (Resolve-Path -LiteralPath $CredentialFile).Path
$resolvedImporter = (Resolve-Path -LiteralPath (Join-Path $repoRoot $ImporterPath)).Path
$resolvedExport = (Resolve-Path -LiteralPath $ExportDir).Path

Push-Location $repoRoot
try {
  $ignored = git check-ignore -v -- $credentialPath
  if (-not $ignored) {
    throw "Credential file must be ignored by Git: $credentialPath"
  }
} finally {
  Pop-Location
}

$settings = @{}
foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $credentialPath) {
  if ($line -match "^\s*([^#=]+)=(.*)$") {
    $settings[$matches[1].Trim()] = $matches[2].Trim().Trim('"').Trim("'")
  }
}
$apiBase = $settings.ODDSPOT_PRODUCTION_API_BASE
$adminToken = $settings.ODDSPOT_ADMIN_TOKEN
if ([string]::IsNullOrWhiteSpace($apiBase) -or [string]::IsNullOrWhiteSpace($adminToken)) {
  throw "Credential file must define ODDSPOT_PRODUCTION_API_BASE and ODDSPOT_ADMIN_TOKEN"
}

& $resolvedImporter -ApiBase $apiBase -AdminToken $adminToken -ExportDir $resolvedExport
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
  throw "Importer exited with code $LASTEXITCODE"
}

$headers = @{"X-Admin-Token" = $adminToken}
$catalog = (Invoke-RestMethod -Uri "$apiBase/admin/v1/catalog" -Headers $headers -TimeoutSec 30).data
$series = $catalog.series | Where-Object id -eq $SeriesId
if (-not $series) {
  throw "Series not found after publish: $SeriesId"
}

$verified = 0
$hotspots = 0
foreach ($entry in $series.levels) {
  $level = (Invoke-RestMethod -Uri "$apiBase/admin/v1/levels/$($entry.id)" -Headers $headers -TimeoutSec 30).data
  $hotspots += $level.differences.Count
  $originalStatus = (Invoke-WebRequest -UseBasicParsing -Uri $level.assets.image.url -TimeoutSec 30).StatusCode
  $thumbnailStatus = (Invoke-WebRequest -UseBasicParsing -Uri $level.assets.image.thumbnail.url -TimeoutSec 30).StatusCode
  if ($originalStatus -ne 200 -or $thumbnailStatus -ne 200) {
    throw "Asset verification failed for $($entry.id): original=$originalStatus thumbnail=$thumbnailStatus"
  }
  $verified += 1
}

Write-Output "Published series=$SeriesId levels=$($series.levels.Count) verified=$verified hotspots=$hotspots target=$apiBase"
