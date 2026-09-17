param(
  [string]$ApiBase = "http://127.0.0.1:8080",
  [string]$AdminToken = "oddspot-development-admin-token",
  [string]$DemoHtmlPath = "C:\Users\Admin\Downloads\index.html",
  [string]$ExportDir = ""
)

$ErrorActionPreference = "Stop"
$headers = @{"X-Admin-Token" = $AdminToken}
$seriesId = "rainy_night_detective_v1"
$levelId = "story_rainy_night_001"

function Get-EmbeddedSceneAssets([string]$htmlPath) {
  if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) {
    throw "Demo HTML not found: $htmlPath"
  }

  $html = Get-Content -Raw -Encoding UTF8 -LiteralPath $htmlPath
  $marker = $html.IndexOf("const SC=")
  if ($marker -lt 0) { throw "Demo does not contain const SC={...}" }
  $start = $html.IndexOf("{", $marker)
  $depth = 0
  $inString = $false
  $escaped = $false
  $end = -1

  for ($i = $start; $i -lt $html.Length; $i++) {
    $char = $html[$i]
    if ($inString) {
      if ($escaped) { $escaped = $false; continue }
      if ($char -eq '\') { $escaped = $true; continue }
      if ($char -eq '"') { $inString = $false }
      continue
    }
    if ($char -eq '"') { $inString = $true; continue }
    if ($char -eq '{') { $depth++; continue }
    if ($char -eq '}') {
      $depth--
      if ($depth -eq 0) { $end = $i + 1; break }
    }
  }

  if ($end -lt 0) { throw "Unable to locate the end of the SC asset object" }
  return ($html.Substring($start, $end - $start) | ConvertFrom-Json)
}

function New-NodeImage($asset) {
  return @{
    asset_id = $asset.asset_id
    url = $asset.url
    thumbnail = $asset.thumbnail
    content_type = $asset.content_type
  }
}

$embedded = Get-EmbeddedSceneAssets $DemoHtmlPath
$tempRoot = if ($ExportDir) { $ExportDir } else { Join-Path ([IO.Path]::GetTempPath()) "oddspot-rainy-night-assets" }
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null

$assetMap = @{}
$assetNames = @(
  "ext", "study", "xroom", "sroom", "forest", "maint", "desk", "safe", "cctv", "photoOld", "photoFull",
  "cgS", "cgQ", "watch", "phone", "shoe", "will", "blood", "call", "cam2105", "fileinfo", "accident"
)

foreach ($name in $assetNames) {
  $dataUri = [string]$embedded.$name
  if ($dataUri -notmatch '^data:(?<mime>[^;]+);base64,(?<data>.+)$') { throw "Invalid embedded asset: $name" }
  $path = Join-Path $tempRoot "$name.webp"
  [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($Matches.data))
  $assetId = "rainy_night_${name}_v1"
  $response = Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/v1/assets/$assetId" -Headers $headers -ContentType $Matches.mime -InFile $path -TimeoutSec 60
  $assetMap[$name] = $response.data
  Write-Output "Uploaded asset $name"
}

