#!/usr/bin/env sh
# One entry point for the local (stage-1) checks — a thin driver over the
# containers/checks/compose.yml services. Portable: no host tool installs (the
# images mirror the CI tools exactly). Default: run every surface whose files
# changed (diff-gated, mirroring the CI checks skip-model). --full runs all
# surfaces unconditionally (use for a first run / fresh clone).
#
# Usage:
#   scripts/checks/local.sh                    # all surfaces, changed files only
#   scripts/checks/local.sh --full             # all surfaces, whole repo
#   scripts/checks/local.sh --full --verbose   # + list the files each check scans
#   scripts/checks/local.sh shell jsonc        # selected surfaces, changed only
#
# Surface names match the containers/checks/compose.yml services:
#   jsonc · shell · python · yaml · yaml-syntax
#
# Pre-commit hook (.githooks/pre-commit) execs this script in diff mode, so
# every commit checks all changed surfaces through compose. Install:
#   git config core.hooksPath .githooks

set -eu

# shellcheck disable=SC1007  # CDPATH= cd is the intentional empty-CD cd idiom
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT"

# Colors only when stdout is a TTY (pipes/logs stay plain).
if [ -t 1 ]; then
  ESC=$(printf '\033')
  BOLD="${ESC}[1m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; RED="${ESC}[31m"; NC="${ESC}[0m"
else
  BOLD=""; GREEN=""; YELLOW=""; RED=""; NC=""
fi

# --- CLI ---------------------------------------------------------------------
MODE="diff"   # diff | full
VERBOSE=0
SURFACES=""
for arg in "$@"; do
  case "$arg" in
    --full) MODE="full" ;;
    --diff) MODE="diff" ;;
    --verbose|-v) VERBOSE=1 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) SURFACES="$SURFACES $arg" ;;
  esac
done

ALL="jsonc shell python yaml yaml-syntax gitleaks"
if [ -z "$SURFACES" ]; then
  SURFACES="$ALL"
fi

# --- Changed files (diff mode) ----------------------------------------------
# Whole branch vs origin/main when it exists (PR-shaped), else vs HEAD;
# plus any staged/unstaged working-tree changes on top.
changed_files() {
  if git rev-parse --verify --quiet origin/main >/dev/null; then
    git diff --name-only --diff-filter=ACM origin/main...HEAD
  fi
  git diff --name-only --diff-filter=ACM
  git diff --cached --name-only --diff-filter=ACM
  git ls-files --others --exclude-standard
}

if [ "$MODE" = "diff" ]; then
  CHANGED="$(changed_files | sort -u)"
fi

# --- Surface → changed-file globs (mirror the CI checks filters) -------------
surface_glob() {
  # $1 = surface name; prints the regex its files match (stdout)
  case "$1" in
    jsonc)            printf '%s' '\.jsonc$|scripts/checks/jsonc\.py$' ;;
    shell)            printf '%s' '\.sh$|(^|/)\.githooks/' ;;
    python)           printf '%s' '\.py$' ;;
    yaml|yaml-syntax) printf '%s' '\.ya?ml$' ;;
  esac
}

surface_touched() {
  # $1 = surface name; reads $CHANGED on stdin
  case "$1" in
    gitleaks)         return 0 ;;
    jsonc)            grep -qE '\.jsonc$|scripts/checks/jsonc\.py$' || return 1 ;;
    shell)            grep -qE '\.sh$|(^|/)\.githooks/' || return 1 ;;
    python)           grep -q '\.py$' || return 1 ;;
    yaml|yaml-syntax) grep -qE '\.ya?ml$' || return 1 ;;
  esac
}

# Files this surface checks, one per line.
surface_files() {
  # $1 = surface name
  re="$(surface_glob "$1")"
  if [ "$MODE" = "full" ]; then
    find . -path './.git' -prune -o -type f -print 2>/dev/null | sed 's#^./##' | grep -E "$re" | sort
  else
    printf '%s\n' "$CHANGED" | grep -E "$re" | sort
  fi
}

# --- Run ---------------------------------------------------------------------
status=0
for svc in $SURFACES; do
  if [ "$MODE" = "diff" ]; then
    if ! printf '%s\n' "$CHANGED" | surface_touched "$svc"; then
      printf '%s⏭  skip: %s (no matching files changed)%s\n' "$YELLOW" "$svc" "$NC"
      continue
    fi
    reason="changed"
  else
    reason="full"
  fi

  printf '%s== %s (%s) ==%s\n' "$BOLD" "$svc" "$reason" "$NC"
  if [ "$VERBOSE" -eq 1 ]; then
    surface_files "$svc" | sed 's#^#    #'
  fi
  if podman-compose -f containers/checks/compose.yml run --rm "$svc"; then
    printf '%s✅ %s (%s) passed%s\n' "$GREEN" "$svc" "$reason" "$NC"
  else
    printf '%s❌ %s (%s) failed%s\n' "$RED" "$svc" "$reason" "$NC"
    status=1
  fi
done

if [ "$MODE" = "diff" ] && [ -z "${CHANGED:-}" ]; then
  printf '%s⏭  no changed files detected — nothing to check (use --full for a whole-repo pass)%s\n' "$YELLOW" "$NC"
fi

if [ "$status" -eq 0 ]; then
  printf '%s✅ all checks passed%s\n' "$GREEN" "$NC"
else
  printf '%s❌ some checks failed%s\n' "$RED" "$NC"
fi
exit "$status"
