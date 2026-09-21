#!/usr/bin/env bash
# Exercise failure detection without touching the user's tools or credentials.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/bin"
export DEVENV_TEST_INSTALLS="$scratch/installs"
export DISABLE_AUTOUPDATER=1 DISABLE_UPDATES=1
export PATH="$scratch/bin:/usr/bin:/bin"
cat > "$scratch/bin/mise" <<'MISE'
#!/usr/bin/env bash
[[ $1 == where ]] || exit 1
printf '%s/%s\n' "$DEVENV_TEST_INSTALLS" "${2##*/}"
MISE
chmod +x "$scratch/bin/mise"

declare -A executables
while read -r tool version; do
  case $tool in
    codex) location="$DEVENV_TEST_INSTALLS/codex@$version/bin/codex"; output="codex-cli $version" ;;
    claude) location="$DEVENV_TEST_INSTALLS/claude-code@$version/claude"; output="$version (Claude Code)" ;;
    gh) location="$DEVENV_TEST_INSTALLS/gh@$version/gh_${version}_linux_amd64/bin/gh"; output="gh version $version (test)" ;;
  esac
  mkdir -p "$(dirname "$location")"
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$output" > "$location"
  chmod +x "$location"
  executables[$tool]=$location
  export PATH="$(dirname "$location"):$PATH"
done < <(awk -F '"' '
  $2 == "aqua:openai/codex" {print "codex", $4}
  $2 == "aqua:anthropics/claude-code" {print "claude", $4}
  $1 == "gh = " {print "gh", $2}
' "$root/mise/config.thin.toml")

check() { bash "$root/scripts/check-thin-tools.sh" installed; }
reject() {
  if check > "$scratch/result" 2>&1; then
    printf 'FAIL: accepted %s\n' "$1" >&2; exit 1
  fi
  grep -q "$2" "$scratch/result"
  printf 'PASS: rejects %s\n' "$1"
}
check
for tool in codex claude gh; do
  file=${executables[$tool]}
  cp "$file" "$scratch/saved"
  printf '#!/bin/sh\necho wrong-version\n' > "$file"
  reject "$tool version drift" 'version drift'
  cp "$scratch/saved" "$file"
  mv "$file" "$file.absent"
  reject "missing executable $tool" 'missing from PATH'
  mv "$file.absent" "$file"
  # A foreign executable must be rejected before it can run.
  printf '#!/bin/sh\ntouch "%s"\n' "$scratch/foreign-executed" > "$scratch/bin/$tool"
  chmod +x "$scratch/bin/$tool"
  saved_path=$PATH
  export PATH="$scratch/bin:$PATH"
  reject "$tool PATH shadowing" 'path drift'
  [[ ! -e $scratch/foreign-executed ]]
  export PATH=$saved_path
  rm "$scratch/bin/$tool"
done
unset DISABLE_UPDATES
reject 'missing update control' 'update controls'

# Standalone installs are a second owner of the same executables. Each known
# leftover, including a dangling launcher symlink, must be reported.
standalone() { HOME="$scratch/home" bash "$root/scripts/check-thin-tools.sh" standalone; }
mkdir -p "$scratch/home"
standalone
printf 'PASS: accepts a home with no standalone installs\n'
leftovers=(.local/bin/claude .local/bin/codex .local/share/claude .claude/local .codex/packages/standalone)
for leftover in "${leftovers[@]}"; do
  mkdir -p "$scratch/home/$(dirname "$leftover")"
  mkdir "$scratch/home/$leftover"
  if standalone > "$scratch/result" 2>&1; then
    printf 'FAIL: accepted standalone %s\n' "$leftover" >&2; exit 1
  fi
  grep -q "Standalone install found: $scratch/home/$leftover" "$scratch/result"
  rmdir "$scratch/home/$leftover"
  printf 'PASS: rejects standalone ~/%s\n' "$leftover"
done
ln -s "$scratch/gone" "$scratch/home/.local/bin/codex"
if standalone > "$scratch/result" 2>&1; then
  printf 'FAIL: accepted a dangling standalone launcher\n' >&2; exit 1
fi
grep -q 'Standalone install found' "$scratch/result"
printf 'PASS: rejects a dangling standalone launcher\n'
printf 'PASS: thin tool verification failure cases\n'
