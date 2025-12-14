#![warn(clippy::all)]
#![warn(clippy::pedantic)]
#![allow(clippy::module_name_repetitions)]

pub use seekable_zstd_core::{Decoder, Encoder, Error, ParallelDecoder, Result};
