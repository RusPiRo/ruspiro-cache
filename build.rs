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
            if target_arch == "arm" && env::var_os("CARGO_FEATURE_RUSPIRO_PI3").is_some() {
                cc::Build::new()
                    .file("src/asm/cache.s")
                    .flag("-march=armv8-a")
                    .flag("-mfpu=neon-fp-armv8")
                    .flag("-mfloat-abi=hard")
                    .compile("cache");
            }
        },
        _ => ()
    }
}