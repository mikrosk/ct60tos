#include <mint/osbind.h>
//#include <linux/device.h>
//#include <linux/mm.h>
//#include <linux/dma-mapping.h>
//#include "dmapool.h"
#include "usb.h"
//#include <linux/slab.h>
//#include <linux/module.h>

#ifndef BITS_PER_LONG
#define BITS_PER_LONG sizeof(long)
#endif
#ifndef PAGE_SIZE
#define PAGE_SIZE 4096
#endif

/*
 * Pool allocator ... wraps the dma_alloc_coherent page allocator, so
 * small blocks are easily used by drivers for bus mastering controllers.
 * This should probably be sharing the guts of the slab allocator.
 */

struct dma_pool {	/* the pool */
	struct list_head	page_list;
	unsigned long			blocks_per_page;
	unsigned long			size;
	unsigned long			allocation;
	char			name [32];
	struct list_head	pools;
};

struct dma_page {	/* cacheable header for 'allocation' bytes */
	struct list_head	page_list;
	void			*vaddr;
	unsigned long		dma;
	unsigned		in_use;
	unsigned long		bitmap [0];
};

void *dma_alloc_coherent(unsigned long size, unsigned long *dma_handle, int gfp)
{
	void *ret;
	if(gfp);
	ret =	(void *)Mxalloc(size,2);
	if(ret != NULL)
	{
		_memset((char *)ret, 0, size);
		*dma_handle = (unsigned long)ret;
	}
	return(ret);
}

void dma_free_coherent(unsigned long size, void *vaddr, unsigned long dma_handle)
{
	if(size);
	if(dma_handle);
	Mfree(vaddr);
}

/**
 * dma_pool_create - Creates a pool of consistent memory blocks, for dma.
 * @name: name of pool, for diagnostics
 * @size: size of the blocks in this pool.
 * @align: alignment requirement for blocks; must be a power of two
 * @allocation: returned blocks won't cross this boundary (or zero)
 * Context: !in_interrupt()
 *
 * Returns a dma allocation pool with the requested characteristics, or
 * null if one can't be created.  Given one of these pools, dma_pool_alloc()
 * may be used to allocate memory.  Such memory will all have "consistent"
 * DMA mappings, accessible by the device and its driver without using
 * cache flushing primitives.  The actual size of blocks allocated may be
 * larger than requested because of alignment.
 *
 * If allocation is nonzero, objects returned from dma_pool_alloc() won't
 * cross that size boundary.  This is useful for devices which have
 * addressing restrictions on individual DMA transfers, such as not crossing
 * boundaries of 4KBytes.
 */
struct dma_pool *dma_pool_create (const char *name, unsigned long size, unsigned long align, unsigned long allocation)
{
	struct dma_pool		*retval;
	int i;

	if (align == 0)
		align = 1;
	if (size == 0)
		return NULL;
	else if (size < align)
		size = align;
	else if ((size % align) != 0) {
		size += align + 1;
		size &= ~(align - 1);
	}
	if(allocation == 0)
	{
		if(PAGE_SIZE < size)
			allocation = size;
		else
			allocation = PAGE_SIZE;
		// FIXME: round up for less fragmentation
	}
	else if(allocation < size)
		return NULL;
	if(!(retval = (struct dma_pool	*)Mxalloc(sizeof *retval, 3)))
		return retval;
 	i=0;
 	while(i < sizeof(retval->name)-1 && name[i])
 	{
		retval->name[i] = name[i];
		i++; 	
 	}
	if(name[i])
		retval->name[i] = 0;
	INIT_LIST_HEAD (&retval->page_list);
	retval->size = size;
	retval->allocation = allocation;
	retval->blocks_per_page = allocation / size;
	INIT_LIST_HEAD (&retval->pools);
	return retval;
}

static struct dma_page *pool_alloc_page (struct dma_pool *pool, unsigned int mem_flags)
{
	struct dma_page	*page;
	int		mapsize;

	mapsize = pool->blocks_per_page;
	mapsize = (mapsize + BITS_PER_LONG - 1) / BITS_PER_LONG;
	mapsize *= sizeof (long);

