extern crate cbindgen;

use std::env;
use std::path::PathBuf;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    // Try to locate the bindings directory relative to the crate directory
    let output_file =
        PathBuf::from(crate_dir.clone()).join("../../bindings/go/include/seekable_zstd.h");

    // Only generate if the directory exists (to avoid errors in CI if structure is different)
    if output_file.parent().unwrap().exists() {
        cbindgen::Builder::new()
            .with_crate(crate_dir)
            .with_language(cbindgen::Language::C)
            .with_include_guard("SEEKABLE_ZSTD_H")
            .generate()
            .expect("Unable to generate bindings")
            .write_to_file(output_file);
    }
}
