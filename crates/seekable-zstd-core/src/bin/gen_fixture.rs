use seekable_zstd_core::Encoder;
use std::fs::File;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("Usage: gen_fixture <output_file> <text>");
        std::process::exit(1);
    }

    let output_path = &args[1];
    let text = &args[2];

    let file = File::create(output_path)?;
    let mut encoder = Encoder::new(file)?;
    encoder.write_all(text.as_bytes())?;
    encoder.finish()?;

    println!("Generated fixture at {}", output_path);
    Ok(())
}
