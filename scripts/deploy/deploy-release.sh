#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <release.tar.gz> <release.sha256>" >&2
  exit 2
fi

archive="$(readlink -f "$1")"
checksum="$(readlink -f "$2")"
install_root=/opt/oddspot
stage="$(mktemp -d "$install_root/.deploy.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT

cd "$(dirname "$archive")"
echo "verifying $archive"
sha256sum --check "$checksum"
echo "extracting files to temporary directory"
tar --extract --gzip --file "$archive" --directory "$stage" --strip-components=1 --no-same-owner
test -f "$stage/bin/oddspot-api"
test -f "$stage/bin/oddspot-worker"
test -f "$stage/bin/oddspot-migrate"

echo "replacing application files in $install_root"
install -d -o root -g root -m 0755 "$install_root/bin" "$install_root/admin"
install -o root -g root -m 0755 "$stage/bin/oddspot-migrate" "$install_root/bin/oddspot-migrate.next"
mv -f "$install_root/bin/oddspot-migrate.next" "$install_root/bin/oddspot-migrate"

echo "applying database migrations"
systemd-run --quiet --wait --collect --pipe \
  --unit="oddspot-migrate-deploy-$$" \
  --uid=oddspot --gid=oddspot \
  --property="EnvironmentFile=/etc/oddspot/oddspot.env" \
  "$install_root/bin/oddspot-migrate"

install -o root -g root -m 0755 "$stage/bin/oddspot-api" "$install_root/bin/oddspot-api.next"
install -o root -g root -m 0755 "$stage/bin/oddspot-worker" "$install_root/bin/oddspot-worker.next"
mv -f "$install_root/bin/oddspot-api.next" "$install_root/bin/oddspot-api"
mv -f "$install_root/bin/oddspot-worker.next" "$install_root/bin/oddspot-worker"
cp -a "$stage/admin/." "$install_root/admin/"
chmod -R a+rX "$install_root/admin"
if [[ -f "$stage/VERSION" ]]; then
  install -o root -g root -m 0644 "$stage/VERSION" "$install_root/VERSION"
fi

echo "restarting Misplaced Detective services"
systemctl restart oddspot-api.service oddspot-worker.service

for _ in {1..20}; do
  if curl --fail --silent http://127.0.0.1:8080/health/ready >/dev/null; then
    echo "release deployed successfully to $install_root"
    exit 0
  fi
  sleep 1
done

echo "release failed readiness check; inspect systemd status and service logs" >&2
exit 1
