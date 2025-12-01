# Rust Coding Standards

> Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) Rust standards.

This document establishes Rust-specific coding standards for seekable-zstd, building on the [cross-language standards](README.md).

---

## 1. Critical Rules

### 1.1 Rust Version (MSRV)

**Minimum Supported Rust Version:** 1.70

```toml
# Cargo.toml
[package]
rust-version = "1.70"
edition = "2021"
```

### 1.2 Output Hygiene

Use `tracing` for all diagnostic output:

```rust
use tracing::{debug, info, warn, error};

// Correct - goes to STDERR via tracing subscriber
debug!("Processing {} frames", frame_count);
info!(duration_ms = elapsed.as_millis(), "Decompression complete");

// WRONG - pollutes STDOUT
println!("DEBUG: Processing...");  // Never in library code
```

**Exception:** Binary entrypoints may use `println!` for final structured output.

### 1.3 No `unwrap()` or `expect()` in Library Code

```rust
// WRONG
let config = load_config(path).unwrap();

// CORRECT
let config = load_config(path)?;
let value = map.get("key").ok_or_else(|| Error::MissingKey("key"))?;

// Exception: Tests may use unwrap/expect with context
#[test]
fn test_decoder() {
    let decoder = Decoder::open(path).expect("test file should exist");
}
```

### 1.4 No Undocumented `unsafe`

```rust
// WRONG
unsafe { ptr::write(dest, value); }

// CORRECT
// SAFETY: `dest` is valid, aligned, and we have exclusive access via &mut self.
unsafe { ptr::write(dest, value); }
```

---

## 2. Code Organization

### 2.1 Project Structure

```
crates/seekable-zstd-core/
├── src/
│   ├── lib.rs          # Public API exports
│   ├── error.rs        # Error types (thiserror)
│   ├── encoder.rs      # Compression
│   ├── decoder.rs      # Decompression
│   ├── parallel.rs     # Parallel decompression
│   └── ffi.rs          # C FFI exports
├── benches/            # Criterion benchmarks
└── tests/              # Integration tests
```

### 2.2 Naming Conventions

- **Crates/Modules:** `snake_case` (`seekable_zstd`, `parallel_decoder`)
- **Types/Traits:** `PascalCase` (`Encoder`, `ParallelDecoder`)
- **Functions/Methods:** `snake_case` (`read_range`, `frame_count`)
- **Constants:** `SCREAMING_SNAKE_CASE` (`DEFAULT_FRAME_SIZE`)
- **Lifetimes:** Short lowercase (`'a`, `'de`)

### 2.3 Visibility

Use minimum visibility required:

```rust
pub struct Decoder<R> {           // Public API
    pub(crate) inner: Inner,      // Crate-internal
    buffer: Vec<u8>,              // Private
}
```

---

## 3. Error Handling

### 3.1 Use `thiserror`

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum Error {
    #[error("failed to read frame at offset {offset}")]
    FrameRead { offset: u64, source: std::io::Error },

    #[error("invalid seek table: {0}")]
    InvalidSeekTable(String),

    #[error("I/O error")]
    Io(#[from] std::io::Error),
}
```

### 3.2 Result Type Alias

```rust
pub type Result<T> = std::result::Result<T, Error>;

pub fn open(path: &Path) -> Result<Decoder<File>> {
    let file = File::open(path)?;
    Decoder::new(file)
}
```

### 3.3 Error Propagation

```rust
fn read_frame(&mut self, index: usize) -> Result<Vec<u8>> {
    let offset = self.seek_table.frame_offset(index)
        .ok_or_else(|| Error::InvalidFrameIndex(index))?;

    self.reader.seek(SeekFrom::Start(offset))?;
    // ...
}
```

---

## 4. Type Safety

### 4.1 Ownership and Borrowing

```rust
// Take ownership when storing
pub struct ParallelDecoder {
    path: PathBuf,  // Owned
}

// Borrow when only reading
impl ParallelDecoder {
    pub fn read_range(&self, start: u64, end: u64) -> Result<Vec<u8>> {
        // ...
    }
}

// Use Cow for flexible ownership
pub fn normalize(input: &str) -> Cow<'_, str> {
    if needs_normalization(input) {
        Cow::Owned(do_normalize(input))
    } else {
        Cow::Borrowed(input)
    }
}
```

### 4.2 Builder Pattern

```rust
#[derive(Debug, Default)]
pub struct EncoderBuilder {
    frame_size: Option<usize>,
    level: Option<i32>,
}

impl EncoderBuilder {
    pub fn new() -> Self { Self::default() }

    pub fn frame_size(mut self, size: usize) -> Self {
        self.frame_size = Some(size);
        self
    }

    pub fn level(mut self, level: i32) -> Self {
        self.level = Some(level);
        self
    }

    pub fn build<W: Write>(self, writer: W) -> Result<Encoder<W>> {
        let frame_size = self.frame_size.unwrap_or(DEFAULT_FRAME_SIZE);
        let level = self.level.unwrap_or(3);
        Encoder::with_options(writer, frame_size, level)
    }
}
```

---

## 5. Async and Concurrency

### 5.1 Use `rayon` for Parallel Decompression

```rust
use rayon::prelude::*;

