#!/bin/bash
#
# Prepares and builds a signed PPA source package for PrusaSlicer.
#
# Usage: bash debian/build-ppa-source.sh [--force-deps]
#
#   --force-deps   Re-download third-party bundled deps (heatshrink, NanoSVG,
#                  LibBGCode) even if third_party/ already exists.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=debian/bundled-deps.sh
source "$SCRIPT_DIR/bundled-deps.sh"

SIGNING_KEY="${DEBEMAIL:-kovrov@gmail.com}"
PPA="ppa:kovrov/prusa-slicer"
FORCE_DEPS=0

for arg in "$@"; do
    case "$arg" in
        --force-deps) FORCE_DEPS=1 ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

VERSION=$(dpkg-parsechangelog -l "$SOURCE_DIR/debian/changelog" -S Version)
UPSTREAM_VERSION=$(echo "$VERSION" | cut -d- -f1)

# Work entirely in /tmp/ - dpkg-source never sees the git working tree.
WORK_DIR="/tmp/prusaslicer-ppa-work"
TARBALL="$WORK_DIR/prusaslicer_${UPSTREAM_VERSION}.orig.tar.xz"
EXTRACT_DIR="$WORK_DIR/prusaslicer-${UPSTREAM_VERSION}"
CHANGES="$WORK_DIR/prusaslicer_${VERSION}_source.changes"

# ---------------------------------------------------------------------------
# Step 1: Ensure bundled deps are present; re-download only if forced
# ---------------------------------------------------------------------------
if [[ "$FORCE_DEPS" -eq 1 ]]; then
    rm -rf "$SOURCE_DIR/third_party"
fi
echo "==> Ensuring bundled deps are present in third_party/..."
populate_third_party "$SOURCE_DIR"

# ---------------------------------------------------------------------------
# Step 2: Pack orig tarball from git HEAD + third_party/
# ---------------------------------------------------------------------------
echo ""
echo "==> Packing orig tarball..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
pack_orig_tarball "$SOURCE_DIR" "$TARBALL" "$UPSTREAM_VERSION"

# ---------------------------------------------------------------------------
# Step 3: Extract orig and inject debian/ — dpkg-source sees a clean tree
# ---------------------------------------------------------------------------
echo ""
echo "==> Extracting orig and injecting debian/..."
tar xJf "$TARBALL" -C "$WORK_DIR"
cp -r "$SOURCE_DIR/debian" "$EXTRACT_DIR/"

# ---------------------------------------------------------------------------
# Step 4: Build signed source package from the extracted (clean) tree
# ---------------------------------------------------------------------------
echo ""
echo "==> Building signed source package (key: ${SIGNING_KEY})..."
cd "$EXTRACT_DIR"
dpkg-buildpackage -S -sa -k"${SIGNING_KEY}"

# ---------------------------------------------------------------------------
echo ""
echo "=== Done ==="
echo "Upload with:"
echo "  dput ${PPA} ${CHANGES}"
