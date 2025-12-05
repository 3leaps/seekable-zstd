# TypeScript Coding Standards

> Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) TypeScript standards.

This document establishes TypeScript-specific coding standards for the seekable-zstd napi-rs bindings, building on the [cross-language standards](README.md).

---

## 1. Critical Rules

### 1.1 No `any` Types

```typescript
// WRONG
function processData(data: any): any {}

// CORRECT
function processData(data: Buffer): Uint8Array {}
```

### 1.2 Output Hygiene

Use `console.error` for diagnostics, `console.log` only for structured output:

```typescript
// Correct
console.error("Processing", frameCount, "frames");

// For structured output only
console.log(JSON.stringify(result));

// WRONG in library code
console.log("DEBUG: Processing...");
```

### 1.3 Explicit Type Imports

```typescript
// WRONG
import { Reader, ReaderOptions } from "./reader";

// CORRECT
import { Reader } from "./reader";
import type { ReaderOptions } from "./reader";

// Or combined
import { Reader, type ReaderOptions } from "./reader";
```

---

## 2. Code Organization

### 2.1 Project Structure

```
bindings/nodejs/
├── package.json
├── tsconfig.json
├── src/
│   └── lib.rs          # napi-rs bindings
├── index.ts            # TypeScript wrapper
├── index.d.ts          # Type definitions
└── __tests__/
    └── reader.test.ts
```

### 2.2 Naming Conventions

- **Files:** `kebab-case.ts`
- **Classes:** `PascalCase`
- **Functions/Methods:** `camelCase`
- **Constants:** `UPPER_SNAKE_CASE`
- **Interfaces/Types:** `PascalCase`

---

## 3. API Design

### 3.1 Reader Class

````typescript
/**
 * Random access reader for seekable zstd archives.
 *
 * @example
 * ```typescript
 * const reader = new Reader("archive.szst");
 * const data = reader.readRange(1000n, 2000n);
 * console.log(`Read ${data.length} bytes`);
 * reader.close();
 * ```
 */
export class Reader {
  /**
   * Opens a seekable zstd archive.
   * @param path - Path to the archive file
   * @throws {Error} If the file cannot be opened or is not a valid archive
   */
  constructor(path: string);

  /** Decompressed size in bytes. */
  get size(): bigint;

  /** Number of compressed frames. */
  get frameCount(): bigint;

  /**
   * Reads decompressed bytes in the range [start, end).
   * @param start - Start offset (inclusive)
   * @param end - End offset (exclusive)
   * @returns Buffer containing decompressed data
   * @throws {RangeError} If range is out of bounds
   */
  readRange(start: bigint, end: bigint): Buffer;

  /**
   * Reads multiple ranges in parallel.
   * @param ranges - Array of [start, end] tuples
   * @returns Array of Buffers, one per input range
   */
  readRanges(ranges: Array<[bigint, bigint]>): Buffer[];

  /** Releases resources. Safe to call multiple times. */
  close(): void;
}
````

### 3.2 Use `bigint` for Large Values

Since file sizes and offsets can exceed `Number.MAX_SAFE_INTEGER`:

```typescript
// WRONG - may lose precision
readRange(start: number, end: number): Buffer

// CORRECT
readRange(start: bigint, end: bigint): Buffer
```

---

## 4. Error Handling

### 4.1 Custom Errors

```typescript
export class SeekableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SeekableError";
  }
}

export class InvalidArchiveError extends SeekableError {
  constructor(message: string) {
    super(message);
    this.name = "InvalidArchiveError";
  }
}

export class RangeError extends SeekableError {
  constructor(message: string) {
    super(message);
    this.name = "RangeError";
  }
}
```

### 4.2 Error Context

```typescript
readRange(start: bigint, end: bigint): Buffer {
  if (start < 0n) {
    throw new RangeError(`start must be >= 0, got ${start}`);
  }
  if (end > this.size) {
    throw new RangeError(
      `end (${end}) exceeds archive size (${this.size})`
    );
  }
  if (start >= end) {
    throw new RangeError(`invalid range: start (${start}) >= end (${end})`);
  }

  return this._native.readRange(start, end);
}
```

