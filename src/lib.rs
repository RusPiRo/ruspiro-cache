/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: Apache License 2.0
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-cache/0.3.0")]
#![no_std]
#![feature(asm)]

//! # Raspberry Pi cache maintenance
//! 
//! If the caches are active on the Raspberry Pi than there might be specific cache
//! operations needed to clean and invalidate the cache to ensure in cross core and/or
//! ARM core to GPU communications the most recent data is seen.
//! 
//! # Usage
//! 
//! ```
//! use ruspiro_cache as cache;
//! 
//! fn demo() {
//!     cache::clean(); // clean the data cache
//!     cache::invalidate(); // invalidate the data cache
//!     cache::cleaninvalidate(); // clean and invalidate the data cache
//! }
//! ```
//! 
//! # Features
//! 
//! - ``ruspiro_pi3`` is active by default and ensures the proper cache operations assembly is compiled
//! 

/// Perform a cache clean operation on the entire data cache
pub fn clean() {
    unsafe {
        __clean_dcache();
        #[cfg(target_arch="arm")]
        asm!("dmb");
    }
}

/// Perform a cache invalidate operation on the entire data cache
pub fn invalidate() {
    unsafe {
        __invalidate_dcache();
        #[cfg(target_arch="arm")]
        asm!("dmb");
    }
}

/// Perform a cache clean and invalidate operation on the entire data cache
pub fn cleaninvalidate() {
    unsafe {
        __cleaninvalidate_dcache();
        #[cfg(target_arch="arm")]
        asm!("dmb");
    }
}

/// Flush the instruction cache in a given memory address range
#[cfg(target_arch="aarch64")]
pub fn flush_icache_range(from: u64, to: u64) {
    unsafe {
        __flush_icache_range(from, to);
    };
}

/// Flush the data cache in a given memory address range
#[cfg(target_arch="aarch64")]
pub fn flush_dcache_range(from: u64, to: u64) {
    unsafe {
        __flush_dcache_range(from, to);
    };
}

extern "C" {
    fn __clean_dcache();
    fn __invalidate_dcache();
    fn __cleaninvalidate_dcache();

    #[cfg(target_arch="aarch64")]
    fn __flush_icache_range(start: u64, end: u64);
    #[cfg(target_arch="aarch64")]
    fn __flush_dcache_range(start: u64, end: u64);
}
