#!/usr/bin/env bash
# Dependency Update Skill
# Automatically checks for outdated dependencies and creates update PRs
# for the openai-agents-python project.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
BRANCH_PREFIX="chore/dependency-update"
COMMIT_MESSAGE_PREFIX="chore: update dependencies"
PYTHON=${PYTHON:-python3}
PIP=${PIP:-pip}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[dependency-update] $*"; }
err()  { echo "[dependency-update] ERROR: $*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
require_cmd git
require_cmd "$PYTHON"
require_cmd "$PIP"

cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Step 1: Discover outdated packages
# ---------------------------------------------------------------------------
log "Checking for outdated packages..."

# pip list --outdated returns JSON with name/version/latest fields
OUTDATED_JSON=$("$PIP" list --outdated --format=json 2>/dev/null || echo "[]")

if [ "$OUTDATED_JSON" = "[]" ]; then
  log "All dependencies are up to date. Nothing to do."
  exit 0
fi

log "Outdated packages found:"
echo "$OUTDATED_JSON" | "$PYTHON" -c "
import json, sys
pkgs = json.load(sys.stdin)
for p in pkgs:
    print(f'  {p[\"name\"]}: {p[\"version\"]} -> {p[\"latest\"]}')
"

# ---------------------------------------------------------------------------
# Step 2: Determine which packages are direct dependencies
# ---------------------------------------------------------------------------
log "Filtering to direct project dependencies..."

# Collect direct dependency names from pyproject.toml (if present) or requirements files
DIRECT_DEPS=()

if [ -f "pyproject.toml" ]; then
  mapfile -t DIRECT_DEPS < <(
    "$PYTHON" - <<'EOF'
import re, sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib  # fallback for Python < 3.11

with open("pyproject.toml", "rb") as f:
    data = tomllib.load(f)

deps = data.get("project", {}).get("dependencies", [])
for dep in deps:
    name = re.split(r"[>=<!\[\s]", dep)[0].strip().lower()
    if name:
        print(name)
EOF
  )
fi

if [ -f "requirements.txt" ]; then
  mapfile -t REQ_DEPS < <(
    grep -v '^\.\|^#\|^-' requirements.txt \
      | sed 's/[>=<!].*//' \
      | tr '[:upper:]' '[:lower:]' \
      | tr -d ' ' \
      | grep -v '^$'
  )
  DIRECT_DEPS+=("${REQ_DEPS[@]}")
fi

log "Direct dependencies detected: ${#DIRECT_DEPS[@]}"

# ---------------------------------------------------------------------------
# Step 3: Build list of packages to update
# ---------------------------------------------------------------------------
TO_UPDATE=$(echo "$OUTDATED_JSON" | "$PYTHON" - "${DIRECT_DEPS[@]}" <<'EOF'
import json, sys

outdated = json.load(open('/dev/stdin') if False else __import__('io').StringIO(sys.stdin.read()))
direct = {d.lower() for d in sys.argv[1:]}

for pkg in outdated:
    name = pkg["name"].lower()
    # Include if it is a direct dep, or if no direct dep list was found
    if not direct or name in direct:
        print(f"{pkg['name']}=={pkg['latest']}")
EOF
)

if [ -z "$TO_UPDATE" ]; then
  log "No direct dependencies require updates."
  exit 0
fi

log "Packages to update:"
echo "$TO_UPDATE" | sed 's/^/  /'

# ---------------------------------------------------------------------------
# Step 4: Create a new git branch
# ---------------------------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BRANCH_NAME="${BRANCH_PREFIX}-${TIMESTAMP}"

log "Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

# ---------------------------------------------------------------------------
# Step 5: Apply updates
# ---------------------------------------------------------------------------
log "Installing updated packages..."
echo "$TO_UPDATE" | xargs "$PIP" install --quiet

# Regenerate lock / requirements files if tooling is present
if command -v pip-compile &>/dev/null && [ -f "requirements.in" ]; then
  log "Re-compiling requirements.in -> requirements.txt"
  pip-compile --quiet requirements.in
elif [ -f "requirements.txt" ]; then
  log "Updating versions in requirements.txt"
  echo "$TO_UPDATE" | while IFS= read -r pkg_ver; do
    pkg_name=$(echo "$pkg_ver" | cut -d= -f1)
    pkg_new=$(echo "$pkg_ver" | cut -d= -f3)
    sed -i "s|${pkg_name}[>=!<][^[:space:]]*|${pkg_name}>=${pkg_new}|Ig" requirements.txt || true
  done
fi

# ---------------------------------------------------------------------------
# Step 6: Commit changes
# ---------------------------------------------------------------------------
CHANGED_FILES=$(git diff --name-only)

if [ -z "$CHANGED_FILES" ]; then
  log "No file changes detected after update. Cleaning up branch."
  git checkout -
  git branch -D "$BRANCH_NAME"
  exit 0
fi

PKG_SUMMARY=$(echo "$TO_UPDATE" | tr '\n' ' ' | sed 's/ $//')
git add -A
git commit -m "${COMMIT_MESSAGE_PREFIX}: ${PKG_SUMMARY}"

log "Changes committed on branch '${BRANCH_NAME}'."
log "Push the branch and open a PR to complete the update."
