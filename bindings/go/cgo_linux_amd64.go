//go:build linux && amd64 && !musl

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/linux-amd64 -lseekable_zstd_core -lm -lpthread
*/
import "C"
