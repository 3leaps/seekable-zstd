//go:build linux && arm64 && !musl

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/local/linux-arm64 -L${SRCDIR}/lib/linux-arm64 -lseekable_zstd_core -lm -lpthread
*/
import "C"
