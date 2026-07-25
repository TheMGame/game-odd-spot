# 中国历史“找出时代错误”Prompt 包 V1

本包包含 10 个单图关卡。所有图片统一为 1024 x 1536、竖向 2:3、精致工笔叙事插画风。游戏只使用一张包含时代错误的最终图，不生成左右对照图。

## 难度分档

难度不只由答案数量决定：

| 档位 | 答案数 | 物件大小 | 遮挡 | 色彩融合 | 画面密度 | 历史知识 |
|---|---:|---|---|---|---|---|
| 入门 | 5 | 大、中 | 无 | 明显反差 | 低 | 常识即可 |
| 简单 | 5 | 中 | 极少 | 少量融合 | 中 | 常识即可 |
| 普通 | 6 | 中、小 | 少量 | 中等融合 | 中 | 少量常识 |
| 进阶 | 8 | 中、小 | 约 25% | 较强融合 | 高 | 需要观察 |
| 困难 | 8 | 小 | 约 35% | 强融合 | 高 | 少量历史知识 |
| 专家 | 10 | 小、微小 | 约 40% | 强融合 | 很高 | 观察与知识结合 |

额外调节维度：

- `object_size`：目标在画面中的相对尺寸。
- `occlusion`：目标被人物、桌沿、货物遮挡的比例。
- `color_similarity`：目标颜色是否与周围环境相近。
- `visual_density`：目标附近物件数量。
- `edge_distance`：目标是否靠近画面边缘。
- `semantic_obviousness`：现代属性是否一眼可见。
- `decoy_similarity`：是否有外形相似但符合年代的干扰物。
- `knowledge_depth`：是否需要知道物件的大致发明年代。

## 通用 Negative Prompt

wrong dynasty clothing, Qing queue hairstyle outside Qing scenes, Japanese architecture, Korean clothing, fantasy armor, western medieval castle, random readable text, gibberish typography, watermark, logo, collage, split screen, comparison image, duplicate modern objects, extra anachronisms, deformed hands, extra fingers, distorted face, cropped target object, photorealism

## 01 北宋汴京市集｜入门｜5 个

年代：北宋末年，约 1100 年。  
答案：金属拉链、现代腕表、塑料水瓶、白炽电灯泡、现代安全自行车。

Prompt：

> Create one polished vertical mobile hidden-object game illustration of a bustling market in Bianjing, Northern Song China, circa 1100 CE. Historically grounded timber shopfronts, tiled roofs, fabric awnings, handcarts, shoulder poles, woven baskets, ceramic jars, candle-lit paper lanterns, and townspeople in accurate Song cross-collar robes and putou headwear. Warm daylight, readable composition, fine gongbi-inspired linework with softly painted color. Include exactly five recognizable anachronisms: a metal zipper on the large blue robe in the lower-left, a modern analog wristwatch on a vendor near center-left, a transparent plastic water bottle with blue cap on the lower-center stall, an incandescent bulb glowing inside the large upper-right paper lantern, and a complete modern safety bicycle parked in the lower-right street. Make these five objects medium or large, unobstructed, and slightly color-contrasted for beginner difficulty. No other modern object. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 02 盛唐长安夜市｜简单｜5 个

年代：唐玄宗时期，约 740 年。  
答案：智能手机、铝制易拉罐、太阳镜、滑板、LED 灯串。

Prompt：

> Create one richly detailed evening market scene in Chang'an during the High Tang dynasty, circa 740 CE. Accurate Tang timber architecture, ward-market atmosphere, candle and oil lanterns, Central Asian merchants, horses, silk stalls, ceramic cups, wooden trays, and Tang garments. Warm amber dusk, elegant gongbi-inspired game illustration, readable silhouettes. Include exactly five anachronisms: a glowing smartphone held by a young customer in the center-left, a red aluminum beverage can on a food counter, modern dark sunglasses on a merchant, a skateboard leaning against a lower-right stall, and a short string of tiny LED fairy lights under the upper awning. Keep the first four clear; make only the LED string slightly subtle. Do not add electric wires elsewhere. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 03 明代江南书院｜简单｜5 个

年代：明代中期，约 1500 年。  
答案：圆珠笔、订书机、电子计算器、塑料直尺、现代台灯。

Prompt：

