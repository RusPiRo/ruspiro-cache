/***********************************************************************************************************************
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/
//! Build script to pre-compile the assembly files containing the cache operations code
//!

extern crate cc;
use std::env;

fn main() {
    match env::var_os("CARGO_CFG_TARGET_ARCH") {
        Some(target_arch) => {
            if target_arch == "arm" {
                cc::Build::new()
                    .file("src/asm/cache32.s")
                    .flag("-march=armv8-a")
                    .flag("-mfpu=neon-fp-armv8")
                    .flag("-mfloat-abi=hard")
                    .compile("cache");
            }

            if target_arch == "aarch64" {
                cc::Build::new()
                    .file("src/asm/cache64.s")
                    .flag("-march=armv8-a")
                    .compile("cache");
            }
        }
        _ => (),
    }
}
