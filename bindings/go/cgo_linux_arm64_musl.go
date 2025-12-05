//go:build linux && arm64 && musl

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/linux-arm64-musl -lseekable_zstd_core -lm -lpthread
*/
import "C"
