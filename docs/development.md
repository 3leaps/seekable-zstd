# Development Guide

This guide covers development setup, workflow, and tooling for seekable-zstd.

## Prerequisites

### Required Tools

| Tool    | Version | Purpose             |
| ------- | ------- | ------------------- |
| Rust    | 1.88+   | Core library        |
| Go      | 1.21+   | Go bindings         |
| Python  | 3.10+   | Python bindings     |
| Node.js | 18+     | TypeScript bindings |
| Make    | Any     | Build orchestration |

### Optional Tools

| Tool            | Purpose                       | Installation                    |
| --------------- | ----------------------------- | ------------------------------- |
| goneat          | Hooks, formatting, assessment | See below                       |
| ripgrep         | Fast code search              | `brew install ripgrep`          |
| cbindgen        | C header generation           | `cargo install cbindgen`        |
| uv              | Python package management     | See below                       |
| cargo-tarpaulin | Rust coverage                 | `cargo install cargo-tarpaulin` |

### Python Development with uv

We use [uv](https://docs.astral.sh/uv/) as the standard Python package manager for this project. Other package managers (pip, poetry, etc.) will also work, but uv is recommended for consistency.

**Install uv:**

```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or via Homebrew
brew install uv
```

**Python binding development:**

```bash
cd crates/seekable-zstd-py

# Sync dev dependencies and build
uv sync --group dev

# Run tests
uv run pytest tests/

# Run linting
uv run ruff check .
uv run mypy python/
```

### Installing goneat

**macOS (Homebrew):**

```bash
brew tap fulmenhq/tap
brew install goneat
```

**Windows (Scoop):** _(coming soon)_

```powershell
scoop bucket add fulmenhq https://github.com/fulmenhq/scoop-bucket
scoop install goneat
```

**From source:**

```bash
go install github.com/fulmenhq/goneat@latest
```

**Note:** In this repo, `make bootstrap` uses `sfetch` as the trust anchor to install `goneat`.

## First-Time Setup

```bash
# Clone repository
git clone https://github.com/3leaps/seekable-zstd
cd seekable-zstd

# Bootstrap (installs trusted tooling and hooks)
make bootstrap
```

Bootstrap prerequisites (developer machine):

- `curl`
- `bash`
- `minisign` (required for validating signed releases via the sfetch trust anchor)

The bootstrap target:

1. Installs `sfetch` (trust anchor) if missing
2. Runs `sfetch --self-verify`
3. Installs pinned `goneat`
4. Installs language toolchains + foundation tools via `goneat doctor tools`
5. Installs git hooks (skipped in CI)

---

## Makefile Reference

The Makefile orchestrates all development tasks, ensuring correct ordering across languages.

### Build Targets

```bash
make build              # Build everything
make build-rust         # Build Rust crates only
make build-go           # Build Go bindings (requires Rust FFI)
make build-python       # Build Python wheel
make build-nodejs       # Build npm package
```

### Quality Targets

```bash
make quality            # Run all quality checks
make format             # Auto-format all code
make lint               # Run all linters
make lint-rust          # Rust: clippy
make lint-python        # Python: ruff
make lint-typescript    # TypeScript: biome
```

### Test Targets

```bash
make test               # Run all tests
make test-rust          # Rust tests only
make test-go            # Go tests only
make test-python        # Python tests only
make test-nodejs        # TypeScript tests only
make test-parallel      # Parallel correctness + speedup tests
```

### Fixture Targets

```bash
make fixtures           # Generate test fixtures
make fixtures-validate  # Verify fixture checksums
```

### Version Targets

```bash
make version            # Show current version
make version-check      # Verify all packages match
make bump-patch         # 0.1.0 -> 0.1.1
make bump-minor         # 0.1.0 -> 0.2.0
make bump-major         # 0.1.0 -> 1.0.0
```

### Hook Targets

```bash
make hooks-install      # Install git hooks
make hooks-remove       # Remove git hooks
make hooks-validate     # Check hook configuration
```

---

## Git Hooks

Git hooks enforce quality gates before commits and pushes.

### Hook Options

#### Option 1: goneat (Recommended)

[goneat](https://github.com/fulmenhq/goneat) provides comprehensive hook management with built-in support for multiple languages:

```bash
# Initialize hooks
goneat hooks init

# Install hooks
goneat hooks install

# Configure pre-commit behavior
goneat hooks configure --pre-commit="format,lint,test"
```

Configuration in `.goneat/hooks.yaml`:

```yaml
version: "1.0"

hooks:
  pre-commit:
    enabled: true
    categories:
      - format
      - lint
    fail_on:
      - error
    languages:
      rust:
        format: rustfmt
        lint: clippy
      python:
        format: ruff format
        lint: ruff check
      typescript:
        format: biome format
        lint: biome lint

  pre-push:
    enabled: true
    categories:
      - test
    require_approval: true
```

#### Option 2: pre-commit (Community Standard)

For those preferring the widely-used Python-based [pre-commit](https://pre-commit.com/):

```bash
pip install pre-commit
pre-commit install
```

Configuration in `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml

  - repo: https://github.com/doublify/pre-commit-rust
    rev: v1.0
    hooks:
      - id: fmt
      - id: clippy

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.6
    hooks:
      - id: ruff
      - id: ruff-format

  - repo: https://github.com/biomejs/pre-commit
    rev: v0.1.0
    hooks:
      - id: biome-check
```

### Pre-Commit Hook Behavior

The pre-commit hook runs before each commit:

1. **Format check**: Verifies code is formatted (rustfmt, ruff, biome)
2. **Lint**: Runs linters (clippy, ruff check, biome lint)
3. **Quick tests**: Runs fast unit tests for modified code

If any check fails, the commit is blocked. Fix issues and retry.

### Pre-Push Hook Behavior

The pre-push hook runs before pushing:

1. **Full test suite**: All tests must pass
2. **Cross-language verification**: Ensures bindings produce identical results
3. **Version consistency**: Verifies all packages have matching versions

**Note**: Push operations typically require human approval. The hook enforces quality gates but does not authorize the push itself.

### Bypassing Hooks (Emergency Only)

In rare cases where hooks must be bypassed:

```bash
# Bypass pre-commit (requires documented reason)
git commit --no-verify -m "emergency: <reason>"

# Bypass pre-push (requires explicit authorization)
git push --no-verify
```

**Warning**: Bypassing hooks requires explicit human maintainer authorization and documented justification. This should be extremely rare.

---

## Semantic Versioning

This project strictly follows [Semantic Versioning 2.0.0](https://semver.org/).

### Version Format

```
MAJOR.MINOR.PATCH
```

- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Version Synchronization

All packages must have identical versions:

| Package        | Location                                 |
| -------------- | ---------------------------------------- |
| Rust workspace | `Cargo.toml` (workspace)                 |
| Rust core      | `crates/seekable-zstd-core/Cargo.toml`   |
| Rust Python    | `crates/seekable-zstd-py/Cargo.toml`     |
| Python         | `crates/seekable-zstd-py/pyproject.toml` |
| TypeScript     | `bindings/nodejs/package.json`           |
| Go             | Git tags (`v0.1.0`)                      |

### Bumping Versions

Always use Makefile targets to bump versions:

```bash
# Patch release (bug fix)
make bump-patch

# Minor release (new feature)
make bump-minor

# Major release (breaking change)
make bump-major
```

These targets:

1. Update all version files atomically
2. Verify consistency
3. Create a version commit (but do not push)

---

## Workflow

### Feature Development

1. Create feature branch (requires approval)
2. Implement changes
3. Ensure `make quality` passes
4. Ensure `make test` passes
5. Commit with proper attribution
6. Request review/audit if required
7. Request push authorization

### Bug Fix

1. Reproduce issue with test
2. Implement fix
3. Verify test passes
4. Run full `make test`
5. Commit with attribution
6. Request push authorization

### Release

See `RELEASE_CHECKLIST.md` for the step-by-step SSOT and `docs/cicd.md` for the rationale behind CI-built artifacts.

High-level flow:

1. Ensure CI is green on `main`
2. Prepare prebuilt Go libs (release prep): run `.github/workflows/artifacts.yml` via `workflow_dispatch` with `commit_to_main=true`
3. Validate Go prebuilt linking (glibc + musl): run `.github/workflows/go-prebuilt-libs.yml` via `workflow_dispatch`
4. Bump version: `make bump-patch|minor|major`
5. Update `CHANGELOG.md`
6. Create release commit, push, then tag `vX.Y.Z` on the commit that includes updated `bindings/go/lib/**`
7. Publishing to registries is planned for v0.2.x (v0.1.x focuses on tags + CI-built artifacts for early Go users)

---

## Troubleshooting

### Hook Installation Fails

```bash
# Verify goneat is installed
which goneat

# Or install pre-commit
pip install pre-commit
pre-commit install
```

### Version Mismatch

```bash
# Check all versions
make version-check

# If mismatch, reset to correct version
make set-version VERSION=0.1.0
```

### Build Fails for Go Bindings

Go bindings require the Rust FFI library to be built first:

```bash
make build-rust    # Must complete first
make build-go      # Now this will work
```

### Tests Fail in CI but Pass Locally

Ensure you're running the full test suite:

```bash
make test          # Full suite, not just cargo test
```

### CI Rust Toolchain Drift (Runbook)

CI intentionally tests both `stable` and an explicit “minimum supported” Rust toolchain. This is useful, but it can churn when upstream dependencies raise their MSRV (minimum supported Rust version).

Common examples:

- Some crates adopt `edition = "2024"` (requires newer Cargo/Rust than `2021`).
- `bindings/nodejs` depends on `napi-build`, which can raise MSRV independently.

When updating CI’s pinned Rust toolchain, validate the assumption locally before pushing:

```bash
# Preflight the same crates CI will compile.
# Uses an isolated temp target dir, so it doesn't pollute `target/`.
# Runs `cargo check` + `cargo clippy -- -D warnings`.
make ci-preflight TOOLCHAIN=1.88.0
```

If it fails, use the error message to decide whether to:

- bump the pinned toolchain in CI, or
- pin a dependency version (rare; prefer bumping toolchain unless policy requires otherwise).

---

## Test Infrastructure

### Test Runners by Language

| Language   | Runner       | Coverage          | Benchmarks       |
| ---------- | ------------ | ----------------- | ---------------- |
| Rust       | `cargo test` | cargo-tarpaulin   | criterion        |
| Go         | `go test`    | `go test -cover`  | `go test -bench` |
| Python     | pytest       | pytest-cov        | pytest-benchmark |
| TypeScript | vitest       | vitest --coverage | vitest bench     |

### Coverage Tools

```bash
# Rust coverage (requires cargo-tarpaulin)
cargo install cargo-tarpaulin
cargo tarpaulin --out Html

# Go coverage
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Python coverage
pip install pytest-cov
pytest --cov=seekable_zstd --cov-report=html

# TypeScript coverage
npm run test -- --coverage
```

### CI/CD (GitHub Actions)

The repository uses GitHub Actions for CI. Key workflows:

**`.github/workflows/ci.yml`**

- Runs on pushes to `main` and on PRs
- Uses a `tools` job (per OS) to install trusted tooling once and distribute to the test matrix via artifacts
- Test matrix: `ubuntu-latest`, `macos-latest` × Rust `stable` and `1.88`

**`.github/workflows/artifacts.yml`**

- Runs on pushes to `main` and tags `v*` to build/upload prebuilt static libraries
- Supports release prep via `workflow_dispatch` with `commit_to_main=true`, which commits updated `bindings/go/lib/**` to `main` so tags include the correct Go prebuilt libs

**`.github/workflows/go-prebuilt-libs.yml`**

- Manual validation (workflow_dispatch) to prove Linux glibc + musl linking against committed prebuilt libs

### CI Matrix Example

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        rust: [stable, "1.88"]
```

### Fixture Generation

Test fixtures must be generated before running integration tests:

```bash
# Generate all fixtures (idempotent)
make fixtures

# Or manually
./scripts/generate-fixtures.sh tests/fixtures/generated
```

For CI, fixtures are generated as a setup step:

```yaml
- name: Generate fixtures
  run: make fixtures

- name: Run tests
  run: make test
```

### Cross-Platform Considerations

**Go CGO bindings** require pre-built Rust static libraries for each platform:

```bash
# Build for current platform
cargo build --release -p seekable-zstd-core

# Cross-compile (requires cross or zigbuild)
cargo install cross
cross build --release --target x86_64-unknown-linux-gnu
cross build --release --target aarch64-unknown-linux-gnu
cross build --release --target x86_64-apple-darwin
cross build --release --target aarch64-apple-darwin
```

Static libraries are placed in `bindings/go/lib/<os>-<arch>/`.

### Local Test Environment

For consistent local testing across languages:

```bash
# Full test suite (all languages)
make test

# Quick Rust-only iteration
make test-rust

# Test specific binding
make test-go
make test-python
make test-nodejs

# Parallel correctness verification
make test-parallel
```

### Test Isolation

Tests should be isolated and not depend on:

- Network access (mock external services)
- Specific file paths (use temp directories)
- System state (clean up after tests)

```rust
// Rust - use tempfile
use tempfile::TempDir;

#[test]
fn test_roundtrip() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().join("test.szst");
    // ... test using path
}
```

```python
# Python - use pytest tmp_path fixture
def test_roundtrip(tmp_path):
    path = tmp_path / "test.szst"
    # ... test using path
```

---

## Related Documentation

- [README.md](../README.md) - Project overview
- [AGENTS.md](../AGENTS.md) - AI developer guide
- [standards/](standards/README.md) - Coding and testing standards
- [standards/testing.md](standards/testing.md) - Test fixtures and parallel verification
