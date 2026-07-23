#!/usr/bin/env bash
set -euo pipefail

target="${1:-api}"
case "$target" in api|worker|migrate) ;; *) echo "usage: $0 {api|worker|migrate} [env-file]" >&2; exit 2 ;; esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${2:-$root/server/.env.linux}"
if [[ ! -f "$env_file" ]]; then echo "environment file not found: $env_file" >&2; exit 1; fi

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

if [[ -x "$root/bin/oddspot-$target" ]]; then
  exec "$root/bin/oddspot-$target"
fi
cd "$root/server"
exec go run "./cmd/$target"
