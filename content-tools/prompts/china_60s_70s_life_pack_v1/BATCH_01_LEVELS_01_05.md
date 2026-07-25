# 图片生成批次 01｜关卡 01–05（完整 Prompt）

## 批次执行规则

- 逐关生成独立图片，不得把五关合成一张图。
- 每关先只生成 1 张。检查不通过时，仅重新生成或局部修复当前关卡，不预先批量生成候选。
- 输出必须为 1024 × 1536、2:3 竖图，并按 `<level_id>.png` 命名。
- 本阶段只生成图片，不输出答案坐标、热点或 Admin JSON。
- 缺失、重复、变形或不可辨认的目标必须局部修复后再定稿。

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
