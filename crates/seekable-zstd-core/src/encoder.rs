use crate::error::Error;
use std::io::Write;
use zeekstd::{EncodeOptions, FrameSizePolicy};

pub const DEFAULT_FRAME_SIZE: usize = 256 * 1024;

pub struct Encoder<'a, W: Write> {
    inner: zeekstd::Encoder<'a, W>,
}

impl<W: Write> Encoder<'_, W> {
    /// Creates a new `Encoder` with default configuration.
    ///
    /// # Errors
    ///
    /// Returns an error if the encoder cannot be initialized.
    pub fn new(writer: W) -> Result<Self, Error> {
        Self::with_frame_size(writer, DEFAULT_FRAME_SIZE)
    }

    /// Creates a new `Encoder` with a custom frame size.
    ///
    /// # Errors
    ///
    /// Returns an error if the encoder cannot be initialized.
    pub fn with_frame_size(writer: W, frame_size: usize) -> Result<Self, Error> {
        let frame_size_u32 = u32::try_from(frame_size)
            .map_err(|_| Error::Format("Frame size too large".to_string()))?;

        let options =
            EncodeOptions::new().frame_size_policy(FrameSizePolicy::Uncompressed(frame_size_u32));

        let inner = options.into_encoder(writer).map_err(Error::from)?;
        Ok(Self { inner })
    }

    /// Creates a new `Encoder` with a custom compression level.
    ///
    /// # Errors
    ///
    /// Returns an error if the encoder cannot be initialized.
    pub fn with_level(writer: W, level: i32) -> Result<Self, Error> {
        // Map i32 level to CompressionLevel
        let options = EncodeOptions::new().compression_level(level);

        let inner = options.into_encoder(writer).map_err(Error::from)?;
        Ok(Self { inner })
    }

    /// Creates a new `Encoder` with custom options.
    ///
    /// # Errors
    ///
    /// Returns an error if the encoder cannot be initialized.
    pub fn new_with_options(writer: W, frame_size: usize, level: i32) -> Result<Self, Error> {
        let frame_size_u32 = u32::try_from(frame_size)
            .map_err(|_| Error::Format("Frame size too large".to_string()))?;

        let options = EncodeOptions::new()
            .frame_size_policy(FrameSizePolicy::Uncompressed(frame_size_u32))
            .compression_level(level);

        let inner = options.into_encoder(writer).map_err(Error::from)?;
        Ok(Self { inner })
    }

    /// Writes all data to the encoder.
    ///
    /// # Errors
    ///
    /// Returns an error if the write fails.
    pub fn write_all(&mut self, data: &[u8]) -> Result<(), Error> {
        self.inner.write_all(data).map_err(Error::from)
    }

    /// Finishes the stream and returns the underlying writer.
    ///
    /// # Errors
    ///
    /// Returns an error if the finish operation fails.
    pub fn finish(self) -> Result<u64, Error> {
        self.inner.finish().map_err(Error::from)
    }
}

// Implement Write for Encoder
impl<W: Write> Write for Encoder<'_, W> {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.inner.write(buf)
    }

    fn flush(&mut self) -> std::io::Result<()> {
        self.inner.flush()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encoder_write() {
        let mut buffer = Vec::new();
        let mut encoder = Encoder::new(&mut buffer).unwrap();
        encoder.write_all(b"Hello World").unwrap();
        encoder.finish().unwrap();

        assert!(!buffer.is_empty());
    }
}
