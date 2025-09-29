#!/usr/bin/env bash
set -euo pipefail

# Workspace root directory (directory of this script's parent)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

warn() { echo -e "${YELLOW}[clean]${NC} $*"; }
info() { echo -e "${GREEN}[clean]${NC} $*"; }
err()  { echo -e "${RED}[clean]${NC} $*" >&2; }

AGGRESSIVE=false
KEEP_PUB_CACHE=false

usage() {
  cat <<EOF
Clean Flutter MapLibre multi-package workspace.

Usage: $0 [--aggressive] [--keep-pub-cache]

Options:
  --aggressive       Also delete generated code, lock files, pod caches and Gradle caches inside the repository.
  --keep-pub-cache   Do not run 'dart pub cache clean' (saves time if you have limited bandwidth).
  -h, --help         Show this help.

The script runs for every Flutter/Dart package:
  - flutter clean (if Flutter project)
  - rm -rf build/ .dart_tool/ .flutter-plugins .flutter-plugins-dependencies
  - removes example platform build artifacts (Pods/, DerivedData/) when aggressive.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aggressive) AGGRESSIVE=true; shift ;;
    --keep-pub-cache) KEEP_PUB_CACHE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

cd "$ROOT_DIR"

PACKAGES=(scripts maplibre_gl maplibre_gl_platform_interface maplibre_gl_web maplibre_gl_example)

# Validate flutter is available
if ! command -v flutter >/dev/null 2>&1; then
  err "flutter not found in PATH"; exit 1
fi

if ! command -v dart >/dev/null 2>&1; then
  err "dart not found in PATH"; exit 1
fi

for pkg in "${PACKAGES[@]}"; do
  if [[ ! -d "$pkg" ]]; then
    warn "Skipping missing package $pkg"; continue
  fi
  info "Cleaning $pkg"
  pushd "$pkg" >/dev/null

  # Run flutter clean only if pubspec contains 'flutter:' section or directory has android/ or ios/
  if grep -q '^flutter:' pubspec.yaml 2>/dev/null || [[ -d android || -d ios || -d macos || -d web ]]; then
    (flutter clean || warn "flutter clean failed in $pkg (continuing)")
  fi

  rm -rf build/ .dart_tool/ .package_config .packages pubspec.lock .flutter-plugins .flutter-plugins-dependencies

  if $AGGRESSIVE; then
    rm -rf .idea *.iml ios/Pods ios/Podfile.lock macos/Pods macos/Podfile.lock
    rm -rf android/.gradle android/build
    # Generated Dart code (regenerate later with scripts)
    find lib -maxdepth 1 -type f -name "*.g.dart" -delete 2>/dev/null || true
  fi

  popd >/dev/null
done

if $AGGRESSIVE; then
  info "Aggressive clean: removing top-level lock & melos artifacts"
  rm -f pubspec.lock
  rm -rf .dart_tool/ build/
fi

if ! $KEEP_PUB_CACHE; then
  info "Cleaning pub cache (this may take a while)"
  dart pub cache clean || warn "Failed to clean pub cache"
fi

info "Done. You can now run: melos bootstrap"
