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

Expected directories (per release tag):

- `bindings/go/lib/darwin-amd64/`
- `bindings/go/lib/darwin-arm64/`
- `bindings/go/lib/linux-amd64/` (glibc)
- `bindings/go/lib/linux-arm64/` (glibc)
- `bindings/go/lib/linux-amd64-musl/` (musl)
- `bindings/go/lib/linux-arm64-musl/` (musl)

For local development, `make test-go` builds a fresh static library into `bindings/go/lib/local/<platform>/`.
The CGO flags prefer the `local/` directory first, so you can test changes without overwriting committed prebuilt artifacts.

### GitHub Release bundle (optional)

Each release tag also publishes a tarball containing the same `bindings/go/lib/**` tree:

- Asset name: `seekable-zstd-go-libs-vX.Y.Z.tar.gz`
- Includes: `bindings/go/lib/**`, `VERSION`, `MANIFEST.json`

Download example:

```bash
gh release download vX.Y.Z --repo 3leaps/seekable-zstd \
  --pattern "seekable-zstd-go-libs-vX.Y.Z.tar.gz"

tar -xzf seekable-zstd-go-libs-vX.Y.Z.tar.gz
```

Most Go users can ignore this and just use `go get github.com/3leaps/seekable-zstd/bindings/go@vX.Y.Z` (the prebuilt libs are committed in the repo at that tag).

## Build Requirements

- Go 1.21+
- Rust 1.88+ (if rebuilding from source)
- A C toolchain (because this is CGO)

CGO must be enabled (usually the default when a compiler toolchain is present):

```bash
export CGO_ENABLED=1
```

## Troubleshooting

- If you see “build constraints exclude all Go files” or similar, you likely have `CGO_ENABLED=0`. Enable CGO and install a compiler toolchain.
- If you see linker errors like `cannot find -lseekable_zstd_core` / `ld: library not found`, check that your `GOOS/GOARCH` has a matching directory under `bindings/go/lib/<platform>/`.
- On Alpine (musl), you must build with `-tags musl` (it uses `bindings/go/lib/linux-<arch>-musl/`).
- For local iteration on the Rust core, run `make test-go` to build a fresh lib into `bindings/go/lib/local/<platform>/`.

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
