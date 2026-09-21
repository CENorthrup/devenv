#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
action=${1:-check}
case $action in
  installed|session|standalone|check|doctor) ;;
  *) printf 'Usage: %s {installed|session|standalone|check|doctor}\n' "$0" >&2; exit 1 ;;
esac

# Read the exact pins from their existing owner, not a second version table.
pin() {
  awk -F '"' -v key="$1" '$1 == key " = " {print $2} $2 == key && $3 == " = " {print $4}' \
    "$root/mise/config.thin.toml"
}

verify_tools() {
  local tool backend version location expected actual output observed
  for tool in codex claude gh; do
    case $tool in
      codex) backend=aqua:openai/codex ;;
      claude) backend=aqua:anthropics/claude-code ;;
      gh) backend=gh ;;
    esac
    version=$(pin "$backend")
    [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid pin for %s\n' "$tool" >&2; return 1; }
    location=$(mise where "$backend@$version") || return 1
    case $tool in
      codex) expected="$location/bin/codex" ;;
      claude) expected="$location/claude" ;;
      gh) expected="$location/gh_${version}_linux_amd64/bin/gh" ;;
    esac
    actual=$(command -v "$tool") || { printf '%s is missing from PATH\n' "$tool" >&2; return 1; }
    [[ $actual == "$expected" && -x $expected ]] || {
      printf '%s path drift: expected %s; found %s\n' "$tool" "$expected" "$actual" >&2
      return 1
    }
    output=$("$expected" --version) || return 1
    case $tool in
      codex) observed=$(awk 'NR == 1 {print $2}' <<< "$output") ;;
      claude) observed=$(awk 'NR == 1 {print $1}' <<< "$output") ;;
      gh) observed=$(awk 'NR == 1 {print $3}' <<< "$output") ;;
    esac
    [[ $observed == "$version" ]] || {
      printf '%s version drift: expected %s; found %s\n' "$tool" "$version" "$observed" >&2
      return 1
    }
    printf '%s %s: %s\n' "$tool" "$version" "$actual"
  done
  [[ ${DISABLE_AUTOUPDATER:-} == 1 && ${DISABLE_UPDATES:-} == 1 ]] || {
    printf 'Claude update controls are missing from the thin mise environment.\n' >&2
    return 1
  }
}

# Codex and Claude also ship self-updating standalone installers. Mise owns
# both here, so a leftover is a second owner of the same executable: it serves
# shells without mise activation and can move past the recorded pin.
standalone_leftovers() {
  local path found=0
  for path in "$HOME/.local/bin/claude" "$HOME/.local/bin/codex" \
    "$HOME/.local/share/claude" "$HOME/.claude/local" "$HOME/.codex/packages/standalone"; do
    if [[ -e $path || -L $path ]]; then
      printf 'Standalone install found: %s\n' "$path" >&2
      found=1
    fi
  done
  ((found == 0)) || {
    printf 'Remove standalone Codex/Claude installs; see the migration note in wsl/README.md.\n' >&2
    return 1
  }
}

if [[ $action == installed || $action == session ]]; then
  verify_tools
  exit
fi

if [[ $action == standalone ]]; then
  standalone_leftovers
  exit
fi

# Start in HOME with no inherited mise PATH or update flags. This must work
# through the deployed login shell configuration, outside the devenv checkout.
fresh_shell() {
  (cd "$HOME" && env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" \
    TERM=dumb PATH=/usr/bin:/bin /usr/bin/zsh -lic \
    'bash "$1/scripts/check-thin-tools.sh" session' -- "$root")
}

status=0
if [[ $action == doctor ]]; then
  if fresh_shell; then
    printf 'Thin agent/GitHub tools: versions, paths and fresh login PATH match.\n'
  else
    printf 'Thin agent/GitHub tools: drift or incomplete fresh-shell setup.\n'
  fi
  if standalone_leftovers; then
    printf 'Standalone Codex/Claude installs: none found.\n'
  fi
else
  # Report both problems rather than stopping at the first.
  fresh_shell || status=1
  standalone_leftovers || status=1
fi
exit "$status"
