# Canonical agent skills

This directory documents the generic mechanism for deploying agent skills to
supported agent discovery locations. Factory-specific skill content and
workflow orchestration belong to Claytron9000.
Each immediate child is a portable Agent Skills directory containing `SKILL.md`
and, optionally, `scripts/`, `references/`, or `assets/`.

Use `just apply-skills` to deploy the approved default-branch revision. The
agent discovery directories are generated copies and are not edited directly.
