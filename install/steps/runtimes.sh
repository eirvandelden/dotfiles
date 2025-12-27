#!/usr/bin/env bash
# Runtime installation steps (Ruby + Node) for the dotfiles installer.
#
# This file is intended to be sourced (not executed).
#
# Assumptions / policy:
# - You manage desired versions via:
#     - ruby/.ruby-version
#     - node/.node-version
# - You install the build tools elsewhere (packages step / Brewfile):
#     - ruby-install
#     - node-build
# - This step only:
#     - validates the tooling exists
#     - installs the requested runtimes into user-space prefixes
# - Ruby install requirements:
#     - jemalloc support
#     - YJIT enabled at build time (ZJIT is experimental and not reliably available as a build flag)
#
# Typical call sequence (from install.sh):
#   source install/lib/generic.sh
#   source install/steps/runtimes.sh
#   install_all_runtimes

set -euo pipefail

: "${DOTFILES_ROOT:=$(pwd)}"

RUBY_VERSION_FILE="${RUBY_VERSION_FILE:-${DOTFILES_ROOT}/ruby/.ruby-version}"
NODE_VERSION_FILE="${NODE_VERSION_FILE:-${DOTFILES_ROOT}/node/.node-version}"

# Install prefixes (user-space, cross-platform)
RUBY_PREFIX_BASE="${RUBY_PREFIX_BASE:-${HOME}/.rubies}"
NODE_PREFIX_BASE="${NODE_PREFIX_BASE:-${HOME}/.nodes}"

###############################################################################
# Helpers
###############################################################################

read_version_file_or_abort() {
  local path="$1"
  [[ -f "$path" ]] || abort "Version file not found: $path"
  local version
  version="$(tr -d ' \t\r\n' <"$path")"
  [[ -n "$version" ]] || abort "Version file is empty: $path"
  printf '%s' "$version"
}

ruby_prefix_for_version() {
  local version="$1"
  printf '%s' "${RUBY_PREFIX_BASE}/ruby-${version}"
}

node_prefix_for_version() {
  local version="$1"
  printf '%s' "${NODE_PREFIX_BASE}/node-${version}"
}

ruby_is_installed() {
  local version="$1"
  local prefix="$2"
  [[ -x "${prefix}/bin/ruby" ]] || return 1
  "${prefix}/bin/ruby" -v 2>/dev/null | grep -q "ruby ${version}\b"
}

node_is_installed() {
  local version="$1"
  local prefix="$2"
  [[ -x "${prefix}/bin/node" ]] || return 1
  "${prefix}/bin/node" --version 2>/dev/null | tr -d 'v' | grep -qx "${version}"
}

###############################################################################
# Ruby
###############################################################################

install_ruby_runtime() {
  log "Installing Ruby runtime…"

  # Tooling should have been installed earlier (Brewfile / packages step).
  #
  # NOTE:
  # - chruby is not required to build Ruby; it's only needed to *select* Ruby in your shell.
  # - `ruby-install` is the only required tool for this build step.
  check_required_tooling ruby-install

  local version prefix
  version="$(read_version_file_or_abort "$RUBY_VERSION_FILE")"
  prefix="$(ruby_prefix_for_version "$version")"

  if ruby_is_installed "$version" "$prefix"; then
    log "Ruby ${version} already installed at ${prefix}"
    return 0
  fi

  # Ruby build options:
  # - jemalloc: reduces fragmentation, good for long-running processes.
  # - YJIT: stable JIT for modern Ruby (3.1+).
  #
  # Notes / advice:
  # - ZJIT is experimental and not consistently available as a configure flag across versions/tooling.
  # - If you want additional build customization later, you can extend the configure flags here.
  log "Building Ruby ${version} with jemalloc + YJIT (prefix: ${prefix})"
  ruby-install ruby "${version}" -- \
    --prefix="${prefix}" \
    --with-jemalloc \
    --enable-yjit

  log "Ruby ${version} installed at ${prefix}"
  log "To use it, add it to PATH, e.g.:"
  log "  export PATH=\"${prefix}/bin:\$PATH\""
  log "If you use chruby, you can select it with:"
  log "  chruby ruby-${version}"
}

###############################################################################
# Node
###############################################################################

install_node_runtime() {
  log "Installing Node.js runtime…"

  # Tooling should have been installed earlier (Brewfile / packages step).
  check_required_tooling node-build

  local version prefix
  version="$(read_version_file_or_abort "$NODE_VERSION_FILE")"
  prefix="$(node_prefix_for_version "$version")"

  if node_is_installed "$version" "$prefix"; then
    log "Node ${version} already installed at ${prefix}"
    return 0
  fi

  log "Building Node ${version} (prefix: ${prefix})"
  # node-build usage: node-build <version> <prefix>
  node-build "${version}" "${prefix}"

  log "Node ${version} installed at ${prefix}"
  log "Add it to PATH, e.g.:"
  log "  export PATH=\"${prefix}/bin:\$PATH\""
}

###############################################################################
# Entrypoint
###############################################################################

install_all_runtimes() {
  install_ruby_runtime
  install_node_runtime
}
