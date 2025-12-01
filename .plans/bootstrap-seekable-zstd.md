# seekable-zstd Bootstrap Plan v2

**Repository**: `3leaps/seekable-zstd`  
**Purpose**: Community library for seekable zstd compression with parallel decompression  
**Pattern**: Minimalist, like `string-metrics-wasm`  
**License**: MIT

**Parallel Workstream**: `fulmenhq/forge-workhorse-roan` (Rust workhorse template)

---

## Overview

This plan guides two parallel implementation efforts:

1. **`3leaps/seekable-zstd`** — Community Rust library with Go/Python/TypeScript bindings
2. **`fulmenhq/forge-workhorse-roan`** — Generic Rust workhorse template (peers with groningen/percheron/tuvan)

After both are complete, we CDRL `roan` → `destrier` to create the reference CLI for seekable-zstd validation.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PARALLEL WORKSTREAMS                             │
├───────────────────────────────┬─────────────────────────────────────────┤
│  3leaps/seekable-zstd         │  fulmenhq/forge-workhorse-roan          │
│  (Library)                    │  (Template)                             │
├───────────────────────────────┼─────────────────────────────────────────┤
│  Days 1-5: Rust core          │  Days 1-5: Workhorse scaffold           │
│  Days 6-8: Go binding (CGO)   │  Days 6-8: Core modules                 │
│  Days 9-10: Python binding    │  Days 9-10: Observability + CLI         │
│  Days 11-12: TypeScript       │  Days 11-12: CDRL tooling + docs        │
│  Days 13-14: Polish + release │  Days 13-14: Polish + release           │
└───────────────────────────────┴─────────────────────────────────────────┘
                              │
                              │ CDRL (clone + refit)
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  destrier (Days 15-16)                                                  │
│  ─────────────────────────────────────────────────────────────────────  │
│  • CDRL'd from forge-workhorse-roan                                     │
│  • Refitted with seekable-zstd-core                                     │
│  • Reference client for library validation                              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

# Workstream A: 3leaps/seekable-zstd

## Repository Structure (Target)

```
seekable-zstd/
├── Cargo.toml                      # Workspace root
├── LICENSE                         # MIT
├── README.md                       # Community-focused
├── CHANGELOG.md
├── Makefile
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
│   ├── fixtures/                   # Small test files (<10MB)
│   └── fixtures.yaml               # Test case definitions
│
├── scripts/
│   ├── generate-corpus.sh
│   ├── build-all.sh
│   └── publish-all.sh
│
├── benches/
│   └── parallel.rs
│
└── docs/
    ├── README.md
    ├── getting-started.md
    ├── parallel-decompression.md
    └── development.md
```

## Phase A1: Rust Core (Days 1-5)

### Day 1: Project Scaffold

```bash
mkdir seekable-zstd && cd seekable-zstd
cargo init --lib crates/seekable-zstd-core
```

**Deliverables**:
- [ ] Workspace structure
- [ ] MIT LICENSE
- [ ] Basic README.md
- [ ] GitHub repo created

### Day 2: Encoder

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

**Deliverables**:
- [ ] `Encoder` wrapping zeekstd
- [ ] Configurable frame size and compression level
- [ ] Unit tests

### Day 3: Decoder

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

**Deliverables**:
- [ ] `Decoder` with random access
- [ ] Metadata accessors
- [ ] Unit tests

### Day 4: Parallel Decompression

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

**Deliverables**:
- [ ] `ParallelDecoder` with rayon
- [ ] Benchmarks (1/2/4/8/16 threads)

### Day 5: C FFI Layer

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

**Deliverables**:
- [ ] C API in `ffi.rs`
- [ ] cbindgen → `seekable_zstd.h`
- [ ] Static library for linux-amd64

---

## Phase A2: Go Binding (Days 6-8)

### Day 6: CGO Wrapper

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

**Deliverables**:
- [ ] CGO wrapper
- [ ] Pre-built lib for linux-amd64

### Day 7: Cross-Platform Builds

**Deliverables**:
- [ ] Makefile cross-compile targets
- [ ] CI workflow for 5 platforms
- [ ] Pre-built libs committed

### Day 8: Go Tests

**Deliverables**:
- [ ] Go test suite
- [ ] Benchmarks
- [ ] `docs/go-binding.md`

---

## Phase A3: Python Binding (Days 9-10)

### Day 9: PyO3 Implementation

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

### Day 10: Python Tests + Publish

**Deliverables**:
- [ ] pytest suite
- [ ] maturin build
- [ ] Test PyPI publish

---

## Phase A4: TypeScript Binding (Days 11-12)

### Day 11: napi-rs Implementation

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

### Day 12: TypeScript Tests + Publish

**Deliverables**:
- [ ] TypeScript tests
- [ ] npm publish workflow
- [ ] `docs/typescript-binding.md`

