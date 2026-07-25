# 中国六七十年代生活“找出时代错误”Prompt 包 V1

本包是独立于“中国历史 Prompt 包”的新系列，聚焦中国 20 世纪 60–70 年代的日常生活场景。玩家需要找出不属于该年代、主要来自 1980 年代以后或当代的物品。

所有图片统一为 1024 × 1536、竖向 2:3、精致叙事插画风。游戏只使用一张包含时代错误的最终图，不生成左右对照图。

## 系列生产规则

- 每个目标必须明确晚于场景年份，避免使用年代边界有争议的物品。
- 时代错误应自然混入真实生活用品，不得集中摆放或依赖发光描边。
- 使用同形的年代正确物品作为干扰物，例如玻璃瓶对 PET 瓶、火柴盒对一次性打火机、机械表对智能手表。
- 生成最终图片后，必须由支持视觉分析的 AI 重新识别答案并输出 Admin 热点；不得把 Prompt 的预定方位直接当作最终坐标。
- AI 未找到、重复、变形或无法辨认的物品必须返工，不能伪造热点。

## 通用 Negative Prompt

wrong historical period, ancient Chinese robes, Qing dynasty clothing, Japanese architecture, Korean clothing, western retro diner, Soviet military parade, contemporary city skyline, modern apartment interior, extra modern objects, duplicate target objects, missing target objects, oversized hidden objects, cropped target objects, malformed target objects, random readable text, gibberish typography, brand names, logos, watermark, answer labels, circles, arrows, highlights, glowing outlines, collage, split screen, comparison image, borders, UI overlay, photorealism, 3D render, deformed hands, extra fingers, distorted faces

## 难度分档

| 档位 | 关卡数 | 答案数 | 目标表现 |
|---|---:|---:|---|
| 入门 | 1 | 5 | 中大型、无遮挡、颜色反差明显 |
| 简单 | 2 | 5 | 中型、极少遮挡、少量环境融合 |
| 普通 | 2 | 6 | 中小型、少量遮挡、中等环境融合 |
| 进阶 | 2 | 8 | 中小型、约 25% 遮挡、画面密度高 |
| 困难 | 1 | 8 | 小型、约 35% 遮挡、强环境融合 |
| 专家 | 2 | 10 | 小或微小、约 40% 遮挡、观察与年代知识结合 |

## 01 1960 年代北方农村院落｜入门｜5 个

关卡 ID：`cn_1960s_rural_courtyard_001`  
年代：中国 20 世纪 60 年代中期，约 1965 年。  
答案：智能手机、塑料瓶装矿泉水、现代运动鞋、微波炉、拉杆旅行箱。

Prompt：

> Create one polished vertical mobile hidden-object game illustration of an everyday northern Chinese rural family courtyard in the mid-1960s, circa 1965. Show an earthen courtyard with mud-brick houses, paper-covered wooden windows, a simple tiled roof, a hand-operated water pump, wooden farm tools, shoulder poles, bamboo baskets, ceramic storage jars, an iron cooking pot, a straw broom, cotton quilts drying on a rope, chickens, a wooden handcart and one period-correct heavy black bicycle. Family members wear plain blue, gray and faded khaki cotton jackets, trousers, cloth shoes and simple headscarves. Use clear morning light, restrained earthy colors, readable silhouettes and refined Chinese narrative illustration.
>
> Include exactly five obvious post-1960s objects: a black touchscreen smartphone placed on a center-left wooden stool; a transparent disposable plastic mineral-water bottle with blue screw cap beside ceramic water jars in the lower center; a pair of brightly colored modern cushioned running shoes near the center-right doorway; a complete white countertop microwave oven on a rear kitchen shelf; and a hard-shell rolling suitcase with extended telescoping handle near the lower-right wall. Make all five targets medium or large, completely unobstructed, separated and slightly color-contrasted for beginner difficulty. Include no other modern object.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait. Recompose the full scene for portrait orientation. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders or UI overlays.

## 02 1970 年代小学教室｜简单｜5 个

关卡 ID：`cn_1970s_primary_classroom_001`  
年代：中国 20 世纪 70 年代初期，约 1972 年。  
答案：电子计算器、修正带、荧光笔、平板电脑、塑料文件夹。

Prompt：

