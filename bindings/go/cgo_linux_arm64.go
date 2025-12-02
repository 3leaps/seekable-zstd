//go:build linux && arm64

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/linux-arm64 -lseekable_zstd_core -lm -ldl -lpthread
*/
import "C"
