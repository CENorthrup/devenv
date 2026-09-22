#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d /tmp/devenv-agent-skills.XXXXXXXX)
trap 'rm -rf -- "$scratch"' EXIT

repo=$scratch/repo
home=$scratch/home
state=$scratch/state
test_root=$scratch/test-state
mkdir -p "$repo/skills" "$home/.agents/skills/user-skill" "$home/.claude/skills/user-skill"
cp -R "$root/tests/fixtures/skills/example" "$repo/skills/example"
printf 'user\n' > "$home/.agents/skills/user-skill/SKILL.md"
printf 'user\n' > "$home/.claude/skills/user-skill/SKILL.md"
git -C "$repo" init -q -b master
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name 'Agent Skills Test'
git -C "$repo" add skills
git -C "$repo" commit -qm initial

run_lifecycle() {
  HOME="$home" \
  DEVENV_SKILLS_REPOSITORY="$repo" \
  DEVENV_SKILLS_STATE_DIR="$state" \
  DEVENV_SKILLS_TEST_ROOT="$test_root" \
  DEVENV_SKILLS_APPROVED_REF=master \
  bash "$root/scripts/deploy-agent-skills.sh" "$@"
}

run_lifecycle deploy
cmp "$repo/skills/example/SKILL.md" "$home/.agents/skills/example/SKILL.md"
cmp "$repo/skills/example/SKILL.md" "$home/.claude/skills/example/SKILL.md"
run_lifecycle check
test "$(<"$home/.agents/skills/user-skill/SKILL.md")" = user

before=$(stat -c '%Y:%s' "$state/codex.manifest")
run_lifecycle deploy
after=$(stat -c '%Y:%s' "$state/codex.manifest")
test "$before" = "$after"

printf 'modified\n' >> "$home/.agents/skills/example/SKILL.md"
if run_lifecycle check; then exit 1; fi
run_lifecycle deploy
rm "$home/.agents/skills/example/SKILL.md"
if run_lifecycle check; then exit 1; fi
run_lifecycle deploy

# The normal path remains on approved master while the checked-out branch is changed and dirty.
git -C "$repo" switch -qc feature
printf 'feature\n' >> "$repo/skills/example/SKILL.md"
run_lifecycle deploy
grep -qxF 'This file exists only for deployment tests.' "$home/.agents/skills/example/SKILL.md"

# The explicit test path receives the working-tree version and cannot touch normal state.
run_lifecycle test-deploy
grep -qxF feature "$test_root/codex/skills/example/SKILL.md"
grep -qxF 'This file exists only for deployment tests.' "$home/.agents/skills/example/SKILL.md"
run_lifecycle test-clean
test ! -e "$test_root"

# Removing a canonical skill from the approved revision removes only its managed copies.
git -C "$repo" switch -q master --discard-changes
rm -rf -- "$repo/skills/example"
git -C "$repo" add -u skills
git -C "$repo" commit -qm 'remove fixture skill'
run_lifecycle deploy
test ! -e "$home/.agents/skills/example"
test ! -e "$home/.claude/skills/example"
test "$(<"$home/.agents/skills/user-skill/SKILL.md")" = user

printf 'Agent skills lifecycle tests passed.\n'
