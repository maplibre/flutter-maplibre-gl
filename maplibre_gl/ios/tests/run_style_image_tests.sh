#!/bin/sh
set -eu

tests_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/maplibre-style-image-tests.XXXXXX")
mkdir -p "$test_dir/Sources/StyleImageRetention" "$test_dir/Tests/StyleImageRetentionTests"
cp "$tests_dir/Package.swift" "$test_dir/Package.swift"
cp "$tests_dir/../maplibre_gl/Sources/maplibre_gl/DartStyleImages.swift" \
  "$test_dir/Sources/StyleImageRetention/"
cp "$tests_dir/DartStyleImagesTests.swift" "$test_dir/Tests/StyleImageRetentionTests/"
printf 'Test harness: %s\n' "$test_dir"
swift test --package-path "$test_dir" "$@"
