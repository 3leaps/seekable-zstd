use crate::decoder::Decoder;
use std::cell::RefCell;
use std::ffi::{CStr, CString};
use std::fs::File;
use std::os::raw::c_char;
use std::ptr;

// Thread-local storage for the last error message
thread_local! {
    static LAST_ERROR: RefCell<Option<CString>> = const { RefCell::new(None) };
}

/// Sets the thread-local error message
fn set_error(err: &impl ToString) {
    LAST_ERROR.with(|e| {
        // CString::new fails if the string contains null bytes.
        // We substitute null bytes or just ignore the error for simplicity in this context,
        // but robust handling would be better.
        if let Ok(c_str) = CString::new(err.to_string()) {
            *e.borrow_mut() = Some(c_str);
        } else {
            *e.borrow_mut() = Some(CString::new("Error message contained null byte").unwrap());
        }
    });
}

pub struct SeekableDecoder {
    inner: Decoder<'static, File>,
}

/// Opens a seekable zstd archive.
///
/// # Safety
/// `path` must be a valid null-terminated C string.
/// The returned pointer must be freed with `seekable_close`.
#[no_mangle]
pub unsafe extern "C" fn seekable_open(path: *const c_char) -> *mut SeekableDecoder {
    if path.is_null() {
        set_error(&"Path pointer is null");
        return ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(path) };
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(e) => {
            set_error(&format!("Invalid UTF-8 path: {e}"));
            return ptr::null_mut();
        }
    };

    let file = match File::open(path_str) {
        Ok(f) => f,
        Err(e) => {
            set_error(&format!("Failed to open file: {e}"));
            return ptr::null_mut();
        }
    };

    // We rely on Decoder::<'static, File>::new returning a decoder that owns its context.
    // This avoids unsafe transmute.
    let decoder = match Decoder::<'static, File>::new(file) {
        Ok(d) => d,
        Err(e) => {
            set_error(&format!("Failed to create decoder: {e}"));
            return ptr::null_mut();
        }
    };

    let boxed = Box::new(SeekableDecoder { inner: decoder });
    Box::into_raw(boxed)
}

/// Returns the total decompressed size of the archive.
///
/// # Safety
/// `decoder` must be a valid pointer returned by `seekable_open`.
#[no_mangle]
pub unsafe extern "C" fn seekable_size(decoder: *const SeekableDecoder) -> u64 {
    if decoder.is_null() {
        return 0;
    }
    unsafe { (*decoder).inner.size() }
}

/// Returns the number of frames in the archive.
///
/// # Safety
/// `decoder` must be a valid pointer returned by `seekable_open`.
#[no_mangle]
pub unsafe extern "C" fn seekable_frame_count(decoder: *const SeekableDecoder) -> u64 {
    if decoder.is_null() {
        return 0;
    }
    unsafe { (*decoder).inner.frame_count() }
}

/// Reads a range of bytes from the archive.
///
/// # Safety
/// `decoder` must be a valid pointer returned by `seekable_open`.
/// `out_data` must point to a buffer of at least `*out_len` bytes.
/// `out_len` must be a valid pointer to a `size_t`.
#[no_mangle]
pub unsafe extern "C" fn seekable_read_range(
    decoder: *mut SeekableDecoder,
    start: u64,
    end: u64,
    out_data: *mut u8,
    out_len: *mut usize,
) -> i32 {
    if decoder.is_null() {
        set_error(&"Decoder pointer is null");
        return -1;
    }
    if out_data.is_null() {
        set_error(&"Output buffer pointer is null");
        return -1;
    }
    if out_len.is_null() {
        set_error(&"Output length pointer is null");
        return -1;
    }

    let decoder = unsafe { &mut *decoder };

    // Check if buffer is large enough
    let Ok(req_len) = usize::try_from(end - start) else {
        set_error(&"Requested range length too large for size_t");
        return -2;
    };

    if unsafe { *out_len } < req_len {
        set_error(&format!(
            "Buffer too small: provided {}, required {}",
            unsafe { *out_len },
            req_len
        ));
        return -2;
    }

    let data = match decoder.inner.read_range(start, end) {
        Ok(d) => d,
        Err(e) => {
            set_error(&format!("Read error: {e}"));
            return -3;
        }
    };

    // Copy data
    unsafe {
        ptr::copy_nonoverlapping(data.as_ptr(), out_data, data.len());
        *out_len = data.len();
    }

    0 // Success
}

/// Closes the decoder and frees resources.
///
/// # Safety
/// `decoder` must be a valid pointer returned by `seekable_open`.
#[no_mangle]
pub unsafe extern "C" fn seekable_close(decoder: *mut SeekableDecoder) {
    if !decoder.is_null() {
        unsafe { drop(Box::from_raw(decoder)) };
    }
}

/// Returns the last error message.
///
/// # Safety
/// Thread-safe. Returns a pointer to a thread-local C string.
/// The string is valid until the next error occurs on this thread.
#[no_mangle]
pub unsafe extern "C" fn seekable_last_error() -> *const c_char {
    LAST_ERROR.with(|e| match *e.borrow() {
        Some(ref s) => s.as_ptr(),
        None => ptr::null(),
    })
}
