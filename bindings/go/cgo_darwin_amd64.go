//go:build darwin && amd64

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/darwin-amd64 -lseekable_zstd_core -lm -lpthread
*/
import "C"
