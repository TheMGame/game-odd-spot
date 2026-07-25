# cn_song_bianjing_001 — 北宋汴京市井

## 生成顺序

先用“基准图 Prompt”生成一张图，选定后保存为：

`client/assets/levels/cn_song_bianjing_001/base.png`

然后把这张图作为唯一参考图，使用“目标图编辑 Prompt”做局部编辑，保存为：

`client/assets/levels/cn_song_bianjing_001/target.png`

不要独立文生图两次，否则人物、建筑和镜头会产生大量非预期差异。

## 基准图 Prompt

Create a polished vertical mobile hidden-object game illustration set in the bustling market of Bianjing (Kaifeng) during the late Northern Song dynasty, circa 1100 CE. Historically grounded Chinese urban daily life: timber shopfronts with tiled roofs, fabric awnings, wooden signboards with non-legible decorative marks, handcarts, shoulder poles, woven baskets, ceramic jars, paper lanterns lit by candles, merchants and townspeople wearing accurate Song-dynasty cross-collar robes, cloth belts, putou headwear, and simple cloth shoes. Warm daylight, lively but readable composition, fine gongbi-inspired linework combined with softly painted color, cinematic depth, family-friendly, premium mobile puzzle game art.

Use a fixed eye-level portrait composition with layered foreground, middle ground, and background and deliberately reserve five readable object zones: lower-left robe front, center-left vendor wrist, lower-center drink vessel beside a stall, upper-right hanging lantern, lower-right open street. Every object must belong plausibly to China around 1100 CE. No fantasy, no Qing clothing, no Japanese architecture, no modern technology. 2:3 portrait composition, exactly 1024 x 1536. Recompose the scene vertically rather than cropping or stretching a landscape image. Reserve the top 12% and bottom 15% as low-detail UI-safe areas; keep all five targets within the central safe area and at least 8% away from every edge.

## 基准图 Negative Prompt

modern objects, zipper, wristwatch, clock, plastic, plastic bottle, glass soda bottle, electric light, light bulb, bicycle, motorcycle, car, cable, power line, neon sign, printed Latin letters, Arabic numerals, camera, umbrella with metal ribs, gun, Qing queue hairstyle, Manchu clothing, Japanese torii, modern storefront, photorealism, text, watermark, logo, extra fingers, distorted hands, cropped bicycle

## 目标图编辑 Prompt

Edit the supplied base image with a strict locked composition. Preserve every pixel, character, pose, face, garment color, building, lighting, shadow, texture, crop, and camera position except for the following five localized changes:

1. Lower-left: add a small but clearly recognizable metal zipper to the front opening of one merchant's robe.
2. Center-left: add a compact modern analog wristwatch with a dark leather strap to the visible wrist of the vendor.
3. Lower-center: replace one small ceramic drink flask beside the stall with a transparent disposable plastic water bottle with a blue cap; preserve its size and shadow.
4. Upper-right: replace the candle flame inside one hanging paper lantern with a clearly visible pear-shaped incandescent electric light bulb, with no wire.
5. Lower-right open street: add one small complete modern safety bicycle with two equal wheels, pedals, chain and curved handlebar, naturally parked and matching the scene's painted style.

Make exactly these five changes and no others. Blend them naturally into the original gongbi-inspired illustration while keeping each anachronistic object recognizable. Do not redraw or reinterpret untouched areas. Output exactly 1024 x 1536.

## 目标图 Negative Prompt

global restyle, changed face, changed pose, changed crowd, changed architecture, changed camera, changed crop, changed lighting, changed colors, added people, removed people, extra differences, duplicate object, misshapen bicycle, three wheels, illegible watch, hidden zipper, oil lamp instead of light bulb, glass bottle instead of plastic bottle, text, watermark, logo

## 五个答案及年代依据

| ID | 不属于北宋的物件 | 简要依据 |
|---|---|---|
| zipper | 金属拉链 | 现代实用拉链形成于 19–20 世纪 |
| wristwatch | 现代腕表 | 腕表在近现代才普及 |
| plastic_bottle | 一次性塑料水瓶 | 合成塑料及此类容器属于现代工业产品 |
| electric_bulb | 白炽电灯泡 | 实用电灯出现于 19 世纪 |
| modern_bicycle | 现代安全自行车 | 链传动双轮安全自行车形成于 19 世纪 |

这些物件刻意选择“年代边界非常清楚”的对象，避免把争议较大的食材、服饰纹样或器物形制作为首关答案。
