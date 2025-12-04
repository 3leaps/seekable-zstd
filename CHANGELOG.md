# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-04

### Added

- **Rust Core**: Initial implementation of seekable zstd compression (`seekable-zstd-core`).
  - `Encoder` supporting independent frames.
  - `Decoder` and `ParallelDecoder` for random access and parallel decompression.
  - C FFI layer for binding support.
- **Go Bindings**: CGO wrapper (`github.com/3leaps/seekable-zstd/bindings/go`).
  - Cross-platform static linking support.
  - `Reader` interface for seekable access.
- **Python Bindings**: PyO3 wrapper (`seekable-zstd`).
  - Python 3.10+ support.
  - `read_ranges` for parallel extraction.
- **Node.js Bindings**: napi-rs wrapper (`seekable-zstd`).
  - Cross-platform support.
  - Native `Reader` class.
- **DevSecOps**:
  - CI workflow (`.github/workflows/ci.yml`).
  - `goneat` quality gates and hooks.
  - Comprehensive test suite with shared fixtures.
