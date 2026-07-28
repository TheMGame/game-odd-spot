# Prompt Pack Specification

## Required level design

Each level contains:

- stable `level_id`;
- scene year or internal era;
- distinct scene name;
- difficulty tier and numeric difficulty;
- exact answer count and answer list;
- one complete English image-generation prompt;
- optional level-specific negative prompt when the shared negative prompt is insufficient.

Default counts:

| Tier | Levels | Answers | Target treatment |
|---|---:|---:|---|
| beginner | 1 | 5 | medium/large, no occlusion, visible contrast |
| easy | 2 | 5 | medium, minimal occlusion, light blending |
| normal | 2 | 6 | medium/small, 15–25% occlusion |
| advanced | 2 | 8 | medium/small, about 25% occlusion, dense scene |
| hard | 1 | 8 | small, about 35% occlusion, strong blending |
| expert | 2 | 10 | small, 30–40% occlusion, decoys and knowledge |

These counts are a hard production contract:

- Every level must contain 5–15 answers.
- Never create a one-answer level, even at beginner difficulty.
- Use the table counts unless the user explicitly requests another count in the
  allowed range.
- Write the exact count and the complete numbered answer list in the README,
  `pack.json`, and standalone batch prompt for that level.

## Prompt structure

Write each prompt in this order:

1. Single-image command, scene, place and date.
2. Era-correct architecture, clothing, tools, activities and materials.
3. Composition, lighting, palette and illustration style.
4. Exact answer list with one fixed semantic location per target.
5. Difficulty treatment: size, occlusion, color integration, density and decoys.
6. Explicit ban on extra wrong objects.
7. Canvas, portrait recomposition, safe areas and target separation.
8. Ban on text, marks, answer indicators, collage, comparison layout and UI.

Every prompt must contain an equivalent of:

> Create one single vertical mobile hidden-object game illustration at exactly 1024 x 1536 pixels, 2:3 portrait orientation. Generate exactly one independent image for this level, not a contact sheet, collage or multi-panel composition. Keep every required target inside the playable safe area. No labels, circles, arrows, highlights, split screen, comparison panels, borders, watermark or UI overlays.

## Batch document structure

Each batch file must:

- contain exactly five numbered level sections;
- repeat each level's ID, date, answer list and full prompt;
- begin with a short instruction to generate five separate image files;
- state that each level initially gets one image only;
- forbid collages and candidate grids;
- require filenames matching each `level_id`;
- omit coordinates and Admin JSON.

Do not use references such as “see README for the full prompt.” The batch must be directly pasteable into a new AI task.

## Pack JSON

Use the existing pack schema:

```json
{
  "schema_version": 1,
  "pack_id": "<theme_slug>_pack_v1",
  "mode": "find_anachronism",
  "image_spec": {
    "width": 1024,
    "height": 1536,
    "format": "png",
    "aspect_ratio": "2:3",
    "orientation": "portrait"
  },
  "levels": []
}
```

Each level includes `level_id`, `period`, `scene`, `tier`, `answer_count` and the nine difficulty dimensions used by existing packs.

## Validation checklist

- Parse every JSON file.
- Confirm 10 unique level IDs.
- Confirm README contains 10 level headings and 10 full prompts.
- Confirm batch 1 contains levels 01–05 and five full prompts.
- Confirm batch 2 contains levels 06–10 and five full prompts.
- Confirm `answer_count` matches the written answer list.
- Reject any level whose `answer_count` or enumerated answer list contains fewer
  than 5 or more than 15 items.
- Confirm every standalone image prompt repeats the exact answer count and all
  numbered target objects; a theme description without the full list is invalid.
- Search for stale instructions requesting multiple candidates or AI coordinates.
- Run `git diff --check` on the new pack.
