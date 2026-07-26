# 中国传统手艺·非遗工坊 Prompt 包 V1

本包包含 10 个单图关卡。每关呈现一项中国传统手工艺的纯手工作坊，玩家找出混入传统流程的现代电动设备、合成材料、数字仪器或工业包装。所有图片统一为 1024 × 1536、2:3 竖图；一关一图，不生成对比图或候选宫格。

## 设计原则

- 场景基准为约 1880 年的清代晚期传统手工作坊，并明确采用无电力机械的纯手工流程。
- 合法物件以木、竹、陶、铜、铁、天然纤维、天然颜料及传统手工具为主。
- 答案选择无争议的现代物件，不使用发明年代边界模糊的普通手工具。
- 高难度依靠尺寸、遮挡、色彩融合、密度和相似干扰物，不依靠畸形或不可辨认目标。
- 图片生成后必须在最终成图上重新确认答案并测量坐标。

## 难度梯度

| 关卡 | 场景 | 档位 | 答案数 |
|---:|---|---|---:|
| 01 | 泾县宣纸作坊 | 入门 | 5 |
| 02 | 景德镇制瓷作坊 | 简单 | 5 |
| 03 | 桃花坞木版年画作坊 | 简单 | 5 |
| 04 | 南京云锦织造坊 | 普通 | 6 |
| 05 | 北京景泰蓝作坊 | 普通 | 6 |
| 06 | 榫卯木作营造场 | 进阶 | 8 |
| 07 | 龙泉宝剑锻制坊 | 进阶 | 8 |
| 08 | 福州脱胎漆器髹饰坊 | 困难 | 8 |
| 09 | 陕西皮影戏后台 | 专家 | 10 |
| 10 | 山间古法制茶坊 | 专家 | 10 |

## 资料依据

