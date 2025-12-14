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
Pre-built static libraries are included under `bindings/go/lib/<platform>/`.

For local development, `make test-go` builds a fresh static library into `bindings/go/lib/local/<platform>/`.
The CGO flags prefer the `local/` directory first, so you can test changes without overwriting committed prebuilt artifacts.

## Build Requirements

- Go 1.21+
- Rust 1.70+ (if rebuilding from source)
- A C toolchain (because this is CGO)

CGO must be enabled (usually the default when a compiler toolchain is present):

```bash
export CGO_ENABLED=1
```

## Linux (glibc vs musl)

We ship two Linux flavors of the prebuilt static library:

- `linux-*-*` (glibc, built for compatibility with glibc 2.17+)
- `linux-*-*-musl` (musl, for Alpine-style environments)

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
