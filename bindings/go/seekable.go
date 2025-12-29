package seekable

/*
#include "include/seekable_zstd.h"
*/
import "C"
import (
	"errors"
	"fmt"
	"io"
	"unsafe"
)

// Version returns the current library version.
func Version() string {
	return "0.1.2"
}

// Reader provides random access to seekable zstd archives.
type Reader struct {
	ptr *C.SeekableDecoder
}

// Encoder writes seekable zstd archives.
type Encoder struct {
	ptr *C.SeekableEncoder
}

// Open opens a seekable zstd archive for reading.
func Open(path string) (*Reader, error) {
	cPath := C.CString(path)
	defer C.free(unsafe.Pointer(cPath))

	ptr := C.seekable_open(cPath)
	if ptr == nil {
		errStr := C.seekable_last_error()
		if errStr == nil {
			return nil, errors.New("unknown error")
		}
		return nil, errors.New(C.GoString(errStr))
	}

	return &Reader{ptr: ptr}, nil
}

// NewEncoder creates a new encoder that writes to a file.
// frameSize of 0 uses the default (256KiB).
func NewEncoder(path string, frameSize uint32) (*Encoder, error) {
	cPath := C.CString(path)
	defer C.free(unsafe.Pointer(cPath))

	ptr := C.seekable_encoder_new(cPath, C.uint32_t(frameSize))
	if ptr == nil {
		errStr := C.seekable_last_error()
		if errStr == nil {
			return nil, errors.New("unknown error")
		}
		return nil, errors.New(C.GoString(errStr))
	}

	return &Encoder{ptr: ptr}, nil
}

// Size returns the decompressed size in bytes.
func (r *Reader) Size() uint64 {
	return uint64(C.seekable_size(r.ptr))
}

// FrameCount returns the number of compressed frames.
func (r *Reader) FrameCount() uint64 {
	return uint64(C.seekable_frame_count(r.ptr))
}

// ReadRange reads decompressed bytes in the range [start, end).
func (r *Reader) ReadRange(start, end uint64) ([]byte, error) {
	if start >= end {
		return nil, fmt.Errorf("invalid range: start (%d) >= end (%d)", start, end)
	}

	if end > r.Size() {
		return nil, fmt.Errorf("range end (%d) exceeds size (%d)", end, r.Size())
	}

	size := end - start
	buf := make([]byte, size)

	n, err := r.ReadAt(buf, int64(start))
	if err != nil {
		return nil, err
	}

	if n != len(buf) {
		return buf[:n], nil
	}

	return buf, nil
}

// ReadAt implements io.ReaderAt.
func (r *Reader) ReadAt(p []byte, off int64) (n int, err error) {
	if off < 0 {
		return 0, errors.New("seekable: negative offset")
	}

	if len(p) == 0 {
		return 0, nil
	}

	start := uint64(off)
	end := start + uint64(len(p))

	// Check bounds to be safe, though C layer also checks buffer size vs request
	if start >= r.Size() {
		return 0, io.EOF
	}

	// Clamp end to size
	if end > r.Size() {
		end = r.Size()
	}

	// If clamped end <= start, we are at EOF or invalid range
	if end <= start {
		return 0, io.EOF
	}

	cLen := C.uintptr_t(len(p))

	res := C.seekable_read_range(
		r.ptr,
		C.uint64_t(start),
		C.uint64_t(end),
		(*C.uint8_t)(unsafe.Pointer(&p[0])),
		&cLen,
	)

	if res < 0 {
		errStr := C.seekable_last_error()
		if errStr == nil {
			return 0, errors.New("read failed: unknown error")
		}
		return 0, fmt.Errorf("read failed: %s", C.GoString(errStr))
	}

	bytesRead := int(cLen)

	if bytesRead < len(p) {
		// Short read usually implies EOF in ReadAt semantics if we hit the end
		if start+uint64(bytesRead) == r.Size() {
			return bytesRead, io.EOF
		}
	}

	return bytesRead, nil
}

// Close releases resources. Safe to call multiple times.
func (r *Reader) Close() error {
	if r.ptr != nil {
		C.seekable_close(r.ptr)
		r.ptr = nil
	}
	return nil
}

// Write writes data to the encoder.
func (e *Encoder) Write(p []byte) (int, error) {
	if e.ptr == nil {
		return 0, errors.New("encoder already closed")
	}

	if len(p) == 0 {
		return 0, nil
	}

	res := C.seekable_encoder_write(
		e.ptr,
		(*C.uint8_t)(unsafe.Pointer(&p[0])),
		C.uintptr_t(len(p)),
	)

	if res < 0 {
		errStr := C.seekable_last_error()
		if errStr == nil {
			return 0, errors.New("write failed: unknown error")
		}
		return 0, fmt.Errorf("write failed: %s", C.GoString(errStr))
	}

	return len(p), nil
}

// Finish completes the stream, writes the seek table, and closes the file.
// Returns the total compressed size in bytes.
func (e *Encoder) Finish() (int64, error) {
	if e.ptr == nil {
		return 0, errors.New("encoder already closed")
	}

	res := C.seekable_encoder_finish(e.ptr)
	e.ptr = nil

	if res < 0 {
		errStr := C.seekable_last_error()
		if errStr == nil {
			return 0, errors.New("finish failed: unknown error")
		}
		return 0, fmt.Errorf("finish failed: %s", C.GoString(errStr))
	}

	return int64(res), nil
}

// Close aborts the encoder without finishing. Prefer Finish() for normal completion.
func (e *Encoder) Close() error {
	if e.ptr != nil {
		C.seekable_encoder_close(e.ptr)
		e.ptr = nil
	}
	return nil
}

// Ensure Reader implements io.Closer and io.ReaderAt
var _ io.Closer = (*Reader)(nil)
var _ io.ReaderAt = (*Reader)(nil)

// Ensure Encoder implements io.Writer and io.Closer
var _ io.Writer = (*Encoder)(nil)
var _ io.Closer = (*Encoder)(nil)
