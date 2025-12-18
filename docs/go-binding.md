# Go Binding for seekable-zstd

This package provides CGO-based bindings for `seekable-zstd`.

## Installation

```bash
go get github.com/3leaps/seekable-zstd/bindings/go
```

## Usage

```go
package main

import (
	"fmt"
	"log"

	"github.com/3leaps/seekable-zstd/bindings/go"
)

func main() {
	reader, err := seekable.Open("archive.szst")
	if err != nil {
		log.Fatal(err)
	}
	defer reader.Close()

	// Read first 100 bytes
	data, err := reader.ReadRange(0, 100)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("Read %d bytes\n", len(data))
}
```

## Architecture

The Go binding wraps the Rust static library via CGO.

### Prebuilt library layout

Pre-built static libraries are included under `bindings/go/lib/<platform>/`.

Naming conventions:

- **Linux glibc** is the default and uses `linux-<arch>/`.
- **Linux musl** uses the explicit `linux-<arch>-musl/` suffix.
- musl vs glibc selection is **not auto-detected** at build time; musl is an explicit Go build tag.

Expected directories for v0.1.0:

- `bindings/go/lib/darwin-amd64/`
- `bindings/go/lib/darwin-arm64/`
- `bindings/go/lib/linux-amd64/` (glibc)
- `bindings/go/lib/linux-arm64/` (glibc)
- `bindings/go/lib/linux-amd64-musl/` (musl)
- `bindings/go/lib/linux-arm64-musl/` (musl)

For local development, `make test-go` builds a fresh static library into `bindings/go/lib/local/<platform>/`.
The CGO flags prefer the `local/` directory first, so you can test changes without overwriting committed prebuilt artifacts.

## Build Requirements

- Go 1.21+
- Rust 1.88+ (if rebuilding from source)
- A C toolchain (because this is CGO)

CGO must be enabled (usually the default when a compiler toolchain is present):

```bash
export CGO_ENABLED=1
```

## Linux (glibc vs musl)

We ship two Linux flavors of the prebuilt static library:

- `linux-<arch>/` (glibc, built for compatibility with glibc 2.17+)
- `linux-<arch>-musl/` (musl, for Alpine-style environments)

Glibc is the implied default in the path. Musl is an explicit suffix.

Go does **not** automatically select the `musl` build tag. If you are building in an Alpine/musl container, you must enable it:

```bash
# Alpine example
apk add --no-cache build-base

cd bindings/go
CGO_ENABLED=1 go test -tags musl ./...
```

Or via the repo Makefile (Linux only):

```bash
make test-go-musl
```
