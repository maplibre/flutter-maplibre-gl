#!/usr/bin/env bash
set -euo pipefail

# Bump every package in the workspace to one shared version, as RELEASE.md requires.
#
# What this touches:
#   - version: in the pubspec of every workspace package
#   - the internal maplibre_gl_* dependency constraints, so they follow the bump
#   - the maplibre_gl: ^x.y.z install snippets in README.md and website/docs
#
# What it deliberately does not touch: changelogs and the migration guide. Those
# need prose, so the script only reports whether they mention the new version.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

warn() { echo -e "${YELLOW}[bump]${NC} $*"; }
info() { echo -e "${GREEN}[bump]${NC} $*"; }
err()  { echo -e "${RED}[bump]${NC} $*" >&2; }

# Every package carrying a version:. maplibre_gl_example and scripts are not
# published, but RELEASE.md keeps the whole workspace on one number.
PACKAGES=(maplibre_gl maplibre_gl_platform_interface maplibre_gl_web maplibre_gl_example scripts)

# Changelogs that get their own page on pub.dev, plus the root one.
CHANGELOGS=(CHANGELOG.md maplibre_gl/CHANGELOG.md maplibre_gl_platform_interface/CHANGELOG.md maplibre_gl_web/CHANGELOG.md)

# Files documenting the version an app should depend on.
DOC_FILES=(README.md website/docs/index.md website/docs/getting-started.md website/docs/migration.md)

usage() {
  cat <<EOF
Bump all workspace packages to a single version.

Usage: $0 <new-version> [--dry-run]
       $0 --check

Arguments:
  <new-version>   Target version, e.g. 0.27.0 (no leading v).

Options:
  --dry-run       Print the edits without writing anything.
  --check         Verify the workspace is self-consistent and exit. Fails when
                  packages disagree on the version, when an internal constraint
                  is stale, or when a changelog has no section for it. Safe to
                  run in CI.
  -h, --help      Show this help.

Typical release flow (see RELEASE.md):
  $0 0.27.0
  # write the changelog sections and the migration guide entry
  $0 --check
EOF
}

# Reads the authoritative current version from the main package.
current_version() {
  local v
  v="$(sed -n 's/^version: *//p' "$ROOT_DIR/maplibre_gl/pubspec.yaml" | head -1)"
  if [[ -z "$v" ]]; then
    err "No version: found in maplibre_gl/pubspec.yaml"; exit 1
  fi
  echo "$v"
}

# perl rather than sed -i, which differs between macOS and GNU. The strings go
# through the environment so nothing in them is read as pattern syntax.
replace_in_file() {
  local file="$1"
  PAT="$2" REPL="$3" perl -0777 -pi -e 's/\Q$ENV{PAT}\E/$ENV{REPL}/g' "$ROOT_DIR/$file"
}

count_in_file() {
  local file="$1" pattern="$2" n
  [[ -f "$ROOT_DIR/$file" ]] || { echo 0; return 0; }
  # grep -c already prints 0 when nothing matches; || true keeps its exit
  # status from tripping set -e.
  n="$(grep -c -F -- "$pattern" "$ROOT_DIR/$file" 2>/dev/null || true)"
  echo "${n:-0}"
}

do_check() {
  local failures=0
  local expected
  expected="$(current_version)"
  info "Checking the workspace against version $expected"

  for pkg in "${PACKAGES[@]}"; do
    local file="$pkg/pubspec.yaml" found
    if [[ ! -f "$ROOT_DIR/$file" ]]; then
      warn "$file is missing, skipping"; continue
    fi
    found="$(sed -n 's/^version: *//p' "$ROOT_DIR/$file" | head -1)"
    if [[ "$found" != "$expected" ]]; then
      err "$file is at ${found:-<none>}, expected $expected"; failures=$((failures + 1))
    fi
  done

  # An internal constraint left on an older version publishes fine but resolves
  # to the previous release, so it has to match exactly.
  for file in maplibre_gl/pubspec.yaml maplibre_gl_web/pubspec.yaml; do
    while IFS= read -r line; do
      local constraint="${line##*: }"
      if [[ "$constraint" != "^$expected" ]]; then
        err "$file: '$line' should be ^$expected"; failures=$((failures + 1))
      fi
    done < <(grep -E '^  maplibre_gl(_platform_interface|_web): \^' "$ROOT_DIR/$file" || true)
  done

  for file in "${CHANGELOGS[@]}"; do
    if ! grep -qE "^## \[?$(printf '%s' "$expected" | sed 's/\./\\./g')" "$ROOT_DIR/$file"; then
      err "$file has no section for $expected"; failures=$((failures + 1))
    fi
  done

  for file in "${DOC_FILES[@]}"; do
    [[ -f "$ROOT_DIR/$file" ]] || continue
    while IFS= read -r line; do
      if [[ "$line" != *"^$expected" ]]; then
        err "$file: '$(echo "$line" | xargs)' should pin ^$expected"; failures=$((failures + 1))
      fi
    done < <(grep -E '^ *maplibre_gl: \^[0-9]' "$ROOT_DIR/$file" || true)
  done

  if [[ $failures -gt 0 ]]; then
    err "$failures problem(s) found"; return 1
  fi
  info "Workspace is consistent at $expected"
}

