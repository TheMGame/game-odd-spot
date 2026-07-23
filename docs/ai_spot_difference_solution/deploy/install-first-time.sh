#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then echo "run as root" >&2; exit 1; fi
install -d -o root -g root -m 0755 /opt/oddspot /opt/oddspot/releases
if ! id oddspot >/dev/null 2>&1; then useradd --system --home /var/lib/oddspot --shell /usr/sbin/nologin oddspot; fi
install -d -o oddspot -g oddspot -m 0750 /var/lib/oddspot
install -d -o root -g oddspot -m 0750 /etc/oddspot
install -d -o root -g root -m 0750 /var/backups/oddspot
install -m 0644 ./oddspot-api.service /etc/systemd/system/oddspot-api.service
install -m 0644 ./oddspot-worker.service /etc/systemd/system/oddspot-worker.service
systemctl daemon-reload
echo "Create /etc/oddspot/oddspot.env from oddspot.env.example with owner root:oddspot and mode 0640, then deploy a release."
