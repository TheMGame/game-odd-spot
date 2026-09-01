#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  echo "usage: $0 <oddspot-site-version.tar.gz>" >&2
  exit 2
fi

archive="$(readlink -f "$1")"
install_root=/opt/oddspot/www/oddspot-site
releases="$install_root/releases"
install -d -o root -g www-data -m 0755 "$releases"
stage="$(mktemp -d "$install_root/.deploy.XXXXXX")"
cleanup() {
  if [[ -n "${stage:-}" && -d "$stage" ]]; then rm -rf -- "$stage"; fi
}
trap cleanup EXIT

tar --extract --gzip --file "$archive" --directory "$stage" --strip-components=1 --no-same-owner
test -f "$stage/index.html"
test -f "$stage/VERSION"
version="$(tr -d '\r\n' < "$stage/VERSION")"
if [[ ! "$version" =~ ^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$ ]]; then
  echo "invalid website version: $version" >&2
  exit 1
fi
release="$releases/$version"
if [[ -e "$release" ]]; then
  echo "website release already exists: $release" >&2
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
if ! curl --fail --silent --show-error --insecure --max-time 15 \
  --resolve "$public_host:443:127.0.0.1" "https://$public_host/" >/dev/null; then
  if [[ -n "$old_target" ]]; then
    ln -sfn "$old_target" "$install_root/current.rollback"
    mv -Tf "$install_root/current.rollback" "$install_root/current"
  else
    rm -f -- "$install_root/current"
  fi
  echo "website health check failed; current was rolled back" >&2
  exit 1
fi
current_version="$(basename -- "$(readlink -f "$install_root/current")")"
previous_version=""
if [[ -n "$old_target" ]]; then previous_version="$(basename -- "$old_target")"; fi
releases_real="$(readlink -f "$releases")"
for candidate in "$releases"/*; do
  [[ -d "$candidate" ]] || continue
  candidate_version="$(basename -- "$candidate")"
  [[ "$candidate_version" == "$current_version" || "$candidate_version" == "$previous_version" ]] && continue
  [[ "$candidate_version" =~ ^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$ ]] || { echo "skip unsafe release name: $candidate_version" >&2; continue; }
  candidate_real="$(readlink -f "$candidate")"
  case "$candidate_real" in "$releases_real"/*) rm -rf -- "$candidate_real" ;; *) echo "skip release outside root: $candidate_real" >&2 ;; esac
done
echo "website $version deployed to $release"
