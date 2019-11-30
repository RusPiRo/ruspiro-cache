/***********************************************************************************************************************
 * Raspberry Pi3 cache operation functions
 * cache opeartions are needed as the MMU need an active MMU and several
 * cross core/cross GPU operations need to clean/invalite the cache to se the
 * most actual data in the memory
 * TODO: actuall always the whole cache gets cleaned/invalidated, for better performance
 *       this should be enabled for specific address regions.
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/

.global __flush_icache_range
.global __invalidate_dcache
.global __clean_dcache
.global __cleaninvalidate_dcache

.macro debug_lit_led num
    sub sp, sp, #16
    stp x0, x30, [sp, #0]
    
    mov x0, \num
    bl lit_led

    ldp x0, x30, [sp, #0]
    add sp, sp, #16
.endm

.macro save_state
	sub		sp, sp, #256 // make place at the stack to store all register values
	
	stp		x0, x1, [sp, #16 * 0]
	stp     x2, x3, [sp, #16 * 1]
	stp		x4, x5, [sp, #16 * 2]
	stp		x6, x7, [sp, #16 * 3]
	stp		x8, x9, [sp, #16 * 4]
	stp		x10, x11, [sp, #16 * 5]
	stp		x12, x13, [sp, #16 * 6]
	stp		x14, x15, [sp, #16 * 7]
	stp		x16, x17, [sp, #16 * 8]
	stp		x18, x19, [sp, #16 * 9]
	stp		x20, x21, [sp, #16 * 10]
	stp		x22, x23, [sp, #16 * 11]
	stp		x24, x25, [sp, #16 * 12]
	stp		x26, x27, [sp, #16 * 13]
	stp		x28, x29, [sp, #16 * 14]
	str     x30, [sp, #16 * 15]
.endm

.macro restore_state
	ldp		x0, x1, [sp, #16 * 0]
	ldp     x2, x3, [sp, #16 * 1]
	ldp		x4, x5, [sp, #16 * 2]
	ldp		x6, x7, [sp, #16 * 3]
	ldp		x8, x9, [sp, #16 * 4]
	ldp		x10, x11, [sp, #16 * 5]
	ldp		x12, x13, [sp, #16 * 6]
	ldp		x14, x15, [sp, #16 * 7]
	ldp		x16, x17, [sp, #16 * 8]
	ldp		x18, x19, [sp, #16 * 9]
	ldp		x20, x21, [sp, #16 * 10]
	ldp		x22, x23, [sp, #16 * 11]
	ldp		x24, x25, [sp, #16 * 12]
	ldp		x26, x27, [sp, #16 * 13]
	ldp		x28, x29, [sp, #16 * 14]
	ldr     x30, [sp, #16 * 15]

	add		sp, sp, #256 // free the stack as it is no longer needed
.endm


/**************************************************************************
 * read the minimum d-cache line size
 * Curruptile registers: x0, x1
 * returns x0 = cache line size
 **************************************************************************/
__get_dcache_line_size:
	mrs		x0, ctr_el0
	nop
	ubfm    x0, x0, #16, #19 // get bit's 16:19 and shift to the right (cache line encoding)
	mov     x1, #4           // bytes per word
	lsl     x0, x1, x0       // actual cache line size
	ret

/**************************************************************************
 * read the minimum i-cache line size
 * Corruptile registers: x0, x1
 * returns x0 = cache line size
 **************************************************************************/
__get_icache_line_size:
	mrs		x0, ctr_el0
	nop
	and    x0, x0, #0xF // get bit's 0:3 (cache line encoding)
	mov     x1, #4           // bytes per word
	lsl     x0, x1, x0       // actual cache line size
	ret

/*************************************************************************
 * flushing instruction cache / data cache in the specified region
 * x0 - start address
 * x1 - end address
 * Curruptile registers x0-x6
 *************************************************************************/
