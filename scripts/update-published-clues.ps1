param(
  [string]$ApiBase = "https://oddspot.guaguatu.com",
  [Parameter(Mandatory = $true)][string]$AdminToken,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$adminBase = "$($ApiBase.TrimEnd('/'))/admin/v1"
$headers = @{"X-Admin-Token" = $AdminToken}

function Get-ObjectUse([string]$label) {
  switch -Regex ($label) {
    '锅|茶壶|电水壶|电饭煲|烤面包机|打蛋器|擀面杖|筷|微波炉' { return '烹饪、烧水或处理食材' }
    '喷头|马桶刷|洗衣机|搓衣板|熨衣板|熨斗|吸尘器|吹风机' { return '家庭清洁、洗护或衣物整理' }
    '浇水壶|割草机|雪铲' { return '园艺养护或户外清理' }
    '冰鞋|雪橇|羊毛手套|滑雪镜|雨靴|针织帽|电暖器' { return '寒冷天气、防寒或冰雪活动' }
    '闹钟|台灯' { return '卧室或书桌等固定室内环境' }
    '打印机|键盘|笔记本电脑|打字机|电话|磁带机|算盘' { return '办公、通信、记录或计算' }
    '平底锅|煎锅' { return '厨房煎炒' }
    '橡皮鸭|雪景球|象棋|松果|蘑菇|仙人掌' { return '玩具、摆件或自然环境' }
    '油漆滚筒' { return '墙面涂装' }
    default { return '与该物品原本对应的专门生活或工作场景' }
  }
}

function Get-TechnologyKnowledge([string]$label, [string]$levelTitle) {
  if ($label -match '手机|二维码|平板|笔记本电脑|VR|自拍|蓝牙|无线|USB|存储卡|读卡器|电子阅读器|触屏') {
    return @{clue='依赖20世纪末至21世纪的数字技术'; reason="${label}需要芯片、数字网络或现代电子显示技术；《${levelTitle}》所处时代尚不具备这套技术基础设施。"}
  }
  if ($label -match 'LED|激光|红外|数字|数显|电子秤|血氧|感应') {
    return @{clue='依赖现代半导体与传感技术'; reason="${label}通过半导体、传感器或数字显示工作，而《${levelTitle}》中的同类任务依靠机械结构、人工观察或经验判断完成。"}
  }
  if ($label -match '电动|电钻|电磨|电圆锯|焊机|电磁炉|喷釉枪|喷涂枪|热熔胶枪|热风枪|封口机|抛光机|打磨机|发动机|微波炉|吹风机|洗衣机|打印机') {
    return @{clue='机械化设备在该场景之后才普及'; reason="${label}需要电机、电热元件或现代供电系统；《${levelTitle}》中的对应工序依靠人力、炉火或传统手工具，动力来源明显矛盾。"}
  }
  if ($label -match '塑料|涤纶|尼龙|丙烯|环氧|聚氨酯|气泡膜|保鲜膜|胶带|扎带|丁腈|气雾|喷漆|泡罩|PET') {
    return @{clue='现代合成材料，20世纪才广泛应用'; reason="${label}依赖石化工业生产的合成材料；《${levelTitle}》所呈现的传统环境通常使用竹木、纸、陶瓷、金属或天然纤维。"}
  }
  if ($label -match '罐头|易拉罐|集装箱|条形码|扫码|覆膜|自动回墨|十字螺丝') {
    return @{clue='近现代标准化工业体系的产物'; reason="${label}依赖统一规格、机器批量制造及配套流通体系，这些条件晚于《${levelTitle}》所处的生产和商业环境。"}
  }
  return $null
}

function Improve-Difference($difference, [string]$seriesId, [string]$levelTitle) {
  $era = [string]$difference.era
  $explanation = ([string]$difference.explanation).Trim()
  $placeholderEra = [string]::IsNullOrWhiteSpace($era) -or $era -match '^(modern|not_in_scene|unknown|n/a)$'
  $locationOnly = [string]::IsNullOrWhiteSpace($explanation) -or $explanation.Length -lt 20 -or $explanation -match '^(画面|挂在|摆在|放在|藏在|混在|斜靠|停在|位于|竹|工匠|传统|石槽|木架|纸堆|印版|大花楼|左侧|铜丝|工作台|上层|右侧|前景|后方|剑架|水槽|炭炉|高处|皮影|鼓旁|乐器架|线轴|纸本|茶叶|陶制)'
  if ($explanation.Contains('画面识别点：')) { $locationOnly = $false }
  if (-not $placeholderEra -and -not $locationOnly) { return $false }

  $knowledge = Get-TechnologyKnowledge ([string]$difference.label) $levelTitle
  if ($seriesId -eq 'daily_task' -and $null -eq $knowledge) {
    $use = Get-ObjectUse ([string]$difference.label)
    $knowledge = @{
      clue = "用途属于另一类场景"
      reason = "$($difference.label)通常用于${use}；《${levelTitle}》的人员、设施和活动目的与这种用途没有合理联系，所以它是场景错置。"
    }
  }
  if ($null -eq $knowledge) {
    $knowledge = @{
      clue = if ($placeholderEra) {'出现或普及时间晚于当前场景'} else {$era}
      reason = "${explanation}《${levelTitle}》当时缺少制造、使用或普及这种物品所需的技术与社会条件，因此并非同时代日常用品。"
    }
  }

  if ($placeholderEra) { $difference.era = $knowledge.clue }
  if ($locationOnly) {
    $visualText = $explanation.TrimEnd('。', '.', '！', '!', '？', '?')
    $visual = if ([string]::IsNullOrWhiteSpace($visualText)) {''} else {"画面识别点：${visualText}。"}
    $difference.explanation = "$($knowledge.reason)$visual"
  }
  return $true
}

$catalog = (Invoke-RestMethod -Uri "$adminBase/catalog" -Headers $headers -TimeoutSec 30).data
$changedLevels = 0
$changedAnswers = 0
foreach ($series in $catalog.series) {
  foreach ($entry in $series.levels) {
    $level = (Invoke-RestMethod -Uri "$adminBase/levels/$([uri]::EscapeDataString($entry.id))" -Headers $headers -TimeoutSec 30).data
    $levelChanges = 0
    foreach ($difference in $level.differences) {
      if (Improve-Difference $difference $series.id $level.title) {
        $levelChanges++
      }
    }
    if ($levelChanges -eq 0) { continue }
    $changedLevels++
    $changedAnswers += $levelChanges
    Write-Output "$($series.id)/$($level.level_id): $levelChanges answers"
    if ($DryRun) { continue }
    $payload = @{
      series_id = $series.id
      sort_order = $entry.sort_order
      status = 'published'
      runtime_json = $level
    } | ConvertTo-Json -Depth 40
    Invoke-RestMethod -Method Post -Uri "$adminBase/levels/$([uri]::EscapeDataString($level.level_id))" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 30 | Out-Null
  }
}
Write-Output "Updated levels=$changedLevels answers=$changedAnswers dry_run=$DryRun"
