#![deny(clippy::all)]

use napi::bindgen_prelude::{Buffer, Error, Result, Status};
use napi_derive::napi;
use seekable_zstd_core::ParallelDecoder;

#[napi]
pub struct Reader {
    inner: ParallelDecoder,
}

#[napi]
impl Reader {
    #[napi(constructor)]
    pub fn new(path: String) -> Result<Self> {
        let inner = ParallelDecoder::open(path)
            .map_err(|e| Error::new(Status::GenericFailure, e.to_string()))?;
        Ok(Reader { inner })
    }

    #[napi(getter)]
    pub fn size(&self) -> i64 {
        self.inner.size() as i64
    }

    #[napi(getter)]
    pub fn frame_count(&self) -> i64 {
        self.inner.frame_count() as i64
    }

    #[napi]
    pub fn read_range(&self, start: i64, end: i64) -> Result<Buffer> {
        let start_u64 = start as u64;
        let end_u64 = end as u64;

        let range = vec![(start_u64, end_u64)];
        let results = self
            .inner
            .read_ranges(&range)
            .map_err(|e| Error::new(Status::GenericFailure, e.to_string()))?;

        if let Some(data) = results.first() {
            Ok(Buffer::from(data.as_slice()))
        } else {
            Ok(Buffer::from(&[][..]))
        }
    }
}
