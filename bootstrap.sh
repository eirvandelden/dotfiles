#!/usr/bin/env sh
# bootstrap.sh
#
# Curlable bootstrap script for eirvandelden/dotfiles.
#
# Purpose:
# - Clone or update the dotfiles repo into a default location: ~/Developer/dotfiles
# - Run the installer: ./install.sh
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/eirvandelden/dotfiles/main/bootstrap.sh | sh
#
# Optional environment overrides:
#   TARGET_DIR=/custom/path \
#   REPO_URL=https://github.com/eirvandelden/dotfiles.git \
#   BRANCH=main \
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/eirvandelden/dotfiles/main/bootstrap.sh)"
#
# Notes:
# - This script is POSIX sh (no bashisms) so it works on macOS/Linux.
# - It intentionally keeps dependencies minimal: requires `git`.
# - `install.sh` is expected to handle OS detection and prerequisites.

set -eu

DEFAULT_REPO_URL="https://github.com/eirvandelden/dotfiles.git"
DEFAULT_BRANCH="main"
DEFAULT_TARGET_DIR="${HOME}/Developer/dotfiles"

REPO_URL="${REPO_URL:-$DEFAULT_REPO_URL}"
BRANCH="${BRANCH:-$DEFAULT_BRANCH}"
TARGET_DIR="${TARGET_DIR:-$DEFAULT_TARGET_DIR}"

log() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_parent_dir() {
  parent_dir=$(dirname "$TARGET_DIR")
  if [ -z "$parent_dir" ] || [ "$parent_dir" = "." ]; then
    die "Could not determine parent directory for TARGET_DIR: $TARGET_DIR"
  fi
  mkdir -p "$parent_dir"
}

clone_repo() {
  log "Cloning dotfiles repo into: $TARGET_DIR"
  git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$TARGET_DIR"
}

update_repo() {
  log "Updating dotfiles repo in: $TARGET_DIR"
  git -C "$TARGET_DIR" fetch --prune origin
  # Ensure we are on the desired branch; if not present locally, create tracking branch.
  if git -C "$TARGET_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git -C "$TARGET_DIR" checkout "$BRANCH"
  else
    git -C "$TARGET_DIR" checkout -B "$BRANCH" "origin/$BRANCH"
  fi
  git -C "$TARGET_DIR" pull --ff-only origin "$BRANCH"
}

run_installer() {
  if [ ! -f "$TARGET_DIR/install.sh" ]; then
    die "install.sh not found in $TARGET_DIR (clone/update may have failed)"
  fi
  log "Running installer: $TARGET_DIR/install.sh"
  exec sh "$TARGET_DIR/install.sh"
}

main() {
  log "Dotfiles bootstrap (repo: $REPO_URL, branch: $BRANCH)"
  log "Target directory: $TARGET_DIR"

  if ! need_cmd git; then
    die "git is required to bootstrap. Install git and re-run."
  fi

  ensure_parent_dir

  if [ -d "$TARGET_DIR/.git" ]; then
    update_repo
  else
    # If target exists but isn't a git repo, be conservative.
    if [ -e "$TARGET_DIR" ] && [ ! -d "$TARGET_DIR" ]; then
      die "TARGET_DIR exists but is not a directory: $TARGET_DIR"
    fi

    # Allow empty dir; refuse non-empty dir to avoid clobbering user files.
    if [ -d "$TARGET_DIR" ]; then
      # Check for emptiness (portable).
      if [ "$(ls -A "$TARGET_DIR" 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then
        die "TARGET_DIR exists and is not empty (refusing to overwrite): $TARGET_DIR"
      fi
    fi

    clone_repo
  fi

  run_installer
}

main "$@"
