
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

swift build --disable-sandbox -c release \
  --cache-path "$swift_cache" \
  --config-path "$swift_config" \
  --security-path "$swift_config"

app="$root/outputs/HandMouse.app"
contents="$app/Contents"
mkdir -p "$root/outputs"
rm -rf "$app"
mkdir -p "$contents/MacOS" "$contents/Resources"

cp "$root/.build/release/HandMouse" "$contents/MacOS/HandMouse"
cp "$root/Resources/Info.plist" "$contents/Info.plist"
chmod +x "$contents/MacOS/HandMouse"

plutil -lint "$contents/Info.plist" >/dev/null
codesign --force --deep --sign - \
  --identifier "local.handmouse.app" \
  --requirements '=designated => identifier "local.handmouse.app"' \
  "$app" >/dev/null 2>&1

requirement="$(codesign -d -r- "$app" 2>&1)"
if [[ "$requirement" != *'identifier "local.handmouse.app"'* ]]; then
  printf 'stable code requirement missing: %s\n' "$requirement" >&2
  exit 1
fi

printf 'built=%s\n' "$app"
