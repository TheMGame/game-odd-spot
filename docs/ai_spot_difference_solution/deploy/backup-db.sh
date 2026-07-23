#!/usr/bin/env bash
set -euo pipefail

: "${ODDSPOT_DB_HOST:?required}"
: "${ODDSPOT_DB_PORT:?required}"
: "${ODDSPOT_DB_USER:?required}"
: "${ODDSPOT_DB_NAME:?required}"
: "${MYSQL_PWD:?required; provide through root-only environment file}"

backup_dir=/var/backups/oddspot
test "$(readlink -f "$backup_dir")" = "/var/backups/oddspot"
install -d -m 0750 "$backup_dir"
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
target="$backup_dir/${ODDSPOT_DB_NAME}_${timestamp}.sql.gz"

mysqldump --single-transaction --quick --routines --triggers \
  --host="$ODDSPOT_DB_HOST" --port="$ODDSPOT_DB_PORT" --user="$ODDSPOT_DB_USER" \
  --set-gtid-purged=OFF "$ODDSPOT_DB_NAME" | gzip -9 > "$target"
gzip --test "$target"
sha256sum "$target" > "$target.sha256"
echo "$target"
