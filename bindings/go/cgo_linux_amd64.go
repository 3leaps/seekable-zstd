//go:build linux && amd64

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/linux-amd64 -lseekable_zstd_core -lm -ldl -lpthread
*/
import "C"
