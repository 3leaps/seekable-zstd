//go:build darwin && arm64

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/local/darwin-arm64 -L${SRCDIR}/lib/darwin-arm64 -lseekable_zstd_core -lm -lpthread
*/
import "C"
