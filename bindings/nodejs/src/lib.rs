#![deny(clippy::all)]

use napi::bindgen_prelude::{Buffer, Error, Result, Status};
use napi_derive::napi;
use seekable_zstd_core::ParallelDecoder;

#[napi]
pub struct Reader {
    inner: Option<ParallelDecoder>,
}

#[napi]
impl Reader {
    #[napi(constructor)]
    pub fn new(path: String) -> Result<Self> {
        let inner = ParallelDecoder::open(path)
            .map_err(|e| Error::new(Status::GenericFailure, e.to_string()))?;
        Ok(Reader { inner: Some(inner) })
    }

    #[napi(getter)]
    pub fn size(&self) -> Result<i64> {
        match &self.inner {
            Some(inner) => Ok(inner.size() as i64),
            None => Err(Error::new(Status::GenericFailure, "Reader is closed")),
        }
    }

    #[napi(getter)]
    pub fn frame_count(&self) -> Result<i64> {
        match &self.inner {
            Some(inner) => Ok(inner.frame_count() as i64),
            None => Err(Error::new(Status::GenericFailure, "Reader is closed")),
        }
    }

    #[napi]
    pub fn read_range(&self, start: i64, end: i64) -> Result<Buffer> {
        let inner = self
            .inner
            .as_ref()
            .ok_or_else(|| Error::new(Status::GenericFailure, "Reader is closed"))?;

        let start_u64 = start as u64;
        let end_u64 = end as u64;

        let range = vec![(start_u64, end_u64)];
        let results = inner
            .read_ranges(&range)
            .map_err(|e| Error::new(Status::GenericFailure, e.to_string()))?;

        if let Some(data) = results.first() {
            Ok(Buffer::from(data.as_slice()))
        } else {
            Ok(Buffer::from(&[][..]))
        }
    }

    #[napi]
    pub async fn read_range_async(&self, start: i64, end: i64) -> Result<Buffer> {
        let inner_clone = self
            .inner
            .as_ref()
            .ok_or_else(|| Error::new(Status::GenericFailure, "Reader is closed"))?
            .clone();

        let start_u64 = start as u64;
        let end_u64 = end as u64;

        // Offload to libuv thread pool
        napi::tokio::task::spawn_blocking(move || {
            let range = vec![(start_u64, end_u64)];
            let results = inner_clone
                .read_ranges(&range)
                .map_err(|e| Error::new(Status::GenericFailure, e.to_string()))?;

            if let Some(data) = results.first() {
                Ok(Buffer::from(data.as_slice()))
            } else {
                Ok(Buffer::from(&[][..]))
            }
        })
        .await
        .map_err(|e| Error::new(Status::GenericFailure, e.to_string()))?
    }

    /// Closes the reader and releases resources.
    /// After calling close(), any further operations will throw an error.
    #[napi]
    pub fn close(&mut self) {
        self.inner = None;
    }
}
