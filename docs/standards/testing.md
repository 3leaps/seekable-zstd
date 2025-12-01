# Testing Standards

> Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) portable testing practices.

This document establishes testing standards for seekable-zstd, with emphasis on:
- Portable, deterministic tests
- Shared test fixtures across language bindings
- Fixture generation for reproducibility
- Parallel decompression verification

---

## 1. Core Principles

### Deterministic Execution

Tests must produce identical results across:
- Developer laptops (macOS, Linux, Windows)
- CI environments (GitHub Actions)
- Sandboxed environments (containers)

**Requirements:**
- No hard-coded ports (use ephemeral port allocation)
- Seed all randomness explicitly
- No undeclared timeouts
- No reliance on system state

### Capability Detection

Probe for required features before relying on them:

```rust
// Rust
fn requires_multithread() {
    if std::thread::available_parallelism().map(|p| p.get()).unwrap_or(1) < 2 {
        eprintln!("Skipping: requires 2+ threads");
        return;
    }
}
```

```python
# Python
import pytest
import os

def require_multithread():
    if os.cpu_count() < 2:
        pytest.skip("requires 2+ CPU cores")
```

### Isolated Cleanup

Register cleanup handlers to tear down resources:
- Temp directories
- Open file handles
- Thread pools

---

## 2. Test Fixture Strategy

### Fixture Categories

| Category | Size | Storage | Generation |
|----------|------|---------|------------|
| Small | <100KB | In-repo | Pre-generated, committed |
| Medium | 100KB-10MB | In-repo (LFS optional) | Script-generated, committed |
| Large | >10MB | Generated | Script-generated, not committed |

### Small Fixtures (Committed)

Small fixtures live in `tests/fixtures/` and are committed to the repository:

```
tests/fixtures/
├── hello.txt           # "Hello, World!" (14 bytes)
├── hello.szst          # Seekable-compressed hello.txt
├── lorem_4kb.txt       # Lorem ipsum (4KB)
├── lorem_4kb.szst      # 4KB compressed, single frame
├── multi_frame.szst    # 64KB across 4 frames (16KB each)
└── checksums.txt       # SHA256 of all fixtures
```

**Fixture spec (tests/fixtures/spec.yaml):**

```yaml
fixtures:
  - name: hello
    description: Minimal roundtrip test
    decompressed_size: 14
    frame_size: 1024
    frame_count: 1
    sha256_decompressed: 7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069

  - name: lorem_4kb
    description: Single-frame compression
    decompressed_size: 4096
    frame_size: 8192
    frame_count: 1
    sha256_decompressed: <computed>

  - name: multi_frame
    description: Multi-frame for parallel testing
    decompressed_size: 65536
    frame_size: 16384
    frame_count: 4
    sha256_decompressed: <computed>
```

### Large Fixtures (Generated)

Large fixtures are generated on-demand by a deterministic script:

```
scripts/generate-fixtures.sh
```

**Idempotent generation:**

```bash
#!/bin/bash
# scripts/generate-fixtures.sh
# Generates large test fixtures idempotently

set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures/generated}"
mkdir -p "$FIXTURES_DIR"

# Generate 1MB random but deterministic data
generate_deterministic() {
    local size=$1
    local seed=$2
    local output=$3

    # Use openssl with fixed seed for reproducibility
    openssl enc -aes-256-ctr -nosalt \
        -pass pass:"seekable-zstd-seed-$seed" \
        </dev/zero 2>/dev/null | head -c "$size" > "$output"
}

# 1MB fixture (generates ~1MB of deterministic "random" data)
if [[ ! -f "$FIXTURES_DIR/random_1mb.txt" ]]; then
    echo "Generating random_1mb.txt..."
    generate_deterministic 1048576 "1mb" "$FIXTURES_DIR/random_1mb.txt"
fi

# 10MB fixture
if [[ ! -f "$FIXTURES_DIR/random_10mb.txt" ]]; then
    echo "Generating random_10mb.txt..."
    generate_deterministic 10485760 "10mb" "$FIXTURES_DIR/random_10mb.txt"
fi

# Compress fixtures using our tool (once built)
if command -v seekable-zstd &> /dev/null; then
    for txt in "$FIXTURES_DIR"/*.txt; do
        szst="${txt%.txt}.szst"
        if [[ ! -f "$szst" ]]; then
            echo "Compressing $(basename "$txt")..."
            seekable-zstd compress --frame-size 262144 "$txt" "$szst"
        fi
    done
fi

echo "Fixtures ready in $FIXTURES_DIR"
```