- [宣纸传统制作技艺](https://www.ihchina.cn/xuanzhi.html)：青檀皮、沙田稻草和传统手工制纸流程。
- [景德镇手工制瓷技艺](https://www.ihchina.cn/Article/Index/detail?id=14270)：拉坯、利坯、施釉、装烧等传统工序。
- [桃花坞木版年画](https://www.ihchina.cn/project_details/13902.html)：画稿、刻版、套色印刷和传统工具。
- [南京云锦织造技艺](https://www.ihchina.cn/yunjinzhizao.html)：大花楼木织机、拽花工与织手配合。
- [景泰蓝制作技艺](https://www.bjdch.gov.cn/mldc/bglj/fwzwhyc/ctjy/202008/t20200828_2975781.html)：制胎、掐丝、烧蓝、磨光和镀金。
- [中国传统木结构建筑营造技艺](https://www.ihchina.cn/mujiegou.html)：木材、榫卯和模数制。
- [福州脱胎漆器髹饰技艺](https://www.ihchina.cn/art/detail/id/14362.html)：传统脱胎与髹饰体系。
- [中国皮影戏](https://www.ihchina.cn/project_details/11905/)：皮制或纸制影偶、木杆操控与灯光投影。
- [中国传统制茶技艺及其相关习俗](https://ich.unesco.org/en/RL/traditional-tea-processing-techniques-and-associated-social-practices-in-china-01884)：茶叶采摘、手工加工和饮用实践。

## 通用 Negative Prompt

extra modern objects, unlisted electric tools, factory assembly line, modern architecture, modern clothing, readable text, brands, logos, QR codes unless explicitly listed, fantasy costume, Japanese workshop, Korean clothing, malformed tools, fused targets, duplicated targets, microscopic objects, collage, split screen, comparison image, candidate grid, labels, circles, arrows, highlights, watermark, border, UI overlay

## 01 泾县宣纸作坊｜入门｜5 个

关卡 ID：`cn_craft_xuan_paper_001`  
年代：清代晚期，约 1880 年。  
答案：电动搅拌机、塑料水桶、一次性丁腈手套、数字电子秤、LED 工作灯。

Prompt：

> Create one polished vertical mobile hidden-object game illustration of a traditional Xuan paper workshop in Jing County, Anhui, late Qing China circa 1880. Show artisans processing sandalwood bark and rice straw, soaking fibers in stone vats, beating pulp with wooden tools, lifting wet sheets with bamboo screens, pressing paper, brushing sheets onto a drying wall, and stacking finished white paper. Use timber beams, stone floors, bamboo baskets, ceramic jars, cotton clothing and soft humid morning light in refined Chinese narrative illustration. Include exactly five obvious modern intrusions: a red electric immersion pulp mixer in the center vat; a bright blue molded plastic bucket beside a stone trough; a pair of blue disposable nitrile gloves on a central workbench; a digital electronic tabletop scale beside fiber bundles; and a slim LED work light mounted beneath a drying rack. Keep all five medium or large, unobstructed, separated and slightly color-contrasted. Include no other modern object. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 02 景德镇制瓷作坊｜简单｜5 个

关卡 ID：`cn_craft_jingdezhen_porcelain_001`  
年代：清代晚期，约 1880 年。  
答案：电动拉坯机、喷釉枪、塑料釉料桶、红外测温枪、气泡膜。

Prompt：

> Create one richly detailed vertical mobile hidden-object game illustration of a traditional porcelain workshop in Jingdezhen, late Qing China circa 1880. Show artisans wedging clay, shaping vessels on hand-powered pottery wheels, trimming leather-hard bowls, painting cobalt decoration with brushes, dipping wares in glaze, loading saggers and tending a wood-fired kiln. Include wooden shelves, clay tubs, bamboo tools, ceramic bowls, cotton aprons and warm kiln light. Include exactly five modern intrusions: a compact electric pottery wheel with a visible power pedal at center-left; a metal spray-glaze gun on the rear worktable; a white molded plastic glaze bucket below a shelf; a handheld infrared thermometer aimed toward the kiln; and a roll of clear plastic bubble wrap beside finished porcelain at lower-right. Keep targets medium-sized and mostly unobstructed, with light color blending. No other modern workshop equipment. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 03 桃花坞木版年画作坊｜简单｜5 个

关卡 ID：`cn_craft_taohuawu_print_001`  
年代：清代晚期，约 1880 年。  
答案：喷墨打印机、电动雕刻笔、丙烯颜料软管、透明塑料直尺、自动回墨印章。

Prompt：

> Create one elegant vertical mobile hidden-object game illustration of a Taohuawu woodblock New Year print workshop in Suzhou, late Qing China circa 1880. Show artists drawing designs, transferring outlines to pear-wood blocks, carving with traditional knives and chisels, brushing water-based pigments, hand-printing separate color blocks on paper and hanging bright finished prints. Use Jiangnan timber interiors, lattice windows, inkstones, ceramic pigment dishes, paper stacks and restrained festive color. Include exactly five modern intrusions: a compact inkjet printer on a rear side table; a corded rotary engraving pen among hand carving knives; a squeezed acrylic paint tube beside mineral pigment dishes; a transparent plastic ruler across a paper stack; and a rectangular self-inking office stamp near the printing bench. Keep all targets medium-sized and fully readable, with only mild blending. Add no other modern stationery or machine. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 04 南京云锦织造坊｜普通｜6 个

关卡 ID：`cn_craft_yunjin_brocade_001`  
年代：清代晚期，约 1880 年。  
答案：电动缝纫机、涤纶线轴、尼龙拉链、塑料梭芯、平板电脑、LED 灯带。

Prompt：

> Create one dense vertical mobile hidden-object game illustration of a traditional Nanjing Yunjin brocade workshop in late Qing China circa 1880. Center a towering wooden jacquard loom operated manually by a drawboy above and a weaver below, surrounded by silk bobbins, gold thread, pattern drafts, bamboo tools, wooden winding frames and folded brocade. Use filtered window light, jewel-toned textiles and detailed historically grounded narrative art. Include exactly six modern intrusions: a compact electric sewing machine on a lower-left table; one bright polyester thread spool among natural silk reels; a short nylon zipper pinned to a folded brocade sample; a translucent plastic bobbin inside a wooden tray; a thin touchscreen tablet displaying an abstract pattern on the rear desk; and a short LED light strip concealed under the loom canopy. Use medium and small targets, 15–25% occlusion on the zipper and bobbin, and period silk reels as decoys. No additional modern textile tools or synthetic fabric. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 05 北京景泰蓝作坊｜普通｜6 个

关卡 ID：`cn_craft_cloisonne_001`  
年代：清代晚期，约 1880 年。  
答案：热熔胶枪、环氧树脂双管胶、迷你电磨、数显卡尺、气雾喷漆罐、电磁炉。

Prompt：

> Create one ornate vertical mobile hidden-object game illustration of a traditional Beijing cloisonne workshop in late Qing China circa 1880. Show artisans hammering copper bodies, bending and attaching fine copper wires into patterns, filling cells with colored enamel paste, firing small pieces in a charcoal furnace, polishing surfaces with stones and preparing gilded rims. Surround them with copper vessels, wire coils, ceramic pigment dishes, charcoal braziers, hand files and polishing stones. Warm workshop light, turquoise and deep-blue accents, medium-high detail. Include exactly six modern intrusions: a red hot-glue gun beside wire tools; a twin-syringe epoxy adhesive package partly behind enamel dishes; a handheld electric rotary grinder among manual files; a digital caliper measuring a vase rim; a small aerosol spray-paint can on a lower shelf; and a black induction hot plate beneath a copper bowl. Use 15–25% occlusion on the epoxy and spray can and blend colors with legitimate tools. No other modern adhesive, electric tool or synthetic coating. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 06 榫卯木作营造场｜进阶｜8 个

关卡 ID：`cn_craft_timber_joinery_001`  
年代：清代晚期，约 1880 年。  
答案：无绳电钻、激光水平仪、气动钉枪、十字螺丝、塑料安全帽、电圆锯、聚氨酯泡沫胶罐、角磨机。

Prompt：

> Create one busy vertical mobile hidden-object game illustration of a traditional Chinese timber-frame construction yard in late Qing China circa 1880. Show master carpenters marking full-size modules with ink lines and measuring rods, apprentices cutting mortises and tenons by hand, wooden columns and beams test-fitted without metal fasteners, hand saws, axes, chisels, mallets, planes, bamboo scaffolding and an unfinished tiled hall. Clear afternoon light, timber-and-earth palette, high visual density. Hide exactly eight modern violations: a cordless power drill among brace drills on the center bench; a compact laser level on a beam; a pneumatic nail gun partly under a tool cloth; several shiny Phillips-head screws in a wooden parts tray; a yellow molded plastic hard hat on a post; an electric circular saw behind stacked boards; a pressurized polyurethane expanding-foam can beside natural glue pots; and a small angle grinder among sharpening stones. Keep targets medium-small, about 25% occluded on the nail gun, saw and grinder, color-integrated with tools, and use period hand drills and saws as decoys. No other metal fastener or powered machine. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 07 龙泉宝剑锻制坊｜进阶｜8 个

关卡 ID：`cn_craft_longquan_sword_001`  
年代：清代晚期，约 1880 年。  
答案：电弧焊机、角磨机、电动砂带机、丙烷喷枪、数字高温计、塑料机油瓶、透明面罩、充电式工作灯。

Prompt：

> Create one dramatic vertical mobile hidden-object game illustration of a traditional Longquan sword-forging workshop in late Qing China circa 1880. Show smiths heating layered steel in a charcoal forge, hand-hammering on anvils, quenching blades in a long trough, filing and polishing by hand, fitting wooden hilts and examining straight blades. Include bellows, charcoal baskets, tongs, hammers, whetstones, water buckets and warm sparks against a dark timber interior. Hide exactly eight modern intrusions: a compact electric arc welder under the rear bench; a handheld angle grinder beside files; an electric belt sander partly behind a polishing stand; a blue propane blowtorch near the charcoal forge; a pistol-shaped digital infrared pyrometer aimed at a blade; a translucent plastic motor-oil bottle beside quench vessels; a clear polycarbonate full-face shield hanging from a peg; and a rechargeable LED work light under the center shelf. Keep targets small to medium, around 25% occluded on the welder, sander and light, with dark metal color integration and manual grinding stones as decoys. No other powered equipment or modern protective gear. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 08 福州脱胎漆器髹饰坊｜困难｜8 个

关卡 ID：`cn_craft_fuzhou_lacquer_001`  
年代：清代晚期，约 1880 年。  
答案：喷漆罐、电热风枪、合成树脂瓶、保鲜膜卷、电动打磨机、泡沫刷、数字湿度计、热熔胶枪。

Prompt：

> Create one sophisticated vertical mobile hidden-object game illustration of a traditional Fuzhou bodiless lacquerware workshop in late Qing China circa 1880. Show artisans forming a clay mold, wrapping it with hemp cloth and natural lacquer, removing the inner mold, applying repeated lacquer coats, inlaying decoration and polishing lightweight finished vessels. Include wooden racks, covered bowls of lacquer, linen, brushes, charcoal warming trays, polishing powder and glossy black-red-gold objects. Soft controlled indoor light, dense layered composition and strong reflections. Hide exactly eight modern intrusions: an aerosol spray-paint can behind lacquer jars; an electric heat gun among charcoal warming tools; a small synthetic resin bottle beside natural lacquer bowls; a roll of clear plastic cling film partly under hemp cloth; a compact electric orbital sander behind a polishing tray; a disposable rectangular foam brush among hair brushes; a tiny digital humidity meter on a high shelf; and a red hot-glue gun beneath the inlay table. Make targets small, about 30–35% occluded on four objects, closely color-matched, with traditional brushes and stones as decoys. No other plastic container, synthetic finish or electric device. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 09 陕西皮影戏后台｜专家｜10 个

关卡 ID：`cn_craft_shadow_puppet_001`  
年代：清代晚期，约 1880 年。  
答案：LED 平板灯、透明塑料片、电动雕刻笔、丙烯马克笔、订书机、透明胶带、无线麦克风、蓝牙音箱、平板电脑、塑料扎带。

Prompt：

> Create one extremely detailed vertical mobile hidden-object game illustration of a Shaanxi shadow-puppet troupe backstage in late Qing China circa 1880. Show artisans scraping and carving translucent cowhide figures, applying mineral colors, joining articulated limbs with thread, attaching bamboo control rods, while performers prepare a white paper screen, oil lamp, drums, gongs and string instruments. Fill the timber room with puppet racks, carving knives, awls, pigment dishes, scripts and costume chests. Warm oil-lamp light, layered foreground and background, very high density. Hide exactly ten modern intrusions: a slim LED light panel behind the paper screen; a clear plastic transparency sheet among prepared hides; a corded electric engraving pen among carving knives; an acrylic paint marker in a brush cup; a small metal office stapler beside joint threads; a roll of clear adhesive tape partly under paper scripts; a wireless handheld microphone beside traditional instruments; a compact Bluetooth speaker behind a drum; a touchscreen tablet displaying an abstract script layout on a rear stand; and two plastic zip ties among bamboo control rods. Keep targets small, 30–40% occlusion on at least four, color-integrated, with oil lamps, knives, thread and bamboo rods as close decoys. No extra modern light, audio device, plastic or office tool. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 10 山间古法制茶坊｜专家｜10 个

关卡 ID：`cn_craft_traditional_tea_001`  
年代：清代晚期，约 1880 年。  
答案：电炒茶锅、数字水分仪、真空封口机、铝箔茶袋、塑料茶勺、尼龙筛网、红外测温枪、电热水壶、条形码标签、干燥剂小包。

Prompt：

> Create one extremely detailed vertical mobile hidden-object game illustration of a traditional mountain tea-processing workshop in late Qing China circa 1880. Show baskets of freshly picked leaves, artisans withering tea on bamboo trays, hand-tossing and rolling leaves, firing them in wood- or charcoal-heated iron woks, sorting with woven bamboo sieves, drying on racks and packing tea into paper-lined bamboo baskets and ceramic jars. Open timber walls reveal misty tea terraces; use humid morning light, green-brown palette and very high object density. Hide exactly ten modern intrusions: an electric thermostatic tea-firing wok with a small control panel; a handheld digital leaf-moisture meter; a tabletop vacuum heat sealer behind packing baskets; a silver foil-lined stand-up tea pouch among folded paper wrappers; a molded plastic tea scoop inside a bamboo tray; a fine blue nylon mesh sieve among woven bamboo sieves; a pistol-shaped infrared thermometer beside the charcoal wok; a stainless electric kettle behind ceramic kettles; a small barcode sticker on a paper tea parcel; and a tiny silica-gel packet half visible inside an open storage jar. Keep targets small, 30–40% occluded on at least four, strongly color-integrated, and use manual woks, paper packets and bamboo sieves as decoys. No other electricity, plastic packaging or digital instrument. Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image, not a contact sheet, collage or multi-panel composition. Keep every target inside the central safe area, reserve the top 8%, bottom 10% and left/right 7% margins for non-essential background, and separate targets by at least 8% of canvas width. No readable text, brands, labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## 使用方式

图片生成请分别使用 `BATCH_01_LEVELS_01_05.md` 和 `BATCH_02_LEVELS_06_10.md`。每关首次只生成一张图；若某关缺失目标或构图失败，只修复或重生成该关。