$nodes = [ordered]@{
  intro = @{ type="scene"; title="雨夜来客"; text="暴雨封山，白石民宿的主人沈老爷在书房离奇身亡。道路中断，在天亮之前，你必须找出凶手。"; image=(New-NodeImage $assetMap.ext); next="enter_study" }
  enter_study = @{ type="scene"; title="封锁的书房"; text="门窗没有强行闯入的痕迹，桌上的茶仍有余温。现场似乎在刻意讲述一个过于完整的故事。"; image=(New-NodeImage $assetMap.study); next="study_search" }
  study_search = @{ type="hotspot"; title="勘查书房"; text="找出现场的三件关键物证。"; image=(New-NodeImage $assetMap.study); required=3; hotspots=@(
    @{id="watch";x=0.23;y=0.63;radius=0.09;label="停走的手表";evidence_id="watch_2053"},
    @{id="phone";x=0.52;y=0.55;radius=0.09;label="死者手机";evidence_id="phone_record"},
    @{id="will";x=0.78;y=0.47;radius=0.09;label="被撕掉一页的遗嘱";evidence_id="missing_will"}
  ); next="watch_evidence" }
  watch_evidence = @{ type="evidence"; title="停走的手表"; text="手表停在 20:53，但表面没有受到撞击。这更像是有人故意调整了时间。"; image=(New-NodeImage $assetMap.watch); evidence_id="watch_2053"; next="phone_evidence" }
  phone_evidence = @{ type="evidence"; title="最后一通电话"; text="通话记录显示：20:57，沈老爷与沈恒通话三分钟。死亡时间不可能早于 20:57。"; image=(New-NodeImage $assetMap.phone); evidence_id="phone_record"; next="room_choice" }
  room_choice = @{ type="choice"; title="继续调查"; text="走廊尽头的两个房间都亮着灯。"; image=(New-NodeImage $assetMap.ext); choices=@(
    @{id="xulan";label="先去许岚的房间";next="ask_xulan"},
    @{id="suyu";label="先去苏雨的房间";next="ask_suyu"}
  ) }
  ask_xulan = @{ type="dialogue"; speaker="许岚"; text="我八点四十分回房后再没出去。快九点时，我听见维修间方向有争吵声。"; image=(New-NodeImage $assetMap.xroom); next="ask_suyu" }
  ask_suyu = @{ type="dialogue"; speaker="苏雨"; text="20:53 我离开书房时，沈老爷还活着。有人让我去维修间，说那里藏着父亲旧案的证据。"; image=(New-NodeImage $assetMap.sroom); next="forest_trace" }
  forest_trace = @{ type="scene"; title="雨中的脚印"; text="通往维修间的小路上留着一枚沾泥鞋印，鞋底纹路与客房里的鞋都不同。"; image=(New-NodeImage $assetMap.forest); next="shoe_evidence" }
  shoe_evidence = @{ type="evidence"; title="维修工鞋印"; text="鞋印来自民宿备用工鞋。钥匙一直由管理员老秦保管。"; image=(New-NodeImage $assetMap.shoe); evidence_id="maintenance_shoe"; next="maint_scene" }
  maint_scene = @{ type="scene"; title="维修间"; text="苏雨被反锁在维修间。门锁可以从外侧用备用钥匙锁上，她显然是被人故意困住的。"; image=(New-NodeImage $assetMap.cgS); next="restore_cctv" }
  restore_cctv = @{ type="puzzle"; title="恢复 20:53 监控"; text="拼合损坏的监控截图，确认苏雨离开书房的时间。"; image=(New-NodeImage $assetMap.cctv); puzzle=@{rows=3;cols=3}; next="suyu_statement" }
  suyu_statement = @{ type="dialogue"; speaker="苏雨"; text="匿名纸条说维修间有父亲车祸的真相。我进来后，门就被从外面锁上了。"; image=(New-NodeImage $assetMap.sroom); next="call_evidence" }
  call_evidence = @{ type="evidence"; title="20:57 通话记录"; text="运营商记录证实沈恒在 20:57 与死者通话。他关于死亡时间的说法是假的。"; image=(New-NodeImage $assetMap.call); evidence_id="call_2057"; next="ask_qin" }
  ask_qin = @{ type="dialogue"; speaker="老秦"; text="备用钥匙今天被人动过。21:05 我去维修间时，看见走廊尽头有个人影。"; image=(New-NodeImage $assetMap.maint); next="maint_search" }
  maint_search = @{ type="hotspot"; title="搜索维修间"; text="找出被忽略的两处痕迹。"; image=(New-NodeImage $assetMap.maint); required=2; hotspots=@(
    @{id="blood";x=0.30;y=0.66;radius=0.09;label="擦拭过的血迹";evidence_id="cleaned_blood"},
    @{id="camera";x=0.78;y=0.24;radius=0.09;label="备用摄像头";evidence_id="backup_camera"}
  ); next="backup_camera" }
  backup_camera = @{ type="evidence"; title="21:05 备用监控"; text="备用摄像头拍到老秦抵达时苏雨仍被锁在维修间，也拍到另一个身影从书房方向离开。"; image=(New-NodeImage $assetMap.cgQ); evidence_id="camera_2105"; next="desk_search" }
  desk_search = @{ type="hotspot"; title="管理员书桌"; text="调查是谁查阅并篡改了旧案资料。"; image=(New-NodeImage $assetMap.desk); required=2; hotspots=@(
    @{id="file";x=0.35;y=0.55;radius=0.10;label="旧案档案";evidence_id="old_case_file"},
    @{id="photo";x=0.73;y=0.43;radius=0.10;label="剪裁照片";evidence_id="cropped_photo"}
  ); next="photo_old" }
  photo_old = @{ type="evidence"; title="被剪裁的合影"; text="旧照片右侧被裁掉了一人，但玻璃反光里还留着他的轮廓。"; image=(New-NodeImage $assetMap.photoOld); evidence_id="cropped_photo"; next="photo_restore" }
  photo_restore = @{ type="puzzle"; title="恢复完整照片"; text="还原照片，找出被刻意抹去的人。"; image=(New-NodeImage $assetMap.photoFull); puzzle=@{rows=3;cols=3}; next="reflection_search" }
  reflection_search = @{ type="hotspot"; title="照片中的倒影"; text="点击照片里最关键的异常。"; image=(New-NodeImage $assetMap.photoFull); required=1; hotspots=@(
    @{id="reflection";x=0.87;y=0.52;radius=0.08;label="玻璃中的倒影";evidence_id="luming_reflection"}
  ); next="ask_luming" }
  ask_luming = @{ type="dialogue"; speaker="陆铭"; text="那张照片不能证明今晚的事……我只是想拿回属于我父亲的材料。"; image=(New-NodeImage $assetMap.fileinfo); next="safe_scene" }
  safe_scene = @{ type="evidence"; title="保险柜中的旧案"; text="保险柜里保存着事故报告：沈老爷当年伪造记录，将责任推给陆铭的父亲。遗嘱原件也在这里。"; image=(New-NodeImage $assetMap.safe); evidence_id="accident_truth"; next="evidence_order" }
  evidence_order = @{ type="sequence"; title="还原雨夜时间线"; text="按发生顺序排列四项关键证据。"; items=@(
    @{id="A";label="20:53 苏雨离开书房"},
    @{id="B";label="20:57 沈恒与死者通话"},
    @{id="C";label="苏雨被锁进维修间"},
    @{id="D";label="21:05 老秦抵达维修间"}
  ); correct_order=@("A","B","C","D"); next="finale" }
  finale = @{ type="ending"; title="完整真相"; text="陆铭利用旧案把苏雨引到维修间并反锁，再回书房与沈老爷对质。争执中他杀害沈老爷，调停手表、剪裁照片并伪造时间线。电话记录、备用监控和照片倒影共同拆穿了谎言。案件告破。"; image=(New-NodeImage $assetMap.accident); ending_id="case_solved" }
}

