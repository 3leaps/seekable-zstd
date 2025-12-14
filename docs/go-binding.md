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
- CGO enabled
