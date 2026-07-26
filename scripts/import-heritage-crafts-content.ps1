param(
  [string]$ApiBase = "http://127.0.0.1:8080",
  [string]$AdminToken = "oddspot-development-admin-token",
  [string]$ExportDir = "C:\Users\Admin\Downloads\export"
)

$ErrorActionPreference = "Stop"
$headers = @{"X-Admin-Token" = $AdminToken}
$repoRoot = (Resolve-Path -LiteralPath $PSScriptRoot\..).Path
$manifestPath = Join-Path $repoRoot "content-tools\imports\china_heritage_crafts_pack_v1\levels.json"
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json

$seriesPayload = @{
  id = $manifest.series.id
  title = $manifest.series.title
  description = $manifest.series.description
  mode = $manifest.series.mode
  cover_url = ""
  sort_order = $manifest.series.sort_order
  enabled = $manifest.series.enabled
} | ConvertTo-Json -Compress

Invoke-RestMethod `
  -Method Post `
  -Uri "$ApiBase/admin/v1/series" `
  -Headers $headers `
  -ContentType "application/json; charset=utf-8" `
  -Body ([Text.Encoding]::UTF8.GetBytes($seriesPayload)) | Out-Null

$tierScores = @{
  beginner = 1
  easy = 2
  normal = 3
  advanced = 4
  hard = 4
  expert = 5
}

foreach ($level in $manifest.levels) {
  $imagePath = Join-Path $ExportDir "$($level.id).png"
  if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
    throw "Missing selected image: $imagePath"
  }

  $assetId = "$($level.id)_image_v1"
  $assetResponse = Invoke-RestMethod `
    -Method Post `
    -Uri "$ApiBase/admin/v1/assets/$assetId" `
    -Headers $headers `
    -ContentType "image/png" `
    -InFile $imagePath
  $asset = $assetResponse.data

  $score = $tierScores[$level.tier]
  $differences = @(
    foreach ($difference in $level.differences) {
      @{
        id = $difference.id
        shape = "circle"
        x = $difference.x
        y = $difference.y
        radius = $difference.radius
        label = $difference.label
        era = "modern"
        explanation = $difference.explanation
        difficulty = $score
        operation = "anachronism"
      }
    }
  )

  $runtime = @{
    schema_version = 1
    level_id = $level.id
    level_version = 1
    mode = "find_anachronism"
    title = $level.title
    instruction = "找出 $($differences.Count) 个不属于传统手工作坊的现代物件"
    assets = @{
      image = $asset
      width = 1024
      height = 1536
    }
    differences = $differences
    tags = @{
      regions = @("china")
      themes = @("intangible_cultural_heritage", "traditional_crafts", "anachronism")
      styles = @("historical_narrative_illustration")
      scenes = @($level.scene)
      risk = @()
    }
    difficulty = @{
      total = $score
      object_size = $score
      color_similarity = $score
      visual_density = [Math]::Min(5, $score + 1)
      edge_distance = $score
      semantic_obviousness = [Math]::Max(1, $score - 1)
    }
  }

  $levelPayload = @{
    series_id = $manifest.series.id
    sort_order = $level.sort_order
    status = "published"
    runtime_json = $runtime
  } | ConvertTo-Json -Depth 30

  Invoke-RestMethod `
    -Method Post `
    -Uri "$ApiBase/admin/v1/levels/$($level.id)" `
    -Headers $headers `
    -ContentType "application/json; charset=utf-8" `
    -Body ([Text.Encoding]::UTF8.GetBytes($levelPayload)) | Out-Null

  Write-Output "Imported $($level.id) hotspots=$($differences.Count) image=$([IO.Path]::GetFileName($imagePath))"
}

