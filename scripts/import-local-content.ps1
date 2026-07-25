param(
  [string]$ApiBase = "http://127.0.0.1:8080",
  [string]$AdminToken = "oddspot-development-admin-token"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$headers = @{"X-Admin-Token" = $AdminToken}
$series = '{"id":"china_history_pack_v1","title":"\u9519\u7f6e\u5343\u5e74","description":"\u4ece\u4e2d\u56fd\u5386\u53f2\u573a\u666f\u4e2d\u627e\u51fa\u4e0d\u5c5e\u4e8e\u8be5\u5e74\u4ee3\u7684\u7269\u4ef6","mode":"find_anachronism","cover_url":"","sort_order":10,"enabled":true}'
Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/v1/series" -Headers $headers -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($series)) | Out-Null

$catalog = Get-Content -Raw -Encoding UTF8 (Join-Path $root "client/config/content_catalog.json") | ConvertFrom-Json
$sourceSeries = $catalog.series | Where-Object id -eq "china_history_pack_v1"
$order = 0
foreach ($entry in $sourceSeries.levels) {
  $order += 10
  $levelPath = Join-Path $root ($entry.path -replace "^res://", "client/")
  $level = Get-Content -Raw -Encoding UTF8 $levelPath | ConvertFrom-Json
  $imagePath = Join-Path (Split-Path -Parent $levelPath) "image.png"
  $assetId = "$($level.level_id)_image_v$($level.level_version)"
  $asset = Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/v1/assets/$assetId" -Headers $headers -ContentType "image/png" -InFile $imagePath
  $level.assets.image = $asset.data
  $payload = @{
    series_id = "china_history_pack_v1"
    sort_order = $order
    status = "published"
    runtime_json = $level
  } | ConvertTo-Json -Depth 30
  Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/v1/levels/$($level.level_id)" -Headers $headers -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($payload)) | Out-Null
  Write-Output "Imported $($level.level_id)"
}
