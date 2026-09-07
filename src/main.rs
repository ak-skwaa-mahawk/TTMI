//! pge-as CLI entrypoint for build systems
use std::env;
use std::process;
use std::path::Path;

mod assembler;
use assembler::{Assembler, AsmError};

fn print_usage(prog: &str) {
    eprintln!("Usage: {} <input.gw> -o <output.hex> [--verbose]", prog);
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 4 {
        print_usage(&args[0]);
        process::exit(1);
    }

    let input_path = &args[1];
    let mut output_path = String::new();
    let mut verbose = false;

    let mut i = 2;
    while i < args.len() {
        match args[i].as_str() {
            "-o" | "--output" => {
                if i + 1 < args.len() {
                    output_path = args[i + 1].clone();
                    i += 1;
                } else {
                    eprintln!("Error: -o requires a target filename");
                    process::exit(1);
                }
            }
            "-v" | "--verbose" => {
                verbose = true;
            }
            other => {
                eprintln!("Unknown argument: {}", other);
                print_usage(&args[0]);
                process::exit(1);
            }
        }
        i += 1;
    }

    if output_path.is_empty() {
        eprintln!("Error: Output path not specified.");
        process::exit(1);
    }

    if !Path::new(input_path).exists() {
        eprintln!("Error: Input source file '{}' does not exist.", input_path);
        process::exit(1);
    }

    match Assembler::assemble_file(input_path, &output_path) {
        Ok(count) => {
            if verbose {
                println!("[pge-as] Compiled {} instructions: '{}' -> '{}'", count, input_path, output_path);
            }
            process::exit(0);
        }
        Err(e) => {
            eprintln!("[pge-as] Compilation failed: {:?}", e);
            process::exit(2);
        }
    }
}
