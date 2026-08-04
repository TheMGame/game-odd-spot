# Misplaced Detective Publishing Contract

## Local credential file

Default path:

`server/production.local.env`

Required variables:

```dotenv
ODDSPOT_PRODUCTION_API_BASE=https://oddspot.guaguatu.com
ODDSPOT_ADMIN_TOKEN=<local secret>
```

The repository ignores `*.local.env`. Always confirm with:

```powershell
git check-ignore -v -- server/production.local.env
```

## Admin endpoints

- `POST /admin/v1/series`
- `POST /admin/v1/assets/{assetId}`
- `POST /admin/v1/levels/{levelId}`
- `GET /admin/v1/catalog`
- `GET /admin/v1/levels/{levelId}`

Send `X-Admin-Token` on all Admin requests.

Image upload accepts PNG or JPEG. The response asset object contains:

- original `asset_id`, `url`, `sha256`, `bytes`, `content_type`;
- nested `thumbnail` object with its own URL and metadata.

Store the complete returned object as `runtime_json.assets.image`.

## Critical environment distinction

The content file is written by the API process receiving the upload:

- upload to `127.0.0.1` → local content directory;
- upload to production host → production content directory.

A local API may connect to the production database. That does not copy local files to production. Always upload assets through the final target API.

## Importer interface

Pack-specific importers must accept:

```powershell
param(
  [string]$ApiBase,
  [string]$AdminToken,
  [string]$ExportDir
)
```

They must upload the final image before upserting each level and replace any previous `assets.image` value with the response from the target API.

## Verification

After publishing:

1. Read the target Admin catalog and locate the exact series ID.
2. Confirm the expected level count.
3. Read every level through the target Admin API.
4. Confirm the expected hotspot count.
5. Request the original URL and nested thumbnail URL.
6. Require HTTP 200 for both.
7. Report completion only when all checks pass.

Do not validate production by requesting local URLs.