**Rust equivalent (for bootstrapping):**

```rust
// crates/seekable-zstd-core/src/bin/gen-fixtures.rs

use std::io::Write;

fn main() {
    let seed: u64 = 0xDEADBEEF_CAFEBABE;
    let mut rng = make_deterministic_rng(seed);

    // Generate 1MB
    let data: Vec<u8> = (0..1_048_576).map(|_| rng.next_byte()).collect();

    std::fs::write("tests/fixtures/generated/random_1mb.txt", &data).unwrap();

    // Compress with seekable-zstd
    let compressed = seekable_zstd::compress(&data, 262144).unwrap();
    std::fs::write("tests/fixtures/generated/random_1mb.szst", &compressed).unwrap();
}
```

---

## 3. Parallel Testing

### Demonstrating Parallel Access

A key goal is proving parallel decompression works correctly and provides speedup.

**Parallel verification test:**

```rust
// tests/parallel_correctness.rs

use seekable_zstd::ParallelDecoder;
use rayon::prelude::*;
use std::time::Instant;

#[test]
fn parallel_ranges_match_sequential() {
    let decoder = ParallelDecoder::open("tests/fixtures/multi_frame.szst").unwrap();
    let size = decoder.size();

    // Define 4 ranges covering the entire file
    let ranges: Vec<(u64, u64)> = vec![
        (0, size / 4),
        (size / 4, size / 2),
        (size / 2, 3 * size / 4),
        (3 * size / 4, size),
    ];

    // Read sequentially
    let sequential: Vec<Vec<u8>> = ranges.iter()
        .map(|(start, end)| {
            let mut dec = Decoder::open("tests/fixtures/multi_frame.szst").unwrap();
            dec.read_range(*start, *end).unwrap()
        })
        .collect();

    // Read in parallel
    let parallel = decoder.read_ranges(&ranges).unwrap();

    // Verify identical results
    for (i, (seq, par)) in sequential.iter().zip(parallel.iter()).enumerate() {
        assert_eq!(seq, par, "Range {} differs between sequential and parallel", i);
    }
}

#[test]
fn parallel_shows_speedup() {
    let decoder = ParallelDecoder::open("tests/fixtures/generated/random_10mb.szst").unwrap();
    let size = decoder.size();

    // 16 ranges
    let ranges: Vec<(u64, u64)> = (0..16)
        .map(|i| {
            let start = size * i / 16;
            let end = size * (i + 1) / 16;
            (start, end)
        })
        .collect();

    // Time sequential
    let start = Instant::now();
    for (s, e) in &ranges {
        let mut dec = Decoder::open("tests/fixtures/generated/random_10mb.szst").unwrap();
        dec.read_range(*s, *e).unwrap();
    }
    let sequential_time = start.elapsed();

    // Time parallel
    let start = Instant::now();
    decoder.read_ranges(&ranges).unwrap();
    let parallel_time = start.elapsed();

    // On multi-core systems, parallel should be faster
    let cores = std::thread::available_parallelism().map(|p| p.get()).unwrap_or(1);
    if cores >= 4 {
        // Expect at least 2x speedup with 4+ cores
        assert!(
            parallel_time < sequential_time / 2,
            "Expected 2x+ speedup, got sequential={:?}, parallel={:?}",
            sequential_time, parallel_time
        );
    }

    println!(
        "Parallel speedup: {:.2}x (sequential={:?}, parallel={:?}, cores={})",
        sequential_time.as_secs_f64() / parallel_time.as_secs_f64(),
        sequential_time,
        parallel_time,
        cores
    );
}
```

### Cross-Language Parallel Tests

Each binding must verify parallel correctness:

**Go:**

