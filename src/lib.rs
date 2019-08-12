/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: Apache License 2.0
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-cache/0.1.1")]
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

extern "C" {
    fn __clean_dcache();
    fn __invalidate_dcache();
    fn __cleaninvalidate_dcache();
}
