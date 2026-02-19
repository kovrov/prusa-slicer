#!/bin/bash
#
# End-to-end local test: confirms the source package is buildable.
#
# Workflow:
#   1. Populate third_party/ if needed (bundled deps not in Ubuntu repos)
#   2. Pack orig tarball from git HEAD + third_party/
#   3. Extract orig to /tmp/, inject debian/ — dpkg-source sees a clean tree
#   4. Build signed source package (ready to upload if binary build passes)
#   5. Build .deb artifacts in /tmp/ — simulates exactly what Launchpad does
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=debian/bundled-deps.sh
source "$SCRIPT_DIR/bundled-deps.sh"

SIGNING_KEY="${DEBEMAIL:-kovrov@gmail.com}"
PPA="ppa:kovrov/prusa-slicer"
NUMJOBS="${DEB_BUILD_OPTIONS_PARALLEL:-$(nproc)}"

VERSION=$(dpkg-parsechangelog -l "$SOURCE_DIR/debian/changelog" -S Version)
UPSTREAM_VERSION=$(echo "$VERSION" | cut -d- -f1)

WORK_DIR="/tmp/prusaslicer-ppa-work"
TARBALL="$WORK_DIR/prusaslicer_${UPSTREAM_VERSION}.orig.tar.xz"
EXTRACT_DIR="$WORK_DIR/prusaslicer-${UPSTREAM_VERSION}"
CHANGES="$WORK_DIR/prusaslicer_${VERSION}_source.changes"

# ---------------------------------------------------------------------------
# Step 1: Populate third_party/ if needed
# ---------------------------------------------------------------------------
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
# Step 3: Extract orig and inject debian/
# ---------------------------------------------------------------------------
echo ""
echo "==> Extracting orig and injecting debian/..."
tar xJf "$TARBALL" -C "$WORK_DIR"
cp -r "$SOURCE_DIR/debian" "$EXTRACT_DIR/"

# ---------------------------------------------------------------------------
# Step 4: Build signed source package
# ---------------------------------------------------------------------------
echo ""
echo "==> Building signed source package (key: ${SIGNING_KEY})..."
cd "$EXTRACT_DIR"
dpkg-buildpackage -S -sa -k"${SIGNING_KEY}"

# ---------------------------------------------------------------------------
# Step 5: Build deb artifacts (simulates Launchpad binary build)
# ---------------------------------------------------------------------------
echo ""
echo "==> Building deb artifacts (this will take a while)..."
dpkg-buildpackage -us -uc -j"${NUMJOBS}" -b

echo ""
echo "=== Done ==="
echo "Artifacts in: ${WORK_DIR}/"
ls "$WORK_DIR/"prusaslicer_*.deb 2>/dev/null || true
echo ""
echo "If the build looks good, upload with:"
echo "  dput ${PPA} ${CHANGES}"