```go
func TestParallelMatchesSequential(t *testing.T) {
    reader := openTestFile(t)
    defer reader.Close()

    size := reader.Size()
    ranges := [][2]uint64{
        {0, size / 4},
        {size / 4, size / 2},
        {size / 2, 3 * size / 4},
        {3 * size / 4, size},
    }

    // Sequential
    sequential := make([][]byte, len(ranges))
    for i, r := range ranges {
        data, err := reader.ReadRange(r[0], r[1])
        require.NoError(t, err)
        sequential[i] = data
    }

    // Parallel (via C FFI)
    parallel, err := reader.ReadRanges(ranges)
    require.NoError(t, err)

    for i := range ranges {
        assert.Equal(t, sequential[i], parallel[i], "Range %d mismatch", i)
    }
}
```

**Python:**

```python
def test_parallel_matches_sequential(sample_archive):
    with Reader(sample_archive) as reader:
        size = reader.size
        ranges = [
            (0, size // 4),
            (size // 4, size // 2),
            (size // 2, 3 * size // 4),
            (3 * size // 4, size),
        ]

        # Sequential
        sequential = [reader.read_range(s, e) for s, e in ranges]

        # Parallel
        parallel = reader.read_ranges(ranges)

        for i, (seq, par) in enumerate(zip(sequential, parallel)):
            assert seq == par, f"Range {i} differs"
```

---

## 4. Test Organization

### Directory Structure

```
tests/
├── fixtures/
│   ├── spec.yaml           # Fixture specifications
│   ├── checksums.txt       # SHA256 checksums
│   ├── hello.txt           # Minimal test data
│   ├── hello.szst
│   ├── lorem_4kb.txt
│   ├── lorem_4kb.szst
│   ├── multi_frame.szst    # For parallel tests
│   └── generated/          # Large fixtures (gitignored)
│       ├── random_1mb.txt
│       ├── random_1mb.szst
│       ├── random_10mb.txt
│       └── random_10mb.szst
│
├── unit/                   # Fast, isolated unit tests
│   ├── encoder_test.rs
│   ├── decoder_test.rs
│   └── seek_table_test.rs
│
├── integration/            # Cross-component tests
│   ├── roundtrip_test.rs
│   ├── parallel_test.rs
│   └── ffi_test.rs
│
└── benchmarks/             # Performance benchmarks
    ├── compression.rs
    ├── decompression.rs
    └── parallel.rs
```

### Makefile Integration

```makefile
# Generate test fixtures
.PHONY: fixtures
fixtures:
	./scripts/generate-fixtures.sh tests/fixtures/generated

# Run all tests (generates fixtures first)
.PHONY: test
test: fixtures
	cargo test
	cd bindings/go && go test ./...
	cd crates/seekable-zstd-py && maturin develop && pytest
	cd bindings/nodejs && npm test

# Run parallel-specific tests
.PHONY: test-parallel
test-parallel: fixtures
	cargo test parallel -- --nocapture
```

---

## 5. CI Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml

name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]

    steps:
      - uses: actions/checkout@v4

      - name: Install Rust
        uses: dtolnay/rust-action@stable

      - name: Generate fixtures
        run: |
          cargo build --release --bin gen-fixtures
          ./target/release/gen-fixtures

      - name: Run tests
        run: cargo test --all-features

      - name: Test parallel speedup
        run: cargo test parallel_shows_speedup -- --nocapture
        if: runner.os != 'Windows'  # Windows runners may be single-core
```

---

## 6. Fixture Verification

### Checksum Validation

All fixtures include checksums for integrity verification:

```
# tests/fixtures/checksums.txt
# SHA256 checksums for test fixtures
# Regenerate with: sha256sum tests/fixtures/*.txt tests/fixtures/*.szst

7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069  hello.txt
<checksum>  hello.szst
<checksum>  lorem_4kb.txt
<checksum>  lorem_4kb.szst
<checksum>  multi_frame.szst
```

**Verification in tests:**

```rust
#[test]
fn fixtures_match_expected_checksums() {
    let checksums = include_str!("../fixtures/checksums.txt");

    for line in checksums.lines() {
        if line.starts_with('#') || line.is_empty() {
            continue;
        }

        let parts: Vec<&str> = line.split_whitespace().collect();
        let expected_hash = parts[0];
        let filename = parts[1];

        let path = format!("tests/fixtures/{}", filename);
        let data = std::fs::read(&path).unwrap();
        let actual_hash = sha256_hex(&data);

        assert_eq!(
            expected_hash, actual_hash,
            "Checksum mismatch for {}", filename
        );
    }
}
```

---

*Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) portable testing practices.*
