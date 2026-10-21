#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

swift_cache="${TMPDIR:-/tmp}/handmouse-swiftpm-cache"
swift_config="${TMPDIR:-/tmp}/handmouse-swiftpm-config"
module_cache="${TMPDIR:-/tmp}/handmouse-module-cache"
mkdir -p "$swift_cache" "$swift_config" "$module_cache"
export CLANG_MODULE_CACHE_PATH="$module_cache"
export SWIFT_MODULECACHE_PATH="$module_cache"

swift test --disable-sandbox \
  --cache-path "$swift_cache" \
  --config-path "$swift_config" \
  --security-path "$swift_config"
for rung in F0 F1 F2 F3 F4; do
  "$root/scripts/check_rung.sh" "$rung"
done

printf 'all-checks=pass\n'
