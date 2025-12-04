# seekable-zstd

Seekable zstd compression with parallel decompression support.

## Why Seekable Compression?

Standard compression formats like gzip and zstd produce opaque blobs - to read byte 1,000,000, you must decompress everything before it. This is problematic for large files processed by parallel workers:

**The Problem:**
- Log files compressed to save storage can't be efficiently searched
- Index files must be fully decompressed before querying
- Parallel processing pipelines serialize on decompression
- Cloud storage egress costs multiply when workers fetch entire files

**The Solution:**
Seekable zstd divides data into independently-compressed frames with a seek table. This enables:
- **Random access**: Jump directly to any byte offset
- **Parallel decompression**: Multiple workers process different ranges simultaneously
- **Reduced I/O**: Fetch only the frames containing your data

**Use Cases:**
- Distributed log processing (each worker handles a byte range)
- Compressed index files with random lookups
- Large dataset sharding without pre-splitting
- Streaming partial results from compressed archives

## Overview

This library wraps the [seekable zstd format](https://github.com/facebook/zstd/tree/dev/contrib/seekable_format) with ergonomic APIs for multiple languages.

**Features:**
- Compress data in independently-accessible frames
- Read any byte range without decompressing the entire file
- Decompress multiple ranges concurrently via rayon
- Consistent API across Rust, Go, Python, and TypeScript

**Language Support:**
- Rust (native)
- Go (CGO)
- Python (PyO3)
- TypeScript/Node.js (napi-rs)

## Installation

```bash
# Rust
cargo add seekable-zstd

# Python
pip install seekable-zstd

# Node.js
npm install seekable-zstd

# Go
go get github.com/3leaps/seekable-zstd/bindings/go
```

## Quick Start

### Rust

```rust
use seekable_zstd::{Encoder, Decoder, ParallelDecoder};

// Compress
let mut encoder = Encoder::new(output_file)?;
encoder.write_all(&data)?;
encoder.finish()?;

// Random access
let mut decoder = Decoder::open("archive.szst")?;
let chunk = decoder.read_range(1000, 2000)?;

// Parallel decompression
let decoder = ParallelDecoder::open("archive.szst")?;
let chunks = decoder.read_ranges(&[(0, 1000), (1000, 2000), (2000, 3000)])?;
```

### Python

```python
from seekable_zstd import Reader

with Reader("archive.szst") as r:
    print(f"Size: {r.size}, Frames: {r.frame_count}")

    # Single range
    data = r.read_range(1000, 2000)

    # Parallel ranges
    chunks = r.read_ranges([(0, 1000), (1000, 2000), (2000, 3000)])
```

### Go

```go
import seekable "github.com/3leaps/seekable-zstd/bindings/go"

reader, err := seekable.Open("archive.szst")
if err != nil {
    log.Fatal(err)
}
defer reader.Close()

data, err := reader.ReadRange(1000, 2000)
```

### TypeScript

```typescript
import { Reader } from "seekable-zstd";

const reader = new Reader("archive.szst");
console.log(`Size: ${reader.size}, Frames: ${reader.frameCount}`);

const data = reader.readRange(1000, 2000);
reader.close();
```

## Project Structure

```
seekable-zstd/
├── crates/
│   ├── seekable-zstd-core/     # Rust library + C FFI
│   └── seekable-zstd-py/       # Python bindings (PyO3)
├── bindings/
│   ├── go/                     # Go bindings (CGO)
│   └── nodejs/                 # TypeScript bindings (napi-rs)
├── tests/fixtures/             # Shared test fixtures
├── docs/                       # Documentation
│   └── standards/              # Coding and testing standards
└── Makefile                    # Build orchestration
```

## Development

### Prerequisites

- Rust 1.70+ (via rustup)
- Go 1.21+ (for Go bindings)
- Python 3.10+ with maturin (for Python bindings)
- Node.js 18+ (for TypeScript bindings)

### Makefile

The Makefile is the primary task orchestrator, ensuring correct ordering of multi-language builds:

```bash
make bootstrap      # First-time setup (install tools, dependencies)
make build          # Build all crates and bindings
make test           # Run all tests across all languages
make quality        # Format + lint checks (rustfmt, clippy, ruff, biome)
make bench          # Run benchmarks
make clean          # Remove build artifacts
```

**Why Makefile?** This project spans multiple languages (Rust, Go, Python, TypeScript). Make provides:
- Unified interface across all toolchains
- Correct dependency ordering (e.g., Rust must build before Go CGO)
- Consistent behavior in CI and local development

### Versioning

This project uses [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking API changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

Versions are synchronized across all packages:
- `Cargo.toml` (Rust workspace)
- `pyproject.toml` (Python)
- `package.json` (TypeScript)
- `go.mod` (Go - via tags)

```bash
make bump-patch     # 0.1.0 -> 0.1.1
make bump-minor     # 0.1.0 -> 0.2.0
make bump-major     # 0.1.0 -> 1.0.0
```

### Quality Gates

Pre-commit hooks enforce quality standards:

```bash
make hooks-install  # Install git hooks
```

Hooks run automatically on commit:
- `rustfmt` - Rust formatting
- `clippy` - Rust linting
- `cargo test` - Rust tests
- Language-specific linters for modified bindings

See [docs/development.md](docs/development.md) for detailed development guide.

## Documentation

- [Development Guide](docs/development.md) - Setup, workflow, hooks
- [Standards](docs/standards/README.md) - Coding and testing standards
- [API Documentation](https://docs.rs/seekable-zstd) - Rust API docs

## License

MIT - See [LICENSE](LICENSE)

## Contributing

See [AGENTS.md](AGENTS.md) for AI developer guidelines or [CONTRIBUTING.md](CONTRIBUTING.md) for human contributors.

## Governance

- Authoritative policies repository: https://github.com/3leaps/oss-policies/
- Code of Conduct: https://github.com/3leaps/oss-policies/blob/main/CODE_OF_CONDUCT.md
- Security Policy: https://github.com/3leaps/oss-policies/blob/main/SECURITY.md
- Contributing Guide: https://github.com/3leaps/oss-policies/blob/main/CONTRIBUTING.md

---

**Built by the [3 Leaps](https://3leaps.net) team**