---

## Phase A5: Polish (Days 13-14)

- [ ] Complete README with all language examples
- [ ] API documentation (rustdoc, godoc, docstrings)
- [ ] CI/CD for multi-platform
- [ ] CHANGELOG.md
- [ ] Tag v0.1.0

---

# Workstream B: fulmenhq/forge-workhorse-roan

## Repository Structure (Target)

```
forge-workhorse-roan/
├── .fulmen/
│   └── app.yaml                    # App identity (binary_name: roan)
├── Cargo.toml
├── src/
│   ├── lib.rs                      # Library exports (optional)
│   └── bin/
│       └── roan.rs                 # CLI entry point
├── internal/
│   ├── cmd/
│   │   ├── mod.rs
│   │   ├── root.rs                 # Root command
│   │   ├── serve.rs                # Server mode
│   │   └── version.rs              # Version info
│   ├── config/
│   │   ├── mod.rs
│   │   ├── loader.rs               # Three-layer config
│   │   └── types.rs                # Config structs
│   ├── runtime/
│   │   ├── mod.rs
│   │   ├── logging.rs              # Structured logging
│   │   ├── signals.rs              # Graceful shutdown
│   │   └── telemetry.rs            # Prometheus metrics
│   └── server/
│       ├── mod.rs
│       ├── health.rs               # /health endpoint
│       ├── metrics.rs              # /metrics endpoint
│       └── version.rs              # /version endpoint
├── config/
│   └── roan.yaml                   # Default config
├── docs/
│   ├── development/
│   │   └── fulmen_cdrl_guide.md    # CDRL instructions
│   └── workhorse-overview.md
├── scripts/
│   └── validate-app-identity.sh
├── tests/
│   ├── integration/
│   └── unit/
├── Makefile
├── README.md
└── CHANGELOG.md
```

## Phase B1: Workhorse Scaffold (Days 1-5)

### Day 1: Project Setup

```bash
mkdir forge-workhorse-roan && cd forge-workhorse-roan
cargo init --name roan
```

**Deliverables**:
- [ ] Cargo workspace
- [ ] `.fulmen/app.yaml` with identity
- [ ] Basic CLI skeleton (clap)
- [ ] Makefile with standard targets

### Day 2: App Identity Module

```rust
// internal/identity/mod.rs

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct AppIdentity {
    pub binary_name: String,
    pub vendor: String,
    pub env_prefix: String,
    pub config_name: String,
    pub description: String,
}

impl AppIdentity {
    pub fn load() -> Result<Self, Error> {
        // Load from .fulmen/app.yaml
    }
}
```

**`.fulmen/app.yaml`**:
```yaml
binary_name: roan
vendor: fulmenhq
env_prefix: ROAN_
config_name: roan
description: "Rust workhorse template for production applications"
```

**Deliverables**:
- [ ] App identity loader
- [ ] Environment prefix support
- [ ] `make validate-app-identity` target

### Day 3: Three-Layer Config

```rust
// internal/config/loader.rs

pub struct Config {
    pub host: String,
    pub port: u16,
    pub log_level: String,
    // ... other fields
}

impl Config {
    pub fn load(identity: &AppIdentity) -> Result<Self, Error> {
        // Layer 1: Defaults (embedded)
        // Layer 2: User config (~/.config/{vendor}/{app}/config.yaml)
        // Layer 3: Env vars ({PREFIX}_*)
    }
}
```

**Deliverables**:
- [ ] Three-layer config loading
- [ ] Standard env vars (PORT, HOST, LOG_LEVEL, CONFIG_PATH)
- [ ] Config validation

### Day 4: Logging Module

```rust
// internal/runtime/logging.rs

use tracing::{info, warn, error, Level};
use tracing_subscriber::{fmt, EnvFilter};

pub fn init(config: &Config, identity: &AppIdentity) -> Result<(), Error> {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(&config.log_level));
    
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .json()  // Structured logging
        .with_target(true)
        .init();
    
    info!(service = %identity.binary_name, "Logger initialized");
    Ok(())
}
```

**Deliverables**:
- [ ] Structured JSON logging (tracing)
- [ ] Log level from config/env
- [ ] Service name from identity

### Day 5: Signal Handling

```rust
// internal/runtime/signals.rs

use tokio::signal;
use std::sync::atomic::{AtomicBool, Ordering};

static SHUTDOWN_REQUESTED: AtomicBool = AtomicBool::new(false);

pub async fn wait_for_shutdown() {
    let ctrl_c = async {
        signal::ctrl_c().await.expect("failed to listen for ctrl+c");
    };
    
    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to listen for SIGTERM")
            .recv()
            .await;
    };
    
    tokio::select! {
        _ = ctrl_c => info!("Received SIGINT"),
        _ = terminate => info!("Received SIGTERM"),
    }
    
    SHUTDOWN_REQUESTED.store(true, Ordering::SeqCst);
}
```

