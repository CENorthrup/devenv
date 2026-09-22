# Canonical agent skills

This directory is the single source of truth for factory-owned agent skills.
Each immediate child is a portable Agent Skills directory containing `SKILL.md`
and, optionally, `scripts/`, `references/`, or `assets/`.

Use `just apply-skills` to deploy the approved default-branch revision. The
agent discovery directories are generated copies and are not edited directly.
