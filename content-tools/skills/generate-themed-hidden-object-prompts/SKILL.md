---
name: generate-themed-hidden-object-prompts
description: Generate reusable, production-ready image prompts for themed hidden-object or “find the anachronism” game packs. Use when the user supplies a new era, culture, setting, profession, lifestyle, or other theme and wants difficulty-graded level concepts, exact answer objects, standalone image-generation prompts, or two five-image generation batches saved under content-tools/prompts.
---

# Generate Themed Hidden-Object Prompts

Create prompt files only. Do not generate images unless the user separately and explicitly asks to run image generation.

## Workflow

1. Read `references/prompt-spec.md` completely.
2. Inspect `content-tools/prompts/PROMPT_STANDARD.md` when it exists.
3. Inspect one relevant existing prompt pack for local naming and JSON conventions. Never add the new theme to an unrelated pack.
4. Derive a short lowercase theme slug and create a new directory:
   `content-tools/prompts/<theme_slug>_pack_v1/`
5. Design 10 distinct levels unless the user specifies another count.
6. Use the default difficulty progression:
   `1 beginner + 2 easy + 2 normal + 2 advanced + 1 hard + 2 expert`.
7. Assign every level at least 5 answer objects. Use the default per-tier counts
   `5 / 5 / 6 / 8 / 8 / 10`; user overrides may use 5–15 answers per level,
   but never produce a one-answer or otherwise undersized level.
8. Verify that every answer is incompatible with the scene's date or internal rules. Avoid disputed boundary cases.
9. Write:
   - `README.md`: series rules, difficulty table, all level specifications and canonical prompts.
   - `pack.json`: machine-readable pack metadata and all level metadata.
   - `BATCH_01_LEVELS_01_05.md`: complete standalone prompts for levels 01–05.
   - `BATCH_02_LEVELS_06_10.md`: complete standalone prompts for levels 06–10.
10. Make each batch document self-contained. Never tell the image model to read another file.
11. Validate JSON, level counts, IDs, answer counts, heading order and one-to-one correspondence across all files. Reject the pack if any level has fewer than 5 or more than 15 answers, or if `answer_count` differs from the enumerated target list.

## Production defaults

- Produce one independent 1024 × 1536 portrait image per level.
- Tell the image model to generate exactly one image per level, never a collage or five-panel sheet.
- Generate one initial image per level. Regenerate or locally repair only a failed level; do not request 3–4 candidates by default.
- Split 10 levels into two prompt documents of five images each so either batch fits comfortably into an image-generation task.
- Delay coordinates and Admin hotspots until final images are approved.
- Do not ask the image-generation model for answer coordinates.
- Preserve the project safe-area rules and output naming `<level_id>.png`.
- State the exact answer count in every level heading/specification and repeat the
  complete numbered target list inside that level's standalone image prompt.

## Judgment rules

- Vary scenes, activities, lighting and visual structure; do not create ten reskins of one room.
- Increase difficulty through size, occlusion, color similarity, density, decoys and knowledge depth—not malformed or microscopic targets.
- Give every answer a fixed semantic location inside its prompt.
- Use era-correct look-alike objects as decoys at higher difficulties.
- Require exactly the listed wrong objects and forbid additional violations.
- Treat answer-count compliance as a hard contract, not a difficulty suggestion:
  minimum 5, maximum 15, with the default tier counts defined above.
- Avoid readable brands, slogans and incidental text unless exact text is essential.
- Prefer objects image models can render and humans can identify at final resolution.
- If the theme is historical or culturally specific and facts are uncertain, verify with authoritative sources before finalizing.

## Scope control

- Modify only the new theme pack unless the user explicitly requests a shared-standard change.
- Do not add the new series to an existing historical or thematic pack.
- Do not create batch manifests or auxiliary files unless requested.
- Do not import into Admin, generate coordinates or publish content during prompt-authoring work.

## Handoff

Report the new pack directory and link the two standalone batch documents. State the number of levels and confirm that each batch contains five complete prompts.