__flush_icache_range:
__flush_dcache_range:
	mov 	x6, x30	// secure ret address
	mov     x2, x0	// start
	mov     x3, x1  // end
	bl      __get_dcache_line_size
	sub     x4, x0, #1
	bic     x4, x2, x4 // cache line size aligned start address
//  first clean(invalidate data cache)
1:
	dc      civac, x4	// clean/invalidatze cache for VA to PoC
	add		x4, x4, x0  // inc. address by cache line size
	cmp     x4, x1      // until we reach the end address
	b.lo    1b

	dsb     ish
// after data cache the instruction cache could be invalidated
	bl      __get_icache_line_size
	sub     x4, x0, #1
	bic     x4, x3, x4	// cache line size aligned start address
2:
	ic      ivau, x4	// invalidate instruction cache
	add     x4, x4, x0  // inc. address by cache line size
	cmp     x4, x3
	b.lo    2b

	dsb     ish
	isb

	ret 	x6

/**************************************************************************
 *
 * invalidate_dcache - invalidate the entire d-cache by set/way
 * 
 **************************************************************************/
__invalidate_dcache:
	bl		__cleaninvalidate_dcache
	ret

/*
 *************************************************************************
 *
 * clean_dcache - clean the entire d-cache by set/way
 *
 * Note: for Cortex-A53, there is no cp instruction for invalidating
 * the whole D-cache. Need to invalidate each line.
 *
 *************************************************************************
 */

__clean_dcache:
	bl		__cleaninvalidate_dcache
	ret

/*
 *************************************************************************
 *
 * cleaninvalidate_dcache - clen & invalidate the entire d-cache by set/way
 *
 * Note: for Cortex-A53, there is no cp instruction for invalidating
 * the whole D-cache. Need to invalidate each line.
 *
  *
 *************************************************************************
 */

__cleaninvalidate_dcache:
	save_state

	dsb	sy				// ensure ordering with previous memory accesses
	mrs	x0, clidr_el1			// read clidr
	and	x3, x0, #0x7000000		// extract loc from clidr
	lsr	x3, x3, #23			// left align loc bit field
	cbz	x3, finished			// if loc is 0, then no need to clean
	mov	x10, #0				// start clean at cache level 0
loop1:
	add	x2, x10, x10, lsr #1		// work out 3x current cache level
	lsr	x1, x0, x2			// extract cache type bits from clidr
	and	x1, x1, #7			// mask of the bits for current cache only
	cmp	x1, #2				// see what cache we have at this level
	b.lt	skip				// skip if no cache, or just i-cache
	msr	csselr_el1, x10			// select current cache level in csselr
	isb					// isb to sych the new cssr&csidr
	mrs	x1, ccsidr_el1			// read the new ccsidr
	and	x2, x1, #7			// extract the length of the cache lines
	add	x2, x2, #4			// add 4 (line length offset)
	mov	x4, #0x3ff
	and	x4, x4, x1, lsr #3		// find maximum number on the way size
	clz	w5, w4				// find bit position of way size increment
	mov	x7, #0x7fff
	and	x7, x7, x1, lsr #13		// extract max number of the index size
loop2:
	mov	x9, x4				// create working copy of max way size
loop3:
	lsl	x6, x9, x5
	orr	x11, x10, x6			// factor way and cache number into x11
	lsl	x6, x7, x2
	orr	x11, x11, x6			// factor index number into x11
	dc	cisw, x11			// clean & invalidate by set/way
	subs	x9, x9, #1			// decrement the way
	b.ge	loop3
	subs	x7, x7, #1			// decrement the index
	b.ge	loop2
skip:
	add	x10, x10, #2			// increment cache number
	cmp	x3, x10
	b.gt	loop1
finished:
	mov	x10, #0				// swith back to cache level 0
	msr	csselr_el1, x10			// select current cache level in csselr
	dsb	sy
	isb

	restore_state

	//debug_lit_led #20
	ret