DRY_RUN=false
NEW_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) do_check; exit $? ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) err "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -n "$NEW_VERSION" ]]; then err "Unexpected argument: $1"; exit 1; fi
      NEW_VERSION="$1"; shift ;;
  esac
done

if [[ -z "$NEW_VERSION" ]]; then
  err "Missing target version"; usage; exit 1
fi

# Pre-1.0 releases use x.y.z with no build metadata (RELEASE.md), and a
# prerelease suffix is still allowed so a release candidate can be cut.
if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  err "'$NEW_VERSION' is not a version like 0.27.0 (drop any leading v)"; exit 1
fi

OLD_VERSION="$(current_version)"

if [[ "$OLD_VERSION" == "$NEW_VERSION" ]]; then
  err "maplibre_gl is already at $NEW_VERSION"; exit 1
fi

info "$OLD_VERSION -> $NEW_VERSION"
$DRY_RUN && warn "Dry run, nothing will be written"

# (file, literal to find, replacement) triples, built before writing so a dry
# run and a real run report exactly the same thing.
declare -a EDITS=()

for pkg in "${PACKAGES[@]}"; do
  file="$pkg/pubspec.yaml"
  if [[ ! -f "$ROOT_DIR/$file" ]]; then
    warn "$file is missing, skipping"; continue
  fi
  if [[ "$(count_in_file "$file" "version: $OLD_VERSION")" == "0" ]]; then
    warn "$file has no 'version: $OLD_VERSION', skipping"; continue
  fi
  EDITS+=("$file|version: $OLD_VERSION|version: $NEW_VERSION")
done

for file in maplibre_gl/pubspec.yaml maplibre_gl_web/pubspec.yaml; do
  for dep in maplibre_gl_platform_interface maplibre_gl_web; do
    if [[ "$(count_in_file "$file" "$dep: ^$OLD_VERSION")" != "0" ]]; then
      EDITS+=("$file|$dep: ^$OLD_VERSION|$dep: ^$NEW_VERSION")
    fi
  done
done

for file in "${DOC_FILES[@]}"; do
  if [[ "$(count_in_file "$file" "maplibre_gl: ^$OLD_VERSION")" != "0" ]]; then
    EDITS+=("$file|maplibre_gl: ^$OLD_VERSION|maplibre_gl: ^$NEW_VERSION")
  fi
done

for edit in "${EDITS[@]}"; do
  IFS='|' read -r file pattern replacement <<< "$edit"
  n="$(count_in_file "$file" "$pattern")"
  info "$file: $pattern -> $replacement (${n}x)"
  $DRY_RUN || replace_in_file "$file" "$pattern" "$replacement"
done

if $DRY_RUN; then
  exit 0
fi

echo
info "Version numbers updated. Remaining, by hand:"

for file in "${CHANGELOGS[@]}"; do
  if grep -qE "^## \[?$(printf '%s' "$NEW_VERSION" | sed 's/\./\\./g')" "$ROOT_DIR/$file"; then
    info "  [x] $file documents $NEW_VERSION"
  else
    warn "  [ ] $file needs a $NEW_VERSION section"
  fi
done

if grep -q "Upgrading to $NEW_VERSION" "$ROOT_DIR/website/docs/migration.md" 2>/dev/null; then
  info "  [x] website/docs/migration.md documents $NEW_VERSION"
else
  warn "  [ ] website/docs/migration.md needs an 'Upgrading to $NEW_VERSION' section"
fi

warn "  [ ] smoke test the example on Android, iOS and web (RELEASE.md)"
warn "  [ ] melos analyze && melos test"
echo
info "Then re-run '$0 --check' before opening the release PR."
