# Dev Environment

An opinionated, terminal-first Linux development environment designed for portability and clarity.

This project defines a cohesive developer workstation setup rather than a collection of independent tools. It prioritizes:

- terminal-first workflows
- strong defaults over configurability
- portability across Linux distributions
- clear separation of system, toolchain, and configuration

AI tooling is included as part of the environment, but the workflow is not yet defined. The system is designed to evolve as AI-assisted development patterns become clearer.

---

## Status

This project is in active development.

### Current scope
- Scaffolding (filesystem + environment structure)

### Planned
- System packages
- Toolchain (mise)
- Shell + editor setup
- Desktop applications
- Docker

---

## Usage

### 1. Install chezmoi

```bash
sh -c "$(curl -fsLS get.chezmoi.io)"
```

### 2. Initialize

```bash
chezmoi init --apply <repo-url>
```

---

## Scripts

Scripts are executed via chezmoi using `run_onchange_*`.

### 01 - Scaffolding

Responsible for:

- XDG base directory setup
- core directory structure
- base environment layout

---

## Design Principles

- Scripts are idempotent (safe to run multiple times)
- Scripts do not modify managed config files
- Chezmoi owns all persistent configuration
- Scripts handle installation and side effects only

---

## Notes

This is not a universal bootstrap framework.

This is an opinionated development environment with a specific workflow in mind.
