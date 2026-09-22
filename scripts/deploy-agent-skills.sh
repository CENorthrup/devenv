#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
action=${1:-deploy}

case $action in
  deploy|check|test-deploy|test-clean) ;;
  *) printf 'Usage: %s {deploy|check|test-deploy|test-clean}\n' "$0" >&2; exit 2 ;;
esac

state_root=${DEVENV_SKILLS_STATE_DIR:-$HOME/.local/state/devenv-skills}
test_root=${DEVENV_SKILLS_TEST_ROOT:-$HOME/.local/state/devenv-skills-test}
repository=${DEVENV_SKILLS_REPOSITORY:-$root}

declare -a agents=(codex claude)
declare -A destinations=(
  [codex]="${DEVENV_CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
  [claude]="${DEVENV_CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
)

fail() { printf 'agent skills: %s\n' "$*" >&2; exit 1; }
sha256() { sha256sum -- "$1" | awk '{print $1}'; }

validate_skill_name() {
  [[ $1 =~ ^[A-Za-z0-9._-]+$ ]] || fail "unsupported skill directory name: $1"
}

list_source_files() {
  local source=$1 path rel
  local skill
  while IFS= read -r -d '' skill; do
    validate_skill_name "$(basename -- "$skill")"
    [[ -f $skill/SKILL.md ]] || fail "skill is missing SKILL.md: ${skill#"$source"/}"
  done < <(find "$source" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  while IFS= read -r -d '' path; do
    fail "skills must not contain symlinks: ${path#"$source"/}"
  done < <(find "$source" -mindepth 2 -type l -print0 | sort -z)
  while IFS= read -r -d '' path; do
    [[ -f $path && ! -L $path ]] || fail "skills must contain regular files, not symlinks: ${path#"$source"/}"
    rel=${path#"$source"/}
    printf '%s\t%s\n' "$(sha256 "$path")" "$rel"
  done < <(find "$source" -mindepth 2 -type f -print0 | sort -z)
}

prepare_archive_source() {
  local ref=${DEVENV_SKILLS_APPROVED_REF:-}
  if [[ -z $ref ]]; then
    if git -C "$repository" show-ref --verify --quiet refs/remotes/origin/master; then
      ref=origin/master
    elif git -C "$repository" show-ref --verify --quiet refs/heads/master; then
      ref=master
    else
      fail 'could not find approved default branch (expected origin/master or master)'
    fi
  fi
  git -C "$repository" rev-parse --verify "$ref^{commit}" >/dev/null || fail "approved revision not found: $ref"
  approved_commit=$(git -C "$repository" rev-parse "$ref^{commit}")
  snapshot=$(mktemp -d "${TMPDIR:-/tmp}/devenv-skills.XXXXXXXX")
  cleanup_snapshot=1
  trap '[[ ${cleanup_snapshot:-0} == 1 ]] && rm -rf -- "$snapshot"; [[ -n ${source_files:-} ]] && rm -f -- "$source_files"' EXIT
  if git -C "$repository" archive --format=tar "$approved_commit" skills 2>/dev/null | tar -xf - -C "$snapshot" 2>/dev/null; then
    :
  else
    mkdir -p "$snapshot/skills"
  fi
  source_dir=$snapshot/skills
  source_label=$ref
  source_kind=approved
}

prepare_worktree_source() {
  source_dir=$repository/skills
  [[ -d $source_dir ]] || fail "canonical skills directory is missing: $source_dir"
  approved_commit=$(git -C "$repository" rev-parse HEAD)
  source_label=working-tree
  source_kind=test
}

manifest_path() { printf '%s/%s.manifest\n' "$1" "$2"; }

old_files=()
old_skills=()
read_old_manifest() {
  local manifest=$1 line kind value
  old_files=()
  old_skills=()
  [[ -f $manifest ]] || return 0
  while IFS= read -r line; do
    if [[ $line == file$'\t'* ]]; then
      IFS=$'\t' read -r kind value _ <<< "$line"
      old_files+=("$value")
    elif [[ $line == skill$'\t'* ]]; then
      old_skills+=("${line#*$'\t'}")
    fi
  done < "$manifest"
}

remove_obsolete_managed_files() {
  local destination=$1 manifest=$2 rel path skill
  read_old_manifest "$manifest"
  for skill in "${managed_skills[@]}"; do
    path=$destination/$skill
    [[ ! -L $path ]] || fail "managed skill directory is a symlink: $path"
    [[ -d $path ]] || continue
    while IFS= read -r -d '' path; do
      rel=${path#"$destination"/}
      [[ -n ${desired[$rel]+present} ]] || rm -f -- "$path"
    done < <(find "$destination/$skill" \( -type f -o -type l \) -print0)
    find "$destination/$skill" -depth -type d -empty -delete
  done
}

deploy_agent() {
  local agent=$1 destination=${destinations[$1]} manifest_root=$2
  local manifest old_manifest hash rel target temp
  manifest=$(manifest_path "$manifest_root" "$agent")
  old_manifest=$manifest
  [[ ! -L $destination ]] || fail "managed destination is a symlink: $destination"
  mkdir -p "$destination" "$manifest_root"

  declare -A desired=()
  declare -A skill_names=()
  declare -a managed_skills=()
  read_old_manifest "$old_manifest"
  for rel in "${old_skills[@]}"; do skill_names["$rel"]=1; done
  for rel in "${old_files[@]}"; do skill_names["${rel%%/*}"]=1; done
  while IFS= read -r -d '' target; do
    skill_names["$(basename -- "$target")"]=1
  done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d -print0)
  for rel in "${!skill_names[@]}"; do managed_skills+=("$rel"); done
  while IFS=$'\t' read -r hash rel; do
    [[ -n $rel ]] || continue
    desired["$rel"]=$hash
  done < "$source_files"
  remove_obsolete_managed_files "$destination" "$old_manifest"
  while IFS=$'\t' read -r hash rel; do
    [[ -n $rel ]] || continue
    target=$destination/$rel
    [[ ! -L $target ]] || fail "refusing to replace symlink: $target"
    if [[ ! -f $target ]] || [[ $(sha256 "$target") != "$hash" ]]; then
      mkdir -p "$(dirname -- "$target")"
      temp=$(mktemp "$destination/.devenv-skill.XXXXXXXX")
      cp -- "$source_dir/$rel" "$temp"
      chmod --reference="$source_dir/$rel" "$temp" 2>/dev/null || true
      mv -f -- "$temp" "$target"
    fi
  done < "$source_files"

  local tmp_manifest
  tmp_manifest=$(mktemp "$manifest_root/.manifest.XXXXXXXX")
  {
    printf 'version\t1\nrepository\t%s\ncommit\t%s\nsource\t%s\nkind\t%s\nagent\t%s\n' "$repository" "$approved_commit" "$source_label" "$source_kind" "$agent"
    for rel in "${!skill_names[@]}"; do printf 'skill\t%s\n' "$rel"; done | sort
  } > "$tmp_manifest"
  while IFS=$'\t' read -r hash rel; do
    [[ -n $rel ]] || continue
    printf 'file\t%s\t%s\n' "$rel" "$hash" >> "$tmp_manifest"
  done < "$source_files"

  if [[ -f $manifest ]] && cmp -s <(sed '/^deployed_at\t/d' "$manifest") "$tmp_manifest"; then
    rm -f -- "$tmp_manifest"
  else
    { printf 'deployed_at\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; cat "$tmp_manifest"; } > "$tmp_manifest.with-time"
    mv -f -- "$tmp_manifest.with-time" "$manifest"
    rm -f -- "$tmp_manifest"
  fi
  if [[ $source_kind == approved ]]; then
    printf '%s: deployed approved revision %s (%s files) to %s\n' "$agent" "$approved_commit" "${#desired[@]}" "$destination"
  else
    printf '%s: deployed TEST working-tree revision %s (%s files) to %s\n' "$agent" "$approved_commit" "${#desired[@]}" "$destination"
  fi
}

check_agent() {
  local agent=$1 destination=${destinations[$1]} manifest_root=$2
  local manifest=$manifest_root/$agent.manifest
  local expected_hash rel hash line actual missing=0 unexpected=0
  declare -A source_hashes=()
  declare -A manifest_hashes=()
  [[ -f $manifest ]] || { printf '%s: missing provenance manifest\n' "$agent"; return 1; }
  [[ $(awk -F '\t' '$1 == "repository" {print $2; exit}' "$manifest") == "$repository" ]] || {
    printf '%s: incorrect provenance (manifest repository differs)\n' "$agent"; missing=1;
  }
  [[ $(awk -F '\t' '$1 == "commit" {print $2; exit}' "$manifest") == "$approved_commit" ]] || {
    printf '%s: incorrect provenance (manifest commit differs from approved %s)\n' "$agent" "$approved_commit"; missing=1;
  }
  while IFS=$'\t' read -r hash rel; do
    [[ -n $rel ]] || continue
    source_hashes["$rel"]=$hash
  done < <(list_source_files "$source_dir")
  while IFS=$'\t' read -r kind rel expected_hash; do
    [[ $kind == file ]] || continue
    manifest_hashes["$rel"]=$expected_hash
    if [[ -z ${source_hashes[$rel]+present} ]]; then
      printf '%s: manifest contains stale source path %s\n' "$agent" "$rel"; unexpected=1
    elif [[ ${source_hashes[$rel]} != "$expected_hash" ]]; then
      printf '%s: manifest hash differs from approved source for %s\n' "$agent" "$rel"; missing=1
    fi
    if [[ ! -f $destination/$rel ]]; then
      printf '%s: missing %s\n' "$agent" "$rel"; missing=1; continue
    fi
    actual=$(sha256 "$destination/$rel")
    [[ $actual == "$expected_hash" ]] || { printf '%s: modified %s\n' "$agent" "$rel"; missing=1; }
  done < "$manifest"
  for rel in "${!source_hashes[@]}"; do
    if [[ -z ${manifest_hashes[$rel]+present} ]]; then
      printf '%s: manifest is missing source path %s\n' "$agent" "$rel"; missing=1
    fi
  done
  local skill
  while IFS=$'\t' read -r kind skill; do
    [[ $kind == skill ]] || continue
    while IFS= read -r -d '' line; do
      rel=${line#"$destination"/}
      if ! awk -F '\t' -v p="$rel" '$1 == "file" && $2 == p {found=1} END {exit !found}' "$manifest"; then
        printf '%s: unexpected file in managed skill %s\n' "$agent" "$rel"; unexpected=1
      fi
    done < <([[ -d $destination/$skill ]] && find "$destination/$skill" -type f -print0 || true)
  done < "$manifest"
  (( missing == 0 && unexpected == 0 ))
}

if [[ $action == test-clean ]]; then
  [[ -f $test_root/.devenv-skills-test ]] || fail "test root was not created by test-deploy: $test_root"
  rm -rf -- "$test_root"
  printf 'Removed isolated test skills state: %s\n' "$test_root"
  exit 0
fi

if [[ $action == test-deploy ]]; then
  prepare_worktree_source
  source_files=$(mktemp "${TMPDIR:-/tmp}/devenv-skills-files.XXXXXXXX")
  list_source_files "$source_dir" > "$source_files"
  trap 'rm -f -- "$source_files"' EXIT
  declare -A destinations=(
    [codex]="$test_root/codex/skills"
    [claude]="$test_root/claude/skills"
  )
  state_root=$test_root/state
  mkdir -p "$state_root"
  : > "$test_root/.devenv-skills-test"
  for agent in "${agents[@]}"; do deploy_agent "$agent" "$state_root"; done
  printf 'Test deployment is isolated under %s; invoke the agent with its test home/config explicitly.\n' "$test_root"
  exit 0
fi

prepare_archive_source
source_files=$(mktemp "${TMPDIR:-/tmp}/devenv-skills-files.XXXXXXXX")
list_source_files "$source_dir" > "$source_files"
if [[ $action == deploy ]]; then
  mkdir -p "$state_root"
  for agent in "${agents[@]}"; do deploy_agent "$agent" "$state_root"; done
else
  status=0
  for agent in "${agents[@]}"; do check_agent "$agent" "$state_root" || status=1; done
  (( status == 0 )) && printf 'Agent skills: no drift from approved commit %s.\n' "$approved_commit"
  exit "$status"
fi
