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

function Get-CraftKnowledge($difference) {
  $label = [string]$difference.label
  if ($label -match 'LED|数字|数显|红外|平板电脑|蓝牙|无线|激光') {
    return @{ clue = '依赖20世纪后期至21世纪的电子技术'; reason = "${label}依靠半导体、传感器或数字显示工作，而画面呈现的是以人力、经验和传统手工具完成的工序。" }
  }
  if ($label -match '电动|电磨|电圆锯|电钻|焊机|电磁炉|喷釉枪|喷涂枪|热熔胶枪|热风枪|真空封口机|抛光机|打磨机') {
    return @{ clue = '机械化设备比传统工序晚出现'; reason = "${label}需要电机、电热元件或现代供电系统；传统作坊以手工工具和炉火完成同一步骤，动力来源明显不一致。" }
  }
  if ($label -match '塑料|涤纶|尼龙|丙烯|环氧|聚氨酯|气泡膜|保鲜膜|透明胶带|扎带|丁腈|气雾|喷漆') {
    return @{ clue = '现代合成材料，20世纪才进入日常生产'; reason = "${label}使用石化工业制造的合成材料；传统作坊通常采用竹木、纸、天然纤维、动物胶或天然漆，因此材质本身就是时代线索。" }
  }
  if ($label -match '十字螺丝|订书机|自动回墨|安全帽|防护面罩|干燥剂') {
    return @{ clue = '现代标准化工业用品'; reason = "${label}依赖标准化零件、模具或现代工业生产体系，和画面中就地取材、手工制作的传统工具体系不相符。" }
  }
  return @{ clue = '现代工业制品'; reason = "${label}的材料、结构和制造方式来自现代工业体系，传统作坊没有相应的能源、设备或批量生产条件。" }
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
      $knowledge = Get-CraftKnowledge $difference
      @{
        id = $difference.id
        shape = "circle"
        x = $difference.x
        y = $difference.y
        radius = $difference.radius
        label = $difference.label
        era = $knowledge.clue
        explanation = "$($knowledge.reason)$($difference.explanation)"
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

