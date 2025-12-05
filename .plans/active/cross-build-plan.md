# Cross-Build and Distribution Plan

## Problem Statement

seekable-zstd provides bindings for Go, Python, and TypeScript/Node.js. Each binding wraps a Rust core library that links against zstd (a C library). Users of these bindings should ideally not need Rust or C toolchains installed.

**Constraints:**
- Rust can cross-compile pure Rust, but C dependencies (zstd-sys) require platform-specific toolchains
- Go CGO requires static libraries for each target platform
- Python wheels must be built per platform/Python version
- Node.js native modules must be built per platform/Node version

## Target Platforms

| Platform | Architecture | Priority | Notes |
|----------|--------------|----------|-------|
| Linux | x86_64 (glibc) | P0 | Most servers |
| Linux | aarch64 (glibc) | P0 | AWS Graviton, ARM servers |
| Linux | x86_64 (musl) | P1 | Alpine containers (High priority for log processing) |
| Linux | aarch64 (musl) | P1 | Alpine on ARM |
| macOS | arm64 | P0 | Apple Silicon (macos-latest) |
| macOS | x86_64 | P1 | Intel Macs (macos-13) |
| Windows | x86_64 (gnu) | P2 | Deferred to v0.2.0 (using MinGW strategy) |

## Strategy by Language

### Python: maturin + PyPI

**Approach:** Use maturin-action to build wheels in CI, publish to PyPI.

**Tooling:**
- `maturin` for building Python wheels from Rust
- `PyO3/maturin-action` GitHub Action
- `manylinux` containers for glibc compatibility
- `musllinux` for Alpine support

### Node.js/TypeScript: napi-rs + npm

**Approach:** Use napi-rs with platform-specific optional dependencies.

**Tooling:**
- `napi-rs` for building native Node.js addons from Rust
- GitHub Actions matrix for cross-compilation

### Go: Vendored Static Libraries

**Approach:** Build static libraries in CI, commit to repository.

**Rationale:**
- Go lacks a standard mechanism for downloading native dependencies
- `go get` must work without additional steps for standard targets
- Static libraries are ~2-4MB each

**Tooling:**
- **`cargo-zigbuild`**: Uses Zig as a linker to cross-compile C/Rust deps easily.
    - **Benefit**: Can cross-compile Linux targets (glibc/musl) from macOS or Ubuntu hosts without Docker.
    - **Compatibility**: Targets `glibc 2.17` for broad Linux support.

**Repository Structure:**
```
bindings/go/
├── lib/
│   ├── darwin-amd64/
│   ├── darwin-arm64/
│   ├── linux-amd64/
│   ├── linux-arm64/
│   ├── linux-amd64-musl/  (New: requires -tags musl)
│   └── linux-arm64-musl/  (New: requires -tags musl)
├── cgo_linux_amd64.go       // //go:build linux && amd64 && !musl
├── cgo_linux_amd64_musl.go  // //go:build linux && amd64 && musl
├── seekable.go
└── ...
```

**User Experience:**
```bash
# Standard glibc (Ubuntu, Debian, RHEL)
go get github.com/3leaps/seekable-zstd/bindings/go

# Alpine Linux (musl)
go get -tags musl github.com/3leaps/seekable-zstd/bindings/go
```

**CI Workflow:**
```yaml
# .github/workflows/build-go-libs.yml
name: Build Go Static Libraries

jobs:
  build-linux:
    name: Build Linux Libs
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          targets: x86_64-unknown-linux-gnu,aarch64-unknown-linux-gnu,x86_64-unknown-linux-musl,aarch64-unknown-linux-musl
      - name: Install cargo-zigbuild
        run: pip install ziglang && cargo install cargo-zigbuild
      - name: Build
        run: |
          # glibc 2.17 targets
          cargo zigbuild --release --target x86_64-unknown-linux-gnu.2.17 -p seekable-zstd-core
          cargo zigbuild --release --target aarch64-unknown-linux-gnu.2.17 -p seekable-zstd-core
          # musl targets
          cargo zigbuild --release --target x86_64-unknown-linux-musl -p seekable-zstd-core
          cargo zigbuild --release --target aarch64-unknown-linux-musl -p seekable-zstd-core
          
          # Organize artifacts
          mkdir -p bindings/go/lib/linux-amd64
          cp target/x86_64-unknown-linux-gnu/release/libseekable_zstd_core.a bindings/go/lib/linux-amd64/
          
          mkdir -p bindings/go/lib/linux-amd64-musl
          cp target/x86_64-unknown-linux-musl/release/libseekable_zstd_core.a bindings/go/lib/linux-amd64-musl/
          
          # ... repeat for arm64

  build-macos:
    name: Build macOS Libs
    runs-on: macos-latest # Currently macOS 14 (ARM)
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: x86_64-apple-darwin,aarch64-apple-darwin
      - name: Build
        run: |
          # Native ARM build
          cargo build --release --target aarch64-apple-darwin -p seekable-zstd-core
          # Cross-compile to Intel
          cargo build --release --target x86_64-apple-darwin -p seekable-zstd-core
```

## Implementation Phases

### Phase 1: CI Infrastructure (Week 1)
- [x] Set up GitHub Actions for Rust tests
- [ ] Add `cargo-zigbuild` workflow for Linux (glibc + musl)
- [ ] Verify builds on all target platforms

### Phase 2: Distribution
- [ ] Python: Configure maturin for wheel building
- [ ] Node.js: Configure napi-rs
- [ ] Go: Commit pre-built libraries (Linux/Mac)

### Phase 3: Release Automation
- [ ] Create unified release workflow
- [ ] Add version synchronization checks

## Architecture Decisions

1. **Go library size:** Accepting repo bloat for v0.1.0 to prioritize DX.
2. **Windows:** Deferred. Will use `x86_64-pc-windows-gnu` (MinGW) when implemented to simplify cross-compilation.
3. **Go musl support**: Implemented via `//go:build musl` build tag. This requires explicit user opt-in (`-tags musl`), which is standard practice for CGO libraries handling libc variations.