**Deliverables**:
- [ ] SIGTERM/SIGINT handling
- [ ] Graceful shutdown pattern
- [ ] Context cancellation

---

## Phase B2: Core Modules (Days 6-8)

### Day 6: Telemetry/Metrics

```rust
// internal/runtime/telemetry.rs

use prometheus::{Registry, Counter, Histogram, Encoder, TextEncoder};

pub struct Metrics {
    pub requests_total: Counter,
    pub request_duration: Histogram,
    registry: Registry,
}

impl Metrics {
    pub fn new(identity: &AppIdentity) -> Self {
        let prefix = &identity.binary_name;
        // Create metrics with binary-prefixed names
        // e.g., roan_requests_total, roan_request_duration_seconds
    }
    
    pub fn encode(&self) -> String {
        let encoder = TextEncoder::new();
        let metric_families = self.registry.gather();
        let mut buffer = Vec::new();
        encoder.encode(&metric_families, &mut buffer).unwrap();
        String::from_utf8(buffer).unwrap()
    }
}
```

**Deliverables**:
- [ ] Prometheus registry
- [ ] Standard metrics (requests, duration, errors)
- [ ] Binary-prefixed metric names

### Day 7: HTTP Server + Endpoints

```rust
// internal/server/mod.rs

use axum::{Router, routing::get};

pub fn create_router(metrics: Arc<Metrics>, identity: Arc<AppIdentity>) -> Router {
    Router::new()
        .route("/health", get(health::handler))
        .route("/metrics", get(metrics::handler))
        .route("/version", get(version::handler))
        .with_state(AppState { metrics, identity })
}
```

**Deliverables**:
- [ ] `/health` endpoint
- [ ] `/metrics` endpoint (Prometheus format)
- [ ] `/version` endpoint (with Crucible version placeholder)

### Day 8: Error Handling

```rust
// internal/error.rs

use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("configuration error: {0}")]
    Config(#[from] ConfigError),
    
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    
    #[error("server error: {0}")]
    Server(String),
}

impl AppError {
    pub fn to_response(&self) -> (StatusCode, Json<ErrorResponse>) {
        // Map to HTTP response with structured error
    }
}
```

**Deliverables**:
- [ ] Unified error type
- [ ] Error wrapping with context
- [ ] HTTP error responses

---

## Phase B3: CLI + CDRL (Days 9-12)

### Day 9: CLI Commands

```rust
// src/bin/roan.rs

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "roan", about = "Rust workhorse template")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the server
    Serve {
        #[arg(short, long, default_value = "8080")]
        port: u16,
    },
    /// Show version information
    Version {
        #[arg(long)]
        extended: bool,
    },
    /// Run environment diagnostics
    Doctor,
}
```

**Deliverables**:
- [ ] `roan serve` command
- [ ] `roan version` command
- [ ] `roan doctor` command

### Day 10: Serve Mode

**Deliverables**:
- [ ] Full server startup flow
- [ ] Graceful shutdown integration
- [ ] Config hot-reload (SIGHUP)

### Day 11: CDRL Tooling

**`scripts/validate-app-identity.sh`**:
```bash
#!/bin/bash
# Check for hardcoded "roan" references outside .fulmen/app.yaml

IDENTITY=$(yq '.binary_name' .fulmen/app.yaml)
VIOLATIONS=$(grep -r "roan" --include="*.rs" --include="*.toml" \
  --exclude-dir=target | grep -v ".fulmen/app.yaml" | wc -l)

if [ "$VIOLATIONS" -gt 0 ]; then
    echo "Found hardcoded references to 'roan'"
    exit 1
fi
echo "No hardcoded identity references found"
```

**Deliverables**:
- [ ] `make validate-app-identity`
- [ ] `make doctor` comprehensive check
- [ ] CDRL guide documentation

### Day 12: Documentation

**Deliverables**:
- [ ] `docs/development/fulmen_cdrl_guide.md`
- [ ] `docs/workhorse-overview.md`
- [ ] README with CDRL quick start
- [ ] Inline rustdoc

---

## Phase B4: Polish (Days 13-14)

- [ ] Full test suite (unit + integration)
- [ ] CI/CD workflows
- [ ] Makefile standard targets (`bootstrap`, `check-all`, `build`, `test`)
- [ ] CHANGELOG.md
- [ ] Tag v0.1.0

---

# Phase C: CDRL roan → destrier (Days 15-16)

## Day 15: Clone and Refit

```bash
# Clone roan template
git clone https://github.com/fulmenhq/forge-workhorse-roan destrier
cd destrier
rm -rf .git
git init

# Update identity
cat > .fulmen/app.yaml << 'EOF'
binary_name: destrier
vendor: fulmenhq
env_prefix: DESTRIER_
config_name: destrier
description: "Seekable zstd compression CLI - reference client for 3leaps/seekable-zstd"
EOF

# Validate refit
make validate-app-identity  # Should pass after renaming
```

