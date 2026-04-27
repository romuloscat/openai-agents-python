#!/usr/bin/env bash
# Issue Triage Skill - Automated script for triaging GitHub issues
# This script analyzes new issues and applies labels, assigns owners,
# and posts initial triage comments based on issue content.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO="${REPO:-openai/openai-agents-python}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
ISSUE_NUMBER="${ISSUE_NUMBER:-}"
DRY_RUN="${DRY_RUN:-false}"

# Label definitions
LABEL_BUG="bug"
LABEL_FEATURE="enhancement"
LABEL_QUESTION="question"
LABEL_DOCS="documentation"
LABEL_NEEDS_REPRO="needs-reproduction"
LABEL_NEEDS_INFO="needs-more-info"
LABEL_GOOD_FIRST_ISSUE="good first issue"
LABEL_TRIAGE="triage"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

check_dependencies() {
  for cmd in gh jq curl; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Required command not found: $cmd"
    fi
  done
}

gh_api() {
  local endpoint="$1"
  shift
  gh api "/repos/${REPO}/${endpoint}" "$@"
}

# ---------------------------------------------------------------------------
# Fetch issue details
# ---------------------------------------------------------------------------
fetch_issue() {
  local issue_num="$1"
  log "Fetching issue #${issue_num}..."
  gh_api "issues/${issue_num}" 2>/dev/null || error "Failed to fetch issue #${issue_num}"
}

# ---------------------------------------------------------------------------
# Classify issue based on title and body keywords
# ---------------------------------------------------------------------------
classify_issue() {
  local title="$1"
  local body="$2"
  local combined
  combined=$(echo "${title} ${body}" | tr '[:upper:]' '[:lower:]')

  local labels=()

  # Bug detection
  if echo "$combined" | grep -qE '\b(bug|error|exception|crash|broken|fail|traceback|stacktrace)\b'; then
    labels+=("$LABEL_BUG")
  fi

  # Feature request detection
  if echo "$combined" | grep -qE '\b(feature|request|enhancement|add support|would be nice|suggestion|improve)\b'; then
    labels+=("$LABEL_FEATURE")
  fi

  # Documentation issues
  if echo "$combined" | grep -qE '\b(docs|documentation|readme|typo|spelling|unclear|confusing)\b'; then
    labels+=("$LABEL_DOCS")
  fi

  # Question detection
  if echo "$combined" | grep -qE '\b(how to|how do|question|help|confused|understand|why does)\b'; then
    labels+=("$LABEL_QUESTION")
  fi

  # Needs reproduction steps
  if [[ "${#labels[@]}" -gt 0 ]] && echo "$combined" | grep -qE '\b(bug|error|crash|broken)\b'; then
    if ! echo "$combined" | grep -qE '(steps to reproduce|reproduction|repro|minimal.*example|code.*sample)'; then
      labels+=("$LABEL_NEEDS_REPRO")
    fi
  fi

  # Default triage label if nothing matched
  if [[ "${#labels[@]}" -eq 0 ]]; then
    labels+=("$LABEL_TRIAGE")
  fi

  echo "${labels[@]}"
}

# ---------------------------------------------------------------------------
# Apply labels to an issue
# ---------------------------------------------------------------------------
apply_labels() {
  local issue_num="$1"
  shift
  local labels=("$@")

  if [[ "${#labels[@]}" -eq 0 ]]; then
    log "No labels to apply."
    return 0
  fi

  local labels_json
  labels_json=$(printf '%s\n' "${labels[@]}" | jq -R . | jq -sc .)

  log "Applying labels to #${issue_num}: ${labels[*]}"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY RUN] Would apply labels: ${labels_json}"
    return 0
  fi

  gh_api "issues/${issue_num}/labels" \
    --method POST \
    --input - <<< "{\"labels\": ${labels_json}}" \
    > /dev/null
}

# ---------------------------------------------------------------------------
# Post a triage comment
# ---------------------------------------------------------------------------
post_triage_comment() {
  local issue_num="$1"
  local labels=("${@:2}")

  local comment="Thanks for opening this issue! 🤖 Our automated triage has reviewed it and applied the following label(s): **${labels[*]}**.\n\nA maintainer will review this shortly. In the meantime, please ensure:\n- [ ] You are using the latest version of the package\n- [ ] You have searched existing issues for duplicates\n- [ ] You have provided sufficient detail to reproduce the problem (if applicable)"

  log "Posting triage comment on #${issue_num}..."

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY RUN] Would post comment: ${comment}"
    return 0
  fi

  gh_api "issues/${issue_num}/comments" \
    --method POST \
    --field body="$(printf '%b' "$comment")" \
    > /dev/null
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  check_dependencies

  [[ -z "$GITHUB_TOKEN" ]] && error "GITHUB_TOKEN is not set."
  [[ -z "$ISSUE_NUMBER" ]] && error "ISSUE_NUMBER is not set."

  log "Starting issue triage for #${ISSUE_NUMBER} in ${REPO}"

  local issue_data
  issue_data=$(fetch_issue "$ISSUE_NUMBER")

  local title body
  title=$(echo "$issue_data" | jq -r '.title // ""')
  body=$(echo "$issue_data" | jq -r '.body // ""')
  local state
  state=$(echo "$issue_data" | jq -r '.state // "open"')

  if [[ "$state" != "open" ]]; then
    log "Issue #${ISSUE_NUMBER} is not open (state: ${state}). Skipping triage."
    exit 0
  fi

  log "Issue title: ${title}"

  # Classify and get labels
  read -ra detected_labels <<< "$(classify_issue "$title" "$body")"
  log "Detected labels: ${detected_labels[*]}"

  apply_labels "$ISSUE_NUMBER" "${detected_labels[@]}"
  post_triage_comment "$ISSUE_NUMBER" "${detected_labels[@]}"

  log "Triage complete for issue #${ISSUE_NUMBER}."
}

main "$@"
