
#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
rung="${1:-F0}"

swift_cache="${TMPDIR:-/tmp}/handmouse-swiftpm-cache"
swift_config="${TMPDIR:-/tmp}/handmouse-swiftpm-config"
module_cache="${TMPDIR:-/tmp}/handmouse-module-cache"
mkdir -p "$swift_cache" "$swift_config" "$module_cache"
export CLANG_MODULE_CACHE_PATH="$module_cache"
export SWIFT_MODULECACHE_PATH="$module_cache"

case "$rung" in
  F0)
    swift build --disable-sandbox \
      --cache-path "$swift_cache" \
      --config-path "$swift_config" \
      --security-path "$swift_config"
    smoke="$("$root/.build/debug/HandMouse" --smoke)"
    printf '%s\n' "$smoke"
    printf '%s\n' "$smoke" | grep -q 'handmouse-smoke=ok'
    ;;
  F1)
    swift build --disable-sandbox \
      --cache-path "$swift_cache" \
      --config-path "$swift_config" \
      --security-path "$swift_config"
    smoke="$("$root/.build/debug/HandMouse" --smoke)"
    printf '%s\n' "$smoke"
    printf '%s\n' "$smoke" | grep -q 'camera-present='
    plutil -extract NSCameraUsageDescription raw "$root/Resources/Info.plist" |
      grep -q '不会保存或上传'
    ;;
  F2)
    swift test --disable-sandbox --filter GestureClassifierTests \
      --cache-path "$swift_cache" \
      --config-path "$swift_config" \
      --security-path "$swift_config"
    ;;
  F3)
    swift test --disable-sandbox --filter PointerMappingTests \
      --cache-path "$swift_cache" \
      --config-path "$swift_config" \
      --security-path "$swift_config"
    ;;
  F4)
    "$root/scripts/build_app.sh"
    plutil -extract NSCameraUsageDescription raw \
      "$root/outputs/HandMouse.app/Contents/Info.plist" | grep -q '不会保存或上传'
    test -x "$root/outputs/HandMouse.app/Contents/MacOS/HandMouse"
    codesign -d -r- "$root/outputs/HandMouse.app" 2>&1 |
      grep -q 'identifier "local.handmouse.app"'
    ;;
  *)
    printf 'unknown rung: %s\n' "$rung" >&2
    exit 2
    ;;
esac

printf 'rung=%s status=pass\n' "$rung"
