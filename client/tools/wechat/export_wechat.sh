#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
client_dir="$(cd -- "$script_dir/../.." && pwd)"
repo_root="$(cd -- "$client_dir/.." && pwd)"
output_dir="$repo_root/build/wechat"

if [[ -n "${GODOT_BIN:-}" ]]; then
  [[ -x "$GODOT_BIN" ]] || { echo "GODOT_BIN is not executable: $GODOT_BIN" >&2; exit 1; }
  godot_bin="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  godot_bin="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin="$(command -v godot4)"
else
  echo "Godot 4.7 not found. Set GODOT_BIN or add godot/godot4 to PATH." >&2
  exit 1
fi

version="$("$godot_bin" --version)"
[[ "$version" =~ ^4\.7(\.|$) ]] || { echo "Godot 4.7 is required; found: $version" >&2; exit 1; }
[[ -f "$client_dir/addons/godot-minigame/plugin.cfg" ]] || {
  echo "godot-minigame is not installed. Run install_plugin.sh first." >&2
  exit 1
}
[[ -f "$script_dir/godot-minigame.lock" ]]

mkdir -p "$output_dir"
"$godot_bin" --headless --editor --path "$client_dir" --quit
if ! "$godot_bin" --headless --path "$client_dir" --export-release "小游戏" "$output_dir/oddspot-pck.bin"; then
  echo "The first export attempt failed; retrying once after the editor process settles." >&2
  sleep 2
  "$godot_bin" --headless --path "$client_dir" --export-release "小游戏" "$output_dir/oddspot-pck.bin"
fi
python3 "$script_dir/finalize_export.py" "$output_dir"
python3 "$script_dir/verify_export.py" "$output_dir"
