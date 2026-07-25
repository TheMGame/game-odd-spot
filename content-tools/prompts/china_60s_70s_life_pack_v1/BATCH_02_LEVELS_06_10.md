# 图片生成批次 02｜关卡 06–10（完整 Prompt）

## 批次执行规则

- 逐关生成独立图片，不得把五关合成一张图。
- 每关先只生成 1 张。检查不通过时，仅重新生成或局部修复当前关卡，不预先批量生成候选。
- 输出必须为 1024 × 1536、2:3 竖图，并按 `<level_id>.png` 命名。
- 本阶段只生成图片，不输出答案坐标、热点或 Admin JSON。
- 缺失、重复、变形或不可辨认的目标必须局部修复后再定稿。

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
