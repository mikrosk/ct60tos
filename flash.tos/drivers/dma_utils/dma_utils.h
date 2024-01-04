#ifndef _DMA_UTILS_H_
#define _DMA_UTILS_H_


int dma_transfer(char *src, char *dest, int size, int width, int src_incr, int dest_incr, int step);
int dma_status(void);
void wait_dma(void);

#endif /* _DMA_UTILS_H_ */
