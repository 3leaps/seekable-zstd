# GitHub Actions Standards

This document defines lightweight conventions for GitHub Actions workflows in this repository (files under `.github/workflows/*.yml`).

The goal is consistent, readable workflows without pulling in heavy ecosystem tooling. When in doubt, keep it simple and prefer repository-native tooling (`make`, `goneat`).

---

## 1. Files and Naming

- Workflows live in `.github/workflows/`.
- Prefer `kebab-case` filenames that describe purpose (e.g., `go-prebuilt-libs.yml`, `artifacts.yml`).
- Prefer explicit, human-readable `name:` values for workflows, jobs, and steps.

---

## 2. YAML Style

- Indentation: 2 spaces.
- Prefer <= 120 characters per line.
- Do not require `---` document markers.
- GitHub Actions requires the `on:` key; our lints treat that as valid.

The repo root `.yamllint` is tuned for GitHub Actions:

- `line-length.max: 120`
- `truthy.check-keys: false` (so `on:` doesn’t warn)

---

## 3. Linting (Local)

Before opening a PR that touches workflows:

- `actionlint .github/workflows/*.yml`
- `yamllint .github/workflows/*.yml`

Tooling is managed via goneat:

- `goneat doctor tools validate`
- `goneat doctor tools --scope foundation --install --yes`

---

## 4. Workflow Structure

Recommended top-level order (not a hard requirement):

1. `name`
2. `on`
3. `permissions` (when needed)
4. `env` (rare)
5. `jobs`

---

## 5. Runners and Environments

- `runs-on: ubuntu-latest` is acceptable for most workflows.
- Pinning to a specific runner image (e.g., `ubuntu-24.04`) is encouraged only when reproducibility requires it.
- If you use containers, keep them minimal and document why (e.g., glibc vs musl validation).

---

## 6. Steps and Shell

- Every non-trivial step should have a `name:`.
- Prefer multi-line scripts (`run: |`) for readability.
- For multi-line bash scripts, prefer:
  - `set -euo pipefail`

- Quote variables and special paths (shellcheck friendliness). Example:
  - `echo "$HOME/.local/bin" >> "$GITHUB_PATH"`

If a script relies on bashisms, set `shell: bash` explicitly.

---

## 7. Actions, Versions, and Dependencies

- Prefer official actions where possible.
- Pin actions to stable major tags where reasonable (e.g., `actions/checkout@v4`).
- Avoid floating branches (e.g., `@main`) for third-party actions.

---

## 8. Permissions and Security

- Set minimum required `permissions:` (workflow/job level).
- Avoid `pull_request_target` unless the workflow is explicitly designed for it and reviewed.
- Never print secrets; avoid `set -x` in steps that may handle credentials.

### Authenticated GitHub API access

- Prefer job-level `env` for `GITHUB_TOKEN` (and `GH_TOKEN`) so any tooling that hits GitHub APIs is authenticated by default. This reduces intermittent `403/429` responses under parallel CI load.

### Retry/backoff for signed artifact fetches

- If a workflow installs a signed artifact from GitHub releases (e.g., via `sfetch` with minisign verification), a short retry loop with backoff is acceptable to handle transient GitHub `403/429` responses.

---

## 9. Repository Consistency

- Prefer `make` targets (`make build`, `make test`, `make quality`) over re-implementing logic in YAML.
- When validating prebuilt artifacts, “fail with evidence” (e.g., `test -f <expected-file>`), not silent skips.