> Create one serene Jiangnan academy classroom during the mid-Ming dynasty, circa 1500 CE. Scholars in accurate Ming robes study at wooden desks with bound thread books, brushes, inkstones, paper, bamboo slips used as references, ceramic brush washers, lattice windows and a courtyard beyond. Daylight, calm gongbi-inspired educational game art, medium visual density. Include exactly five modern intrusions: a blue ballpoint pen beside an inkstone in the lower-left, a black metal stapler on the teacher's desk, a pocket electronic calculator among books in the center, a transparent plastic ruler across one sheet of paper, and an adjustable electric desk lamp at the right desk. All five should be fully visible and medium-sized. No printed Latin text or other modern stationery. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 04 西汉边塞军营｜普通｜6 个

年代：西汉，约公元前 100 年。  
答案：双筒望远镜、罐头、手电筒、现代钢盔、橡胶轮胎、腕表。

Prompt：

> Create one historically grounded Western Han frontier military camp, circa 100 BCE, with rammed-earth watchtower, canvas and hide tents, wooden carts with solid wooden wheels, horses, crossbows, spears, lacquered shields, bamboo documents, bronze and iron utensils, and soldiers in Han lamellar armor. Clear morning light, dusty earth palette, dense but readable gongbi-inspired game illustration. Include exactly six anachronisms: compact binoculars hanging from the watchman's neck, a sealed modern food can near a cooking pot, a metal flashlight partly under a folded blanket, one modern rounded steel combat helmet among lacquered helmets, one black pneumatic rubber tire fitted to the supply cart, and a small analog wristwatch on the officer. Use medium and small objects, with the flashlight about 20% occluded and colors blended into the camp. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 05 乾隆时期宫廷画坊｜普通｜6 个

年代：清乾隆时期，约 1750 年。  
答案：照相机、电话、打字机、电风扇、钢笔、塑料调色板。

Prompt：

> Create one refined imperial painting workshop inside a Qing palace during the Qianlong era, circa 1750 CE. Accurate Qing court robes and hairstyles, painters using brushes, ink, mineral pigments, silk scrolls, porcelain water dishes, wooden cabinets and palace lattice windows. Balanced indoor daylight, restrained imperial colors, gongbi-inspired premium puzzle art. Include exactly six later inventions: a compact folding camera on a shelf, a black rotary telephone on a side table, a small typewriter partly covered by a silk cloth, an electric desk fan near the window, a fountain pen placed among calligraphy brushes, and a white plastic oval paint palette held by an apprentice. Make the camera and telephone obvious; blend the pen and palette with legitimate art tools. No power cords except a short cord attached to the fan. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 06 三国江边军寨｜进阶｜8 个

年代：东汉末年至三国初期，约 210 年。  
答案：无线电台、手电筒、罐头、双筒望远镜、腕表、橡胶雨靴、拉链、保温瓶。

Prompt：

> Create one busy riverside military encampment in China circa 210 CE, avoiding fantasy and opera costumes. Timber palisade, river boats with cloth sails, signal flags, crossbows, spears, lacquered armor, command table with hand-drawn silk map, cooking fires and supply baskets. Overcast river light, high visual density, historically grounded gongbi-inspired game art. Hide exactly eight anachronisms: a compact field radio behind rolled maps, a flashlight beside an oil lamp, a canned food tin among ceramic bowls, binoculars held by a lookout, an analog wristwatch partly covered by a sleeve, black rubber rain boots on one soldier, a short metal zipper on a supply pouch, and a stainless-steel vacuum flask among pottery. Objects should be small to medium; obscure the radio, watch and zipper by roughly 20–30%; match their colors to wood, bronze and dark fabric. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 07 元代北方驿站｜进阶｜8 个

年代：元代中期，约 1300 年。  
答案：煤油灯、火柴盒、怀表、报纸、搪瓷杯、保温瓶、行李拉杆箱、电门铃。

Prompt：

> Create one crowded postal relay station in northern Yuan China, circa 1300 CE. Accurate Yuan robes and hats, Mongol and Han travelers, tethered horses, saddles, wooden travel chests, paper travel documents, oil lamps, ceramic bowls, felt blankets and a timber inn interior. Cold late-afternoon light, earthy colors, high-detail gongbi-inspired puzzle illustration. Include exactly eight later objects: a glass kerosene lamp replacing one oil dish, a small matchbox near the hearth, a brass pocket watch half visible from a traveler's sash, a folded modern newspaper without readable headlines, a white enamel mug with blue rim, a stainless vacuum flask, a wheeled hard-shell suitcase partly behind a wooden chest, and a small electric doorbell button beside the entrance. Keep all text illegible. Use strong color integration and 25–35% occlusion on the watch, suitcase and doorbell. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 08 北宋泉州海港｜困难｜8 个

