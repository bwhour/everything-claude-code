#!/usr/bin/env bash
set -euo pipefail

REPO_URL_DEFAULT="https://github.com/affaan-m/everything-claude-code.git"

usage() {
  cat <<'EOF'
Install Everything Claude Code configs into your local Claude config directory.

Default behavior:
  - Clone the repo into a temporary directory (no workspace pollution)
  - Copy agents/, rules/, commands/, skills/ into ~/.claude/*

Usage:
  ./install-claude-config.sh [options]

Options:
  --repo-url <url>     Override git repo URL (default: affaan-m/everything-claude-code)
  --claude-dir <path>  Override target Claude config directory (default: ~/.claude)
  --local              Use this script's directory as the source (skip git clone)
  --backup             Backup existing ~/.claude/{agents,rules,commands,skills} before copying
  -h, --help           Show help

Examples:
  ./install-claude-config.sh
  ./install-claude-config.sh --backup
  ./install-claude-config.sh --local --backup
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

main() {
  local repo_url="${REPO_URL:-$REPO_URL_DEFAULT}"
  local claude_dir="${CLAUDE_DIR:-$HOME/.claude}"
  local mode="clone"
  local backup=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-url)
        repo_url="$2"
        shift 2
        ;;
      --claude-dir)
        claude_dir="$2"
        shift 2
        ;;
      --local)
        mode="local"
        shift
        ;;
      --backup)
        backup=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  require_cmd cp
  require_cmd mkdir
  require_cmd rm

  if [[ "$mode" == "clone" ]]; then
    require_cmd git
    require_cmd mktemp
  fi
  if [[ "$backup" -eq 1 ]]; then
    require_cmd date
  fi

  mkdir -p \
    "$claude_dir/agents" \
    "$claude_dir/rules" \
    "$claude_dir/commands" \
    "$claude_dir/skills"

  if [[ "$backup" -eq 1 ]]; then
    local ts backup_dir d
    ts="$(date +%Y%m%d-%H%M%S)"
    backup_dir="$claude_dir/backup-everything-claude-code-$ts"
    mkdir -p "$backup_dir"

    for d in agents rules commands skills; do
      mkdir -p "$backup_dir/$d"
      # Best-effort backup; if empty, keep going.
      cp -R "$claude_dir/$d/." "$backup_dir/$d/" 2>/dev/null || true
    done

    echo "Backup created at: $backup_dir"
  fi

  local tmp_dir=""
  cleanup() {
    if [[ -n "$tmp_dir" ]]; then
      rm -rf "$tmp_dir"
    fi
  }
  trap cleanup EXIT

  local src_dir=""
  if [[ "$mode" == "local" ]]; then
    src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  else
    tmp_dir="$(mktemp -d)"
    git clone --depth 1 "$repo_url" "$tmp_dir/everything-claude-code"
    src_dir="$tmp_dir/everything-claude-code"
  fi

  local d
  for d in agents rules commands skills; do
    if [[ ! -d "$src_dir/$d" ]]; then
      echo "Source missing directory: $src_dir/$d" >&2
      exit 1
    fi
  done

  cp -f "$src_dir/agents/"*.md "$claude_dir/agents/"
  cp -f "$src_dir/rules/"*.md "$claude_dir/rules/"
  cp -f "$src_dir/commands/"*.md "$claude_dir/commands/"
  cp -R "$src_dir/skills/." "$claude_dir/skills/"

  echo "Installed configs into: $claude_dir"
}

main "$@"
