#!/bin/bash
set -euo pipefail

BIN="$1"
OUT_DIR="$2"

echo "📦 Extracting dependencies from: $BIN"
mkdir -p "$OUT_DIR/bin"

# 1. Copy the binary itself
cp -a "$BIN" "$OUT_DIR/bin"

# 2. Helper: copy file and fix symlinks to be relative inside $OUT_DIR
copy_with_relative_symlink() {
  local src="$1"
  local abs_dest="$OUT_DIR$src"

  mkdir -p "$(dirname "$abs_dest")"

  if [ -L "$src" ]; then
    # It's a symlink: get resolved absolute path and copy target
    local target_path
    target_path=$(readlink -f "$src")

    local abs_target="$OUT_DIR$target_path"
    mkdir -p "$(dirname "$abs_target")"
    cp -a "$target_path" "$abs_target"

    # Create relative symlink
    local rel_link
    rel_link=$(realpath --relative-to="$(dirname "$abs_dest")" "$abs_target")
    ln -sf "$rel_link" "$abs_dest"

    echo "🔗 $src → $rel_link"
  else
    # Regular file, copy as-is
    cp -a "$src" "$abs_dest"
  fi
}

# 3. Copy all ldd-reported shared libs
echo "🔍 Parsing ldd dependencies..."
ldd "$BIN" | awk '{print $3}' | grep '^/' | sort -u | while read -r lib; do
  if [ -e "$lib" ]; then
    copy_with_relative_symlink "$lib"
  fi
done

# 4. Copy ELF interpreter
echo "🔍 Checking ELF interpreter..."
INTERP=$(readelf -l "$BIN" | grep 'interpreter' | awk -F: '{print $2}' | tr -d ' ]')
if [ -n "$INTERP" ] && [ -e "$INTERP" ]; then
  copy_with_relative_symlink "$INTERP"
fi

echo "✅ All dependencies copied to: $OUT_DIR"
