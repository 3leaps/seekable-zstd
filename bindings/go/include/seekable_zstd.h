#ifndef SEEKABLE_ZSTD_H
#define SEEKABLE_ZSTD_H

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#define DEFAULT_FRAME_SIZE (256 * 1024)

typedef struct SeekableDecoder SeekableDecoder;

typedef struct SeekableEncoder SeekableEncoder;

/**
 * Opens a seekable zstd archive.
 *
 * # Safety
 * `path` must be a valid null-terminated C string.
 * The returned pointer must be freed with `seekable_close`.
 */
struct SeekableDecoder *seekable_open(const char *path);

/**
 * Creates a new seekable zstd encoder that writes to a file.
 *
 * `frame_size == 0` uses the default frame size (256KiB).
 *
 * # Safety
 * `path` must be a valid null-terminated C string.
 * The returned pointer must be freed with `seekable_encoder_close` or
 * consumed by `seekable_encoder_finish`.
 */
struct SeekableEncoder *seekable_encoder_new(const char *path, uint32_t frame_size);

/**
 * Writes data to the encoder.
 *
 * Returns `0` on success; negative values indicate an error.
 *
 * # Safety
 * `encoder` must be a valid pointer returned by `seekable_encoder_new`.
 * `data` must point to a buffer of at least `len` bytes.
 */
int32_t seekable_encoder_write(struct SeekableEncoder *encoder, const uint8_t *data, uintptr_t len);

/**
 * Finishes the stream, writes the seek table, and closes the file.
 *
 * Returns the number of bytes written (compressed size) on success, or a
 * negative value on error.
 *
 * # Safety
 * `encoder` must be a valid pointer returned by `seekable_encoder_new`.
 * After calling this, the encoder is consumed and the pointer is invalid.
 */
int64_t seekable_encoder_finish(struct SeekableEncoder *encoder);

/**
 * Closes the encoder without finishing (aborts).
 *
 * Best-effort safety: truncates the output file to `0` bytes after releasing
 * resources, to avoid leaving an invalid partial archive on disk.
 *
 * # Safety
 * `encoder` must be a valid pointer returned by `seekable_encoder_new`.
 */
void seekable_encoder_close(struct SeekableEncoder *encoder);

/**
 * Returns the total decompressed size of the archive.
 *
 * # Safety
 * `decoder` must be a valid pointer returned by `seekable_open`.
 */
uint64_t seekable_size(const struct SeekableDecoder *decoder);

/**
 * Returns the number of frames in the archive.
 *
 * # Safety
 * `decoder` must be a valid pointer returned by `seekable_open`.
 */
uint64_t seekable_frame_count(const struct SeekableDecoder *decoder);

/**
 * Reads a range of bytes from the archive.
 *
 * # Safety
 * `decoder` must be a valid pointer returned by `seekable_open`.
 * `out_data` must point to a buffer of at least `*out_len` bytes.
 * `out_len` must be a valid pointer to a `size_t`.
 */
int32_t seekable_read_range(struct SeekableDecoder *decoder,
                            uint64_t start,
                            uint64_t end,
                            uint8_t *out_data,
                            uintptr_t *out_len);

/**
 * Reads multiple ranges in parallel.
 *
 * # Safety
 * `decoder` must be a valid pointer returned by `seekable_open`.
 * `starts` and `ends` must point to arrays of `count` u64 values.
 * `out_buffers` must point to an array of `count` buffer pointers.
 * `out_lengths` must point to an array of `count` `size_t` values.
 */
int32_t seekable_read_ranges(const struct SeekableDecoder *decoder,
                             const uint64_t *starts,
                             const uint64_t *ends,
                             uintptr_t count,
                             uint8_t **out_buffers,
                             uintptr_t *out_lengths);

/**
 * Closes the decoder and frees resources.
 *
 * # Safety
 * `decoder` must be a valid pointer returned by `seekable_open`.
 */
void seekable_close(struct SeekableDecoder *decoder);

/**
 * Returns the last error message.
 *
 * # Safety
 * Thread-safe. Returns a pointer to a thread-local C string.
 * The string is valid until the next error occurs on this thread.
 */
const char *seekable_last_error(void);

#endif  /* SEEKABLE_ZSTD_H */
