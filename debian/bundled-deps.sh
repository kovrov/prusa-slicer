# Shared constants for bundled third-party dependencies.
# Sourced by build-ppa-source.sh and build-test-local.sh.

HEATSHRINK_URL="https://github.com/atomicobject/heatshrink/archive/refs/tags/v0.4.1.zip"
HEATSHRINK_SHA256="2e2db2366bdf36cb450f0b3229467cbc6ea81a8c690723e4227b0b46f92584fe"
HEATSHRINK_DIR="heatshrink-0.4.1"

NANOSVG_COMMIT="abcd277ea45e9098bed752cf9c6875b533c0892f"
NANOSVG_URL="https://github.com/fltk/nanosvg/archive/${NANOSVG_COMMIT}.zip"
NANOSVG_SHA256="e859938fbaee4b351bd8a8b3d3c7a75b40c36885ce00b73faa1ce0b98aa0ad34"
NANOSVG_DIR="nanosvg-${NANOSVG_COMMIT}"

LIBBGCODE_COMMIT="5041c093b33e2748e76d6b326f2251310823f3df"
LIBBGCODE_URL="https://github.com/prusa3d/libbgcode/archive/${LIBBGCODE_COMMIT}.zip"
LIBBGCODE_SHA256="c323aa196a82d75f08a5b114c95f2d1a019e84b555a196e55d8ea52e5787284c"
LIBBGCODE_DIR="libbgcode-${LIBBGCODE_COMMIT}"

# Populate third_party/ with all bundled deps (skips already-present dirs).
populate_third_party() {
    local SOURCE_DIR="$1"
    local THIRD_PARTY="$SOURCE_DIR/third_party"
    mkdir -p "$THIRD_PARTY"

    if [[ ! -d "$THIRD_PARTY/heatshrink" ]]; then
        echo "--- Downloading heatshrink ---"
        wget -q -O /tmp/heatshrink.zip "$HEATSHRINK_URL"
        echo "$HEATSHRINK_SHA256  /tmp/heatshrink.zip" | sha256sum -c -
        unzip -q /tmp/heatshrink.zip -d "$THIRD_PARTY/"
        mv "$THIRD_PARTY/$HEATSHRINK_DIR" "$THIRD_PARTY/heatshrink"
        cp "$SOURCE_DIR/deps/+heatshrink/CMakeLists.txt" "$THIRD_PARTY/heatshrink/"
        cp "$SOURCE_DIR/deps/+heatshrink/Config.cmake.in" "$THIRD_PARTY/heatshrink/"
        rm /tmp/heatshrink.zip
    fi

    if [[ ! -d "$THIRD_PARTY/nanosvg" ]]; then
        echo "--- Downloading NanoSVG ---"
        wget -q -O /tmp/nanosvg.zip "$NANOSVG_URL"
        echo "$NANOSVG_SHA256  /tmp/nanosvg.zip" | sha256sum -c -
        unzip -q /tmp/nanosvg.zip -d "$THIRD_PARTY/"
        mv "$THIRD_PARTY/$NANOSVG_DIR" "$THIRD_PARTY/nanosvg"
        rm /tmp/nanosvg.zip
    fi

    if [[ ! -d "$THIRD_PARTY/libbgcode" ]]; then
        echo "--- Downloading LibBGCode ---"
        wget -q -O /tmp/libbgcode.zip "$LIBBGCODE_URL"
        echo "$LIBBGCODE_SHA256  /tmp/libbgcode.zip" | sha256sum -c -
        unzip -q /tmp/libbgcode.zip -d "$THIRD_PARTY/"
        mv "$THIRD_PARTY/$LIBBGCODE_DIR" "$THIRD_PARTY/libbgcode"
        rm /tmp/libbgcode.zip
    fi
}

# Pack the orig tarball from the current git HEAD + third_party/ (bundled deps).
# Using git archive ensures only tracked files are included - no untracked junk,
# no risk of over-excluding legitimate upstream files with broad glob patterns.
# debian/ and deps/ are excluded via :(exclude) pathspecs passed to git archive.
pack_orig_tarball() {
    local SOURCE_DIR="$1"
    local TARBALL="$2"
    local UPSTREAM_VERSION="$3"
    local TMP_TAR

    TMP_TAR="$(mktemp /tmp/prusaslicer-git-archive.XXXXXX.tar)"

    # Archive git-tracked files, excluding debian/ (goes in .debian.tar.xz)
    # and deps/ (upstream superbuild with Windows DLLs, not used in PPA build).
    git -C "$SOURCE_DIR" archive \
        --prefix="prusaslicer-${UPSTREAM_VERSION}/" \
        HEAD \
        ':(exclude)debian' \
        ':(exclude)deps' \
        ':(exclude).vscode' \
        --output="$TMP_TAR"

    # Append third_party/ (not tracked by git, contains bundled deps)
    if [[ -d "$SOURCE_DIR/third_party" ]]; then
        tar --append -f "$TMP_TAR" \
            --transform "s|^|prusaslicer-${UPSTREAM_VERSION}/|" \
            -C "$SOURCE_DIR" third_party
    fi

    xz -T0 < "$TMP_TAR" > "$TARBALL"
    rm -f "$TMP_TAR"
    echo "    $TARBALL"
}
