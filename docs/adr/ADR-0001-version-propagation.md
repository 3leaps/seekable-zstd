# ADR-0001: Version Propagation Strategy

## Status

Accepted

## Date

2025-12-28

## Context

seekable-zstd is a multi-language library with a Rust core and bindings for Go, Python, and TypeScript/Node.js. Each language ecosystem has its own versioning conventions and manifest files:

- **Rust**: `Cargo.toml` (workspace and per-crate)
- **Go**: Git tags (module versioning) + `Version()` function
- **Python**: `pyproject.toml` + `__version__` attribute
- **Node.js**: `package.json`

We need a single source of truth for the version number that propagates consistently to all bindings, ensuring users see the same version regardless of which language they use.

## Decision

### Single Source of Truth

The `VERSION` file at the repository root is the canonical version source. All other version references are derived from it.

### Propagation Mechanism

The `Makefile` provides `bump-patch`, `bump-minor`, and `bump-major` targets that:

1. Update the `VERSION` file
2. Invoke `_set-version` to propagate to all manifest files using `sed`

### Files Updated

| File                                     | Field/Location                        |
| ---------------------------------------- | ------------------------------------- |
| `VERSION`                                | Entire file content                   |
| `crates/seekable-zstd/Cargo.toml`        | `version = "X.Y.Z"`                   |
| `crates/seekable-zstd-core/Cargo.toml`   | `version = "X.Y.Z"`                   |
| `crates/seekable-zstd-py/Cargo.toml`     | `version = "X.Y.Z"`                   |
| `crates/seekable-zstd-py/pyproject.toml` | `version = "X.Y.Z"`                   |
| `bindings/nodejs/Cargo.toml`             | `version = "X.Y.Z"`                   |
| `bindings/nodejs/package.json`           | `"version": "X.Y.Z"` (top-level only) |
| `bindings/go/seekable.go`                | `return "X.Y.Z"` in `Version()`       |

### Runtime Version Access

Each binding exposes the version programmatically:

- **Rust**: `env!("CARGO_PKG_VERSION")` or crate metadata
- **Go**: `seekable.Version()` function
- **Python**: `seekable_zstd.__version__`
- **Node.js**: `require("seekable-zstd/package.json").version`

### Validation

Version consistency can be validated by:

```bash
# Quick check - all should match
cat VERSION
grep '^version = ' crates/*/Cargo.toml bindings/nodejs/Cargo.toml
grep '"version":' bindings/nodejs/package.json | head -1
grep 'return "' bindings/go/seekable.go
```

CI does not currently enforce version consistency, but the `make bump-*` workflow ensures it when followed.

## Consequences

### Positive

- **Single source of truth**: `VERSION` file is authoritative
- **Consistent user experience**: All languages report the same version
- **Simple tooling**: `sed`-based updates require no additional dependencies
- **Git tag alignment**: Go module versioning (via tags) matches library version

### Negative

- **Manual process**: Developers must use `make bump-*` targets; direct edits risk drift
- **sed fragility**: Pattern matching assumes specific file formats; unusual formatting could break updates
- **No automated validation**: Version drift won't be caught until release time

### Mitigations

- Document the `make bump-*` workflow clearly (see `docs/versioning.md`)
- Keep manifest file formats conventional and predictable
- Consider adding a CI job to verify version consistency (future enhancement)

## Alternatives Considered

### 1. Workspace-level Version Inheritance (Rust)

Cargo workspaces support `version.workspace = true`, but this only covers Rust crates, not other language bindings.

### 2. Build-time Version Injection

Generate version constants at build time from `VERSION` file. This adds build complexity and doesn't help with manifest files that package managers read directly.

### 3. Dedicated Version Management Tool

Tools like `changesets` or custom scripts could manage versions. Rejected for now due to added complexity; `sed` is sufficient for our scale.

## References

- [docs/versioning.md](../versioning.md) - User-facing version documentation
- [Semantic Versioning 2.0.0](https://semver.org/)
- [Go Module Versioning](https://go.dev/doc/modules/version-numbers)
