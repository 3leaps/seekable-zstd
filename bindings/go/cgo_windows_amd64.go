//go:build windows && amd64

package seekable

/*
#cgo LDFLAGS: -L${SRCDIR}/lib/windows-amd64 -lseekable_zstd_core -lws2_32 -luserenv -lbcrypt
*/
import "C"