**Refit checklist**:
- [ ] `.fulmen/app.yaml` → destrier identity
- [ ] `Cargo.toml` → name = "destrier"
- [ ] `src/bin/roan.rs` → `src/bin/destrier.rs`
- [ ] Add `seekable-zstd-core` dependency
- [ ] Update README

## Day 16: Add Seekable Commands

```rust
// internal/cmd/compress.rs

use seekable_zstd_core::{Encoder, DEFAULT_FRAME_SIZE};

pub async fn run(input: PathBuf, output: PathBuf, frame_size: usize) -> Result<()> {
    let input_file = File::open(&input)?;
    let output_file = File::create(&output)?;
    
    let mut encoder = Encoder::with_frame_size(output_file, frame_size)?;
    std::io::copy(&mut input_file, &mut encoder)?;
    encoder.finish()?;
    
    info!(input = %input.display(), output = %output.display(), "Compression complete");
    Ok(())
}
```

**New commands**:
- [ ] `destrier compress --frame-size 256K input.xml -o output.szst`
- [ ] `destrier decompress --range 1G-2G input.szst -o sample.xml`
- [ ] `destrier inspect input.szst`
- [ ] `destrier parallel --workers 16 --ranges ranges.txt input.szst`

**Deliverables**:
- [ ] Full CLI with seekable commands
- [ ] Integration tests against seekable-zstd
- [ ] README as reference client documentation
- [ ] Release binaries

---

# Validation Strategy

## Cross-Validation Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  destrier (Reference Client)                                            │
│  ─────────────────────────────────────────────────────────────────────  │
│  destrier compress fixtures/lorem.txt -o /tmp/test.szst                 │
│  destrier inspect /tmp/test.szst > /tmp/expected.json                   │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              │ compare output
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Library Implementations                                                │
│  ─────────────────────────────────────────────────────────────────────  │
│  # Go                                                                   │
│  go test -run TestAgainstDestrier                                       │
│                                                                         │
│  # Python                                                               │
│  pytest tests/test_destrier_compat.py                                   │
│                                                                         │
│  # TypeScript                                                           │
│  npm run test:destrier                                                  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Shared Test Fixtures

```yaml
# tests/fixtures.yaml

roundtrip:
  - name: "hello_world"
    input: "Hello, World!"
    frame_size: 1024
    expected:
      size: 14
      frames: 1
      
  - name: "multi_frame"
    input_file: "fixtures/lorem_64kb.txt"
    frame_size: 16384
    expected:
      frames: 4

# destrier produces authoritative output for these cases
```

---

# Timeline Summary

| Days | Workstream A (seekable-zstd) | Workstream B (roan) |
|------|------------------------------|---------------------|
| 1-5 | Rust core (encoder/decoder/parallel/ffi) | Workhorse scaffold (identity/config/logging/signals) |
| 6-8 | Go binding (CGO) | Core modules (telemetry/server/errors) |
| 9-10 | Python binding (PyO3) | CLI commands + serve mode |
| 11-12 | TypeScript binding (napi-rs) | CDRL tooling + docs |
| 13-14 | Polish + v0.1.0 release | Polish + v0.1.0 release |
| 15-16 | — | CDRL → destrier + seekable integration |

**Total**: 16 days to library + template + reference client

---

# Success Criteria

## seekable-zstd (Library)
- [ ] `cargo test` passes
- [ ] Go/Python/TypeScript bindings work
- [ ] Parallel decompression shows linear speedup
- [ ] >1GB/s single-thread decompress
- [ ] Published on crates.io, PyPI, npm

## forge-workhorse-roan (Template)
- [ ] Implements workhorse standard
- [ ] `make validate-app-identity` passes
- [ ] `make doctor` passes
- [ ] CDRL guide complete
- [ ] Joins groningen/percheron/tuvan family

## destrier (Reference Client)
- [ ] Successfully CDRL'd from roan
- [ ] All seekable commands work
- [ ] Cross-validates library output
- [ ] Release binaries available

---

# Dependencies

## seekable-zstd-core
```toml
[dependencies]
zeekstd = "0.3"
rayon = "1.10"
thiserror = "2.0"

[build-dependencies]
cbindgen = "0.27"
```

## forge-workhorse-roan
```toml
[dependencies]
clap = { version = "4", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
axum = "0.7"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["json", "env-filter"] }
prometheus = "0.13"
serde = { version = "1", features = ["derive"] }
serde_yaml = "0.9"
thiserror = "2.0"
```

---

*Bootstrap plan v2 for parallel development of seekable-zstd and forge-workhorse-roan*