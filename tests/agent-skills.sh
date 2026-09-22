#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d /tmp/devenv-agent-skills.XXXXXXXX)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/tmp"

repo=$scratch/repo
home=$scratch/home
state=$scratch/state
test_root=$scratch/test-state
mkdir -p "$repo/skills" "$home/.agents/skills/user-skill" "$home/.claude/skills/user-skill"
cp -R "$root/tests/fixtures/skills/example" "$repo/skills/example"
mkdir -p "$repo/skills/example/references"
printf 'reference\n' > "$repo/skills/example/references/note file.md"
printf 'user\n' > "$home/.agents/skills/user-skill/SKILL.md"
printf 'user\n' > "$home/.claude/skills/user-skill/SKILL.md"
git -C "$repo" init -q -b master
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name 'Agent Skills Test'
git -C "$repo" add skills
git -C "$repo" commit -qm initial

run_lifecycle() {
  HOME="$home" \
  TMPDIR="$scratch/tmp" \
  DEVENV_SKILLS_REPOSITORY="$repo" \
  DEVENV_SKILLS_STATE_DIR="$state" \
  DEVENV_SKILLS_TEST_ROOT="$test_root" \
  DEVENV_SKILLS_APPROVED_REF=master \
  bash "$root/scripts/deploy-agent-skills.sh" "$@"
}

run_lifecycle_at() {
  HOME="$1" \
  TMPDIR="$scratch/tmp" \
  DEVENV_SKILLS_REPOSITORY="$repo" \
  DEVENV_SKILLS_STATE_DIR="$2" \
  DEVENV_SKILLS_TEST_ROOT="$3" \
  DEVENV_SKILLS_APPROVED_REF=master \
  bash "$root/scripts/deploy-agent-skills.sh" "${@:4}"
}

run_lifecycle deploy
cmp "$repo/skills/example/SKILL.md" "$home/.agents/skills/example/SKILL.md"
cmp "$repo/skills/example/SKILL.md" "$home/.claude/skills/example/SKILL.md"
run_lifecycle check
test "$(<"$home/.agents/skills/user-skill/SKILL.md")" = user

before=$(stat -c '%Y:%s' "$state/codex.manifest")
find "$home/.claude/skills" -type f -printf '%p %i %T@\n' | sort > "$scratch/before-files"
run_lifecycle deploy
after=$(stat -c '%Y:%s' "$state/codex.manifest")
test "$before" = "$after"
find "$home/.claude/skills" -type f -printf '%p %i %T@\n' | sort > "$scratch/after-files"
cmp "$scratch/before-files" "$scratch/after-files"

mkdir -p "$home/.agents/skills/example/references/stray/deep"
printf 'stray\n' > "$home/.agents/skills/example/references/stray/deep/file.md"
if run_lifecycle check; then exit 1; fi
run_lifecycle deploy
test ! -e "$home/.agents/skills/example/references/stray"

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

# Symlinks in canonical skills are rejected instead of being silently skipped.
ln -s SKILL.md "$repo/skills/example/unsupported-link"
if run_lifecycle test-deploy; then exit 1; fi
rm "$repo/skills/example/unsupported-link"
test -z "$(find "$scratch/tmp" -name 'devenv-skills-files.*' -print -quit)"

# A first deployment must not claim a same-named user directory silently.
collision_home=$scratch/collision-home
collision_state=$scratch/collision-state
collision_test_root=$scratch/collision-test
mkdir -p "$collision_home/.agents/skills/example" "$collision_home/.claude/skills/example"
printf 'user notes\n' > "$collision_home/.agents/skills/example/my-notes.md"
printf 'user notes\n' > "$collision_home/.claude/skills/example/my-notes.md"
if run_lifecycle_at "$collision_home" "$collision_state" "$collision_test_root" deploy; then exit 1; fi
test -f "$collision_home/.agents/skills/example/my-notes.md"
test -f "$collision_home/.claude/skills/example/my-notes.md"

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