impl ParallelDecoder {
    pub fn read_ranges(&self, ranges: &[(u64, u64)]) -> Result<Vec<Vec<u8>>> {
        ranges.par_iter()
            .map(|(start, end)| {
                let file = File::open(&self.path)?;
                let mut decoder = Decoder::new(file)?;
                decoder.read_range(*start, *end)
            })
            .collect()
    }
}
```

### 5.2 Send + Sync Bounds

Ensure types are thread-safe when needed:

```rust
// ParallelDecoder must be Send + Sync for use with rayon
static_assertions::assert_impl_all!(ParallelDecoder: Send, Sync);
```

---

## 6. Logging

### 6.1 Tracing Setup

```rust
use tracing::{debug, info, instrument, Level};
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

pub fn init_logging() {
    tracing_subscriber::registry()
        .with(fmt::layer().with_writer(std::io::stderr))
        .with(EnvFilter::from_default_env()
            .add_directive(Level::INFO.into()))
        .init();
}
```

### 6.2 Structured Logging

```rust
#[instrument(skip(self), fields(path = %self.path.display()))]
pub fn decompress_all(&self) -> Result<Vec<u8>> {
    info!(size = self.size(), frames = self.frame_count(), "Starting decompression");
    // ...
}
```

---

## 7. Testing

### 7.1 Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encoder_creates_valid_seekable_format() {
        let mut output = Vec::new();
        let mut encoder = Encoder::new(&mut output).unwrap();
        encoder.write_all(b"Hello, World!").unwrap();
        encoder.finish().unwrap();

        // Verify seek table exists
        assert!(output.len() > 13);
    }

    #[test]
    fn decoder_reads_back_original_data() {
        // ... roundtrip test
    }
}
```

### 7.2 Test Fixtures

```rust
fn fixtures_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

#[test]
fn decode_fixture_file() {
    let path = fixtures_dir().join("sample.szst");
    let decoder = Decoder::open(&path).expect("fixture should exist");
    assert_eq!(decoder.size(), 1024);
}
```

### 7.3 Property-Based Testing

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn roundtrip_preserves_data(data: Vec<u8>) {
        let compressed = compress(&data).unwrap();
        let decompressed = decompress(&compressed).unwrap();
        prop_assert_eq!(data, decompressed);
    }
}
```

---

## 8. Code Style

### 8.1 Rustfmt Configuration

```toml
# rustfmt.toml
edition = "2021"
max_width = 100
tab_spaces = 4
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
```

### 8.2 Clippy Configuration

```rust
// src/lib.rs
#![warn(clippy::all)]
#![warn(clippy::pedantic)]
#![allow(clippy::module_name_repetitions)]
```

### 8.3 Documentation

````rust
/// Decompresses a byte range from a seekable zstd archive.
///
/// This function opens the archive, seeks to the appropriate frame,
/// and decompresses only the requested range.
///
/// # Arguments
///
/// * `start` - Start offset in decompressed data
/// * `end` - End offset (exclusive) in decompressed data
///
/// # Returns
///
/// The decompressed bytes in the requested range.
///
/// # Errors
///
/// Returns an error if:
/// - The range is out of bounds
/// - The archive is corrupted
/// - An I/O error occurs
///
/// # Examples
///
/// ```
/// use seekable_zstd::Decoder;
///
/// let decoder = Decoder::open("archive.szst")?;
/// let bytes = decoder.read_range(1000, 2000)?;
/// assert_eq!(bytes.len(), 1000);
/// ```
pub fn read_range(&mut self, start: u64, end: u64) -> Result<Vec<u8>> {
    // ...
}
````

---

## 9. FFI Safety

### 9.1 C API Design

```rust
/// Opaque handle to a seekable decoder.
pub struct SeekableDecoder {
    inner: Box<Decoder<File>>,
}

/// Opens a seekable zstd archive.
///
/// Returns null on error. Call `seekable_last_error()` for details.
#[no_mangle]
pub extern "C" fn seekable_open(path: *const c_char) -> *mut SeekableDecoder {
    let path = match unsafe { CStr::from_ptr(path) }.to_str() {
        Ok(s) => s,
        Err(_) => {
            set_last_error("invalid UTF-8 in path");
            return std::ptr::null_mut();
        }
    };

    match Decoder::open(path) {
        Ok(decoder) => Box::into_raw(Box::new(SeekableDecoder {
            inner: Box::new(decoder),
        })),
        Err(e) => {
            set_last_error(&e.to_string());
            std::ptr::null_mut()
        }
    }
}

/// Frees a decoder handle.
#[no_mangle]
pub extern "C" fn seekable_close(decoder: *mut SeekableDecoder) {
    if !decoder.is_null() {
        // SAFETY: decoder was created by seekable_open via Box::into_raw
        unsafe { drop(Box::from_raw(decoder)); }
    }
}
```

---

## 10. Code Review Checklist

- [ ] MSRV 1.70+ compatible
- [ ] No `println!`/`print!` in library code
- [ ] No `unwrap()`/`expect()` in library code
- [ ] All `unsafe` has `// SAFETY:` comment
- [ ] Error types use `thiserror`
- [ ] Public API documented with examples
- [ ] Tests cover success and error paths
- [ ] `cargo fmt` produces no changes
- [ ] `cargo clippy -- -D warnings` passes

---

*Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) Rust standards.*
