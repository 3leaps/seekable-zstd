# Go Coding Standards

> Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) Go standards.

This document establishes Go-specific coding standards for the seekable-zstd CGO bindings, building on the [cross-language standards](README.md).

---

## 1. Critical Rules

### 1.1 Output Hygiene

Use `log` package for diagnostics (writes to STDERR):

```go
import "log"

// Correct - goes to STDERR
log.Printf("Processing %d frames", frameCount)

// WRONG - pollutes STDOUT
fmt.Printf("DEBUG: Processing...\n")
```

### 1.2 Error Handling

Always handle errors explicitly:

```go
// WRONG
result, _ := decoder.ReadRange(start, end)

// CORRECT
result, err := decoder.ReadRange(start, end)
if err != nil {
    return nil, fmt.Errorf("reading range [%d, %d): %w", start, end, err)
}
```

### 1.3 CGO Safety

Check all pointers from C:

```go
func Open(path string) (*Reader, error) {
    cPath := C.CString(path)
    defer C.free(unsafe.Pointer(cPath))

    ptr := C.seekable_open(cPath)
    if ptr == nil {
        return nil, errors.New(C.GoString(C.seekable_last_error()))
    }

    return &Reader{ptr: ptr}, nil
}
```

---

## 2. Code Organization

### 2.1 Project Structure

```
bindings/go/
├── go.mod
├── go.sum
├── seekable.go         # Main API
├── seekable_test.go    # Tests
├── include/
│   └── seekable_zstd.h # C header
└── lib/
    ├── linux-amd64/
    ├── linux-arm64/
    ├── darwin-amd64/
    ├── darwin-arm64/
    └── windows-amd64/
```

### 2.2 Naming Conventions

- **Types:** `PascalCase` (`Reader`, `FrameInfo`)
- **Functions:** `PascalCase` for exported, `camelCase` for internal
- **Constants:** `PascalCase` for exported
- **Files:** `snake_case.go`

---

## 3. API Design

### 3.1 Reader Interface

```go
package seekable

// Reader provides random access to seekable zstd archives.
type Reader struct {
    ptr *C.SeekableDecoder
}

// Open opens a seekable zstd archive for reading.
func Open(path string) (*Reader, error)

// Size returns the decompressed size in bytes.
func (r *Reader) Size() uint64

// FrameCount returns the number of compressed frames.
func (r *Reader) FrameCount() uint64

// ReadRange reads decompressed bytes in the range [start, end).
func (r *Reader) ReadRange(start, end uint64) ([]byte, error)

// Close releases resources. Safe to call multiple times.
func (r *Reader) Close()
```

### 3.2 Resource Management

Implement `Close()` and consider `io.Closer`:

```go
func (r *Reader) Close() {
    if r.ptr != nil {
        C.seekable_close(r.ptr)
        r.ptr = nil
    }
}

// Ensure Reader implements io.Closer
var _ io.Closer = (*Reader)(nil)
```

---

## 4. Error Handling

### 4.1 Error Wrapping

```go
func (r *Reader) ReadRange(start, end uint64) ([]byte, error) {
    if start >= end {
        return nil, fmt.Errorf("invalid range: start (%d) >= end (%d)", start, end)
    }

    if end > r.Size() {
        return nil, fmt.Errorf("range end (%d) exceeds size (%d)", end, r.Size())
    }

    // ... C call ...

    if result < 0 {
        return nil, fmt.Errorf("read failed: %s", C.GoString(C.seekable_last_error()))
    }

    return data, nil
}
```

---

## 5. Testing

### 5.1 Table-Driven Tests

```go
func TestReader_ReadRange(t *testing.T) {
    tests := []struct {
        name    string
        start   uint64
        end     uint64
        wantLen int
        wantErr bool
    }{
        {"valid range", 0, 100, 100, false},
        {"zero length", 50, 50, 0, true},
        {"out of bounds", 0, 999999, 0, true},
    }

    reader := openTestFile(t)
    defer reader.Close()

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := reader.ReadRange(tt.start, tt.end)
            if (err != nil) != tt.wantErr {
                t.Errorf("ReadRange() error = %v, wantErr %v", err, tt.wantErr)
            }
            if len(got) != tt.wantLen {
                t.Errorf("ReadRange() len = %d, want %d", len(got), tt.wantLen)
            }
        })
    }
}
```

### 5.2 Benchmarks

```go
func BenchmarkReader_ReadRange(b *testing.B) {
    reader := openTestFile(b)
    defer reader.Close()

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _, _ = reader.ReadRange(0, 1024)
    }
}
```

---

## 6. Documentation

### 6.1 Package Documentation

```go
// Package seekable provides Go bindings for seekable zstd archives.
//
// Seekable zstd enables random access into compressed data, allowing
// efficient extraction of arbitrary byte ranges without decompressing
// the entire file.
//
// Basic usage:
//
//     reader, err := seekable.Open("archive.szst")
//     if err != nil {
//         log.Fatal(err)
//     }
//     defer reader.Close()
//
//     data, err := reader.ReadRange(1000, 2000)
//     if err != nil {
//         log.Fatal(err)
//     }
//     fmt.Printf("Read %d bytes\n", len(data))
package seekable
```

---

## 7. Code Review Checklist

- [ ] All errors handled explicitly
- [ ] CGO pointers checked for null
- [ ] Resources cleaned up with `Close()`
- [ ] No `fmt.Print*` in library code
- [ ] Error messages include context
- [ ] Public API documented
- [ ] Tests cover success and error cases
- [ ] `go fmt` produces no changes
- [ ] `go vet` passes

---

*Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) Go standards.*
