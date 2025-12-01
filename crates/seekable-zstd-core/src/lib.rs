#![warn(clippy::all)]
#![warn(clippy::pedantic)]
#![allow(clippy::module_name_repetitions)]

pub mod decoder;
pub mod encoder;
pub mod error;
pub mod ffi;
pub mod parallel;

pub use decoder::Decoder;
pub use encoder::Encoder;
pub use error::Error;
pub use parallel::ParallelDecoder;

pub type Result<T> = std::result::Result<T, Error>;