---

## 5. Testing

### 5.1 Test Organization

```typescript
import { describe, test, expect, beforeEach, afterEach } from "vitest";
import { Reader, RangeError } from "../index";

describe("Reader", () => {
  let reader: Reader;
  const testArchive = "tests/fixtures/sample.szst";

  beforeEach(() => {
    reader = new Reader(testArchive);
  });

  afterEach(() => {
    reader.close();
  });

  test("opens valid archive", () => {
    expect(reader.size).toBeGreaterThan(0n);
    expect(reader.frameCount).toBeGreaterThanOrEqual(1n);
  });

  test("reads range correctly", () => {
    const data = reader.readRange(0n, 100n);
    expect(data.length).toBe(100);
  });

  test("throws RangeError for out-of-bounds", () => {
    expect(() => {
      reader.readRange(0n, reader.size + 1000n);
    }).toThrow(RangeError);
  });
});
```

### 5.2 Async Testing

If providing async APIs:

```typescript
describe("Reader async", () => {
  test("reads range asynchronously", async () => {
    const reader = await Reader.openAsync(testArchive);
    const data = await reader.readRangeAsync(0n, 100n);
    expect(data.length).toBe(100);
    reader.close();
  });
});
```

---

## 6. Type Definitions

### 6.1 Comprehensive Types

```typescript
// index.d.ts

/** Options for creating a Reader. */
export interface ReaderOptions {
  /** Buffer size for decompression. Default: 64KB */
  bufferSize?: number;
}

/** Information about a compressed frame. */
export interface FrameInfo {
  /** Frame index (0-based) */
  index: number;
  /** Compressed size in bytes */
  compressedSize: bigint;
  /** Decompressed size in bytes */
  decompressedSize: bigint;
  /** Offset of frame in archive */
  offset: bigint;
}

export class Reader {
  constructor(path: string, options?: ReaderOptions);
  get size(): bigint;
  get frameCount(): bigint;
  getFrameInfo(index: number): FrameInfo;
  readRange(start: bigint, end: bigint): Buffer;
  readRanges(ranges: Array<[bigint, bigint]>): Buffer[];
  close(): void;
}
```

---

## 7. Code Style

### 7.1 ESLint/Biome Configuration

```json
{
  "extends": ["eslint:recommended", "plugin:@typescript-eslint/recommended"],
  "rules": {
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/explicit-function-return-type": "warn"
  }
}
```

### 7.2 Prettier Configuration

```json
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "printWidth": 100
}
```

---

## 8. Documentation

### 8.1 JSDoc Comments

````typescript
/**
 * Reads multiple byte ranges in parallel.
 *
 * Decompresses multiple ranges concurrently using all available
 * CPU cores. More efficient than sequential readRange() calls
 * for large numbers of ranges.
 *
 * @param ranges - Array of [start, end] tuples. Each range is half-open.
 * @returns Array of Buffers, one per input range, in the same order.
 * @throws {RangeError} If any range extends beyond archive size.
 *
 * @example
 * ```typescript
 * const reader = new Reader("large.szst");
 * const chunks = reader.readRanges([
 *   [0n, 1024n],
 *   [4096n, 8192n],
 * ]);
 * console.log(`Got ${chunks.length} chunks`);
 * reader.close();
 * ```
 */
readRanges(ranges: Array<[bigint, bigint]>): Buffer[];
````

---

## 9. Code Review Checklist

- [ ] No `any` types
- [ ] Explicit type imports
- [ ] No `console.log` for diagnostics
- [ ] `bigint` for large values
- [ ] Custom error classes with context
- [ ] Complete type definitions
- [ ] JSDoc on public API
- [ ] Tests cover success and error cases
- [ ] ESLint/Biome passes
- [ ] TypeScript strict mode passes

---

_Adapted from [FulmenHQ Crucible](https://github.com/fulmenhq/crucible) TypeScript standards._