> Create one richly detailed vertical mobile hidden-object game illustration of a Chinese primary-school classroom in the early 1970s, circa 1972. Show worn wooden desks and benches, a dark chalkboard without readable writing, chalk and felt erasers, exercise books, wooden pencil boxes, fountain pens, ink bottles, abacuses, rulers, canvas schoolbags, enamel drinking cups, a wall clock and students in plain blue-gray cotton clothes. A teacher demonstrates arithmetic with a large wooden abacus while children read and write. Soft daylight through wood-framed windows, medium visual density, clean gongbi-inspired linework and muted period colors.
>
> Include exactly five later school objects: a pocket electronic calculator among abacuses on a center desk; a white correction-tape dispenser beside an ink bottle in the lower-left; one fluorescent yellow highlighter among ordinary pencils near center-right; a thin black touchscreen tablet lying flat on the teacher's desk; and one transparent colored plastic document folder partly under exercise books on the right desk. Keep all five medium-sized and fully visible; only the folder may be about 15% covered. Use modest color integration but preserve recognizable shapes. No ballpoint pens, modern backpacks, projectors, fluorescent ceiling fixtures or other contemporary classroom items.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait. Recompose the full scene for portrait orientation. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders or UI overlays.

## 03 1960 年代县城汽车站｜简单｜5 个

关卡 ID：`cn_1960s_bus_station_001`  
年代：中国 20 世纪 60 年代末期，约 1968 年。  
答案：登机箱、降噪耳机、二维码车票、易拉罐、电子显示屏。

Prompt：

> Create one detailed vertical mobile hidden-object game illustration of a modest Chinese county bus station in the late 1960s, circa 1968. Show a simple brick waiting hall, wooden ticket window, wooden benches, analog wall clock, canvas luggage, bedrolls tied with rope, bamboo baskets, enamel mugs, paper tickets without readable text, travelers carrying shoulder poles, and one rounded period bus visible through the gate. People wear accurate plain cotton jackets, Mao suits, cloth caps and cloth shoes. Cool overcast daylight, medium crowd density, historically grounded narrative illustration with fine linework.
>
> Include exactly five post-1960s travel objects: a small modern hard-shell carry-on suitcase with telescoping handle beside a wooden bench; large over-ear noise-canceling headphones around a seated traveler's neck; one paper ticket bearing a clear black-and-white QR code but no readable words; a red aluminum pull-tab beverage can beside an enamel mug; and a small amber LED departure display mounted above the ticket window, showing only abstract unreadable blocks. Keep targets medium-sized, separated and mostly unobstructed. Blend them lightly into luggage and station clutter without making them unfair. No aircraft imagery, modern coaches, plastic seats, digital clocks or additional modern objects.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait. Recompose the full scene for portrait orientation. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders or UI overlays.

## 04 1970 年代供销社｜普通｜6 个

关卡 ID：`cn_1970s_supply_coop_001`  
年代：中国 20 世纪 70 年代中期，约 1975 年。  
答案：条形码、扫码枪、塑料购物袋、罐装薯片、电子秤、信用卡。

Prompt：

> Create one densely stocked vertical mobile hidden-object game illustration of a Chinese supply-and-marketing cooperative shop in the mid-1970s, circa 1975. Show long wooden glass counters, mechanical balance scales with metal weights, abacuses, cloth and ration coupons without readable text, enamel basins, thermos flasks, sewing notions, soap wrapped in paper, canned goods with plain paper labels, glass soda bottles, bulk sweets in glass jars, cotton fabric bolts, bamboo baskets and customers in blue-gray period clothing. Warm window light, medium-high object density, accurate everyday materials and refined narrative game art.
>
> Include exactly six later retail objects: a small printed barcode label on a lower-center cardboard box; a handheld black barcode scanner partly behind an abacus on the center counter; a thin translucent plastic shopping bag hanging from a customer's hand; a tall cylindrical composite can of stacked potato chips on an upper-right shelf without branding; a compact digital electronic scale among mechanical scales behind the counter; and a plastic bank credit card half visible beside ration coupons near lower-left. Make targets medium to small, color-matched to nearby goods, with about 15–25% occlusion on the scanner and card. Use period-correct labels and glass containers as decoys. No cash register, QR code, modern packaging, refrigeration display or other contemporary retail equipment.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait. Recompose the full scene for portrait orientation. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders or UI overlays.

## 05 1960 年代单位公共食堂｜普通｜6 个

