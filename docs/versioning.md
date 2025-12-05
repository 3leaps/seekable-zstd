# Versioning

`seekable-zstd` follows [Semantic Versioning 2.0.0](https://semver.org/).

A single version number (defined in the `VERSION` file at the root) is synchronized across all language bindings.

## How to Check the Version

### CLI
Check the root `VERSION` file:
```bash
cat VERSION
```

### Go
The library exposes a `Version()` function:
```go
import seekable "github.com/3leaps/seekable-zstd/bindings/go"

fmt.Println(seekable.Version())
```

### Python
Use the standard `__version__` attribute:
```python
import seekable_zstd
print(seekable_zstd.__version__)
```

### Node.js / TypeScript
Read the version from the package manifest:
```javascript
const version = require('seekable-zstd/package.json').version;
console.log(version);
```

### Rust
Use the standard Cargo version environment variable (compile-time) or inspect `Cargo.toml`.

## Release Process

We use `make` targets to handle version bumping and synchronization across all languages:

```bash
make bump-patch  # 0.1.0 -> 0.1.1
make bump-minor  # 0.1.0 -> 0.2.0
make bump-major  # 0.1.0 -> 1.0.0
```

This updates:
- `VERSION` file
- `crates/seekable-zstd-core/Cargo.toml`
- `crates/seekable-zstd-py/Cargo.toml` & `pyproject.toml`
- `bindings/nodejs/Cargo.toml` & `package.json`
- `bindings/go/seekable.go` (Version constant)
