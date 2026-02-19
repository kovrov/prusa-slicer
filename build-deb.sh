#!/bin/bash
#
# Build PrusaSlicer and package it as a .deb file.
# Usage: bash build-deb.sh [--clean] [--skip-deps] [--jobs N]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Defaults ---
CLEAN=0
SKIP_DEPS=0
JOBS="$(nproc)"
BUILD_DIR="$SCRIPT_DIR/build-deb"
DEPS_BUILD_DIR="$SCRIPT_DIR/deps/build-default"
DEPS_PREFIX="$DEPS_BUILD_DIR/destdir/usr/local"
STAGING_DIR="$BUILD_DIR/staging"
DEB_OUT_DIR="$BUILD_DIR"

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)     CLEAN=1; shift ;;
        --skip-deps) SKIP_DEPS=1; shift ;;
        --jobs)      JOBS="$2"; shift 2 ;;
        *)           echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Extract version from version.inc ---
VERSION=$(grep 'set(SLIC3R_VERSION' version.inc | sed 's/.*"\(.*\)".*/\1/')
if [ -z "$VERSION" ]; then
    echo "ERROR: Could not extract version from version.inc"
    exit 1
fi
ARCH="$(dpkg --print-architecture)"
DEB_NAME="prusaslicer_${VERSION}_${ARCH}.deb"

echo "=== Building PrusaSlicer $VERSION .deb package ==="
echo "    Architecture: $ARCH"
echo "    Jobs: $JOBS"
echo ""

# --- Clean if requested ---
if [ "$CLEAN" -eq 1 ]; then
    echo "--- Cleaning build directories ---"
    rm -rf "$BUILD_DIR"
fi

# --- Apply patches for GCC compatibility ---
PATCH_DIR="$SCRIPT_DIR/debian/patches"
if [ -d "$PATCH_DIR" ]; then
    echo "--- Applying patches ---"
    for patch in "$PATCH_DIR"/*.patch; do
        [ -f "$patch" ] || continue
        if git apply --check --reverse "$patch" 2>/dev/null; then
            echo "    Already applied: $(basename "$patch")"
        else
            echo "    Applying: $(basename "$patch")"
            git apply "$patch"
        fi
    done
fi

# --- Step 1: Build dependencies (if needed) ---
if [ "$SKIP_DEPS" -eq 0 ] && [ ! -d "$DEPS_PREFIX" ]; then
    echo "--- Building dependencies (this takes a while on first run) ---"
    cmake --preset default -S "$SCRIPT_DIR/deps"
    cmake --build "$DEPS_BUILD_DIR" -j "$JOBS"
    echo "--- Dependencies built ---"
elif [ ! -d "$DEPS_PREFIX" ]; then
    echo "ERROR: Dependencies not found at $DEPS_PREFIX"
    echo "       Run without --skip-deps first."
    exit 1
else
    echo "--- Dependencies already built, skipping ---"
fi

# --- Step 2: Configure PrusaSlicer ---
echo "--- Configuring PrusaSlicer ---"
cmake -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DSLIC3R_STATIC=1 \
    -DSLIC3R_GTK=3 \
    -DSLIC3R_PCH=1 \
    -DSLIC3R_FHS=1 \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" \
    -DCMAKE_POLICY_DEFAULT_CMP0167=NEW

# --- Step 3: Build ---
echo "--- Building PrusaSlicer ---"
cmake --build "$BUILD_DIR" -j "$JOBS"

# --- Step 4: Stage installation ---
echo "--- Staging installation ---"
rm -rf "$STAGING_DIR"
DESTDIR="$STAGING_DIR" cmake --install "$BUILD_DIR"

# --- Step 5: Prepare DEBIAN metadata ---
echo "--- Preparing package metadata ---"
mkdir -p "$STAGING_DIR/DEBIAN"
sed "s/__VERSION__/$VERSION/" debian/control > "$STAGING_DIR/DEBIAN/control"
sed -i "s/^Architecture: .*/Architecture: $ARCH/" "$STAGING_DIR/DEBIAN/control"
cp debian/postinst "$STAGING_DIR/DEBIAN/postinst"
cp debian/postrm "$STAGING_DIR/DEBIAN/postrm"
chmod 755 "$STAGING_DIR/DEBIAN/postinst" "$STAGING_DIR/DEBIAN/postrm"

# --- Step 6: Build .deb ---
echo "--- Building .deb package ---"
dpkg-deb --build "$STAGING_DIR" "$DEB_OUT_DIR/$DEB_NAME"

echo ""
echo "=== Done ==="
echo "Package: $DEB_OUT_DIR/$DEB_NAME"
echo ""
echo "Install:   sudo dpkg -i $DEB_OUT_DIR/$DEB_NAME"
echo "Uninstall: sudo dpkg -r prusaslicer"