关卡 ID：`cn_1960s_communal_canteen_001`  
年代：中国 20 世纪 60 年代初期，约 1962 年。  
答案：电饭煲、保鲜膜、一次性泡沫餐盒、洗洁精塑料瓶、易拉罐、感应水龙头。

Prompt：

> Create one busy vertical mobile hidden-object game illustration of a Chinese workplace communal canteen in the early 1960s, circa 1962. Show a brick kitchen and dining room with large iron woks, coal-fired stoves, aluminum steamers, wooden chopping boards, cleavers, ceramic bowls, enamel plates and mugs, bamboo baskets, cloth food covers, glass condiment bottles, long wooden tables and workers queuing with metal lunch boxes. Clothing is plain blue, gray and khaki cotton. Steamy warm interior light, medium visual density, historically grounded gongbi-inspired puzzle illustration.
>
> Include exactly six later kitchen objects: a white electric rice cooker among metal pots on the rear shelf; transparent cling film stretched over a bowl on the center preparation table; one white disposable foam meal box among reusable metal lunch boxes; a bright plastic squeeze bottle of dishwashing liquid beside the lower-right washbasin; one aluminum pull-tab drink can among glass bottles; and a chrome automatic sensor faucet at the communal sink. Use medium and small targets, with 15–25% natural occlusion on the cling-film bowl and foam box. Match colors to enamelware and metal utensils. No refrigerator, microwave, induction cooker, plastic disposable cutlery or other modern appliance.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait. Recompose the full scene for portrait orientation. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders or UI overlays.

## 06 1970 年代国营机械厂车间｜进阶｜8 个

关卡 ID：`cn_1970s_factory_workshop_001`  
年代：中国 20 世纪 70 年代中期，约 1976 年。  
答案：数显卡尺、激光测距仪、锂电电钻、触屏控制面板、二维码工牌、塑料安全帽、USB 闪存盘、LED 工作灯。

Prompt：

> Create one highly detailed vertical mobile hidden-object game illustration of a Chinese state-owned machinery factory workshop in the mid-1970s, circa 1976. Show heavy belt-driven lathes, drill presses, analog gauges, steel worktables, paper blueprints without readable text, slide rules, mechanical vernier calipers, oil cans, metal toolboxes, incandescent task lamps, ceiling pulleys, hand carts and workers in blue cotton uniforms and period cloth caps. Use cool industrial daylight, oily steel and faded green machinery, high visual density and precise narrative linework.
>
> Hide exactly eight later industrial objects: a digital-display caliper among mechanical calipers on a lower-center bench; a compact laser distance meter beside a folding ruler; a cordless lithium-battery power drill partly behind a metal toolbox; a small color touchscreen control panel fitted to one center-right lathe; a worker's badge containing a QR code but no readable words; one brightly molded plastic hard hat among period cloth and fiber safety caps; a small USB flash drive beside drafting tools; and a slim LED magnetic work light attached under an upper machine hood. Make targets small to medium and strongly integrated with machinery. Apply roughly 20–30% occlusion to the drill, flash drive and LED light. Include look-alike analog measuring tools and incandescent lamps as decoys. No robots, computers, modern forklifts or additional digital equipment.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait. Recompose the full scene for portrait orientation. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders or UI overlays.

## 07 1960 年代街道卫生所｜进阶｜8 个

关卡 ID：`cn_1960s_neighborhood_clinic_001`  
年代：中国 20 世纪 60 年代中期，约 1966 年。  
答案：电子体温计、一次性口罩、创可贴、乳胶检查手套、药片泡罩、塑料输液袋、血氧仪、免洗洗手液。

Prompt：

> Create one dense vertical mobile hidden-object game illustration of a small Chinese neighborhood clinic in the mid-1960s, circa 1966. Show a doctor taking a pulse, a nurse preparing glass syringes, glass IV bottles, mercury thermometers, cotton gauze masks, cloth bandages, brown glass medicine bottles, paper medicine packets, enamel trays, a mechanical scale, wooden medicine cabinets and patients in plain period clothing. Soft window light, pale green and aged cream interior, high-detail historically grounded narrative art.
>
> Hide exactly eight later medical objects: a slim digital thermometer among mercury thermometers in an enamel cup; a blue disposable nonwoven surgical mask among reusable cotton masks; a small adhesive bandage on a child's finger; one pale latex examination glove hanging partly behind an enamel basin; a silver pill blister strip among folded paper medicine packets; a transparent flexible plastic IV bag beside period glass infusion bottles; a fingertip pulse oximeter half visible on a high shelf; and a small pump bottle of alcohol hand sanitizer behind brown glass medicine bottles. Make all targets small, color-integrated and separated. Use 20–30% occlusion on the glove, oximeter and sanitizer bottle. Period-correct medical objects must act as close visual decoys. No modern monitor, disposable syringe, CT image, ultrasound unit or additional contemporary medical tool.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait. Recompose the full scene for portrait orientation. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders or UI overlays.

