#!/usr/bin/env bash
# Builds libmaplibre-native-c.so from the pinned maplibre-native-ffi tree and
# installs it (stripped) into this package's jniLibs, generating the ffigen
# Dart bindings along the way.
#
# Idempotent, and cheap when nothing changed: the clone is treated as a build
# artifact, but it is only reset to the pin and re-patched when the pin, the
# patch stack, or the clone itself has moved since the last successful run. A
# re-run with everything unchanged is a no-op build instead of a full rebuild.
# Set MLN_KEEP_CLONE=1 to work on the clone by hand.
#
# Usage: tool/build_native.sh [--backend vulkan|egl] [--ffi-dir <path>]
set -euo pipefail

PIN=9d1508dc36d6a2808004c751731313d230da7e7f
NDK_PINNED_VERSION=28.1.13356709
REPO_URL=https://github.com/maplibre/maplibre-native-ffi.git

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Default matches the pubspec path dependency: ../../maplibre-native-ffi
FFI_DIR="$(dirname "$(dirname "$PKG_DIR")")/maplibre-native-ffi"
# Render backend: the two the pinned tree exposes on Android. Both are built
# for arm64-v8a only here; upstream also has android-x64-{egl,vulkan} presets,
# which this script does not reach (see PRESET below and the jniLibs install).
BACKEND=vulkan

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --backend) BACKEND="${2:?}"; shift 2 ;;
    --ffi-dir) FFI_DIR="${2:?}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done
case "$BACKEND" in vulkan|egl) ;; *) die "--backend must be vulkan or egl" ;; esac
# Upstream CMake preset, passed to the mise build task and also the name of its
# build directory. It used to be selected through MISE_ENV; since the pin's
# tasks take it as an argument that defaults to the host preset, an unset one
# would quietly build for macOS instead of Android.
PRESET="android-arm64-$BACKEND"

case "$(uname -s)" in
  Darwin) HOST_TAG=darwin-x86_64; SDK_DEFAULT="$HOME/Library/Android/sdk"
          MISE_HINT="brew install mise" ;;
  Linux)  HOST_TAG=linux-x86_64; SDK_DEFAULT="$HOME/Android/Sdk"
          MISE_HINT="curl https://mise.run | sh" ;;
  *) die "unsupported host OS $(uname -s); on Windows run this under WSL" ;;
esac

command -v git >/dev/null || die "git not found"
command -v dart >/dev/null || die "dart not found (install a Flutter SDK and put it on PATH)"
command -v mise >/dev/null || die "mise not found; install it with: $MISE_HINT"

if command -v shasum >/dev/null; then
  sha256() { shasum -a 256 | cut -d' ' -f1; }
elif command -v sha256sum >/dev/null; then
  sha256() { sha256sum | cut -d' ' -f1; }
else
  die "neither shasum nor sha256sum found"
fi

# Fingerprint of the state a successful run leaves behind, written to the stamp
# at the end and compared at the start. The tree hash covers every tracked
# change, so it catches both our patches and a hand-edited clone; when it
# matches, resetting and re-patching would only touch mtimes and force ninja to
# rebuild ~590 objects for nothing.
PATCHES_DIR="$PKG_DIR/upstream_patches"
STAMP="$FFI_DIR/.maplibre-gl-native-build.stamp"
patches_hash() { cat "$PATCHES_DIR"/0*.patch | sha256; }
tree_hash() { git -C "$FFI_DIR" diff | sha256; }
write_stamp() { printf '%s\n%s\n%s\n' "$PIN" "$(patches_hash)" "$(tree_hash)" >"$STAMP"; }
stamp_matches() {
  [ -f "$STAMP" ] || return 1
  local pin patches tree
  { read -r pin && read -r patches && read -r tree; } <"$STAMP" || return 1
  [ "$pin" = "$PIN" ] && [ "$patches" = "$(patches_hash)" ] \
    && [ "$tree" = "$(tree_hash)" ]
}

export ANDROID_HOME="${ANDROID_HOME:-$SDK_DEFAULT}"
[ -d "$ANDROID_HOME" ] || die "Android SDK not found at $ANDROID_HOME (set ANDROID_HOME)"
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
  if [ -d "$ANDROID_HOME/ndk/$NDK_PINNED_VERSION" ]; then
    ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_PINNED_VERSION"
  else
    ANDROID_NDK_HOME="$(ls -d "$ANDROID_HOME"/ndk/* 2>/dev/null | sort -V | tail -1 || true)"
  fi
fi
export ANDROID_NDK_HOME
[ -n "$ANDROID_NDK_HOME" ] && [ -d "$ANDROID_NDK_HOME" ] \
  || die "no NDK found under $ANDROID_HOME/ndk (install one via Android Studio, e.g. $NDK_PINNED_VERSION)"
