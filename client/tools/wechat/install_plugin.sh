#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
client_dir="$(cd -- "$script_dir/../.." && pwd)"
cache_dir="$client_dir/.cache/godot-minigame"
target_dir="$client_dir/addons/godot-minigame"
lock_path="$script_dir/godot-minigame.lock"
repository="https://github.com/godothub/godot-minigame.git"

[[ -f "$lock_path" ]] || { echo "Lock file not found: $lock_path" >&2; exit 1; }
commit="$(sed -n 's/^GODOT_MINIGAME_COMMIT=//p' "$lock_path" | head -n 1)"
[[ "$commit" =~ ^[0-9a-fA-F]{40}$ ]] || {
  echo "godot-minigame.lock must contain a full 40-character commit SHA." >&2
  exit 1
}

mkdir -p "$(dirname "$cache_dir")"
if [[ ! -d "$cache_dir/.git" ]]; then
  git clone --recurse-submodules "$repository" "$cache_dir"
else
  git -C "$cache_dir" remote set-url origin "$repository"
fi
git -C "$cache_dir" fetch --tags origin "$commit"
git -C "$cache_dir" checkout --detach "$commit"
git -C "$cache_dir" submodule update --init --recursive
[[ "$(git -C "$cache_dir" rev-parse HEAD)" == "$commit" ]] || {
  echo "Checked out plugin commit does not match lock." >&2
  exit 1
}

command -v scons >/dev/null 2>&1 || {
  echo "SCons is required. Install it with: python3 -m pip install scons" >&2
  exit 1
}

case "$(uname -s)" in
  Darwin) (cd "$cache_dir" && ./build_osx.sh) ;;
  Linux) (cd "$cache_dir" && ./build_linux.sh) ;;
  *) echo "Unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac

source_dir="$cache_dir/demo/addons/godot-minigame"
[[ -d "$source_dir" ]] || { echo "Built plugin directory not found: $source_dir" >&2; exit 1; }
rm -rf -- "$target_dir"
mkdir -p "$(dirname "$target_dir")"
cp -R "$source_dir" "$target_dir"

[[ -f "$target_dir/plugin.cfg" ]]
[[ -f "$target_dir/plugin.gd" ]]
[[ -f "$target_dir/godot-minigame.gdextension" ]]
find "$target_dir/bin" -type f -print -quit | grep -q .

if [[ "$(uname -s)" == "Darwin" ]]; then
  xattr -dr com.apple.quarantine "$target_dir" || true
fi

echo "GODOT_MINIGAME_PLUGIN_OK commit=$commit"