## 08 1970 年代绿皮火车硬座车厢｜困难｜8 个

关卡 ID：`cn_1970s_train_carriage_001`  
年代：中国 20 世纪 70 年代末期，约 1978 年。  
答案：高铁票、无线耳机、充电宝、拉杆箱、PET 饮料瓶、自拍杆、电子阅读器、行李密码锁。

Prompt：

> Create one extremely crowded vertical mobile hidden-object game illustration inside a Chinese green hard-seat railway carriage in the late 1970s, circa 1978. Show paired wooden or dark-green padded benches, small tables, overhead metal luggage racks, canvas bags, rope-tied bedrolls, bamboo baskets, enamel mugs, glass tea jars, paper tickets without readable text, thermos flasks, newspapers with illegible printing and travelers in accurate blue-gray period clothing. The aisle is active but orderly. Muted daylight through carriage windows, high visual density, layered depth and refined period narrative illustration.
>
> Hide exactly eight post-1970s travel objects: a small thermal-paper high-speed rail ticket with a QR code tucked into a center passenger's breast pocket; one white wireless earbud in a traveler's ear; a dark rectangular USB power bank partly under a folded cloth on a table; a compact hard-shell rolling suitcase behind canvas luggage on the upper rack; one clear disposable PET beverage bottle among glass jars in a lower basket; a collapsed selfie stick mixed with umbrella handles near the aisle; a thin black e-reader partly behind an old newspaper; and a small three-digit combination luggage lock attached to a canvas bag. Make targets small, strongly color-matched and about 25–35% occluded on four objects. Use paper tickets, wired radios, glass bottles, ordinary padlocks and umbrellas as decoys. No smartphone, laptop, air conditioning vent, modern train interior or other contemporary travel object.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait. Recompose the full scene for portrait orientation. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders or UI overlays.

## 09 1960 年代县城照相馆｜专家｜10 个

关卡 ID：`cn_1960s_photo_studio_001`  
年代：中国 20 世纪 60 年代末期，约 1969 年。  
答案：数码相机、存储卡、USB 读卡器、环形补光灯、遥控快门、自拍杆、喷墨照片、塑料覆膜机、纽扣电池、二维码取片单。

Prompt：

> Create one extremely detailed vertical mobile hidden-object game illustration of a small Chinese county-town photography studio in the late 1960s, circa 1969. Show a painted cloth backdrop, wooden posing chairs, a tripod-mounted medium-format film camera under a black focusing cloth, mechanical cable release, tungsten studio lamps with metal reflectors, rolls of film, paper negative sleeves, glass plates used as old stock, darkroom trays, enlarger, tongs, drying photographic prints, cardboard portrait folders, retouching brushes and customers in plain period clothing. Low warm studio light with a dim red darkroom beyond, very high visual density and meticulous narrative linework.
>
> Hide exactly ten later photographic objects: a compact digital camera body among film cameras; one tiny SD memory card in a film-box compartment; a USB card reader partly under negative sleeves; a circular LED ring light visually entangled with a round metal lamp reflector; a small wireless shutter remote among mechanical cable releases; a collapsed selfie stick among tripod legs; one glossy borderless inkjet photo among fiber-based prints; a compact plastic hot laminator partly behind the cutting table; one silver coin-cell battery among metal lens caps; and a collection slip bearing a QR code without readable words. Keep targets small or very small but identifiable at final resolution. Apply 30–40% occlusion to the card reader, laminator, remote and memory card. Strongly match colors to black cameras, silver tools and photographic paper. Use period-correct cameras, cable releases, reflectors, prints and lens caps as close decoys. No smartphone, computer monitor, modern printer or additional electronic camera accessory.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait. Recompose the full scene for portrait orientation. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders or UI overlays.

## 10 1970 年代国营工厂家属院｜专家｜10 个

