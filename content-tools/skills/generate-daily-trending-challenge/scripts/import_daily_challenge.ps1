param(
  [Parameter(Mandatory = $true)]
  [string]$ApiBase,
  [Parameter(Mandatory = $true)]
  [string]$AdminToken,
  [Parameter(Mandatory = $true)]
  [string]$ExportDir
)

$ErrorActionPreference = "Stop"
$headers = @{"X-Admin-Token" = $AdminToken}
$challengeDir = (Resolve-Path -LiteralPath $ExportDir).Path
$configPath = Join-Path $challengeDir "level.json"
$config = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath | ConvertFrom-Json

if ($config.series_slug -ne "daily_task") {
  throw "Expected series_slug=daily_task"
}
if ($config.mode -ne "find_anachronism") {
  throw "Expected mode=find_anachronism"
}
if (@($config.differences).Count -lt 1) {
  throw "Daily challenge has no answer hotspots"
}

$series = @{
  id = "daily_task"
  title = [regex]::Unescape("\u6bcf\u65e5\u6311\u6218")
  description = [regex]::Unescape("\u6bcf\u65e5\u4e00\u5173\u6311\u6218")
  mode = "find_anachronism"
  cover_url = ""
  sort_order = 30
  enabled = $true
} | ConvertTo-Json -Compress

Invoke-RestMethod `
  -Method Post `
  -Uri "$ApiBase/admin/v1/series" `
  -Headers $headers `
  -ContentType "application/json; charset=utf-8" `
  -Body ([Text.Encoding]::UTF8.GetBytes($series)) | Out-Null

$imagePath = Join-Path $challengeDir $config.image.local_path
if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
  throw "Daily challenge image not found: $imagePath"
}

$assetId = "$($config.level_id)_image_v1"
$assetResponse = Invoke-RestMethod `
  -Method Post `
  -Uri "$ApiBase/admin/v1/assets/$assetId" `
  -Headers $headers `
  -ContentType "image/png" `
  -InFile $imagePath
$asset = $assetResponse.data

$differences = @(
  foreach ($difference in $config.differences) {
    @{
      id = $difference.id
      shape = "circle"
      x = $difference.x
      y = $difference.y
      radius = $difference.radius
      label = $difference.name
      era = $difference.clue
      explanation = $difference.reasoning
      difficulty = $(if ($config.difficulty -eq "expert") { 5 } else { 4 })
      operation = "anachronism"
    }
  }
)

$runtime = @{
  schema_version = 1
  level_id = $config.level_id
  level_version = 1
  mode = "find_anachronism"
  title = $config.title
  instruction = $config.instruction
  assets = @{
    image = $asset
    width = $config.image.width
    height = $config.image.height
  }
  differences = $differences
  tags = @{
    regions = @("china")
    themes = @("daily_challenge", "current_events")
    styles = @("editorial_hidden_object")
    scenes = @((Split-Path -Leaf $challengeDir))
    risk = @()
  }
  difficulty = @{
    total = $(if ($config.difficulty -eq "expert") { 5 } else { 4 })
    object_size = 4
    color_similarity = 4
    visual_density = 5
    edge_distance = 4
    semantic_obviousness = 3
  }
}

$sortOrder = [int](($config.date -replace "-", ""))
$payload = @{
  series_id = "daily_task"
  sort_order = $sortOrder
  status = "published"
  runtime_json = $runtime
} | ConvertTo-Json -Depth 30

Invoke-RestMethod `
  -Method Post `
  -Uri "$ApiBase/admin/v1/levels/$($config.level_id)" `
  -Headers $headers `
  -ContentType "application/json; charset=utf-8" `
  -Body ([Text.Encoding]::UTF8.GetBytes($payload)) | Out-Null

Write-Output "Imported $($config.level_id) with $($differences.Count) hotspots"