$runtime = [ordered]@{
  schema_version = 1
  level_id = $levelId
  level_version = 1
  mode = "interactive_story"
  title = "错位大侦探·雨夜来客"
  instruction = "调查现场、收集证据并还原雨夜真相"
  cover = (New-NodeImage $assetMap.ext)
  assets = @{}
  story = @{ start_node="intro"; nodes=$nodes }
  tags = @{ regions=@("china"); themes=@("detective","mystery"); styles=@("noir"); scenes=@("guesthouse","rainy_night"); risk=@() }
  difficulty = @{ total=3; object_size=3; color_similarity=3; visual_density=3; edge_distance=3; semantic_obviousness=3 }
}

$seriesPayload = @{
  id = $seriesId
  title = "错位大侦探"
  description = "在互动故事中调查场景、拼合线索并找出真相。"
  mode = "interactive_story"
  cover_url = $assetMap.ext.url
  sort_order = 70
  enabled = $true
  min_web_version = "0.3.0"
  min_wechat_version = "0.2.0"
} | ConvertTo-Json -Compress
Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/v1/series" -Headers $headers -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($seriesPayload)) -TimeoutSec 30 | Out-Null

$levelPayload = @{
  series_id = $seriesId
  sort_order = 1
  status = "published"
  runtime_json = $runtime
} | ConvertTo-Json -Depth 30
Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/v1/levels/$levelId" -Headers $headers -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($levelPayload)) -TimeoutSec 30 | Out-Null

$catalog = (Invoke-RestMethod -Uri "$ApiBase/admin/v1/catalog" -Headers $headers -TimeoutSec 30).data
$publishedSeries = @($catalog.series | Where-Object { $_.id -eq $seriesId })
if ($publishedSeries.Count -ne 1) { throw "Production verification failed: series not found" }
$publishedLevel = (Invoke-RestMethod -Uri "$ApiBase/admin/v1/levels/$levelId" -Headers $headers -TimeoutSec 30).data
$publishedNodeCount = @($publishedLevel.story.nodes.PSObject.Properties).Count
if ($publishedLevel.mode -ne "interactive_story" -or $publishedNodeCount -ne 25) {
  throw "Production verification failed: unexpected runtime data"
}

Write-Output "Published $seriesId/$levelId assets=$($assetNames.Count) nodes=$publishedNodeCount audio=deferred"