关卡 ID：`cn_1970s_factory_compound_001`  
年代：中国 20 世纪 70 年代中期，约 1975 年。  
答案：无线蓝牙耳机、USB 闪存盘、二维码、智能手表、LED 灯泡、PET 塑料饮料瓶、电视遥控器、现代插线板、一次性打火机、带滚轮的塑料收纳箱。

Prompt：

> Create one extremely detailed vertical mobile hidden-object game illustration of everyday life in a northern Chinese state-owned factory residential compound in the mid-1970s, circa 1975. Show the shared corridor and courtyard of a modest red-brick tongzilou workers' residence: weathered brick walls, green-painted wooden doors and window frames, exposed incandescent-light wiring, communal water taps, coal stoves, honeycomb coal briquettes, enamel washbasins and mugs, aluminum lunch boxes, bamboo-shell thermos flasks, wooden stools, woven shopping baskets, canvas work bags, patched cotton clothes, paper-wrapped groceries, returnable glass soda bottles, traditional steel-frame bicycles, a handcart, drying quilts and laundry. Characters wear historically accurate plain blue, gray, olive-green and faded khaki Mao suits, cotton jackets, cloth shoes and simple caps. In the foreground, a woman washes vegetables beside an enamel basin while a child sorts glass bottles. In the middle ground, workers return with bicycles and canvas satchels, an elderly resident repairs a wooden radio cabinet, and neighbors prepare food around a coal stove. In the background corridor, residents hang laundry, carry thermos flasks and collect water from a shared tap. Fill the scene with historically correct decoys including a wired tabletop radio, rotary-dial telephone, incandescent bulbs, mechanical alarm clocks, glass beverage bottles, metal flashlights, matchboxes, wooden crates and cardboard cartons.
>
> Hide exactly ten post-1970s anachronisms in these semantic locations: one small white wireless Bluetooth earbud inside the lower-left enamel washbasin, partly concealed by vegetable leaves; one dark USB flash drive among sewing tools and metal bobbins on a lower-center wooden stool; one small black-and-white QR-code payment sticker on the side of a center-right wooden grocery crate, without readable words; one rectangular black smart watch partly visible beneath the blue sleeve of the bicycle-repairing worker near center-left; one white LED bulb in the upper-middle corridor fixture, distinct from the warm incandescent bulbs elsewhere; one transparent disposable PET beverage bottle with a molded screw cap among returnable glass soda bottles in a lower-right basket; one slim black television remote control partly tucked beneath a folded newspaper on the middle-right windowsill; one modern white multi-outlet power strip mostly hidden behind the center-right coal stove, with about two-thirds visible; one translucent disposable butane lighter mixed with historically correct matchboxes beside the foreground cooking area; and one small plastic storage box with integrated rolling wheels partly concealed behind wooden crates in the upper-left corridor.
>
> This is an expert-difficulty level. Make all ten targets small or very small but still recognizable at 1024 x 1536. Use strong color integration, dense neighboring clutter and approximately 25–40% natural occlusion on the earbud, smart watch, power strip, remote control and wheeled storage box. Only the PET bottle and LED bulb may be moderately noticeable. Use historically correct look-alike decoys: a wired radio near the remote control, a mechanical wristwatch elsewhere near the smart watch, glass bottles around the PET bottle, matchboxes around the lighter, incandescent bulbs near the LED bulb, and ordinary wooden boxes around the wheeled plastic box. Keep target silhouettes fair and identifiable rather than relying on malformed generation or extreme miniaturization.
>
> Maintain a muted 1970s palette of brick red, faded blue, gray, olive green, aged cream, coal black and weathered wood. Use soft overcast afternoon daylight mixed with restrained warm indoor incandescent light. Render sophisticated Chinese gongbi-inspired narrative game art with fine controlled linework, softly painted color, believable materials, natural human poses and very high visual density. Include exactly these ten anachronisms and no others. Do not add smartphones, laptops, flat-screen televisions, digital cameras, contemporary cars, electric scooters, modern athletic shoes, baseball caps, modern packaging, plastic shopping bags, aluminum drink cans, induction cookers, microwave ovens, air conditioners, modern road signs, satellite dishes, contemporary furniture or other post-1970s objects. Any printed material must contain no legible text, slogans, dates, brands, logos or Latin letters.
>
> Create one single vertical mobile hidden-object game image at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Design and recompose the entire scene specifically for the portrait canvas; do not crop, stretch, letterbox, rotate or merely resize a landscape composition. Reserve the top 12% and bottom 15% as low-detail UI-safe areas. Keep all ten target objects inside the central playable safe area with at least 8% margin from every outer edge. Distribute targets across foreground, middle ground and background, with clear spatial separation so no two target hitboxes overlap. No answer key, text labels, circles, arrows, highlights, glowing outlines, magnifying effects, split screen, comparison panels, collage, decorative border or UI overlay.

