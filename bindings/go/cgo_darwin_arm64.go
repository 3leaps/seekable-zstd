//go:build darwin && arm64

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/darwin-arm64 -lseekable_zstd_core -lm -lpthread
*/
import "C"
