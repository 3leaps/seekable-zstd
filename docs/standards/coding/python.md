# Python Coding Standards

> Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) Python standards.

This document establishes Python-specific coding standards for the seekable-zstd PyO3 bindings, building on the [cross-language standards](README.md).

---

## 1. Critical Rules

### 1.1 Python Version

**Minimum:** Python 3.10+

```toml
# pyproject.toml
requires-python = ">=3.10"
```

### 1.2 Type Hints Required

All public functions must have complete type hints:

```python
# WRONG
def read_range(self, start, end):
    return self._inner.read_range(start, end)

# CORRECT
def read_range(self, start: int, end: int) -> bytes:
    """Read decompressed bytes in range [start, end)."""
    return self._inner.read_range(start, end)
```

### 1.3 Output Hygiene

Use `logging` for diagnostics:

```python
import logging

logger = logging.getLogger(__name__)

# Correct
logger.debug("Processing %d frames", frame_count)

# WRONG
print(f"DEBUG: Processing {frame_count} frames")
```

---

## 2. Code Organization

### 2.1 Project Structure

```
crates/seekable-zstd-py/
├── Cargo.toml
├── pyproject.toml
├── src/
│   └── lib.rs          # PyO3 bindings
├── python/
│   └── seekable_zstd/
│       ├── __init__.py # Python API re-exports
│       └── py.typed    # PEP 561 marker
└── tests/
    └── test_reader.py
```

### 2.2 Naming Conventions

- **Modules/Packages:** `snake_case` (`seekable_zstd`)
- **Classes:** `PascalCase` (`Reader`, `FrameInfo`)
- **Functions/Methods:** `snake_case` (`read_range`, `frame_count`)
- **Constants:** `UPPER_SNAKE_CASE` (`DEFAULT_FRAME_SIZE`)

---

## 3. API Design

### 3.1 Reader Class

```python
class Reader:
    """Random access reader for seekable zstd archives.

    Example:
        >>> reader = Reader("archive.szst")
        >>> data = reader.read_range(1000, 2000)
        >>> print(f"Read {len(data)} bytes")
        >>> reader.close()

    Or as context manager:
        >>> with Reader("archive.szst") as reader:
        ...     data = reader.read_range(1000, 2000)
    """

    def __init__(self, path: str | os.PathLike[str]) -> None:
        """Open a seekable zstd archive."""
        ...

    @property
    def size(self) -> int:
        """Decompressed size in bytes."""
        ...

    @property
    def frame_count(self) -> int:
        """Number of compressed frames."""
        ...

    def read_range(self, start: int, end: int) -> bytes:
        """Read decompressed bytes in range [start, end)."""
        ...

    def read_ranges(self, ranges: list[tuple[int, int]]) -> list[bytes]:
        """Read multiple ranges in parallel."""
        ...

    def close(self) -> None:
        """Release resources."""
        ...

    def __enter__(self) -> "Reader":
        return self

    def __exit__(self, *args: object) -> None:
        self.close()
```

### 3.2 Context Manager Support

Always implement context manager protocol:

```python
# Enable this usage pattern
with Reader("archive.szst") as reader:
    data = reader.read_range(0, 1024)
# Resources automatically released
```

---

## 4. Error Handling

### 4.1 Custom Exceptions

```python
class SeekableError(Exception):
    """Base exception for seekable-zstd errors."""

class InvalidArchiveError(SeekableError):
    """Raised when archive format is invalid."""

class RangeError(SeekableError):
    """Raised when requested range is invalid."""
```

### 4.2 Error Context

```python
def read_range(self, start: int, end: int) -> bytes:
    if start < 0:
        raise ValueError(f"start must be >= 0, got {start}")
    if end > self.size:
        raise RangeError(
            f"end ({end}) exceeds archive size ({self.size})"
        )
    if start >= end:
        raise ValueError(f"invalid range: start ({start}) >= end ({end})")

    return self._inner.read_range(start, end)
```

---

## 5. Testing

### 5.1 pytest Conventions

```python
import pytest
from seekable_zstd import Reader, RangeError

def test_reader_opens_valid_archive(tmp_path):
    """Test opening a valid seekable archive."""
    archive = tmp_path / "test.szst"
    create_test_archive(archive)

    reader = Reader(archive)
    assert reader.size > 0
    assert reader.frame_count >= 1
    reader.close()

def test_reader_context_manager(tmp_path):
    """Test context manager properly releases resources."""
    archive = tmp_path / "test.szst"
    create_test_archive(archive)

    with Reader(archive) as reader:
        assert reader.size > 0

def test_read_range_out_of_bounds(tmp_path):
    """Test that out-of-bounds range raises RangeError."""
    archive = tmp_path / "test.szst"
    create_test_archive(archive)

    with Reader(archive) as reader:
        with pytest.raises(RangeError, match="exceeds archive size"):
            reader.read_range(0, reader.size + 1000)
```

### 5.2 Fixtures

```python
@pytest.fixture
def sample_archive(tmp_path):
    """Create a sample seekable archive for testing."""
    archive = tmp_path / "sample.szst"
    create_test_archive(archive, size=10240)
    return archive

def test_roundtrip(sample_archive):
    """Test compression/decompression roundtrip."""
    with Reader(sample_archive) as reader:
        data = reader.read_range(0, reader.size)
        assert len(data) == reader.size
```

---

## 6. Documentation

### 6.1 Docstrings (Google Style)

```python
def read_ranges(self, ranges: list[tuple[int, int]]) -> list[bytes]:
    """Read multiple byte ranges in parallel.

    Decompresses multiple ranges concurrently using all available
    CPU cores. More efficient than sequential read_range() calls
    for large numbers of ranges.

    Args:
        ranges: List of (start, end) tuples defining byte ranges.
            Each range is half-open: [start, end).

    Returns:
        List of bytes objects, one per input range, in the same order.

    Raises:
        RangeError: If any range extends beyond archive size.
        ValueError: If any start >= end.

    Example:
        >>> with Reader("large.szst") as r:
        ...     chunks = r.read_ranges([(0, 1024), (4096, 8192)])
        ...     print(f"Got {len(chunks)} chunks")
        Got 2 chunks
    """
```

---

## 7. Code Style

### 7.1 Ruff Configuration

```toml
# ruff.toml
line-length = 100
target-version = "py310"

[lint]
select = ["E", "F", "B", "I", "UP", "C4", "SIM"]
```

### 7.2 Type Checking

```toml
# pyproject.toml
[tool.mypy]
python_version = "3.10"
strict = true
```

---

## 8. Code Review Checklist

- [ ] Python 3.10+ compatible
- [ ] Complete type hints on public API
- [ ] No `print()` in library code
- [ ] Custom exceptions with context
- [ ] Context manager implemented
- [ ] Docstrings on public API
- [ ] Tests cover success and error cases
- [ ] `ruff check` passes
- [ ] `mypy` passes (if configured)

---

*Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) Python standards.*
