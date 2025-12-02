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

// Reader provides random access to seekable zstd archives.
type Reader struct {
	ptr *C.SeekableDecoder
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

	cLen := C.uintptr_t(len(buf))

	res := C.seekable_read_range(
		r.ptr,
		C.uint64_t(start),
		C.uint64_t(end),
		(*C.uint8_t)(unsafe.Pointer(&buf[0])),
		&cLen,
	)

	if res < 0 {
		errStr := C.seekable_last_error()
		if errStr == nil {
			return nil, errors.New("read failed: unknown error")
		}
		return nil, fmt.Errorf("read failed: %s", C.GoString(errStr))
	}

	bytesRead := int(cLen)
	if bytesRead != len(buf) {
		return buf[:bytesRead], nil
	}

	return buf, nil
}

// Close releases resources. Safe to call multiple times.
func (r *Reader) Close() error {
	if r.ptr != nil {
		C.seekable_close(r.ptr)
		r.ptr = nil
	}
	return nil
}

// Ensure Reader implements io.Closer
var _ io.Closer = (*Reader)(nil)
