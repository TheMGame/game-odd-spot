param(
  [string]$ApiBase = "http://127.0.0.1:8080",
  [string]$AdminToken = "oddspot-development-admin-token",
  [string]$ExportDir = "C:\Users\Admin\Downloads\export"
)

$ErrorActionPreference = "Stop"
$headers = @{"X-Admin-Token" = $AdminToken}

function D {
  param($Id, $Label, $Era, $Explanation, $X, $Y, $Radius, $Difficulty)
  @{
    id = $Id; shape = "circle"; x = $X; y = $Y; radius = $Radius
    label = $Label; era = $Era; explanation = $Explanation
    difficulty = $Difficulty; operation = "anachronism"
  }
}

$levels = @(
  @{
    id="cn_1960s_rural_courtyard_001"; candidate=1; title="1960年代北方农村院落"; period="1965年"; scene="rural_courtyard"; total=1
    difficulty=@{object_size=1;color_similarity=1;visual_density=2;edge_distance=1;semantic_obviousness=1}
    differences=@(
      (D smartphone "智能手机" "21世纪" "触屏智能手机在21世纪才普及，不属于1965年的农村生活。" .232 .813 .045 1)
      (D plastic_bottle "塑料瓶装矿泉水" "20世纪末" "一次性PET瓶装水在当时尚未进入日常生活。" .578 .708 .040 1)
      (D running_shoes "现代运动鞋" "20世纪末" "带厚缓震鞋底的现代跑鞋明显晚于该场景年代。" .656 .502 .055 1)
      (D microwave "微波炉" "20世纪末" "家用微波炉在中国家庭普及远晚于1965年。" .797 .319 .060 1)
      (D rolling_suitcase "拉杆旅行箱" "20世纪末" "带万向轮和伸缩拉杆的硬壳旅行箱属于现代产品。" .865 .742 .085 1)
    )
  }
  @{
    id="cn_1970s_primary_classroom_001"; candidate=3; title="1970年代小学教室"; period="1972年"; scene="primary_classroom"; total=2
    difficulty=@{object_size=2;color_similarity=2;visual_density=2;edge_distance=2;semantic_obviousness=1}
    differences=@(
      (D calculator "电子计算器" "20世纪后期" "便携电子计算器并非1972年普通小学课堂用品。" .402 .603 .045 2)
      (D correction_tape "修正带" "20世纪末" "修正带是更晚出现的现代文具。" .188 .661 .035 2)
      (D highlighter "荧光笔" "20世纪后期" "荧光标记笔不属于当时常见的学生文具。" .493 .617 .030 2)
      (D tablet "平板电脑" "21世纪" "触屏平板电脑在21世纪才出现。" .313 .403 .065 1)
      (D plastic_folder "塑料文件夹" "20世纪后期" "透明彩色塑料文件夹晚于场景中的纸质学习用品。" .684 .693 .075 2)
    )
  }
  @{
    id="cn_1960s_bus_station_001"; candidate=1; title="1960年代县城汽车站"; period="1968年"; scene="county_bus_station"; total=2
    difficulty=@{object_size=2;color_similarity=2;visual_density=3;edge_distance=2;semantic_obviousness=2}
    differences=@(
      (D led_board "电子显示屏" "20世纪末" "LED客运信息屏远晚于1968年的县城汽车站。" .133 .203 .075 1)
      (D headphones "降噪耳机" "21世纪" "现代包耳式降噪耳机不属于该年代。" .112 .562 .060 1)
      (D qr_ticket "二维码车票" "21世纪" "二维码电子票务在21世纪才广泛使用。" .281 .629 .040 2)
      (D drink_can "易拉罐" "20世纪后期" "现代拉环铝制饮料罐当时尚未成为普通车站饮品包装。" .114 .769 .035 1)
      (D carryon "登机拉杆箱" "20世纪末" "硬壳伸缩拉杆箱属于现代旅行用品。" .383 .704 .085 1)
    )
  }
  @{
    id="cn_1970s_supply_coop_001"; candidate=2; title="1970年代供销社"; period="1975年"; scene="supply_cooperative"; total=3
    difficulty=@{object_size=3;color_similarity=3;visual_density=3;edge_distance=2;semantic_obviousness=2}
    differences=@(
      (D barcode "条形码" "20世纪末" "商品条形码管理在中国零售场景中普及远晚于1975年。" .531 .801 .040 3)
      (D scanner "扫码枪" "20世纪末" "手持条码扫描器属于现代零售设备。" .610 .523 .045 2)
      (D plastic_bag "塑料购物袋" "20世纪末" "轻薄一次性塑料购物袋并非当时供销社常用包装。" .795 .714 .070 2)
      (D chips_can "罐装薯片" "20世纪末" "这种复合纸筒薯片包装属于现代工业食品。" .948 .153 .045 3)
      (D digital_scale "电子秤" "20世纪末" "数字显示电子秤晚于柜台上的机械秤。" .784 .361 .055 2)
      (D credit_card "信用卡" "20世纪末" "银行卡消费不属于1975年供销社的票证交易方式。" .201 .660 .045 3)
    )
  }
  @{
    id="cn_1960s_communal_canteen_001"; candidate=3; title="1960年代单位公共食堂"; period="1962年"; scene="communal_canteen"; total=3
    difficulty=@{object_size=3;color_similarity=3;visual_density=3;edge_distance=3;semantic_obviousness=3}
    differences=@(
      (D rice_cooker "电饭煲" "20世纪后期" "家用自动电饭煲并非1962年公共食堂设备。" .429 .188 .055 2)
      (D cling_film "保鲜膜" "20世纪后期" "透明食品保鲜膜不属于当时的食物覆盖材料。" .534 .564 .075 3)
      (D foam_box "泡沫餐盒" "20世纪末" "一次性泡沫餐盒晚于可重复使用的金属饭盒。" .729 .588 .060 2)
      (D detergent "洗洁精塑料瓶" "20世纪后期" "泵头塑料洗洁精瓶是更晚的日化包装。" .905 .701 .050 2)
      (D drink_can "易拉罐" "20世纪后期" "拉环铝制饮料罐不属于1962年的食堂。" .313 .824 .042 3)
      (D sensor_faucet "感应水龙头" "20世纪末" "自动感应水龙头需要现代电子传感器。" .839 .712 .055 2)
    )
  }
  @{
    id="cn_1970s_factory_workshop_001"; candidate=3; title="1970年代国营机械厂车间"; period="1976年"; scene="factory_workshop"; total=4
    difficulty=@{object_size=3;color_similarity=4;visual_density=4;edge_distance=3;semantic_obviousness=3}
    differences=@(
      (D digital_caliper "数显卡尺" "20世纪末" "带液晶读数的数显卡尺晚于车间里的机械游标卡尺。" .397 .744 .040 4)
      (D laser_meter "激光测距仪" "20世纪末" "手持激光测距仪属于现代电子测量工具。" .520 .774 .040 3)
      (D cordless_drill "锂电电钻" "21世纪" "使用锂电池包的无绳电钻不属于1976年车间。" .902 .778 .055 3)
      (D touchscreen "触屏控制面板" "21世纪" "彩色触屏机床控制面板明显晚于该年代。" .803 .446 .040 3)
      (D qr_badge "二维码工牌" "21世纪" "二维码身份标识在21世纪才普及。" .943 .557 .040 4)
      (D plastic_helmet "塑料安全帽" "20世纪后期" "这种现代一体成型亮黄色安全帽晚于画面中的传统防护帽。" .867 .642 .060 3)
      (D usb_drive "USB闪存盘" "21世纪" "USB闪存盘在21世纪才成为常见存储工具。" .422 .762 .030 5)
      (D led_worklight "LED工作灯" "21世纪" "线性LED机床工作灯不属于1976年的照明设备。" .878 .202 .055 4)
    )
  }
  @{
    id="cn_1960s_neighborhood_clinic_001"; candidate=3; title="1960年代街道卫生所"; period="1966年"; scene="neighborhood_clinic"; total=4
    difficulty=@{object_size=4;color_similarity=4;visual_density=4;edge_distance=3;semantic_obviousness=3}
    differences=@(
      (D digital_thermometer "电子体温计" "20世纪末" "电子体温计晚于画面中的水银体温计。" .212 .583 .035 4)
      (D disposable_mask "一次性口罩" "20世纪后期" "蓝色无纺布一次性医用口罩不属于1966年的基层卫生所。" .464 .728 .055 3)
      (D bandage "创可贴" "20世纪后期" "画面中这种现代独立粘贴式创可贴并非常用处理方式。" .282 .449 .025 5)
      (D latex_glove "乳胶检查手套" "20世纪后期" "一次性乳胶检查手套晚于当时的基层诊疗条件。" .637 .668 .055 3)
      (D blister_pack "药片泡罩" "20世纪后期" "铝塑泡罩药板晚于纸包和玻璃瓶包装。" .730 .842 .045 4)
      (D plastic_iv "塑料输液袋" "20世纪后期" "柔性塑料输液袋晚于当时常见的玻璃输液瓶。" .916 .269 .060 3)
      (D oximeter "血氧仪" "20世纪末" "指夹式电子血氧仪属于现代医疗设备。" .640 .147 .040 4)
      (D sanitizer "免洗洗手液" "21世纪" "泵装免洗手消毒液不属于1966年的诊室用品。" .873 .724 .040 4)
    )
  }
  @{
    id="cn_1970s_train_carriage_001"; candidate=1; title="1970年代绿皮火车硬座车厢"; period="1978年"; scene="train_carriage"; total=4
    difficulty=@{object_size=4;color_similarity=4;visual_density=5;edge_distance=4;semantic_obviousness=3}
    differences=@(
      (D qr_train_ticket "高铁二维码车票" "21世纪" "高铁二维码票务不属于1978年的铁路旅行。" .533 .331 .035 4)
      (D wireless_earbud "无线耳机" "21世纪" "真无线蓝牙耳机在21世纪才出现。" .170 .300 .025 4)
      (D power_bank "充电宝" "21世纪" "USB移动电源不属于1978年的随身用品。" .135 .754 .055 4)
      (D rolling_suitcase "拉杆箱" "20世纪末" "硬壳滚轮拉杆箱晚于画面中的帆布行李。" .772 .178 .065 3)
      (D pet_bottle "PET饮料瓶" "20世纪末" "一次性PET饮料瓶晚于当时常见的玻璃瓶和茶杯。" .743 .805 .045 3)
      (D selfie_stick "自拍杆" "21世纪" "伸缩自拍杆属于智能手机时代的旅行用品。" .580 .706 .035 5)
      (D ereader "电子阅读器" "21世纪" "电子墨水阅读器远晚于纸质报刊。" .276 .422 .055 4)
      (D combination_lock "行李密码锁" "20世纪末" "现代三位数字行李密码锁不属于画面年代。" .954 .201 .035 4)
    )
  }
  @{
    id="cn_1960s_photo_studio_001"; candidate=1; title="1960年代县城照相馆"; period="1969年"; scene="photo_studio"; total=5
    difficulty=@{object_size=5;color_similarity=5;visual_density=5;edge_distance=4;semantic_obviousness=4}
    differences=@(
      (D digital_camera "数码相机" "20世纪末" "数码相机晚于胶片照相馆时代。" .323 .515 .050 4)
      (D sd_card "存储卡" "21世纪" "SD存储卡不属于胶片和底片工作流程。" .268 .616 .030 5)
      (D card_reader "USB读卡器" "21世纪" "USB读卡器在21世纪才成为常见设备。" .408 .801 .035 5)
      (D ring_light "环形补光灯" "21世纪" "LED环形补光灯属于现代摄影设备。" .666 .376 .065 4)
      (D shutter_remote "遥控快门" "20世纪末" "无线遥控快门晚于机械快门线。" .482 .590 .040 5)
      (D selfie_stick "自拍杆" "21世纪" "自拍杆属于智能手机摄影时代。" .391 .603 .035 5)
      (D inkjet_photo "喷墨照片" "20世纪末" "彩色无边框喷墨照片不属于1969年的暗房冲印。" .597 .715 .070 4)
      (D laminator "塑料覆膜机" "20世纪末" "桌面热覆膜机晚于传统照片装裱工艺。" .806 .874 .075 4)
      (D coin_battery "纽扣电池" "20世纪后期" "现代相机用纽扣电池不属于这套机械摄影器材。" .293 .849 .035 5)
      (D qr_slip "二维码取片单" "21世纪" "二维码取件凭证不属于1969年的照相馆。" .455 .780 .030 5)
    )
  }
  @{
    id="cn_1970s_factory_compound_001"; candidate=3; title="1970年代国营工厂家属院"; period="1975年"; scene="factory_compound"; total=5
    difficulty=@{object_size=5;color_similarity=5;visual_density=5;edge_distance=4;semantic_obviousness=4}
    differences=@(
      (D wireless_earbud "无线蓝牙耳机" "21世纪" "真无线蓝牙耳机在21世纪才出现。" .151 .710 .030 5)
      (D usb_drive "USB闪存盘" "21世纪" "USB闪存盘不属于1975年的缝纫用品。" .464 .827 .030 5)
      (D qr_code "二维码" "21世纪" "二维码支付标识在21世纪才普及。" .672 .570 .045 4)
      (D smartwatch "智能手表" "21世纪" "触屏智能手表不属于1975年的工人用品。" .271 .423 .035 4)
      (D led_bulb "LED灯泡" "21世纪" "白色LED灯泡晚于当时的白炽灯。" .578 .114 .040 4)
      (D pet_bottle "PET塑料瓶" "20世纪末" "一次性PET饮料瓶不属于当时的玻璃瓶回收体系。" .371 .651 .045 5)
      (D remote_control "电视遥控器" "20世纪末" "现代电视遥控器晚于画面年代。" .918 .459 .040 5)
      (D power_strip "现代插线板" "20世纪末" "多孔塑料插线板属于更晚的家用电器配件。" .845 .482 .050 4)
      (D lighter "一次性打火机" "20世纪后期" "透明塑料一次性打火机晚于常见火柴盒。" .708 .853 .035 5)
      (D rolling_box "滚轮塑料收纳箱" "21世纪" "透明塑料滚轮收纳箱不属于1975年的家庭储物方式。" .459 .096 .060 4)
    )
  }
)

