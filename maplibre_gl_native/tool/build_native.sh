#!/usr/bin/env bash
# Builds libmaplibre-native-c.so from the pinned maplibre-native-ffi tree and
# installs it (stripped) into this package's jniLibs, generating the ffigen
# Dart bindings along the way. Idempotent: safe to re-run, reuses an existing
# clone, and treats that clone as a build artifact (it is reset to the pin and
# re-patched on every run; set MLN_KEEP_CLONE=1 to work on it by hand instead).
#
# Usage: tool/build_native.sh [--backend vulkan|egl] [--ffi-dir <path>]
set -euo pipefail

PIN=6ac6cd49e06305646ef23eba4b970fc56c92e17c
NDK_PINNED_VERSION=28.1.13356709
REPO_URL=https://github.com/maplibre/maplibre-native-ffi.git

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Default matches the pubspec path dependency: ../../maplibre-native-ffi
FFI_DIR="$(dirname "$(dirname "$PKG_DIR")")/maplibre-native-ffi"
BACKEND=vulkan

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --backend) BACKEND="${2:?}"; shift 2 ;;
    --ffi-dir) FFI_DIR="${2:?}"; shift 2 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done
case "$BACKEND" in vulkan|egl) ;; *) die "--backend must be vulkan or egl" ;; esac
export MISE_ENV="android-arm64-$BACKEND"

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

echo "==> backend: $BACKEND (MISE_ENV=$MISE_ENV)"
echo "==> upstream clone: $FFI_DIR"
echo "==> NDK: $ANDROID_NDK_HOME"

if [ ! -d "$FFI_DIR/.git" ]; then
  echo "==> cloning maplibre-native-ffi (pinned at ${PIN:0:7})"
  git clone --recurse-submodules "$REPO_URL" "$FFI_DIR"
  git -C "$FFI_DIR" checkout --detach "$PIN"
  git -C "$FFI_DIR" submodule update --init --recursive
elif [ "${MLN_KEEP_CLONE:-0}" = "1" ]; then
  HEAD="$(git -C "$FFI_DIR" rev-parse HEAD)"
  echo "==> MLN_KEEP_CLONE=1: leaving the clone at ${HEAD:0:7} untouched"
  [ "$HEAD" = "$PIN" ] \
    || echo "warning: that is not the pin ${PIN:0:7}; the patches below may not apply" >&2
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
  git -C "$FFI_DIR" checkout -f -- .
fi

echo "==> applying local patches"
for p in "$PKG_DIR"/upstream_patches/0*.patch; do
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

echo "==> toolchain (mise) + build"
(
  cd "$FFI_DIR"
  mise trust --all
  mise install
  mise x -- rustup target add aarch64-linux-android
  mise run //:build
)

echo "==> generating ffigen bindings"
(cd "$FFI_DIR/bindings/dart" && dart pub get && dart run ffigen --config ffigen.yaml)

echo "==> stripping and installing into jniLibs"
BUILT="$FFI_DIR/build/$MISE_ENV/libmaplibre-native-c.so"
[ -f "$BUILT" ] || die "build output not found: $BUILT"
DEST_DIR="$PKG_DIR/android/src/main/jniLibs/arm64-v8a"
mkdir -p "$DEST_DIR"
"$LLVM_STRIP" --strip-unneeded -o "$DEST_DIR/libmaplibre-native-c.so" "$BUILT"

echo "==> done: $DEST_DIR/libmaplibre-native-c.so ($(du -h "$DEST_DIR/libmaplibre-native-c.so" | cut -f1))"
