use std::io;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("IO error: {0}")]
    Io(#[from] io::Error),

    #[error("Zstd error: {0}")]
    Zstd(String),

    #[error("Seekable format error: {0}")]
    Format(String),
}

// Convert zeekstd error to our Error
impl From<zeekstd::Error> for Error {
    fn from(err: zeekstd::Error) -> Self {
        Error::Zstd(err.to_string())
    }
}
