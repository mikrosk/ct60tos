#ifndef _DMAPOOL_H
#define	_DMAPOOL_H

void *dma_alloc_coherent(unsigned long size, unsigned long *dma_handle, int gfp);
void dma_free_coherent(unsigned long size, void *vaddr, unsigned long dma_handle);
struct dma_pool *dma_pool_create(const char *name, unsigned long size, unsigned long align, unsigned long allocation);
void dma_pool_destroy(struct dma_pool *pool);
void *dma_pool_alloc(struct dma_pool *pool, int mem_flags, unsigned long *handle);
void dma_pool_free(struct dma_pool *pool, void *vaddr, unsigned long addr);

#endif

