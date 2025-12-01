# seekable-zstd Bootstrap Guide

**Repository**: `3leaps/seekable-zstd`
**Purpose**: Seekable zstd compression with parallel decompression
**License**: MIT

---

## Overview

This library provides seekable zstd compression - a format that enables random access into compressed data and parallel decompression across multiple threads. It wraps the excellent [zeekstd](https://github.com/facebook/zstd/tree/dev/contrib/seekable_format) format with ergonomic Rust APIs and multi-language bindings.

**Core capabilities:**
- **Seekable compression**: Compress data in frames that can be accessed independently
- **Random access**: Read any byte range without decompressing the entire file
- **Parallel decompression**: Decompress multiple ranges concurrently with rayon

**Language bindings:**
- Rust (native)
- Go (CGO)
- Python (PyO3/maturin)
- TypeScript/Node.js (napi-rs)

---

## Target Repository Structure

```
seekable-zstd/
├── Cargo.toml                      # Workspace root
├── LICENSE                         # MIT
├── README.md                       # Usage-focused documentation
├── CHANGELOG.md
├── Makefile                        # Build orchestration
├── .goneat/
│   └── hooks.yaml                  # Hook configuration (or .pre-commit-config.yaml)
│
├── crates/
│   ├── seekable-zstd-core/         # Rust library
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── encoder.rs
│   │       ├── decoder.rs
│   │       ├── parallel.rs
│   │       ├── ffi.rs              # C API exports
│   │       └── error.rs
│   │
│   └── seekable-zstd-py/           # Python bindings
│       ├── Cargo.toml
│       ├── pyproject.toml
│       └── src/lib.rs
│
├── bindings/
│   ├── go/                         # CGO wrapper
│   │   ├── go.mod
│   │   ├── seekable.go
│   │   ├── seekable_test.go
│   │   ├── include/
│   │   │   └── seekable_zstd.h
│   │   └── lib/                    # Pre-built static libs
│   │       ├── linux-amd64/
│   │       ├── linux-arm64/
│   │       ├── darwin-amd64/
│   │       ├── darwin-arm64/
│   │       └── windows-amd64/
│   │
│   └── nodejs/                     # napi-rs bindings
│       ├── package.json
│       ├── src/lib.rs
│       └── index.d.ts
│
├── tests/
│   ├── fixtures/
│   │   ├── spec.yaml               # Fixture specifications
│   │   ├── checksums.txt           # SHA256 for verification
│   │   ├── hello.txt               # 14 bytes - minimal test
│   │   ├── hello.szst
│   │   ├── lorem_4kb.txt           # Single-frame test
│   │   ├── lorem_4kb.szst
│   │   ├── multi_frame.szst        # 64KB, 4 frames - parallel test
│   │   └── generated/              # Large fixtures (gitignored)
│   ├── unit/
│   ├── integration/
│   └── benchmarks/
│
├── benches/
│   └── parallel.rs
│
├── docs/
│   ├── README.md
│   ├── getting-started.md
│   ├── parallel-decompression.md
│   ├── development.md
│   └── standards/
│       ├── README.md
│       ├── testing.md
│       └── coding/
│           ├── README.md           # Cross-language standards
│           ├── rust.md
│           ├── go.md
│           ├── python.md
│           └── typescript.md
│
└── scripts/
    ├── generate-fixtures.sh        # Idempotent fixture generation
    ├── build-all.sh
    └── publish-all.sh
```

---

## Phase 1A: Rust Core

### Scaffold

```bash
mkdir seekable-zstd && cd seekable-zstd
cargo init --lib crates/seekable-zstd-core
```

**Deliverables:**
- [ ] Workspace structure with `crates/seekable-zstd-core`
- [ ] MIT LICENSE
- [ ] Basic README.md
- [ ] Makefile with initial targets
- [ ] GitHub repo created

### Encoder

```rust
// crates/seekable-zstd-core/src/encoder.rs

pub const DEFAULT_FRAME_SIZE: usize = 256 * 1024;

pub struct Encoder<W: Write> {
    inner: zeekstd::Encoder<W>,
}

impl<W: Write> Encoder<W> {
    pub fn new(writer: W) -> Result<Self, Error>;
    pub fn with_frame_size(writer: W, frame_size: usize) -> Result<Self, Error>;
    pub fn with_level(writer: W, level: i32) -> Result<Self, Error>;
    pub fn write(&mut self, data: &[u8]) -> Result<usize, Error>;
    pub fn finish(self) -> Result<W, Error>;
}
```

**Deliverables:**
- [ ] `Encoder` wrapping zeekstd
- [ ] Configurable frame size and compression level
- [ ] Unit tests

### Decoder

```rust
// crates/seekable-zstd-core/src/decoder.rs

pub struct Decoder<R: Read + Seek> {
    inner: zeekstd::Decoder<R>,
}

impl<R: Read + Seek> Decoder<R> {
    pub fn new(reader: R) -> Result<Self, Error>;
    pub fn size(&self) -> u64;
    pub fn frame_count(&self) -> u64;
    pub fn read_at(&mut self, buf: &mut [u8], offset: u64) -> Result<usize, Error>;
    pub fn read_range(&mut self, start: u64, end: u64) -> Result<Vec<u8>, Error>;
}
```

**Deliverables:**
- [ ] `Decoder` with random access
- [ ] Metadata accessors (size, frame count)
- [ ] Unit tests

### Parallel Decompression

```rust
// crates/seekable-zstd-core/src/parallel.rs

pub struct ParallelDecoder {
    path: PathBuf,
    size: u64,
    frame_count: u64,
}

impl ParallelDecoder {
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self, Error>;

    pub fn read_ranges(&self, ranges: &[(u64, u64)]) -> Result<Vec<Vec<u8>>, Error> {
        ranges.par_iter().map(|(start, end)| {
            let file = File::open(&self.path)?;
            let mut decoder = Decoder::new(file)?;
            decoder.read_range(*start, *end)
        }).collect()
    }

    pub fn size(&self) -> u64;
    pub fn frame_count(&self) -> u64;
}
```

**Deliverables:**
- [ ] `ParallelDecoder` with rayon
- [ ] Benchmarks (1/2/4/8/16 threads)

### C FFI Layer

```rust
// crates/seekable-zstd-core/src/ffi.rs

#[no_mangle]
pub extern "C" fn seekable_open(path: *const c_char) -> *mut SeekableDecoder;

#[no_mangle]
pub extern "C" fn seekable_size(decoder: *const SeekableDecoder) -> u64;

#[no_mangle]
pub extern "C" fn seekable_frame_count(decoder: *const SeekableDecoder) -> u64;

#[no_mangle]
pub extern "C" fn seekable_read_range(
    decoder: *mut SeekableDecoder,
    start: u64, end: u64,
    out_data: *mut u8, out_len: *mut usize,
) -> i32;

#[no_mangle]
pub extern "C" fn seekable_close(decoder: *mut SeekableDecoder);

#[no_mangle]
pub extern "C" fn seekable_last_error() -> *const c_char;
```

**Deliverables:**
- [ ] C API in `ffi.rs`
- [ ] cbindgen generates `seekable_zstd.h`
- [ ] Static library for linux-amd64

---

## Phase 1B: DevSecOps Foundation

### Git Hooks Setup

Establish quality gates via pre-commit and pre-push hooks.

**Option 1: goneat (Recommended)**

[goneat](https://github.com/fulmenhq/goneat) provides hook management with multi-language support:

```bash
# Initialize
goneat hooks init

# Install
goneat hooks install
```

Configuration (`.goneat/hooks.yaml`):

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

  pre-push:
    enabled: true
    categories:
      - test
    timeout: 300s
```

**Option 2: pre-commit (Community Standard)**

```bash
pip install pre-commit
pre-commit install
```

Configuration (`.pre-commit-config.yaml`):

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer

  - repo: https://github.com/doublify/pre-commit-rust
    rev: v1.0
    hooks:
      - id: fmt
      - id: clippy
```

### Makefile Targets

```makefile
# Quality gates
.PHONY: quality
quality: format-check lint test-fast

.PHONY: format
format:
	cargo fmt

.PHONY: format-check
format-check:
	cargo fmt -- --check

.PHONY: lint
lint:
	cargo clippy -- -D warnings

.PHONY: test-fast
test-fast:
	cargo test --lib

# Hook management
.PHONY: hooks-install
hooks-install:
	@if command -v goneat >/dev/null 2>&1; then \
		goneat hooks install; \
	elif command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install; \
	else \
		echo "Install goneat or pre-commit for hook support"; \
	fi

.PHONY: hooks-remove
hooks-remove:
	@rm -f .git/hooks/pre-commit .git/hooks/pre-push

# Bootstrap
.PHONY: bootstrap
bootstrap: hooks-install
	@echo "Checking required tools..."
	@command -v rustc >/dev/null 2>&1 || (echo "rustc required" && exit 1)
	@command -v cargo >/dev/null 2>&1 || (echo "cargo required" && exit 1)
	rustup component add rustfmt clippy
	@echo "Bootstrap complete"
```

### Tool Installation

**goneat** can bootstrap common development tools:

```bash
# Install goneat (macOS)
brew tap fulmenhq/tap
brew install goneat

# Check tool availability
goneat doctor

# Install recommended tools
goneat doctor --fix
```

### Test Infrastructure

Test runner and coverage tools per language:

| Language | Runner | Coverage | Install |
|----------|--------|----------|---------|
| Rust | cargo test | cargo-tarpaulin | `cargo install cargo-tarpaulin` |
| Go | go test | built-in | - |
| Python | pytest | pytest-cov | `pip install pytest pytest-cov` |
| TypeScript | vitest | built-in | `npm install` |

### CI/CD Setup

Initial GitHub Actions workflow (`.github/workflows/ci.yml`):

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  rust:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        rust: [stable, "1.70"]
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@master
        with:
          toolchain: ${{ matrix.rust }}
          components: rustfmt, clippy
      - uses: Swatinem/rust-cache@v2
      - run: make quality
      - run: make test-rust
```

**Deliverables:**
- [ ] `.goneat/hooks.yaml` or `.pre-commit-config.yaml`
- [ ] Makefile with `bootstrap`, `quality`, `hooks-install` targets
- [ ] Pre-commit hook runs: format-check, lint
- [ ] Pre-push hook runs: full test suite
- [ ] `make bootstrap` works on fresh clone
- [ ] `.github/workflows/ci.yml` for Rust CI
- [ ] `cargo-tarpaulin` for coverage (optional at this phase)
- [ ] Documentation in `docs/development.md`

---

## Phase 2: Go Binding

### CGO Wrapper

```go
// bindings/go/seekable.go

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/${GOOS}-${GOARCH} -lseekable_zstd -lm -ldl -lpthread
#include "include/seekable_zstd.h"
*/
import "C"

type Reader struct {
    ptr *C.SeekableDecoder
}

func Open(path string) (*Reader, error)
func (r *Reader) Size() uint64
func (r *Reader) FrameCount() uint64
func (r *Reader) ReadRange(start, end uint64) ([]byte, error)
func (r *Reader) Close()
```

**Deliverables:**
- [ ] CGO wrapper implementation
- [ ] Pre-built libs for linux-amd64
- [ ] Cross-platform builds via Makefile
- [ ] CI workflow for 5 platforms (linux-amd64, linux-arm64, darwin-amd64, darwin-arm64, windows-amd64)
- [ ] Go test suite with benchmarks
- [ ] `docs/go-binding.md`

---

## Phase 3: Python Binding

### PyO3 Implementation

```rust
// crates/seekable-zstd-py/src/lib.rs

#[pyclass]
struct Reader { inner: ParallelDecoder }

#[pymethods]
impl Reader {
    #[new]
    fn new(path: &str) -> PyResult<Self>;
    fn size(&self) -> u64;
    fn frame_count(&self) -> u64;
    fn read_range(&self, py: Python, start: u64, end: u64) -> PyResult<Py<PyBytes>>;
    fn read_ranges(&self, py: Python, ranges: Vec<(u64, u64)>) -> PyResult<Vec<Py<PyBytes>>>;
}
```

**Deliverables:**
- [ ] PyO3 bindings in `crates/seekable-zstd-py`
- [ ] pytest test suite
- [ ] maturin build configuration
- [ ] Test PyPI publish workflow

---

## Phase 4: TypeScript Binding

### napi-rs Implementation

```rust
// bindings/nodejs/src/lib.rs

#[napi]
pub struct Reader { inner: ParallelDecoder }

#[napi]
impl Reader {
    #[napi(constructor)]
    pub fn new(path: String) -> Result<Self>;
    #[napi]
    pub fn size(&self) -> u64;
    #[napi]
    pub fn frame_count(&self) -> u64;
    #[napi]
    pub fn read_range(&self, start: u64, end: u64) -> Result<Buffer>;
}
```

**Deliverables:**
- [ ] napi-rs bindings in `bindings/nodejs`
- [ ] TypeScript type definitions
- [ ] Test suite
- [ ] npm publish workflow
- [ ] `docs/typescript-binding.md`

---

## Phase 5: Polish & Release

- [ ] Complete README with examples for all languages
- [ ] API documentation (rustdoc, godoc, docstrings)
- [ ] CI/CD for multi-platform builds
- [ ] CHANGELOG.md
- [ ] Tag v0.1.0
- [ ] Publish to crates.io, PyPI, npm, and Go module proxy

---

## Dependencies

### seekable-zstd-core

```toml
[dependencies]
zeekstd = "0.3"
rayon = "1.10"
thiserror = "2.0"

[build-dependencies]
cbindgen = "0.27"
```

### seekable-zstd-py

```toml
[dependencies]
pyo3 = { version = "0.22", features = ["extension-module"] }
seekable-zstd-core = { path = "../seekable-zstd-core" }
```

### bindings/nodejs

```toml
[dependencies]
napi = "2"
napi-derive = "2"
seekable-zstd-core = { path = "../../crates/seekable-zstd-core" }
```

---

## Success Criteria

- [ ] `cargo test` passes for all crates
- [ ] Go/Python/TypeScript bindings work correctly
- [ ] Parallel decompression shows linear speedup to 8+ cores
- [ ] Single-thread decompress throughput >1GB/s
- [ ] Published on crates.io, PyPI, npm
- [ ] Cross-platform binaries available for major platforms

---

## Development Workflow

Once the repository is set up, common tasks will be:

```bash
make bootstrap          # First-time setup
make build              # Build all crates
make test               # Run all tests
make quality            # Format + lint checks
make bench              # Run benchmarks

# Version management
make bump-patch         # 0.1.0 -> 0.1.1
make bump-minor         # 0.1.0 -> 0.2.0

# Language-specific
make build-go           # Build Go bindings
make build-python       # Build Python wheel
make build-nodejs       # Build npm package
```

---

## Test Fixtures

See [docs/standards/testing.md](docs/standards/testing.md) for complete testing standards.

### Fixture Strategy

| Category | Size | Storage | Generation |
|----------|------|---------|------------|
| Small | <100KB | Committed | Pre-generated |
| Medium | 100KB-10MB | Committed (LFS optional) | Script |
| Large | >10MB | Generated at test time | Idempotent script |

### Small Fixtures (Committed)

These are committed to the repository in `tests/fixtures/`:

```yaml
# tests/fixtures/spec.yaml

fixtures:
  - name: hello
    description: Minimal roundtrip test
    decompressed_size: 14
    frame_size: 1024
    frame_count: 1
    sha256: 7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069

  - name: lorem_4kb
    description: Single-frame compression
    decompressed_size: 4096
    frame_size: 8192
    frame_count: 1

  - name: multi_frame
    description: Multi-frame for parallel testing
    decompressed_size: 65536
    frame_size: 16384
    frame_count: 4
```

### Large Fixtures (Generated)

Large fixtures are generated on-demand via idempotent script:

```bash
#!/bin/bash
# scripts/generate-fixtures.sh - Deterministic fixture generation

FIXTURES_DIR="${1:-tests/fixtures/generated}"
mkdir -p "$FIXTURES_DIR"

# Generate deterministic "random" data using fixed seed
generate_deterministic() {
    local size=$1 seed=$2 output=$3
    openssl enc -aes-256-ctr -nosalt \
        -pass pass:"seekable-zstd-$seed" \
        </dev/zero 2>/dev/null | head -c "$size" > "$output"
}

# 1MB fixture
[[ -f "$FIXTURES_DIR/random_1mb.txt" ]] || \
    generate_deterministic 1048576 "1mb" "$FIXTURES_DIR/random_1mb.txt"

# 10MB fixture
[[ -f "$FIXTURES_DIR/random_10mb.txt" ]] || \
    generate_deterministic 10485760 "10mb" "$FIXTURES_DIR/random_10mb.txt"

# Compress using our tool
for txt in "$FIXTURES_DIR"/*.txt; do
    szst="${txt%.txt}.szst"
    [[ -f "$szst" ]] || seekable-zstd compress --frame-size 262144 "$txt" "$szst"
done
```

### Parallel Testing Requirements

Tests must demonstrate actual parallel decompression:

1. **Correctness**: Parallel results match sequential results
2. **Speedup**: Measurable improvement with multiple cores
3. **Cross-language**: All bindings produce identical output

```rust
#[test]
fn parallel_shows_speedup() {
    let decoder = ParallelDecoder::open("tests/fixtures/generated/random_10mb.szst")?;
    let ranges: Vec<(u64, u64)> = /* 16 equal ranges */;

    // Time sequential
    let seq_start = Instant::now();
    for (s, e) in &ranges {
        Decoder::open(path)?.read_range(*s, *e)?;
    }
    let seq_time = seq_start.elapsed();

    // Time parallel
    let par_start = Instant::now();
    decoder.read_ranges(&ranges)?;
    let par_time = par_start.elapsed();

    // Expect 2x+ speedup on 4+ core systems
    if num_cpus::get() >= 4 {
        assert!(par_time < seq_time / 2);
    }
}
```

### Cross-Language Fixture Verification

Each binding runs identical tests against shared fixtures:

```python
# Python
def test_matches_rust_output(sample_archive):
    with Reader(sample_archive) as r:
        data = r.read_range(0, 1024)
        assert sha256(data) == EXPECTED_HASH
```

```go
// Go
func TestMatchesRustOutput(t *testing.T) {
    r := Open(sampleArchive)
    defer r.Close()
    data := r.ReadRange(0, 1024)
    assert.Equal(t, expectedHash, sha256(data))
}
```

```typescript
// TypeScript
test("matches Rust output", () => {
    const r = new Reader(sampleArchive);
    const data = r.readRange(0n, 1024n);
    expect(sha256(data)).toBe(EXPECTED_HASH);
    r.close();
});
```

---

## Standards

Coding and testing standards are documented in `docs/standards/`:

- **[coding/README.md](docs/standards/coding/README.md)** - Cross-language patterns
- **[coding/rust.md](docs/standards/coding/rust.md)** - Rust-specific standards
- **[coding/go.md](docs/standards/coding/go.md)** - Go CGO standards
- **[coding/python.md](docs/standards/coding/python.md)** - Python/PyO3 standards
- **[coding/typescript.md](docs/standards/coding/typescript.md)** - TypeScript/napi-rs standards
- **[testing.md](docs/standards/testing.md)** - Test fixtures and parallel verification

Standards adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible).

---

*Bootstrap guide for seekable-zstd - a community library for seekable zstd compression*
