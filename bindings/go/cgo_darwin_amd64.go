//go:build darwin && amd64

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/local/darwin-amd64 -L${SRCDIR}/lib/darwin-amd64 -lseekable_zstd_core -lm -lpthread
*/
import "C"