本关 Negative Prompt：

> wrong historical period, 1950s rural village, ancient Chinese robes, Qing dynasty clothing, Japanese architecture, Korean clothing, western retro diner, Soviet military parade, modern city skyline, contemporary apartment interior, smartphones, laptops, tablet computers, flat-screen television, electric scooter, modern car, plastic shopping bags, aluminum beverage cans, modern sneakers, baseball caps, synthetic sportswear, modern kitchen appliances, air conditioner, microwave oven, induction cooker, satellite dish, extra modern objects, duplicate target objects, missing target objects, oversized hidden objects, cropped target objects, unreadable target silhouettes, random readable text, gibberish typography, brand names, logos, watermark, answer labels, circles, arrows, highlights, glowing outlines, collage, split screen, comparison image, borders, UI overlay, photorealism, 3D render, deformed hands, extra fingers, distorted faces

## AI 答案定位与 Admin 导入协议

图片生成和答案定位分为两个阶段：

1. 按关卡 Prompt 生成候选图，选择并确认不再修改的最终成品。
2. 将最终图片交给支持视觉分析的 AI，逐项检查目标是否实际存在且可辨认。
3. AI 以最终图片左上角为原点重新测量答案。`x` 向右、`y` 向下，并归一化到 `0–1`。
4. `x`、`y` 表示目标可见区域中心；`radius` 是圆形点击热区半径相对于图片宽度的比例，建议为 `0.018–0.055`。
5. 热点覆盖目标可见部分并保留约 15–25% 点击容错，但不能覆盖相邻答案。
6. 缺失、重复、严重变形、被裁切或无法公平辨认的目标必须写入校验结果，不得生成虚假坐标。

视觉定位 Prompt：

> Inspect the final 1024 x 1536 hidden-object game image pixel by pixel. Locate only the expected anachronistic targets that are genuinely present and visually identifiable. For each valid target, estimate the center of its visible pixels and a fair circular tap radius. Convert values to normalized 0–1 coordinates using the full original image: x = center_px / 1024, y = center_py / 1536, radius = tap_radius_px / 1024. Do not infer coordinates from the generation prompt or intended semantic location. Do not invent a hotspot for a missing, duplicated, malformed, cropped or unrecognizable target. Return JSON only. Keep four decimal places for x, y and radius. Set shape to "circle" and operation to "anachronism". Report invalid targets and unexpected modern objects in validation.

AI 输出格式：

```json
{
  "level_id": "<当前关卡 ID>",
  "image_width": 1024,
  "image_height": 1536,
  "differences": [
    {
      "id": "<stable_snake_case_id>",
      "shape": "circle",
      "x": 0.0000,
      "y": 0.0000,
      "radius": 0.0400,
      "label": "<中文答案名>",
      "era": "<物品普及或出现年代>",
      "explanation": "<为什么不属于本关年代>",
      "difficulty": 5,
      "operation": "anachronism"
    }
  ],
  "validation": {
    "expected_count": "<当前关卡答案数>",
    "located_count": 0,
    "missing_or_invalid": [],
    "duplicate_targets": [],
    "unexpected_anachronisms": [],
    "ready_for_admin_import": false
  }
}
```

其中 `expected_count` 在实际输出中必须是整数，并与 `pack.json` 中当前关卡的 `answer_count` 一致。只有答案数量准确、所有异常数组为空、热点位于安全区且互不重叠时，`ready_for_admin_import` 才能设为 `true`。之后由导入流程补充图片资产字段，并将 `differences` 写入 Admin 关卡运行时 JSON；导入完成后仍需叠加热点做一次目视复核。

## 使用流程

1. 每个 Prompt 生成 3–4 个候选。
2. 选择构图稳定、目标齐全且无额外现代物品的一张。
3. 局部修复缺失、重复或变形目标，并锁定最终图片。
4. 将最终图片命名为 `<level_id>.png`。
5. 执行“AI 答案定位与 Admin 导入协议”。
6. 仅在 `ready_for_admin_import` 为 `true` 时导入 Admin。
