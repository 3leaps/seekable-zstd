#ifndef SEEKABLE_ZSTD_H
#define SEEKABLE_ZSTD_H

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#define DEFAULT_FRAME_SIZE (256 * 1024)

typedef struct SeekableDecoder SeekableDecoder;

/**
 * Opens a seekable zstd archive.
 *
 * # Safety
 * `path` must be a valid null-terminated C string.
 * The returned pointer must be freed with `seekable_close`.
 */
struct SeekableDecoder *seekable_open(const char *path);

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
 * `out_lengths` must point to an array of `count` size_t values.
 * Each `out_buffers[i]` must point to a buffer of at least `out_lengths[i]` bytes.
 * On success, `out_lengths[i]` is updated to the actual bytes written.
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