LLVM_STRIP="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/bin/llvm-strip"
[ -x "$LLVM_STRIP" ] || die "llvm-strip not found at $LLVM_STRIP"

echo "==> backend: $BACKEND (preset $PRESET)"
echo "==> upstream clone: $FFI_DIR"
echo "==> NDK: $ANDROID_NDK_HOME"

KEEP_CLONE="${MLN_KEEP_CLONE:-0}"
NEEDS_PATCHES=1

if [ ! -d "$FFI_DIR/.git" ]; then
  echo "==> cloning maplibre-native-ffi (pinned at ${PIN:0:7})"
  git clone --recurse-submodules "$REPO_URL" "$FFI_DIR"
  git -C "$FFI_DIR" checkout --detach "$PIN"
  git -C "$FFI_DIR" submodule update --init --recursive
elif [ "$KEEP_CLONE" = "1" ]; then
  HEAD="$(git -C "$FFI_DIR" rev-parse HEAD)"
  echo "==> MLN_KEEP_CLONE=1: leaving the clone at ${HEAD:0:7} untouched"
  [ "$HEAD" = "$PIN" ] \
    || echo "warning: that is not the pin ${PIN:0:7}; the patches below may not apply" >&2
  # A hand-edited clone must not be mistaken for our own output next time.
  rm -f "$STAMP"
elif stamp_matches; then
  echo "==> clone is already at ${PIN:0:7} with this patch stack; leaving it alone"
  NEEDS_PATCHES=0
else
  HEAD="$(git -C "$FFI_DIR" rev-parse HEAD)"
  if [ "$HEAD" != "$PIN" ]; then
    echo "==> re-pinning the clone: ${HEAD:0:7} -> ${PIN:0:7}"
    git -C "$FFI_DIR" fetch origin
    git -C "$FFI_DIR" checkout -f --detach "$PIN"
    git -C "$FFI_DIR" submodule update --init --recursive
  fi
  # The clone is a build artifact: start from the pinned tree so the patch
  # stack applies the same way every run. Patches build on each other (0007
  # lands next to what 0004 adds), so "is this one already applied?" has no
  # order-independent answer and cannot replace the reset.
  echo "==> resetting the clone to the pinned tree"
  rm -f "$STAMP"
  git -C "$FFI_DIR" checkout -f -- .
fi

if [ "$NEEDS_PATCHES" = "1" ]; then
  echo "==> applying local patches"
  for p in "$PATCHES_DIR"/0*.patch; do
    name="$(basename "$p")"
    if git -C "$FFI_DIR" apply --check "$p" 2>/dev/null; then
      git -C "$FFI_DIR" apply "$p"
      echo "    applied $name"
    elif git -C "$FFI_DIR" apply --reverse --check "$p" 2>/dev/null; then
      echo "    already applied $name"
    else
      die "$name does not apply to the clone at $FFI_DIR (pin ${PIN:0:7}); rebase it or unset MLN_KEEP_CLONE"
    fi
  done
fi

echo "==> toolchain (mise) + build"
(
  cd "$FFI_DIR"
  mise trust --all
  mise install
  mise x -- rustup target add aarch64-linux-android
  mise run //:build "$PRESET"
)

echo "==> generating ffigen bindings"
(cd "$FFI_DIR/bindings/dart" && dart pub get && dart run tool/ffigen.dart)

echo "==> stripping and installing into jniLibs"
BUILT="$FFI_DIR/build/$PRESET/libmaplibre-native-c.so"
[ -f "$BUILT" ] || die "build output not found: $BUILT"
DEST_DIR="$PKG_DIR/android/src/main/jniLibs/arm64-v8a"
mkdir -p "$DEST_DIR"
"$LLVM_STRIP" --strip-unneeded -o "$DEST_DIR/libmaplibre-native-c.so" "$BUILT"

# The upstream Android presets build against the shared C++ runtime
# (ANDROID_STL=c++_shared), so the library needs libc++_shared.so beside it at
# load time and nothing else in a Flutter app ships one. Take it from the same
# NDK that produced the library, so the two always match.
CXX_SHARED="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"
[ -f "$CXX_SHARED" ] || die "libc++_shared.so not found at $CXX_SHARED"
"$LLVM_STRIP" --strip-unneeded -o "$DEST_DIR/libc++_shared.so" "$CXX_SHARED"

echo "==> done: $DEST_DIR"
for lib in libmaplibre-native-c.so libc++_shared.so; do
  echo "    $lib ($(du -h "$DEST_DIR/$lib" | cut -f1))"
done

# Only a run that got this far describes a tree worth reusing. Written after
# ffigen because that step rewrites a tracked file, which the tree hash covers.
if [ "$KEEP_CLONE" != "1" ]; then
  write_stamp
fi
