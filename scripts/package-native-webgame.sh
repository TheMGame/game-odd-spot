#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source="$root/webgame"
build_root="$root/build"
output="$build_root/webgame"
package_root="$build_root/packages"
bundle_root="$build_root/.webgame-bundle"

mkdir -p -- "$build_root"

if [[ -z "$VERSION" ]]; then
  VERSION="$(node -e "console.log(require('$source/package.json').version)")"
fi
if [[ ! "$VERSION" =~ ^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$ ]]; then
  echo "Invalid package version: $VERSION" >&2
  exit 1
fi

if [[ -s "$bundle_root/app.bundle.js" && -s "$bundle_root/app.bundle.js.map" ]]; then
  echo "Using existing bundle at $bundle_root; skipping npm build."
else
  (
    cd "$source"
    if [[ ! -x "$source/node_modules/.bin/esbuild" ]]; then
      npm ci
    fi
    npm run check
  )
fi

resolved_build_root="$(cd -- "$build_root" && pwd)"
resolved_output="$resolved_build_root/$(basename -- "$output")"
if [[ "$(dirname -- "$resolved_output")" != "$resolved_build_root" ]] || [[ "$(basename -- "$resolved_output")" != "webgame" ]]; then
  echo "Unsafe native Web output path: $resolved_output" >&2
  exit 1
fi
rm -rf -- "$resolved_output"
mkdir -p -- "$resolved_output"

for file in index.html styles.css service-worker.js; do
  path="$source/$file"
  if [[ ! -f "$path" ]]; then
    echo "Native Web runtime file is missing: $file" >&2
    exit 1
  fi
  cp -- "$path" "$resolved_output/$file"
done

for file in app.bundle.js app.bundle.js.map; do
  path="$bundle_root/$file"
  if [[ ! -s "$path" ]]; then
    echo "Native Web bundle is missing or empty: $file (run 'npm run build' in webgame/)" >&2
    exit 1
  fi
  cp -- "$path" "$resolved_output/$file"
done
cp -R -- "$source/assets" "$resolved_output/assets"

html_path="$resolved_output/index.html"
html="$(cat -- "$html_path")"
html="$(printf '%s' "$html" | sed -E "s/(styles\.css\?v=)[^\"']+/\1$VERSION/g")"
html="$(printf '%s' "$html" | sed -E "s/(app\.bundle\.js\?v=)[^\"']+/\1$VERSION/g")"
printf '%s' "$html" > "$html_path"

worker_path="$resolved_output/service-worker.js"
worker="$(cat -- "$worker_path")"
worker="$(printf '%s' "$worker" | sed -E "s/const CACHE = 'oddspot-webgame-[^']+'/const CACHE = 'oddspot-webgame-$VERSION'/g")"
printf '%s' "$worker" > "$worker_path"
printf '%s\n' "$VERSION" > "$resolved_output/VERSION"

mkdir -p -- "$package_root"
archive_name="oddspot-native-webgame-$VERSION.tar.gz"
archive="$package_root/$archive_name"
rm -f -- "$archive"
tar -C "$build_root" -czf "$archive" "webgame"

echo "Native Web output: $resolved_output"
echo "Package: $archive"
