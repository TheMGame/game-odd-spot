#!/usr/bin/env bash
set -euo pipefail

target_os="${1:-all}"
arch="${2:-amd64}"
version="${3:-dev}"
skip_tests="${SKIP_TESTS:-0}"

case "$target_os" in windows|linux|all) ;; *) echo "usage: $0 {windows|linux|all} {amd64|arm64} [version]" >&2; exit 2 ;; esac
case "$arch" in amd64|arm64) ;; *) echo "unsupported architecture: $arch" >&2; exit 2 ;; esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$root/build/cross"
mkdir -p "$build_root"

if [[ "$skip_tests" != "1" ]]; then
  (cd "$root/server" && go test ./...)
fi

if [[ "$target_os" == "all" ]]; then targets=(windows linux); else targets=("$target_os"); fi

for os in "${targets[@]}"; do
  package_name="oddspot-${version}-${os}-${arch}"
  stage="$build_root/$package_name"
  case "$stage" in "$build_root"/*) ;; *) echo "unsafe build path: $stage" >&2; exit 1 ;; esac
  rm -rf -- "$stage"
  mkdir -p "$stage/bin" "$stage/admin" "$stage/storage/content"

  extension=""
  [[ "$os" == "windows" ]] && extension=".exe"
  for command in api worker migrate; do
    (
      cd "$root/server"
      CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" \
        go build -trimpath -ldflags="-s -w" -o "$stage/bin/oddspot-${command}${extension}" "./cmd/$command"
    )
  done

  cp -R "$root/admin/." "$stage/admin/"
  if [[ "$os" == "windows" ]]; then env_example="windows.env.example"; else env_example="linux.env.example"; fi
  cp "$root/server/configs/$env_example" "$stage/oddspot.env.example"
  printf '%s\n' "$version" > "$stage/VERSION"

  if [[ "$os" == "windows" ]]; then
    archive="$build_root/$package_name.zip"
    rm -f -- "$archive"
    (cd "$build_root" && zip -qr "$archive" "$package_name")
  else
    archive="$build_root/$package_name.tar.gz"
    rm -f -- "$archive"
    tar -C "$build_root" -czf "$archive" "$package_name"
  fi
  printf '%s\n' "$archive"
done
