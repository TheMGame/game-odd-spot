#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi
if [[ $# -ne 2 ]]; then
  echo "usage: $0 <oddspot-game-version.tar.gz> <oddspot-game-version.tar.gz.sha256>" >&2
  exit 2
fi

archive="$(readlink -f "$1")"
checksum="$(readlink -f "$2")"
install_root=/opt/oddspot/www/oddspot-game
releases="$install_root/releases"
install -d -o root -g www-data -m 0755 "$releases"
stage="$(mktemp -d "$install_root/.deploy.XXXXXX")"
cleanup() {
  if [[ -n "${stage:-}" && -d "$stage" ]]; then rm -rf -- "$stage"; fi
}
trap cleanup EXIT

cd "$(dirname "$archive")"
sha256sum --check "$checksum"
tar --extract --gzip --file "$archive" --directory "$stage" --strip-components=1 --no-same-owner
for required in index.html index.js index.wasm index.pck VERSION; do
  test -f "$stage/$required"
done
version="$(tr -d '\r\n' < "$stage/VERSION")"
if [[ ! "$version" =~ ^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$ ]]; then
  echo "invalid Web game version: $version" >&2
  exit 1
fi
release="$releases/$version"
if [[ -e "$release" ]]; then
  echo "Web game release already exists: $release" >&2
  exit 1
fi

chown -R root:www-data "$stage"
find "$stage" -type d -exec chmod 0755 {} +
find "$stage" -type f -exec chmod 0644 {} +
mv "$stage" "$release"
stage=""

old_target="$(readlink "$install_root/current" 2>/dev/null || true)"
ln -sfn "releases/$version" "$install_root/current.next"
mv -Tf "$install_root/current.next" "$install_root/current"

public_host="${ODDSPOT_PUBLIC_HOST:-oddspot.guaguatu.com}"
if ! curl --fail --silent --show-error --insecure --max-time 20 \
  --resolve "$public_host:443:127.0.0.1" "https://$public_host/game/" >/dev/null; then
  if [[ -n "$old_target" ]]; then
    ln -sfn "$old_target" "$install_root/current.rollback"
    mv -Tf "$install_root/current.rollback" "$install_root/current"
  else
    rm -f -- "$install_root/current"
  fi
  echo "Web game health check failed; current was rolled back" >&2
  exit 1
fi
echo "Web game $version deployed to $release"
