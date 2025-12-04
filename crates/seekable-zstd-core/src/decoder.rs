use crate::error::Error;
use std::fs::File;
use std::io::{Read, Seek};
use std::path::Path;

pub struct Decoder<'a, R: Read + Seek> {
    inner: zeekstd::Decoder<'a, R>,
}

impl<R: Read + Seek> Decoder<'_, R> {
    /// Creates a new `Decoder` from the given reader.
    ///
    /// # Errors
    ///
    /// Returns an error if the decoder cannot be initialized, for example if the
    /// input is not a valid zstd stream or seekable archive.
    pub fn new(reader: R) -> Result<Self, Error> {
        let inner = zeekstd::Decoder::new(reader).map_err(Error::from)?;
        Ok(Self { inner })
    }

    #[must_use]
    pub fn size(&self) -> u64 {
        let num_frames = self.inner.num_frames();
        if num_frames == 0 {
            return 0;
        }
        // frame_end_decomp(num_frames - 1) returns the total decompressed size
        self.inner.frame_end_decomp(num_frames - 1).unwrap_or(0)
    }

    #[must_use]
    pub fn frame_count(&self) -> u64 {
        u64::from(self.inner.num_frames())
    }

    /// Reads data into `buf` starting at `offset`.
    ///
    /// Returns the number of bytes read.
    ///
    /// # Errors
    ///
    /// Returns an error if the range is invalid or if decompression fails.
    pub fn read_at(&mut self, buf: &mut [u8], offset: u64) -> Result<usize, Error> {
        // Read range starting at offset with len = buf.len()
        let end = offset + buf.len() as u64;
        let data = self.read_range(offset, end)?;
        let len = std::cmp::min(buf.len(), data.len());
        buf[..len].copy_from_slice(&data[..len]);
        Ok(len)
    }

    /// Reads a range of bytes from `start` to `end`.
    ///
    /// # Errors
    ///
    /// Returns an error if `end < start`, or if decompression fails.
    pub fn read_range(&mut self, start: u64, end: u64) -> Result<Vec<u8>, Error> {
        if end < start {
            return Err(Error::Format(
                "End offset cannot be less than start offset".to_string(),
            ));
        }

        // 1. Find start and end frames
        let start_frame = self.inner.frame_index_decomp(start);
        let end_frame = self.inner.frame_index_decomp(end.saturating_sub(1)); // inclusive

        // 2. Configure decoder
        self.inner.set_lower_frame(start_frame);
        self.inner.set_upper_frame(end_frame);

        // 3. Decompress
        let start_offset = self
            .inner
            .frame_start_decomp(start_frame)
            .map_err(Error::from)?;

        let skip = usize::try_from(start - start_offset)
            .map_err(|_| Error::Format("Offset too large for usize".to_string()))?;

        let len = usize::try_from(end - start)
            .map_err(|_| Error::Format("Length too large for usize".to_string()))?;

        // Calculate max size needed
        let range_end_offset = self
            .inner
            .frame_end_decomp(end_frame)
            .map_err(Error::from)?;
        let total_decompressed_size = usize::try_from(range_end_offset - start_offset)
            .map_err(|_| Error::Format("Decompressed size too large for usize".to_string()))?;

        let mut temp_buf = vec![0u8; total_decompressed_size];

        // Reset decoder state
        self.inner.reset();

        // Read loop
        let mut pos = 0;
        while pos < total_decompressed_size {
            let n = self
                .inner
                .decompress(&mut temp_buf[pos..])
                .map_err(Error::from)?;
            if n == 0 {
                break;
            }
            pos += n;
        }

        // Extract the requested range
        let available = pos;
        if skip >= available {
            return Ok(Vec::new());
        }

        let end_idx = std::cmp::min(skip + len, available);
        Ok(temp_buf[skip..end_idx].to_vec())
    }
}

impl Decoder<'_, File> {
    /// Opens a seekable zstd archive from a file path.
    ///
    /// This is a convenience method equivalent to:
    /// ```ignore
    /// let file = File::open(path)?;
    /// Decoder::new(file)
    /// ```
    ///
    /// # Errors
    ///
    /// Returns an error if the file cannot be opened or if the decoder
    /// cannot be initialized.
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self, Error> {
        let file = File::open(path)?;
        Self::new(file)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::encoder::Encoder;
    use std::io::Cursor;

    #[test]
    fn test_roundtrip() {
        // Compress
        let mut buffer = Vec::new();
        let mut encoder = Encoder::new(&mut buffer).unwrap();
        let data = b"Hello World, this is a test of seekable zstd.";
        encoder.write_all(data).unwrap();
        encoder.finish().unwrap();

        // Decompress
        let cursor = Cursor::new(buffer);
        let mut decoder = Decoder::new(cursor).unwrap();

        assert_eq!(decoder.size(), data.len() as u64);

        let read_data = decoder.read_range(0, data.len() as u64).unwrap();
        assert_eq!(read_data, data);

        // Random access
        let partial = decoder.read_range(6, 11).unwrap();
        assert_eq!(partial, b"World");
    }
}
