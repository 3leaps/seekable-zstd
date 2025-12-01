# Coding Standards

> These standards are adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) coding standards, simplified for community library use.

This document establishes language-agnostic coding standards that apply to seekable-zstd regardless of implementation language. These patterns ensure consistency, reliability, and interoperability across the library and its bindings.

**Language-Specific Standards:**
- [Rust](rust.md) - Core library
- [Go](go.md) - CGO bindings
- [Python](python.md) - PyO3 bindings
- [TypeScript](typescript.md) - napi-rs bindings

---

## 1. Output Hygiene

### STDERR for Logs, STDOUT for Data

All diagnostic output (logs, debug info, status messages) goes to STDERR. STDOUT is reserved for structured data output.

**Why:**
- Pipelines expect clean data on STDOUT
- CI/CD tools parse STDOUT for results
- STDERR can be suppressed/redirected independently
- Unix philosophy: data flows through STDOUT

```rust
// Rust - use tracing
tracing::info!("Processing {} bytes", size);

// Go - use log package (writes to STDERR)
log.Printf("Processing %d bytes", size)

// Python - use logging
logger.info("Processing %d bytes", size)

// TypeScript - use console.error for diagnostics
console.error("Processing", size, "bytes");
console.log(JSON.stringify(result));  // STDOUT for data only
```

---

## 2. Timestamps

### RFC3339 Format (Required)

All timestamps use RFC3339 format with timezone information.

**Format:** `YYYY-MM-DDTHH:MM:SSZ` or `YYYY-MM-DDTHH:MM:SS±HH:MM`

```rust
// Rust
use chrono::Utc;
let timestamp = Utc::now().to_rfc3339();

// Go
timestamp := time.Now().Format(time.RFC3339)

// Python
from datetime import datetime, timezone
timestamp = datetime.now(timezone.utc).isoformat()

// TypeScript
const timestamp = new Date().toISOString();
```

**Do NOT use:** Unix timestamps, locale-specific formats, ambiguous formats without timezone.

---

## 3. Error Handling

### Error Context

Errors include context about what operation failed and why.

```rust
// Rust
return Err(Error::Io {
    path: path.to_owned(),
    source: e,
    message: "failed to open seekable archive".into(),
});

// Go
return fmt.Errorf("failed to open %s: %w", path, err)

// Python
raise SeekableError(f"Failed to open {path}") from err

// TypeScript
throw new SeekableError(`Failed to open ${path}: ${error.message}`);
```

### CLI Exit Codes

| Code | Meaning              | Usage                            |
|------|----------------------|----------------------------------|
| 0    | Success              | Operation completed successfully |
| 1    | General error        | Catch-all for general errors     |
| 2    | Misuse               | Invalid command-line arguments   |
| 3    | Configuration error  | Invalid or missing configuration |
| 4    | Input error          | Invalid input data or file       |
| 5    | Output error         | Cannot write output              |

---

## 4. Logging Standards

### Log Levels

| Level | Usage                        | Example                               |
|-------|------------------------------|---------------------------------------|
| DEBUG | Detailed diagnostic info     | "Opening file: /path/to/file.szst"    |
| INFO  | General operational messages | "Decompressed 1.2GB in 3.4s"          |
| WARN  | Non-fatal issues             | "Frame size smaller than recommended" |
| ERROR | Failures needing attention   | "Failed to read seek table"           |

### Structured Context

Include relevant context in log messages:

```rust
tracing::info!(
    bytes = decompressed_size,
    frames = frame_count,
    duration_ms = elapsed.as_millis(),
    "Decompression complete"
);
```

---

## 5. Security

### Input Validation

Validate and sanitize all external input:
- File paths (prevent path traversal)
- Byte ranges (prevent out-of-bounds access)
- Frame sizes (prevent excessive memory allocation)

### No Hardcoded Secrets

Never hardcode credentials, API keys, or tokens in source code.

---

## 6. Versioning

### Semantic Versioning

Use SemVer: `MAJOR.MINOR.PATCH`

- **MAJOR:** Breaking API changes
- **MINOR:** New features, backward compatible
- **PATCH:** Bug fixes, backward compatible

Keep versions synchronized across:
- `Cargo.toml` (Rust)
- `go.mod` (Go)
- `pyproject.toml` (Python)
- `package.json` (TypeScript)

---

## 7. Testing

### Coverage Requirements

- Public API: 90%+ coverage
- Critical paths (compression/decompression): 100% coverage
- Error handling: Test failure cases

### Test Organization

```
tests/
├── unit/          # Fast, isolated tests
├── integration/   # Cross-component tests
└── fixtures/      # Shared test data
```

### Shared Fixtures

Test fixtures in `tests/fixtures/` ensure identical behavior across all language bindings. Each binding should validate against the same test cases.

---

## 8. Documentation

### README Requirements

Every package/binding needs:
- Brief description
- Installation instructions
- Quick start example
- API reference or link to docs

### Code Documentation

Public APIs require:
- Purpose description
- Parameter documentation
- Return value documentation
- Error conditions
- Usage example

---

## 9. Code Review Checklist

Before submitting code:

- [ ] No diagnostic output to STDOUT
- [ ] Timestamps use RFC3339
- [ ] Errors include context
- [ ] Exit codes follow convention
- [ ] No hardcoded secrets
- [ ] Input validated
- [ ] Tests cover happy path and errors
- [ ] Public API documented
- [ ] Version sync maintained

---

*Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) coding standards.*
