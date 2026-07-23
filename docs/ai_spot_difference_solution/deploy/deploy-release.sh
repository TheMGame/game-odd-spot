#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <release.tar.gz> <release.sha256>" >&2
  exit 2
fi

archive="$(readlink -f "$1")"
checksum="$(readlink -f "$2")"
release_root=/opt/oddspot/releases
current_link=/opt/oddspot/current
version="$(basename "$archive" .tar.gz)"
target="$release_root/$version"

cd "$(dirname "$archive")"
sha256sum --check "$checksum"
test ! -e "$target"
install -d -o oddspot -g oddspot "$target"
tar --extract --gzip --file "$archive" --directory "$target" --strip-components=1 --no-same-owner
test -x "$target/bin/oddspot-api"
test -x "$target/bin/oddspot-migrate"

set -a
# shellcheck disable=SC1091
source /etc/oddspot/oddspot.env
set +a
sudo --preserve-env=ODDSPOT_ENV,ODDSPOT_DATABASE_DSN,ODDSPOT_INSTALLATION_HMAC_KEY,ODDSPOT_ADMIN_TOKEN,ODDSPOT_DEFAULT_MARKET,ODDSPOT_DEFAULT_LOCALE,ODDSPOT_LOG_LEVEL \
  -u oddspot "$target/bin/oddspot-migrate"
ln -sfn "$target" "${current_link}.next"
mv -Tf "${current_link}.next" "$current_link"
systemctl restart oddspot-api.service oddspot-worker.service

for _ in {1..20}; do
  if curl --fail --silent http://127.0.0.1:8080/health/ready >/dev/null; then
    exit 0
  fi
  sleep 1
done

echo "release failed readiness check; switch current to the previous release and restart services" >&2
exit 1
