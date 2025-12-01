use crate::decoder::Decoder;
use crate::error::Error;
use rayon::prelude::*;
use std::fs::File;
use std::path::{Path, PathBuf};

pub struct ParallelDecoder {
    path: PathBuf,
    size: u64,
    frame_count: u64,
}

impl ParallelDecoder {
    /// Opens a parallel decoder for the given file path.
    ///
    /// # Errors
    ///
    /// Returns an error if the file cannot be opened or if the decoder cannot be initialized.
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self, Error> {
        let path_buf = path.as_ref().to_path_buf();
        let file = File::open(&path_buf)?;
        let decoder = Decoder::new(file)?;

        Ok(Self {
            path: path_buf,
            size: decoder.size(),
            frame_count: decoder.frame_count(),
        })
    }

    #[must_use]
    pub fn size(&self) -> u64 {
        self.size
    }

    #[must_use]
    pub fn frame_count(&self) -> u64 {
        self.frame_count
    }

    /// Reads multiple ranges in parallel.
    ///
    /// # Errors
    ///
    /// Returns an error if any of the reads fail.
    pub fn read_ranges(&self, ranges: &[(u64, u64)]) -> Result<Vec<Vec<u8>>, Error> {
        // Collect results into a Vec<Result<Vec<u8>, Error>> first
        let results: Vec<Result<Vec<u8>, Error>> = ranges
            .par_iter()
            .map(|(start, end)| {
                let file = File::open(&self.path)?;
                let mut decoder = Decoder::new(file)?;
                decoder.read_range(*start, *end)
            })
            .collect();

        // Then collect into Result<Vec<Vec<u8>>, Error>
        results.into_iter().collect()
    }
}
