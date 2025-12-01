# seekable-zstd – AI Developer Guide

## Read First

- **Quality over speed**: This library provides multi-language seekable compression. Correctness and cross-language consistency are paramount. Always verify outputs, run tests across all bindings, and seek human oversight for architectural changes.
- **Confirm your interface**: If your session does not identify an agentic interface (Claude Code, Cursor, Cline, etc.), pause and clarify with the human maintainer before taking action.
- **Attribution required**: All commits from AI developers must follow the [attribution format](#commit-attribution) for traceability.

### Known Interface Adapters

| Interface | Definition File | Notes |
|-----------|-----------------|-------|
| Claude Code | `AGENTS.md` (this file) | Anthropic CLI, primary interface |
| OpenCode | `AGENTS.md` (this file) | Open-source terminal interface |
| Kilo Code | `AGENTS.md` (this file) | VS Code extension |
| Cline | `.cline/rules/` → references this file | VS Code extension |
| Cursor | `AGENTS.md` (this file) | IDE with AI integration |
| Windsurf | `AGENTS.md` (this file) | Codeium IDE |
| Aider | `AGENTS.md` (this file) | Terminal-based pair programming |
| Continue | `AGENTS.md` (this file) | IDE extension |

**Project**: seekable-zstd
**Purpose**: Seekable zstd compression with parallel decompression
**Repository**: https://github.com/3leaps/seekable-zstd
**License**: MIT

---

## Mandatory Reading

Before making changes, read these documents in order:

1. **[BOOTSTRAP.md](BOOTSTRAP.md)** - Project plan, phases, architecture
2. **[docs/standards/README.md](docs/standards/README.md)** - Standards index
3. **[docs/standards/coding/README.md](docs/standards/coding/README.md)** - Cross-language coding standards
4. **[docs/standards/testing.md](docs/standards/testing.md)** - Test fixtures, parallel verification

Language-specific (as needed):
- **[docs/standards/coding/rust.md](docs/standards/coding/rust.md)** - Rust core library
- **[docs/standards/coding/go.md](docs/standards/coding/go.md)** - Go CGO bindings
- **[docs/standards/coding/python.md](docs/standards/coding/python.md)** - Python PyO3 bindings
- **[docs/standards/coding/typescript.md](docs/standards/coding/typescript.md)** - TypeScript napi-rs bindings

---

## Session Startup Protocol

1. **Read mandatory documents** listed above
2. **Check repository state**: `git status`, current branch
3. **Understand the hybrid architecture**: Rust core + multi-language bindings
4. **Review Makefile targets** for available commands
5. **Plan before acting**: Use `.plans/` (gitignored) for session notes

---

## Operational Guidelines

### DO

- **Read before write**: Always read files before editing to understand existing patterns
- **Use Makefile targets**: `make build`, `make test`, `make quality` over raw commands
- **Run quality checks**: `make quality` before any commit - quality gates must pass
- **Test all affected bindings**: Changes to core require testing Go/Python/TypeScript
- **Validate fixtures**: `make fixtures` to regenerate, verify checksums
- **Follow language conventions**: rustfmt, clippy, ruff, biome as appropriate
- **Document APIs**: Update docs when adding public functions
- **Include attribution**: Every commit must follow the attribution format
- **Follow stated process**: If the task requires audit/review, pause and wait for approval before committing
- **Request approval for destructive operations**: Rebase, merge, branch deletion, and similar operations require human maintainer approval

### DO NOT

- **NEVER push without approval**: Push operations are generally reserved for release boundaries. Any push requires explicit per-occurrence approval from a human maintainer.
- **NEVER force push**: No `git push --force` under any circumstances - catastrophic and irreversible
- **NEVER rebase/merge without approval**: Rebase, merge, and history-altering operations require human maintainer approval
- **NEVER delete branches without approval**: Branch deletion requires human maintainer approval
- **NEVER skip quality gates**: All commits must pass `make quality` and `make test` unless explicitly authorized by human maintainer to bypass (rare, documented exceptions only)
- **NEVER commit without process compliance**: If the development task specifies audit/review checkpoints, do not commit until audit is complete and approved
- **NEVER bypass Makefile**: Use orchestrated targets, not raw tool commands
- **NEVER edit without reading**: Understand before modifying
- **NEVER commit build artifacts**: `target/`, `dist/`, `pkg/` are gitignored
- **NEVER commit `.plans/`**: Local planning directory, gitignored
- **NEVER break cross-language consistency**: All bindings must produce identical results
- **NEVER commit autonomously in audit-required contexts**: If human requested audit before commit, wait for explicit approval

---

## Project Architecture

### Hybrid Multi-Language Design

```
┌─────────────────────────────────────────────────────────────┐
│                    seekable-zstd-core (Rust)                │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Encoder │  │ Decoder │  │ Parallel │  │   C FFI       │  │
│  └─────────┘  └─────────┘  └──────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                │                      │
    ┌────┴────┐      ┌────┴────┐           ┌────┴────┐
    │  PyO3   │      │  CGO    │           │ napi-rs │
    │ Python  │      │   Go    │           │  Node   │
    └─────────┘      └─────────┘           └─────────┘
```

### Key Directories

- `crates/seekable-zstd-core/` - Rust library (encoder, decoder, parallel, FFI)
- `crates/seekable-zstd-py/` - Python bindings via PyO3
- `bindings/go/` - Go bindings via CGO
- `bindings/nodejs/` - TypeScript bindings via napi-rs
- `tests/fixtures/` - Shared test fixtures for all languages
- `docs/standards/` - Coding and testing standards

---

## Development Workflow

### Common Tasks

```bash
# Bootstrap (first time)
make bootstrap

# Build
make build              # All crates and bindings
make build-rust         # Rust core only
make build-go           # Go bindings
make build-python       # Python wheel
make build-nodejs       # npm package

# Quality & Testing
make quality            # Format + lint all languages
make test               # Run all tests
make test-rust          # Rust tests only
make test-parallel      # Parallel verification tests

# Fixtures
make fixtures           # Generate/verify test fixtures

# Version management
make bump-patch         # 0.1.0 -> 0.1.1
make bump-minor         # 0.1.0 -> 0.2.0
```

### Pre-Commit Checklist

1. ✅ `make quality` passes
2. ✅ `make test` passes (all languages)
3. ✅ `make test-parallel` shows correctness + speedup
4. ✅ Fixtures verified if modified
5. ✅ Documentation updated if API changed
6. ✅ Clear commit message with attribution
7. ✅ Request push approval (do NOT push autonomously)

---

## Commit Attribution

All AI-assisted commits must include attribution for traceability. This is a simplified format focusing on **model** and **interface** rather than named identities.

### Format

```
<type>: <description>

<detailed explanation>

<changes list>

Generated by <model> via <interface>
Supervised by: <human>

Co-Authored-By: <interface> <model> <noreply@3leaps.net>
```

### Attribution Components

| Component | Description | Examples |
|-----------|-------------|----------|
| **model** | The AI model used | `claude-sonnet-4-20250514`, `claude-opus-4-20250514`, `gpt-4o`, `claude-3.5-sonnet` |
| **interface** | The agentic interface | `Claude Code`, `OpenCode`, `Kilo Code`, `Cline`, `Cursor`, `Aider` |
| **human** | Supervising maintainer | GitHub handle (e.g., `@3leapsdave`) |
| **email** | Co-author email | Always `noreply@3leaps.net` (unified for all providers) |

### Examples

**Claude Code with Claude Sonnet:**

```
feat(core): implement parallel decoder

Add ParallelDecoder struct with rayon-based concurrent
range decompression. Demonstrates 3.2x speedup on 8 cores.

Changes:
- Add ParallelDecoder in parallel.rs
- Implement read_ranges with par_iter
- Add parallel correctness tests
- Add speedup benchmark

Generated by claude-sonnet-4-20250514 via Claude Code
Supervised by: @3leapsdave

Co-Authored-By: Claude Code claude-sonnet-4-20250514 <noreply@3leaps.net>
```

**OpenCode with Claude:**

```
fix(go): correct CGO pointer handling

Fix null pointer check in seekable_open to properly
return error string from C FFI layer.

Changes:
- Add nil check before C.GoString conversion
- Improve error message formatting

Generated by claude-sonnet-4-20250514 via OpenCode
Supervised by: @3leapsdave

Co-Authored-By: OpenCode claude-sonnet-4-20250514 <noreply@3leaps.net>
```

**Kilo Code with Claude:**

```
docs: update Python binding examples

Add context manager usage examples and clarify
read_ranges parallel behavior.

Generated by claude-sonnet-4-20250514 via Kilo Code
Supervised by: @3leapsdave

Co-Authored-By: Kilo Code claude-sonnet-4-20250514 <noreply@3leaps.net>
```

### Why This Format?

1. **Traceability**: Know which model/interface produced code for debugging
2. **Simplicity**: No need for unique agent identities or personas
3. **Neutrality**: Works with any AI provider or interface
4. **Git-friendly**: Standard Co-Authored-By format recognized by GitHub

See [docs/standards/attribution.md](docs/standards/attribution.md) for complete specification.

---

## Git Operation Safety

### Allowed Operations (No Approval Required)

```bash
git status              # ✅ Check state
git add <files>         # ✅ Stage changes
git commit              # ✅ Commit locally (if quality gates pass)
git log                 # ✅ Review history
git diff                # ✅ Review changes
git branch -l           # ✅ List branches
git checkout <branch>   # ✅ Switch branches (existing)
git stash               # ✅ Stash changes
```

### Requires Human Approval (Per-Occurrence)

```bash
git push                # ⚠️ Requires approval - typically at release boundaries
git push origin <branch># ⚠️ Requires approval
git rebase              # ⚠️ Requires approval - history alteration
git merge               # ⚠️ Requires approval - integration decision
git branch -d <branch>  # ⚠️ Requires approval - deletion
git checkout -b <new>   # ⚠️ Requires approval - new branch creation
git reset               # ⚠️ Requires approval - potential data loss
git cherry-pick         # ⚠️ Requires approval - history manipulation
```

### Forbidden Operations (Never Execute)

```bash
git push --force        # ❌ CATASTROPHIC - never use
git push -f             # ❌ CATASTROPHIC - never use
git reset --hard        # ❌ Without approval - data loss risk
git clean -fd           # ❌ Without approval - deletes untracked files
```

### Commit Requirements

Commits are allowed only when:
1. **Quality gates pass**: `make quality` and `make test` succeed
2. **Process compliance**: Any audit/review requirements are satisfied
3. **Attribution included**: Proper commit message format with attribution

If quality gates fail, do NOT commit. Fix the issues first or request explicit human authorization to bypass (rare, documented).

### Push Authorization Process

Push operations are reserved for release boundaries or explicit milestones:

1. Complete all work and local commits
2. Verify `make quality` and `make test` pass
3. Request push approval from human maintainer stating:
   - What is being pushed
   - Why now (release, milestone, etc.)
   - Branch and remote target
4. Wait for explicit written confirmation
5. Push only after documented approval
6. Confirm push succeeded and report back

---

## Testing Requirements

### All Tests Must Pass

- Rust: `cargo test` in all crates
- Go: `go test ./...` in bindings/go
- Python: `pytest` after `maturin develop`
- TypeScript: `npm test` in bindings/nodejs

### Parallel Verification

Tests must demonstrate:
1. **Correctness**: Parallel results match sequential
2. **Speedup**: Measurable improvement (expect 2x+ on 4 cores)
3. **Cross-language**: All bindings produce identical output for same input

### Fixture Validation

- Small fixtures committed in `tests/fixtures/`
- Large fixtures generated via `scripts/generate-fixtures.sh`
- All fixtures have checksums for integrity verification

---

## Design Principles

### Correctness First

- Cross-language consistency is mandatory
- All bindings must produce bit-identical output
- Shared fixtures ensure this

### Performance Matters

- Parallel decompression is a key feature
- Benchmark significant changes
- Target >1GB/s throughput

### API Stability

- Published to crates.io, PyPI, npm
- Breaking changes require major version bump
- Maintain backward compatibility

### Neutral Conventions

- This is a community library, not opinionated
- Follow language idioms (snake_case in Rust/Python, camelCase in TS)
- Minimal dependencies

---

## Getting Help

1. Review mandatory reading list
2. Check existing code patterns
3. Consult human supervisor for architectural questions
4. When uncertain, ask before making significant changes

---

**Last Updated**: 2025-12-01
**Status**: Bootstrap phase

*This guide is for AI developers working on seekable-zstd. For human contributors, see CONTRIBUTING.md (when available).*
