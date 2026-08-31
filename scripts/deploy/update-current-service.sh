#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" == "--remote-admin" ]]; then
  [[ ${EUID} -eq 0 ]] || { echo "run as root" >&2; exit 1; }
  [[ $# -eq 2 ]] || { echo "usage: $0 --remote-admin <archive>" >&2; exit 2; }
  archive="$(readlink -f "$2")"
  install_root=/opt/oddspot
  admin_root="$install_root/admin"
  stage="$(mktemp -d "$install_root/.admin-deploy.XXXXXX")"
  trap 'rm -rf -- "$stage"' EXIT
  tar --extract --gzip --file "$archive" --directory "$stage" --strip-components=1 --no-same-owner
  for required in index.html app.js styles.css VERSION; do
    [[ -f "$stage/$required" ]] || { echo "admin package missing: $required" >&2; exit 1; }
  done
  install -d -o root -g root -m 0755 "$admin_root"
  cp -a "$stage/." "$admin_root/"
  chmod -R a+rX "$admin_root"
  curl --fail --silent --show-error --max-time 15 http://127.0.0.1:8080/admin/ >/dev/null
  echo "Admin $(tr -d '\r\n' < "$stage/VERSION") deployed to $admin_root"
  exit 0
fi

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
script_path="$root/scripts/deploy/update-current-service.sh"

host="101.126.149.220"
port="2213"
user="root"
version="$(date +%Y%m%d-%H%M%S)"
skip_tests=0
dry_run=0
declare -a requested=()

usage() {
  cat <<'EOF'
Usage:
  bash scripts/deploy/update-current-service.sh [options] [components...]

Components:
  backend   Build Go API/Worker/Migrate, migrate DB, update Admin, restart services
  admin     Package and update Admin static files only
  webgame   Install dependencies, test, package and publish WebGame
  website   Package and publish the official website

Options:
  --all                    Deploy backend, admin, webgame and website
  -c, --components LIST    Comma-separated component list
  -v, --version VERSION    Release version (default: current timestamp)
  -H, --host HOST          SSH host (default: 101.126.149.220)
  -p, --port PORT          SSH port (default: 2213)
  -u, --user USER          SSH user (default: root)
  --skip-tests             Skip Go tests; WebGame checks still run
  --dry-run                Print the complete flow without changing anything
  -h, --help               Show this help

Authentication:
  Native ssh/scp is used by default (SSH key or interactive password prompt).
  If both sshpass and ODDSPOT_DEPLOY_PASSWORD are available, sshpass -e is used;
  the password is never printed or stored.

Examples:
  bash scripts/deploy/update-current-service.sh backend webgame
  bash scripts/deploy/update-current-service.sh --all --version 2.3.0
  ODDSPOT_DEPLOY_PASSWORD='...' bash scripts/deploy/update-current-service.sh admin
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

while (($#)); do
  case "$1" in
    --all) requested+=(backend admin webgame website); shift ;;
    -c|--components)
      (($# >= 2)) || die "$1 requires a value"
      IFS=',' read -r -a parsed <<<"$2"
      requested+=("${parsed[@]}")
      shift 2
      ;;
    -v|--version) (($# >= 2)) || die "$1 requires a value"; version="$2"; shift 2 ;;
    -H|--host) (($# >= 2)) || die "$1 requires a value"; host="$2"; shift 2 ;;
    -p|--port) (($# >= 2)) || die "$1 requires a value"; port="$2"; shift 2 ;;
    -u|--user) (($# >= 2)) || die "$1 requires a value"; user="$2"; shift 2 ;;
    --skip-tests) skip_tests=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; requested+=("$@"); break ;;
    -*) die "unknown option: $1" ;;
    *) requested+=("$1"); shift ;;
  esac
done

[[ "$version" =~ ^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$ ]] || die "invalid version: $version"
[[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)) || die "invalid SSH port: $port"
[[ "$host" =~ ^[0-9A-Za-z._:-]+$ ]] || die "invalid SSH host: $host"
[[ "$user" =~ ^[0-9A-Za-z._-]+$ ]] || die "invalid SSH user: $user"

((${#requested[@]})) || requested=(backend)
declare -A selected=()
for component in "${requested[@]}"; do
  case "$component" in
    backend|admin|webgame|website) selected["$component"]=1 ;;
    *) die "unknown component: $component" ;;
  esac
done

declare -a components=()
for component in backend admin webgame website; do
  [[ -n "${selected[$component]:-}" ]] && components+=("$component")
done

remote="${user}@${host}"
remote_root="/tmp/oddspot-deploy-$version"
remote_prepared=0
use_sshpass=0
if [[ -n "${ODDSPOT_DEPLOY_PASSWORD:-}" ]]; then
  if command -v sshpass >/dev/null 2>&1; then
    use_sshpass=1
    export SSHPASS="$ODDSPOT_DEPLOY_PASSWORD"
  else
    echo "NOTICE: sshpass is unavailable; falling back to native SSH authentication." >&2
    echo "NOTICE: SSH may prompt for the password interactively; ODDSPOT_DEPLOY_PASSWORD is ignored." >&2
  fi
fi

declare -a ssh_base=(-p "$port" -o StrictHostKeyChecking=accept-new)
declare -a scp_base=(-P "$port" -o StrictHostKeyChecking=accept-new)

print_command() {
  printf '[dry-run]'
  printf ' %q' "$@"
  printf '\n'
}

run() {
  if ((dry_run)); then print_command "$@"; else "$@"; fi
}

remote_run() {
  local command="$1"
  if ((use_sshpass)); then
    run sshpass -e ssh "${ssh_base[@]}" "$remote" "$command"
  else
    run ssh "${ssh_base[@]}" "$remote" "$command"
  fi
}

upload() {
  local path="$1"
  ((dry_run)) || [[ -f "$path" ]] || die "upload file missing: $path"
  if ((use_sshpass)); then
    run sshpass -e scp "${scp_base[@]}" "$path" "$remote:$remote_root/"
  else
    run scp "${scp_base[@]}" "$path" "$remote:$remote_root/"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command is unavailable: $1"
}

cleanup() {
  if ((remote_prepared == 1 && dry_run == 0)); then
    remote_run "rm -rf -- '$remote_root'" >/dev/null 2>&1 || true
  fi
  unset SSHPASS
}
trap cleanup EXIT

if ((dry_run == 0)); then
  require_command ssh
  require_command scp
  require_command tar
fi

echo "Target: $remote port $port"
echo "Version: $version"
echo "Components: ${components[*]}"
remote_run "install -d -m 0700 '$remote_root'"
remote_prepared=1

if [[ -n "${selected[backend]:-}" ]]; then
  build=(bash "$root/scripts/build-cross-linux.sh" linux amd64 "$version")
  if ((skip_tests)); then
    if ((dry_run)); then print_command env SKIP_TESTS=1 "${build[@]}"; else SKIP_TESTS=1 "${build[@]}"; fi
  else
    run "${build[@]}"
  fi
  archive="$root/build/cross/oddspot-$version-linux-amd64.tar.gz"
  upload "$archive"
  upload "$root/scripts/deploy/deploy-release.sh"
  remote_run "bash '$remote_root/deploy-release.sh' '$remote_root/$(basename -- "$archive")'"
fi

# A backend release already contains and updates Admin, so do not deploy it twice.
if [[ -n "${selected[admin]:-}" && -z "${selected[backend]:-}" ]]; then
  package_root="$root/build/packages"
  stage_name="oddspot-admin-$version"
  stage="$package_root/$stage_name"
  archive="$package_root/$stage_name.tar.gz"
  if ((dry_run)); then
    print_command bash -c "package Admin as $archive"
  else
    mkdir -p -- "$package_root"
    rm -rf -- "$stage"
    mkdir -p -- "$stage"
    cp -a -- "$root/admin/." "$stage/"
    printf '%s\n' "$version" >"$stage/VERSION"
    rm -f -- "$archive"
    tar -C "$package_root" -czf "$archive" "$stage_name"
  fi
  upload "$archive"
  upload "$script_path"
  remote_run "bash '$remote_root/$(basename -- "$script_path")' --remote-admin '$remote_root/$(basename -- "$archive")'"
fi

if [[ -n "${selected[webgame]:-}" ]]; then
  if ((dry_run)); then
    print_command bash -c "cd '$root/webgame' && npm ci && npm run check && npm run package -- '$version'"
  else
    (cd "$root/webgame" && npm ci && npm run check && npm run package -- "$version")
  fi
  archive="$root/build/packages/oddspot-native-webgame-$version.tar.gz"
  upload "$archive"
  upload "$root/scripts/deploy/deploy-web-game.sh"
  remote_run "bash '$remote_root/deploy-web-game.sh' '$remote_root/$(basename -- "$archive")'"
fi

if [[ -n "${selected[website]:-}" ]]; then
  package_root="$root/build/packages"
  stage_name="oddspot-site-$version"
  stage="$package_root/$stage_name"
  archive="$package_root/$stage_name.tar.gz"
  if ((dry_run)); then
    print_command bash -c "package website as $archive"
  else
    [[ -f "$root/website/index.html" ]] || die "website/index.html is missing"
    [[ -d "$root/website/assets" ]] || die "website/assets is missing"
    mkdir -p -- "$package_root"
    rm -rf -- "$stage"
    mkdir -p -- "$stage"
    cp -a -- "$root/website/." "$stage/"
    printf '%s\n' "$version" >"$stage/VERSION"
    rm -f -- "$archive"
    tar -C "$package_root" -czf "$archive" "$stage_name"
  fi
  upload "$archive"
  upload "$root/scripts/deploy/deploy-website.sh"
  remote_run "bash '$remote_root/deploy-website.sh' '$remote_root/$(basename -- "$archive")'"
fi

remote_run "rm -rf -- '$remote_root'"
remote_prepared=0
echo "Selected components deployed successfully."
