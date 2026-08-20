#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  echo "usage: $0 <oddspot-game-version.tar.gz> (supports both Godot and native webgame packages)" >&2
  exit 2
fi

archive="$(readlink -f "$1")"
install_root=/opt/oddspot/www/oddspot-game
releases="$install_root/releases"
install -d -o root -g www-data -m 0755 "$releases"
stage="$(mktemp -d "$install_root/.deploy.XXXXXX")"
cleanup() {
  if [[ -n "${stage:-}" && -d "$stage" ]]; then rm -rf -- "$stage"; fi
}
trap cleanup EXIT

echo "[1/6] extracting archive: $archive"
tar --extract --gzip --file "$archive" --directory "$stage" --strip-components=1 --no-same-owner

echo "[2/6] validating package contents"
if [[ -f "$stage/index.wasm" && -f "$stage/index.pck" ]]; then
  pkg_flavor="Godot Web"
  for required in index.html index.js index.wasm index.pck VERSION; do
    test -f "$stage/$required" || { echo "required file missing in Godot package: $required" >&2; exit 1; }
  done
elif [[ -f "$stage/app.bundle.js" ]]; then
  pkg_flavor="Native JS"
  for required in index.html styles.css service-worker.js app.bundle.js VERSION; do
    test -f "$stage/$required" || { echo "required file missing in Native package: $required" >&2; exit 1; }
  done
else
  echo "unrecognized web package format: no index.wasm/index.pck and no app.bundle.js" >&2
  echo "stage contents:" >&2
  ls -la "$stage" >&2
  exit 1
fi

version="$(tr -d '\r\n' < "$stage/VERSION")"
if [[ ! "$version" =~ ^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$ ]]; then
  echo "invalid web game version: $version" >&2
  exit 1
fi
release="$releases/$version"
if [[ -e "$release" ]]; then
  echo "web game release already exists: $release" >&2
  exit 1
fi

echo "[3/6] setting permissions ($pkg_flavor package, version $version)"
chown -R root:www-data "$stage"
find "$stage" -type d -exec chmod 0755 {} +
find "$stage" -type f -exec chmod 0644 {} +
mv "$stage" "$release"
stage=""

echo "[4/6] switching current symlink"
old_target="$(readlink "$install_root/current" 2>/dev/null || true)"
ln -sfn "releases/$version" "$install_root/current.next"
mv -Tf "$install_root/current.next" "$install_root/current"

public_host="${ODDSPOT_PUBLIC_HOST:-oddspot.guaguatu.com}"
health_path="${ODDSPOT_HEALTH_PATH:-/game/}"
echo "[5/6] health check: https://$public_host$health_path"
if ! curl --fail --silent --show-error --insecure --max-time 20 \
  --resolve "$public_host:443:127.0.0.1" "https://$public_host$health_path" >/dev/null; then
  if [[ -n "$old_target" ]]; then
    echo "health check FAILED, rolling back to: $old_target"
    ln -sfn "$old_target" "$install_root/current.rollback"
    mv -Tf "$install_root/current.rollback" "$install_root/current"
  else
    echo "health check FAILED, no previous target to roll back to; clearing current symlink"
    rm -f -- "$install_root/current"
  fi
  echo "web game health check failed; current was rolled back" >&2
  exit 1
fi

echo "[6/6] done"
echo "web game $version ($pkg_flavor) deployed to $release"
