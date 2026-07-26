param(
  [string]$ApiBase = "http://127.0.0.1:8080",
  [string]$AdminToken = "oddspot-development-admin-token",
  [string]$ExportDir = "content-tools\daily-challenges\2026-07-26\international_swimming"
)

$ErrorActionPreference = "Stop"
$headers = @{"X-Admin-Token" = $AdminToken}

function D {
  param($Id, $Label, $Explanation, $X, $Y, $Radius)
  @{
    id = $Id
    shape = "circle"
    x = $X
    y = $Y
    radius = $Radius
    label = $Label
    era = "不属于游泳赛场"
    explanation = $Explanation
    difficulty = 4
    operation = "anachronism"
  }
}

$series = @{
  id = "daily_task"
  title = "每日挑战"
  description = "每日一关挑战"
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

$levelId = "daily_20260726_international_swimming"
$imagePath = Join-Path $ExportDir "$levelId.png"
if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
  throw "Daily challenge image not found: $imagePath"
}

$assetId = "${levelId}_image_v1"
$assetResponse = Invoke-RestMethod `
  -Method Post `
  -Uri "$ApiBase/admin/v1/assets/$assetId" `
  -Headers $headers `
  -ContentType "image/png" `
  -InFile $imagePath
$asset = $assetResponse.data

$differences = @(
  (D cassette_tape "磁带" "深蓝色毛巾下露出的磁带不是游泳比赛用品。" .276 .843 .045)
  (D kitchen_whisk "厨房打蛋器" "泳具网袋里混入了厨房用金属打蛋器。" .876 .665 .045)
  (D potted_cactus "盆栽仙人掌" "裁判桌文具旁摆着一盆仙人掌。" .139 .221 .034)
  (D alarm_clock "双铃闹钟" "水瓶后面藏着老式双铃闹钟。" .417 .221 .043)
  (D chess_knight "国际象棋马" "观众席台阶边缘摆着一枚国际象棋马。" .949 .266 .035)
  (D pinecone "松果" "泳池排水沟旁出现了一枚松果。" .480 .854 .045)
  (D telephone_handset "老式电话听筒" "5号出发台侧面悬挂着老式电话听筒。" .700 .454 .043)
  (D woodland_mushroom "红帽蘑菇" "泳道线卷盘底部生长着一朵红帽蘑菇。" .258 .559 .040)
)

$runtime = @{
  schema_version = 1
  level_id = $levelId
  level_version = 1
  mode = "find_anachronism"
  title = "泳池里混进了什么？"
  instruction = "找出 8 个不属于国际游泳赛场的物品"
  assets = @{
    image = $asset
    width = 1024
    height = 1536
  }
  differences = $differences
  tags = @{
    regions = @("international")
    themes = @("daily_challenge", "sports", "swimming", "current_events")
    styles = @("photorealistic_editorial")
    scenes = @("indoor_swimming_arena")
    risk = @()
  }
  difficulty = @{
    total = 4
    object_size = 4
    color_similarity = 4
    visual_density = 5
    edge_distance = 4
    semantic_obviousness = 3
  }
}

$payload = @{
  series_id = "daily_task"
  sort_order = 20260726
  status = "published"
  runtime_json = $runtime
} | ConvertTo-Json -Depth 30

Invoke-RestMethod `
  -Method Post `
  -Uri "$ApiBase/admin/v1/levels/$levelId" `
  -Headers $headers `
  -ContentType "application/json; charset=utf-8" `
  -Body ([Text.Encoding]::UTF8.GetBytes($payload)) | Out-Null

Write-Output "Imported $levelId with $($differences.Count) hotspots"