	page = (struct dma_page *) Mxalloc (mapsize + sizeof *page, mem_flags);
	if(!page)
		return NULL;
	page->vaddr = dma_alloc_coherent (pool->allocation, &page->dma, mem_flags);
	if(page->vaddr)
	{
		_memset((unsigned char *)page->bitmap, 0xff, mapsize);	// bit set == free
		list_add (&page->page_list, &pool->page_list);
		page->in_use = 0;
	}
	else
	{
		Mfree(page);
		page = NULL;
	}
	return page;
}

static inline int is_page_busy (int blocks, unsigned long *bitmap)
{
	while (blocks > 0) {
		if (*bitmap++ != ~0UL)
			return 1;
		blocks -= BITS_PER_LONG;
	}
	return 0;
}

static void pool_free_page (struct dma_pool *pool, struct dma_page *page)
{
	unsigned long	dma = page->dma;
	dma_free_coherent(pool->allocation, page->vaddr, dma);
	list_del(&page->page_list);
	Mfree(page);
}

/**
 * dma_pool_destroy - destroys a pool of dma memory blocks.
 * @pool: dma pool that will be destroyed
 * Context: !in_interrupt()
 *
 * Caller guarantees that no more memory from the pool is in use,
 * and that nothing will try to use the pool after this call.
 */
void dma_pool_destroy (struct dma_pool *pool)
{
	list_del (&pool->pools);
	while(!list_empty (&pool->page_list))
	{
		struct dma_page *page;
		page = list_entry (pool->page_list.next, struct dma_page, page_list);
		if(is_page_busy (pool->blocks_per_page, page->bitmap))
		{
			/* leak the still-in-use consistent memory */
			list_del(&page->page_list);
			Mfree(page);
		}
		else
			pool_free_page (pool, page);
	}
	Mfree(pool);
}

/**
 * dma_pool_alloc - get a block of consistent memory
 * @pool: dma pool that will produce the block
 * @mem_flags: GFP_* bitmask
 * @handle: pointer to dma address of block
 *
 * This returns the kernel virtual address of a currently unused block,
 * and reports its dma address through the handle.
 * If such a memory block can't be allocated, null is returned.
 */
void * dma_pool_alloc (struct dma_pool *pool, int mem_flags, unsigned long *handle)
{
	struct dma_page *page;
	int	map, block;
	unsigned long offset;
	void	*retval;
	list_for_each_entry(page, &pool->page_list, page_list)
	{
		int		i;
		/* only cachable accesses here ... */
		for (map = 0, i = 0; i < pool->blocks_per_page;	i += BITS_PER_LONG, map++)
		{
			if (page->bitmap [map] == 0)
				continue;
			block = ffz (~ page->bitmap [map]);
			if((i + block) < pool->blocks_per_page)
			{
				clear_bit (block, &page->bitmap [map]);
				offset = (BITS_PER_LONG * map) + block;
				offset *= pool->size;
				goto ready;
			}
		}
	}
	if(!(page = pool_alloc_page(pool, 2)))
	{
		retval = NULL;
		goto done;
	}
	clear_bit(0, &page->bitmap [0]);
	offset = 0;
ready:
	page->in_use++;
	retval = offset + page->vaddr;
	*handle = offset + page->dma;
done:
	return retval;
}

static struct dma_page *pool_find_page(struct dma_pool *pool, unsigned long dma)
{
	struct dma_page	*page;
	list_for_each_entry(page, &pool->page_list, page_list)
	{
		if(dma < page->dma)
			continue;
		if(dma < (page->dma + pool->allocation))
			goto done;
	}
	page = NULL;
done:
	return page;
}


/**
 * dma_pool_free - put block back into dma pool
 * @pool: the dma pool holding the block
 * @vaddr: virtual address of block
 * @dma: dma address of block
 *
 * Caller promises neither device nor driver will again touch this block
 * unless it is first re-allocated.
 */
void dma_pool_free(struct dma_pool *pool, void *vaddr, unsigned long dma)
{
	struct dma_page *page;
	unsigned long	map, block;
	if((page = pool_find_page(pool, dma)) == 0)
		return;
	block = dma - page->dma;
	block /= pool->size;
	map = block / BITS_PER_LONG;
	block %= BITS_PER_LONG;
	page->in_use--;
	set_bit(block, &page->bitmap [map]);
}
