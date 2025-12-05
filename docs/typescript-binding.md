# Node.js Binding for seekable-zstd

This package provides native Node.js bindings for `seekable-zstd`.

## Installation

```bash
npm install seekable-zstd
```

## Usage

```javascript
const { Reader } = require("seekable-zstd");

const reader = new Reader("archive.szst");
try {
  console.log(`Decompressed size: ${reader.size}`);

  // Read first 100 bytes
  const data = reader.readRange(0, 100);
  console.log(data.toString());
} finally {
  // Resources are managed by GC, but explicit cleanup is good practice if implemented
}
```

## API

### `new Reader(path)`

Opens a seekable zstd archive.

### `reader.size` (Number)

Returns the total decompressed size (as i64, safe up to 9 exabytes).

### `reader.frameCount` (Number)

Returns the number of frames.

### `reader.readRange(start, end)`

Reads bytes from `start` (inclusive) to `end` (exclusive).
Returns a `Buffer`.
