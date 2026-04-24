#!/usr/bin/env bash
# examples-auto-run/scripts/run.sh
# Automatically discovers and runs all examples in the repository,
# capturing output and reporting pass/fail status.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXAMPLES_DIR="${REPO_ROOT}/examples"
LOG_DIR="${REPO_ROOT}/.agents/skills/examples-auto-run/logs"
TIMEOUT_SECONDS="${EXAMPLES_TIMEOUT:-60}"
PYTHON_BIN="${PYTHON_BIN:-python}"

PASSED=0
FAILED=0
SKIPPED=0
FAILED_EXAMPLES=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[examples-auto-run] $*"; }
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() { log "ERROR $*" >&2; }

require_command() {
  if ! command -v "$1" &>/dev/null; then
    error "Required command not found: $1"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
require_command "$PYTHON_BIN"
require_command timeout

mkdir -p "$LOG_DIR"

if [[ ! -d "$EXAMPLES_DIR" ]]; then
  warn "Examples directory not found: $EXAMPLES_DIR — nothing to run."
  exit 0
fi

# ---------------------------------------------------------------------------
# Discover examples
# ---------------------------------------------------------------------------
# An "example" is any *.py file directly inside a sub-directory of examples/
# or any top-level *.py file inside examples/ itself.
mapfile -t EXAMPLE_FILES < <(
  find "$EXAMPLES_DIR" -maxdepth 2 -name '*.py' | sort
)

if [[ ${#EXAMPLE_FILES[@]} -eq 0 ]]; then
  warn "No example files discovered under $EXAMPLES_DIR."
  exit 0
fi

info "Discovered ${#EXAMPLE_FILES[@]} example file(s)."
info "Timeout per example: ${TIMEOUT_SECONDS}s"
info "Log directory: $LOG_DIR"
echo ""

# ---------------------------------------------------------------------------
# Run each example
# ---------------------------------------------------------------------------
for example in "${EXAMPLE_FILES[@]}"; do
  rel_path="${example#"${REPO_ROOT}/"}"
  example_name="$(basename "$example" .py)"
  log_file="${LOG_DIR}/${example_name}.log"

  # Skip files that opt-out via a marker comment
  if grep -q '# agents:skip' "$example" 2>/dev/null; then
    warn "SKIP  $rel_path  (opt-out marker found)"
    ((SKIPPED++)) || true
    continue
  fi

  info "RUN   $rel_path"

  # Run with a timeout; capture stdout+stderr to log file
  set +e
  timeout "$TIMEOUT_SECONDS" \
    "$PYTHON_BIN" "$example" \
    > "$log_file" 2>&1
  exit_code=$?
  set -e

  if [[ $exit_code -eq 0 ]]; then
    info "PASS  $rel_path"
    ((PASSED++)) || true
  elif [[ $exit_code -eq 124 ]]; then
    error "TIMEOUT $rel_path (exceeded ${TIMEOUT_SECONDS}s)"
    FAILED_EXAMPLES+=("$rel_path (timeout)")
    ((FAILED++)) || true
  else
    error "FAIL  $rel_path (exit code $exit_code)"
    # Print last 20 lines of output to help with debugging
    tail -n 20 "$log_file" | sed 's/^/    /' >&2
    FAILED_EXAMPLES+=("$rel_path")
    ((FAILED++)) || true
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
info "================================================"
info "Results: ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
info "================================================"

if [[ ${#FAILED_EXAMPLES[@]} -gt 0 ]]; then
  error "Failed examples:"
  for f in "${FAILED_EXAMPLES[@]}"; do
    error "  - $f"
  done
  exit 1
fi

info "All examples completed successfully."
exit 0
