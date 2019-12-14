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

.global __invalidate_dcache
.global __clean_dcache
.global __cleaninvalidate_dcache

/*
 *************************************************************************
 *
 * invalidate_dcache - invalidate the entire d-cache by set/way
 *
 * Note: for Cortex-A53, there is no cp instruction for invalidating
 * the whole D-cache. Need to invalidate each line.
 *
 *************************************************************************
 */

__invalidate_dcache:
	push	{r0 - r12, lr}

	mrc	p15, 1, r0, c0, c0, 1		/* read CLIDR */
	ands	r3, r0, #0x7000000
	mov	r3, r3, lsr #23			/* cache level value (naturally aligned) */
	beq	.ifinished
	mov	r10, #0				/* start with level 0 */
.iloop1:
	add	r2, r10, r10, lsr #1		/* work out 3xcachelevel */
	mov	r1, r0, lsr r2			/* bottom 3 bits are the Cache type for this level */
	and	r1, r1, #7			/* get those 3 bits alone */
	cmp	r1, #2
	blt	.iskip				/* no cache or only instruction cache at this level */
	mcr	p15, 2, r10, c0, c0, 0		/* write the Cache Size selection register */
	isb					/* isb to sync the change to the CacheSizeID reg */
	mrc	p15, 1, r1, c0, c0, 0		/* reads current Cache Size ID register */
	and	r2, r1, #7			/* extract the line length field */
	add	r2, r2, #4			/* add 4 for the line length offset (log2 16 bytes) */
	ldr	r4, =0x3ff
	ands	r4, r4, r1, lsr #3		/* r4 is the max number on the way size (right aligned) */
	clz	r5, r4				/* r5 is the bit position of the way size increment */
	ldr	r7, =0x7fff
	ands	r7, r7, r1, lsr #13		/* r7 is the max number of the index size (right aligned) */
.iloop2:
	mov	r9, r4				/* r9 working copy of the max way size (right aligned) */
.iloop3:
	orr	r11, r10, r9, lsl r5		/* factor in the way number and cache number into r11 */
	orr	r11, r11, r7, lsl r2		/* factor in the index number */

	mcr	p15, 0, r11, c7, c6, 2		// invalidate by set/way

	subs	r9, r9, #1			/* decrement the way number */
	bge	.iloop3
	subs	r7, r7, #1			/* decrement the index */
	bge	.iloop2
.iskip:
	add	r10, r10, #2			/* increment the cache number */
	cmp	r3, r10
	bgt	.iloop1

.ifinished:
	mov	r10, #0				/* swith back to cache level 0 */
	mcr	p15, 2, r10, c0, c0, 0		/* select current cache level in cssr */
	dsb
	isb

	dmb

	pop {r0-r12, pc}


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
	push	{r0 - r12, lr}

	mrc	p15, 1, r0, c0, c0, 1		/* read CLIDR */
	ands	r3, r0, #0x7000000
	mov	r3, r3, lsr #23			/* cache level value (naturally aligned) */
	beq	.cfinished
	mov	r10, #0				/* start with level 0 */
.cloop1:
	add	r2, r10, r10, lsr #1		/* work out 3xcachelevel */
	mov	r1, r0, lsr r2			/* bottom 3 bits are the Cache type for this level */
	and	r1, r1, #7			/* get those 3 bits alone */
	cmp	r1, #2
	blt	.cskip				/* no cache or only instruction cache at this level */
	mcr	p15, 2, r10, c0, c0, 0		/* write the Cache Size selection register */
	isb					/* isb to sync the change to the CacheSizeID reg */
	mrc	p15, 1, r1, c0, c0, 0		/* reads current Cache Size ID register */
	and	r2, r1, #7			/* extract the line length field */
	add	r2, r2, #4			/* add 4 for the line length offset (log2 16 bytes) */
	ldr	r4, =0x3ff
	ands	r4, r4, r1, lsr #3		/* r4 is the max number on the way size (right aligned) */
	clz	r5, r4				/* r5 is the bit position of the way size increment */
	ldr	r7, =0x7fff
	ands	r7, r7, r1, lsr #13		/* r7 is the max number of the index size (right aligned) */
.cloop2:
	mov	r9, r4				/* r9 working copy of the max way size (right aligned) */
.cloop3:
	orr	r11, r10, r9, lsl r5		/* factor in the way number and cache number into r11 */
	orr	r11, r11, r7, lsl r2		/* factor in the index number */

	mcr	p15, 0, r11, c7, c10, 2		// clean by set/way

	subs	r9, r9, #1			/* decrement the way number */
	bge	.cloop3
	subs	r7, r7, #1			/* decrement the index */
	bge	.cloop2
.cskip:
	add	r10, r10, #2			/* increment the cache number */
	cmp	r3, r10
	bgt	.cloop1

.cfinished:
	mov	r10, #0				/* swith back to cache level 0 */
	mcr	p15, 2, r10, c0, c0, 0		/* select current cache level in cssr */
	dsb
	isb

	dmb

	pop {r0-r12, pc}

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
	push	{r0 - r12, lr}

	mrc	p15, 1, r0, c0, c0, 1		/* read CLIDR */
	ands	r3, r0, #0x7000000
	mov	r3, r3, lsr #23			/* cache level value (naturally aligned) */
	beq	.cifinished
	mov	r10, #0				/* start with level 0 */
.ciloop1:
	add	r2, r10, r10, lsr #1		/* work out 3xcachelevel */
	mov	r1, r0, lsr r2			/* bottom 3 bits are the Cache type for this level */
	and	r1, r1, #7			/* get those 3 bits alone */
	cmp	r1, #2
	blt	.ciskip				/* no cache or only instruction cache at this level */
	mcr	p15, 2, r10, c0, c0, 0		/* write the Cache Size selection register */
	isb					/* isb to sync the change to the CacheSizeID reg */
	mrc	p15, 1, r1, c0, c0, 0		/* reads current Cache Size ID register */
	and	r2, r1, #7			/* extract the line length field */
	add	r2, r2, #4			/* add 4 for the line length offset (log2 16 bytes) */
	ldr	r4, =0x3ff
	ands	r4, r4, r1, lsr #3		/* r4 is the max number on the way size (right aligned) */
	clz	r5, r4				/* r5 is the bit position of the way size increment */
	ldr	r7, =0x7fff
	ands	r7, r7, r1, lsr #13		/* r7 is the max number of the index size (right aligned) */
.ciloop2:
	mov	r9, r4				/* r9 working copy of the max way size (right aligned) */
.ciloop3:
	orr	r11, r10, r9, lsl r5		/* factor in the way number and cache number into r11 */
	orr	r11, r11, r7, lsl r2		/* factor in the index number */

	mcr	p15, 0, r11, c7, c6, 2		// invalidate by set/way
	mcr	p15, 0, r11, c7, c10, 2		// clean by set/way
	//mcr	p15, 0, r11, c7, c12, 2		// clean and invilidate by set/way --> undefined instruction thrown! ??????

	subs	r9, r9, #1			/* decrement the way number */
	bge	.ciloop3
	subs	r7, r7, #1			/* decrement the index */
	bge	.ciloop2
.ciskip:
	add	r10, r10, #2			/* increment the cache number */
	cmp	r3, r10
	bgt	.ciloop1

.cifinished:
	mov	r10, #0				/* swith back to cache level 0 */
	mcr	p15, 2, r10, c0, c0, 0		/* select current cache level in cssr */
	dsb
	isb

	dmb
	
	pop {r0-r12, pc}