年代：北宋末年，约 1120 年。  
答案：望远镜、六分仪、航海钟、救生圈、集装箱、塑料浮标、舷外发动机、条形码。

Prompt：

> Create one expansive maritime trading harbor in Quanzhou during the late Northern Song, circa 1120 CE. Chinese ocean-going junks with battened sails, wooden docks, rope coils, ceramic cargo jars, tea chests, foreign merchants, porters, handcarts, canvas bundles and accurate Song clothing. Bright hazy coastal daylight, high visual density, sophisticated gongbi-inspired game illustration. Include exactly eight maritime anachronisms: a brass telescope used by a dock official, a sextant resting on a crate, a boxed marine chronometer inside an open chest, a red-and-white modern life ring on a ship rail, one small corrugated metal shipping container in the far background, a bright plastic buoy floating near the dock edge, a compact outboard motor attached to a small wooden boat, and a printed barcode label on a foreground cargo crate. Make the life ring moderately visible; keep the sextant, chronometer, motor and barcode small and partially occluded. No steamship or other modern port equipment. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 09 明代医馆｜专家｜10 个

年代：明代嘉靖时期，约 1550 年。  
答案：听诊器、注射器、体温计、创可贴、乳胶手套、药片泡罩、X 光片、塑料药瓶、圆珠笔、电热消毒器。

Prompt：

> Create one extremely detailed traditional medical clinic in Ming China, circa 1550 CE. Physician taking a pulse, assistants preparing herbs with bronze scales, ceramic medicine jars, paper prescriptions written by brush, wooden drawers, mortar and pestle, acupuncture case, cloth bandages and waiting patients in accurate Ming clothing. Soft window light, dense layered composition, refined gongbi-inspired hidden-object game art. Include exactly ten medical anachronisms: a stethoscope partly under a folded cloth, a glass-and-metal hypodermic syringe beside acupuncture needles, a slim clinical thermometer in a ceramic cup, a small adhesive bandage on a patient's finger, one pale latex glove hanging from a basin edge, a silver pill blister pack among paper packets, a dark X-ray film partly behind the physician's screen, an amber plastic medicine bottle on a high shelf, a ballpoint pen among brushes, and a compact electric sterilizer partly hidden under the rear table. Keep targets small, use 30–40% occlusion on four targets, and closely match surrounding colors. Do not add other Western medical tools. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 10 盛唐丝路驿馆｜专家｜10 个

年代：唐代中期，约 750 年。  
答案：护照、拉杆箱、太阳镜、腕表、数码相机、易拉罐、塑料瓶、现代路牌、手电筒、耳机。

Prompt：

> Create one highly populated Silk Road caravan inn near Dunhuang during the Tang dynasty, circa 750 CE. Tang Chinese officials, Sogdian merchants, camel handlers and travelers unloading silk, spices and ceramic goods; mud-brick courtyard, timber galleries, oil lamps, woven rugs, leather bags, wooden chests and paper travel permits. Golden late-afternoon light, very high visual density, historically grounded gongbi-inspired premium puzzle art. Include exactly ten modern travel objects: a burgundy passport half visible from a leather satchel, a compact hard-shell rolling suitcase behind a wooden chest, dark sunglasses on a Sogdian merchant, a small wristwatch under a sleeve, a digital camera hanging among amulets, an aluminum drink can beside ceramic cups, a clear plastic bottle inside a travel basket, a small modern road sign with Arabic numerals near the gate, a flashlight among rolled bedding, and one wired earbud hanging from a traveler's collar. Make only the can and sunglasses immediately obvious; all others small, color-matched, near edges or 25–40% occluded. No car, aircraft, electric lighting or additional modern object. Create one single vertical mobile game image at exactly 1024 x 1536 pixels (2:3 portrait). Recompose the entire scene for portrait orientation; do not crop, stretch, letterbox, rotate, or merely resize a landscape image. Keep every anachronistic target fully visible, naturally integrated, and separated from the others. Reserve the top 12% and bottom 15% as low-detail UI-safe areas, and keep all targets inside the central safe area with at least 8% margin from every edge. No text, labels, circles, arrows, split screen, comparison panels, borders, or UI overlays.

## 使用建议

1. 每个 Prompt 一次生成 3–4 个候选，选择构图最稳定的一张。
2. 检查模型是否真的生成了全部指定答案，缺少时只做局部编辑。
3. 检查是否意外生成额外现代物件。
4. 最终图片按关卡 ID 命名为 `<level_id>.png`。
5. Admin 中以原图像素尺寸录入答案中心和区域；保存时转换为 0–1 归一化坐标。