$series = @{
  id = "china_60s_70s_life_pack_v1"
  title = "旧日生活·六七十年代"
  description = "从20世纪60—70年代中国生活场景中找出不属于那个年代的物品"
  mode = "find_anachronism"
  cover_url = ""
  sort_order = 20
  enabled = $true
} | ConvertTo-Json -Compress
Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/v1/series" -Headers $headers -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($series)) | Out-Null

$order = 0
foreach ($item in $levels) {
  $order += 10
  $matches = @(Get-ChildItem -LiteralPath $ExportDir -File | Where-Object { $_.Name -like "$($item.id)_*.png.png" } | Sort-Object Name)
  if ($matches.Count -ne 3) { throw "Expected 3 candidates for $($item.id), found $($matches.Count)" }
  $imagePath = $matches[$item.candidate - 1].FullName
  $assetId = "$($item.id)_image_v1"
  $assetResponse = Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/v1/assets/$assetId" -Headers $headers -ContentType "image/png" -InFile $imagePath
  $asset = $assetResponse.data

  $runtime = @{
    schema_version = 1
    level_id = $item.id
    level_version = 1
    mode = "find_anachronism"
    title = $item.title
    instruction = "圈出 $($item.differences.Count) 个不属于这个年代的物件"
    assets = @{ image = $asset; width = 1024; height = 1536 }
    differences = $item.differences
    tags = @{
      regions = @("china")
      themes = @("anachronism", "modern_china")
      styles = @("historical_narrative_illustration")
      scenes = @($item.scene)
      risk = @()
    }
    difficulty = @{
      total = $item.total
      object_size = $item.difficulty.object_size
      color_similarity = $item.difficulty.color_similarity
      visual_density = $item.difficulty.visual_density
      edge_distance = $item.difficulty.edge_distance
      semantic_obviousness = $item.difficulty.semantic_obviousness
    }
  }
  $payload = @{
    series_id = "china_60s_70s_life_pack_v1"
    sort_order = $order
    status = "published"
    runtime_json = $runtime
  } | ConvertTo-Json -Depth 30
  Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/v1/levels/$($item.id)" -Headers $headers -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($payload)) | Out-Null
  Write-Output "Imported $($item.id) from $([IO.Path]::GetFileName($imagePath)) with $($item.differences.Count) hotspots"
}
