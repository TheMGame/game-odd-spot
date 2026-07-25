---
name: publish-oddspot-admin-content
description: Publish Odd Spot content packs to local or production Admin, including selected level images, generated thumbnails, series metadata, runtime level JSON and answer hotspots. Use when importing a new series, updating level images or answers, fixing missing /content assets, synchronizing local work to oddspot.guaguatu.com, or verifying production Admin image URLs.
---

# Publish Odd Spot Admin Content

Publish assets and metadata through the Admin API. Never treat a successful local upload as a production upload.

## Required reading

Read `references/publishing-contract.md` completely before changing or publishing content.

## Workflow

1. Identify the target explicitly:
   - local: `http://127.0.0.1:8080`;
   - production: value from the ignored credential file, normally `https://oddspot.guaguatu.com`.
2. Resolve the exact candidate image selected for every level.
3. Inspect each final image and configure real `differences` hotspots. Do not use intended Prompt coordinates.
4. Create or update a pack-specific importer that accepts:
   `-ApiBase`, `-AdminToken`, and `-ExportDir`.
5. Keep credentials only in `server/production.local.env` or another `*.local.env` file ignored by Git.
6. Run `scripts/publish-importer.ps1` with the pack importer and series ID.
7. The pack importer must:
   - upsert the series;
   - upload each original image through `/admin/v1/assets/{assetId}`;
   - use the returned asset object, including generated thumbnail;
   - upsert every level with complete runtime JSON and hotspots.
8. The publisher wrapper must re-read the production catalog and every level, then require HTTP 200 for both original and thumbnail URLs.
9. Open or refresh the production Admin only after automated URL verification succeeds.

## Safety rules

- Never embed or commit an Admin token.
- Never print a token, DSN or HMAC key.
- Verify the credential file is ignored with `git check-ignore`.
- Do not read browser cookies, local storage or session storage to extract a token.
- Do not publish drafts or partially configured hotspots as completed work.
- Do not overwrite an unrelated series.
- Treat production publishing as an external write: only do it when the user asks to publish, upload, sync or fix production.

## Asset rules

- Upload through the target environment's Admin API. Uploading to a local API writes only to local content storage even if its database is remote.
- Use stable asset IDs such as `<level_id>_image_v<version>`.
- Let the server generate thumbnails; never invent a thumbnail URL.
- Persist the exact asset object returned by the upload API in `runtime_json.assets.image`.
- Validate every final `/content/...` original and `-thumb.jpg` URL.

## Hotspot rules

- Use normalized `x`, `y`, and `radius`.
- Position hotspots from the final selected image, not from prompt descriptions.
- Include `id`, `label`, `era`, `explanation`, `difficulty`, and `operation`.
- Generate an overlay review before publishing when hotspots were newly created or substantially changed.
- Reject duplicate, missing or ambiguous targets rather than inventing coordinates.

## Existing pack

The current 60–70s series importer is:
`scripts/import-60s-70s-content.ps1`.

Publish it with:

```powershell
content-tools/skills/publish-oddspot-admin-content/scripts/publish-importer.ps1 `
  -ImporterPath scripts/import-60s-70s-content.ps1 `
  -SeriesId china_60s_70s_life_pack_v1 `
  -ExportDir C:\Users\Admin\Downloads\export
```

Do not include `-AdminToken`; the wrapper reads the ignored local credential file.

## Handoff

Report:

- target environment;
- series ID and level count;
- selected candidate per level;
- total hotspot count;
- original and thumbnail verification totals;
- path to the pack importer and local credential file, without revealing secrets.
